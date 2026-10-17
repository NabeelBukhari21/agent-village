#!/usr/bin/env python3
"""
Agent Village server — runs real AI agents on this Mac for the Agent Village app.

Each task is executed by the Claude Code CLI in headless mode (`claude -p`), so it
uses your Claude Code subscription — no API key or extra cost. The server streams
each agent's progress to the app, and pauses for your approval before anything
risky (sending email, changing files, running commands that modify your Mac).

Run:   python3 server/village_server.py
Then:  enter the pairing code it prints into the app (Menu → Connect to Mac).

Only Python's standard library is used.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse
from urllib.request import Request, urlopen

PORT = int(os.environ.get("VILLAGE_PORT", "8787"))
HOME = Path.home()
DATA = Path(os.environ.get("VILLAGE_DATA", HOME / "AgentVillageServer"))
WORKSPACE = DATA / "workspace"
REPORTS = DATA / "reports"
STATE_FILE = DATA / "tasks.json"
TOKEN_FILE = DATA / "pairing.token"
PUSH_TOPIC_FILE = DATA / "ntfy.topic"
PUSH_CONF_FILE = DATA / "push.json"
NTFY_SERVER = os.environ.get("VILLAGE_NTFY_SERVER", "https://ntfy.sh").rstrip("/")
CLAUDE = shutil.which("claude") or "/opt/homebrew/bin/claude"

# ---------------------------------------------------------------------------
# Agents: who they are and what each may do before / after your approval
# ---------------------------------------------------------------------------

GMAIL = "mcp__claude_ai_Gmail__"
GMAIL_READ = [GMAIL + t for t in ("search_threads", "get_thread", "get_message", "list_labels", "list_drafts", "get_draft")]
GMAIL_DRAFT = [GMAIL + t for t in ("create_draft", "update_draft")]
GMAIL_ACT = [GMAIL + t for t in (
    "send_message", "reply", "forward", "label_message", "label_thread", "unlabel_message", "unlabel_thread",
    "update_message_labels", "create_label", "trash_message", "trash_thread", "untrash_message", "untrash_thread",
    "delete_draft", "mark_message_spam", "mark_thread_spam",
)]

READ_ONLY_SHELL = [f"Bash({c}:*)" for c in (
    "ls", "cat", "find", "du", "df", "ps", "top -l 1", "pmset -g", "system_profiler", "sw_vers", "uptime",
    "which", "head", "tail", "wc", "grep", "date", "mdfind", "stat", "file", "vm_stat", "sysctl", "defaults read",
    "diskutil list", "diskutil info", "networksetup -getinfo", "ifconfig", "ipconfig getifaddr", "scutil --get", "lsof -i",
)]
FILE_READ = ["Read", "Glob", "Grep"]
WEB = ["WebSearch", "WebFetch"]
NEVER = ["Bash(sudo:*)", "Bash(rm -rf /:*)", "Bash(rm -rf ~:*)", "Bash(diskutil erase:*)", "Bash(shutdown:*)",
         "Bash(reboot:*)", "Bash(halt:*)", "Bash(mkfs:*)", "Bash(dd:*)", "Bash(csrutil:*)"]

APPROVAL_RULES = """
APPROVAL PROTOCOL (very important):
- You run unattended for the user, who is watching from their phone.
- Before any action that is irreversible or affects the outside world or the user's
  system — sending/replying/forwarding email, deleting or trashing anything, moving,
  renaming or editing files, running commands that change the system, installing
  things — DO NOT do it. Instead finish your reply with exactly one block:
  <<APPROVAL>>
  A short, concrete description of exactly what you will do (for email: recipient,
  subject and full text; for files/commands: the exact paths/commands).
  <</APPROVAL>>
  Then stop. The user will approve or deny in the app.
- If the task only needs reading, searching or analysis, just do it and answer.
- When you are resumed with "APPROVED", do exactly what you proposed — nothing more.
"""

STYLE = """
VOICE: Before each tool call, write ONE very short line (under 12 words) saying what you
are about to do, in a cheerful, friendly voice — it is shown as your speech bubble.
FINAL ANSWER: concise and well structured (short headings, bullets). Lead with the
result. No preamble.
"""

AGENTS = {
    "hana": {
        "name": "Hana", "cwd": WORKSPACE,
        "persona": "You are Hana, the user's email assistant. You manage their Gmail through the Gmail tools. "
                   "You can read, search and summarize mail and create drafts freely. Sending, replying, "
                   "forwarding, labeling, trashing or marking spam needs approval.",
        "plan": GMAIL_READ + GMAIL_DRAFT,
        "act": GMAIL_READ + GMAIL_DRAFT + GMAIL_ACT,
        "turns": 40,
    },
    "ren": {
        "name": "Ren", "cwd": HOME,
        "persona": "You are Ren, the user's Mac operator and coder. You run tasks on the user's Mac "
                   "(their home folder is your working directory): answer questions about the Mac, find and "
                   "organize files, run scripts, write code. Look before you act. Anything that changes files "
                   "or the system needs approval. Never use sudo.",
        "plan": FILE_READ + READ_ONLY_SHELL + WEB,
        "act": FILE_READ + WEB + ["Bash", "Write", "Edit", "NotebookEdit"],
        "turns": 50,
    },
    "yuki": {
        "name": "Yuki", "cwd": WORKSPACE,
        "persona": "You are Yuki, the user's research assistant. Research the web thoroughly, compare "
                   "sources, and write a clear report with a short summary first and source links at the end.",
        "plan": WEB,
        "act": WEB,
        "turns": 40,
    },
    "kaito": {
        "name": "Kaito", "cwd": HOME,
        "persona": "You are Kaito, the user's data & files analyst on their Mac. Analyze files, folders, "
                   "spreadsheets/CSVs, disk usage and numbers the user gives you; explain trends plainly. "
                   "Reading and analysis are fine; writing files or running Python needs approval.",
        "plan": FILE_READ + READ_ONLY_SHELL + WEB,
        "act": FILE_READ + READ_ONLY_SHELL + WEB + ["Bash(python3:*)", "Write"],
        "turns": 40,
    },
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

lock = threading.RLock()
changed = threading.Condition(lock)
tasks: dict[str, dict] = {}
events: list[dict] = []
seq = 0
queues: dict[str, list[str]] = {a: [] for a in AGENTS}
wakeups = {a: threading.Event() for a in AGENTS}
procs: dict[str, subprocess.Popen] = {}


def now() -> float:
    return time.time()


def emit(kind: str, task: dict | None = None, **extra) -> None:
    """Append an event for the app's long-poll and wake waiting requests."""
    global seq
    with lock:
        seq += 1
        e = {"seq": seq, "type": kind, "time": now()}
        if task:
            e.update(taskId=task["id"], agent=task["agent"], title=task["title"], status=task["status"])
        e.update(extra)
        events.append(e)
        del events[:-500]
        changed.notify_all()
    if task and kind in PUSH_KINDS:
        push(kind, task)


def public(t: dict, full: bool = False) -> dict:
    keys = ["id", "agent", "title", "prompt", "status", "phase", "activity", "steps", "tokens",
            "created", "updated", "needsApproval", "proposal", "summary", "error"]
    d = {k: t.get(k) for k in keys}
    if full:
        d["result"] = t.get("result")
    return d


def save() -> None:
    """Persist tasks. Serialized so concurrent agents can't corrupt the file."""
    with lock:
        data = [{k: v for k, v in t.items() if k != "log"} for t in tasks.values()]
        tmp = STATE_FILE.with_suffix(f".{threading.get_ident()}.tmp")
        tmp.write_text(json.dumps(data, indent=1))
        tmp.replace(STATE_FILE)


def load() -> None:
    if not STATE_FILE.exists():
        return
    try:
        for t in json.loads(STATE_FILE.read_text()):
            if t.get("status") in ("running", "queued"):
                t["status"] = "failed"
                t["error"] = "Server restarted while this task was running."
            tasks[t["id"]] = t
    except Exception as ex:  # corrupted file shouldn't stop the server
        print("Could not load tasks:", ex)


def short_title(prompt: str) -> str:
    p = " ".join(prompt.split())
    return p if len(p) <= 60 else p[:57] + "..."


def create_task(agent: str, prompt: str, needs_approval: bool) -> dict:
    t = {
        "id": uuid.uuid4().hex[:12], "agent": agent, "prompt": prompt.strip(), "title": short_title(prompt),
        "status": "queued", "phase": "plan", "activity": "Waiting in line...", "steps": 0, "tokens": 0,
        "created": now(), "updated": now(), "needsApproval": needs_approval, "proposal": None,
        "summary": None, "result": None, "error": None, "session": None,
    }
    with lock:
        tasks[t["id"]] = t
        queues[agent].append(t["id"])
    save()
    emit("task_created", t)
    wakeups[agent].set()
    return t


# ---------------------------------------------------------------------------
# Phone push via ntfy (free): alerts reach the phone even when the app is closed
# ---------------------------------------------------------------------------

PUSH_KINDS = ("approval_needed", "task_done", "task_failed")
push_state = {"lastStatus": None, "lastError": None, "lastTime": None}


def push_enabled() -> bool:
    try:
        return bool(json.loads(PUSH_CONF_FILE.read_text()).get("enabled"))
    except (OSError, ValueError):
        return False


def push_topic() -> str:
    """A random, unguessable ntfy topic — anyone who knows it can read the alerts."""
    if not PUSH_TOPIC_FILE.exists():
        alphabet = "abcdefghijkmnpqrstuvwxyz23456789"
        PUSH_TOPIC_FILE.write_text("village-" + "".join(secrets.choice(alphabet) for _ in range(22)))
        PUSH_TOPIC_FILE.chmod(0o600)
    return PUSH_TOPIC_FILE.read_text().strip()


def set_push(enabled: bool) -> None:
    PUSH_CONF_FILE.write_text(json.dumps({"enabled": enabled}))
    PUSH_CONF_FILE.chmod(0o600)


def push(kind: str, task: dict | None) -> None:
    """Send a short alert to ntfy. Privacy: only the agent's name and the task title
    ever leave the Mac — never proposals, results, email contents or the pairing code."""
    if task is not None and not push_enabled():
        return
    name = AGENTS.get(task["agent"], {}).get("name", "An agent") if task else "Agent Village"
    title = task["title"] if task else ""
    msg = {
        "approval_needed": (f"{name} needs your approval", title, ["bell"], 4),
        "task_done": (f"{name} finished a quest", title, ["white_check_mark"], 3),
        "task_failed": (f"{name} couldn't finish", title, ["x"], 3),
        "test": ("Agent Village", "Test alert: phone push is working!", ["tada"], 3),
    }[kind]
    link = "agentvillage://open"
    if task:
        link += "?" + urlencode({"task": task["id"], "agent": task["agent"]})
    body = {"topic": push_topic(), "title": msg[0], "message": msg[1] or msg[0], "tags": msg[2],
            "priority": msg[3], "click": link}
    threading.Thread(target=send_push, args=(body,), daemon=True).start()


def send_push(body: dict) -> None:
    req = Request(NTFY_SERVER, data=json.dumps(body).encode(), method="POST",
                  headers={"Content-Type": "application/json", "User-Agent": "AgentVillage/1.0"})
    try:
        with urlopen(req, timeout=15) as resp:
            push_state.update(lastStatus=resp.status, lastError=None, lastTime=now())
    except Exception as ex:
        push_state.update(lastStatus=getattr(ex, "code", None), lastError=str(ex)[:200], lastTime=now())
        print("Push failed:", ex)


def push_info() -> dict:
    return {"enabled": push_enabled(), "topic": push_topic(), "server": NTFY_SERVER,
            "subscribeURL": f"{NTFY_SERVER}/{push_topic()}", **push_state}


# ---------------------------------------------------------------------------
# Running Claude Code
# ---------------------------------------------------------------------------

def friendly(tool: str, inp: dict) -> str:
    """Turn a tool call into a short speech-bubble line."""
    t = tool.replace(GMAIL, "gmail:")
    if t == "WebSearch":
        return f"Searching: {inp.get('query', '')}"[:80]
    if t == "WebFetch":
        url = inp.get("url", "")
        host = urlparse(url).netloc or url
        return f"Reading {host}"[:80]
    if t.startswith("gmail:"):
        name = t.split(":", 1)[1]
        return {
            "search_threads": "Searching your inbox...", "get_thread": "Reading an email thread...",
            "get_message": "Reading an email...", "create_draft": "Writing a draft...",
            "update_draft": "Polishing the draft...", "send_message": "Sending the email!",
            "reply": "Sending the reply!", "forward": "Forwarding the email!", "list_labels": "Checking your labels...",
        }.get(name, f"Gmail: {name.replace('_', ' ')}")
    if t == "Bash":
        return f"Running: {inp.get('command', '')}"[:80]
    if t in ("Read", "Write", "Edit"):
        return f"{ {'Read': 'Reading', 'Write': 'Writing', 'Edit': 'Editing'}[t] } {Path(inp.get('file_path', '')).name}"[:80]
    if t in ("Glob", "Grep"):
        return "Looking through files..."
    if t == "ToolSearch":
        return "Getting my tools ready..."
    return f"Using {t}"


APPROVAL_RE = re.compile(r"<<APPROVAL>>(.*?)<</APPROVAL>>", re.S)


def run_claude(task: dict, prompt: str, phase: str) -> None:
    spec = AGENTS[task["agent"]]
    allowed = spec["plan"] if phase == "plan" else spec["act"]
    system = spec["persona"] + "\n" + APPROVAL_RULES + "\n" + STYLE
    if task["needsApproval"] and phase == "plan":
        system += ("\nThe user asked to review your work before you finish: prepare everything, then present "
                   "your final result inside the APPROVAL block and stop.")
    cmd = [CLAUDE, "-p", prompt, "--output-format", "stream-json", "--verbose",
           "--append-system-prompt", system, "--max-turns", str(spec["turns"]),
           "--allowedTools", ",".join(allowed), "--disallowedTools", ",".join(NEVER)]
    if phase == "act":
        cmd += ["--permission-mode", "acceptEdits"]
    if task.get("session"):
        cmd += ["--resume", task["session"]]

    spec["cwd"].mkdir(parents=True, exist_ok=True)
    proc = subprocess.Popen(cmd, cwd=spec["cwd"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1,
                            env={**os.environ, "CLAUDE_CODE_ENTRYPOINT": "agent-village"})
    procs[task["id"]] = proc
    final = None
    for line in proc.stdout:  # stream-json: one JSON object per line
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = msg.get("type")
        if msg.get("session_id"):
            task["session"] = msg["session_id"]
        if kind == "assistant":
            for block in msg.get("message", {}).get("content", []):
                text = None
                if block.get("type") == "text" and block.get("text", "").strip():
                    first = block["text"].strip().splitlines()[0]
                    if not first.startswith(("<<", "#", "-", "*", "|")) and len(first) < 140:
                        text = first
                elif block.get("type") == "tool_use":
                    task["steps"] += 1
                    text = friendly(block.get("name", ""), block.get("input", {}) or {})
                if text:
                    task["activity"] = text
                    task["updated"] = now()
                    emit("activity", task, text=text, steps=task["steps"])
        elif kind == "result":
            final = msg
    proc.wait()
    procs.pop(task["id"], None)
    err = proc.stderr.read().strip() if proc.stderr else ""

    if task["status"] == "cancelled":
        return
    if final is None or final.get("is_error"):
        reason = (final or {}).get("result") or err or "The agent stopped unexpectedly."
        if "login" in reason.lower():
            reason = "Claude Code isn't logged in on the Mac. Run `claude` and /login."
        task.update(status="failed", error=reason[:500], updated=now())
        save()
        emit("task_failed", task, text=task["error"])
        return

    usage = final.get("usage", {}) or {}
    task["tokens"] += sum(int(usage.get(k, 0) or 0) for k in
                          ("input_tokens", "output_tokens", "cache_creation_input_tokens"))
    result = final.get("result", "") or ""
    m = APPROVAL_RE.search(result)
    if m and phase == "plan":
        task.update(status="awaiting_approval", proposal=m.group(1).strip(),
                    summary=APPROVAL_RE.sub("", result).strip()[:4000], updated=now(),
                    activity="Waiting for your approval!")
        save()
        emit("approval_needed", task, text=task["proposal"][:2000])
        return
    task.update(status="done", result=result, summary=result.strip()[:300], updated=now(), activity="Quest complete!")
    (REPORTS / f"{task['id']}.md").write_text(f"# {task['title']}\n\nAgent: {task['agent']}\n\n{result}\n")
    save()
    emit("task_done", task, text=task["summary"])


def worker(agent: str) -> None:
    while True:
        try:
            work_queue(agent)
        except Exception as ex:  # keep the agent alive no matter what
            print(f"[{agent}] worker error:", ex)
            time.sleep(1)


def work_queue(agent: str) -> None:
    while True:
        wakeups[agent].wait()
        wakeups[agent].clear()
        while True:
            with lock:
                if not queues[agent]:
                    break
                tid = queues[agent].pop(0)
                task = tasks.get(tid)
            if not task or task["status"] not in ("queued", "approved"):
                continue
            phase = "act" if task["status"] == "approved" else "plan"
            prompt = task["prompt"] if phase == "plan" else "APPROVED by the user. Carry out exactly what you proposed, nothing more, then report what you did."
            task.update(status="running", phase=phase, updated=now(), activity="Getting started...")
            save()
            emit("task_started", task)
            try:
                run_claude(task, prompt, phase)
            except Exception as ex:
                task.update(status="failed", error=str(ex)[:500], updated=now())
                save()
                emit("task_failed", task, text=task["error"])


def decide(task: dict, approve: bool, note: str = "") -> None:
    if task["status"] != "awaiting_approval":
        return
    if approve:
        task.update(status="approved", updated=now(), activity="Approved! On it...")
        emit("approved", task)
        with lock:
            queues[task["agent"]].insert(0, task["id"])
        wakeups[task["agent"]].set()
    else:
        task.update(status="cancelled", updated=now(), activity="Okay, I'll drop it.", error="Denied by you.")
        emit("denied", task)
    save()


def cancel(task: dict) -> None:
    task.update(status="cancelled", updated=now(), activity="Cancelled.")
    p = procs.get(task["id"])
    if p:
        p.terminate()
    with lock:
        if task["id"] in queues[task["agent"]]:
            queues[task["agent"]].remove(task["id"])
    save()
    emit("cancelled", task)


# ---------------------------------------------------------------------------
# HTTP API
# ---------------------------------------------------------------------------

TOKEN = ""


class Handler(BaseHTTPRequestHandler):
    server_version = "AgentVillage/1.0"

    def log_message(self, fmt, *args):  # quieter console
        pass

    def send_json(self, obj, status=HTTPStatus.OK):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authed(self) -> bool:
        ok = secrets.compare_digest(self.headers.get("X-Village-Token", ""), TOKEN)
        if not ok:
            time.sleep(0.5)  # slow down guessing
            self.send_json({"error": "Bad pairing code"}, HTTPStatus.UNAUTHORIZED)
        return ok

    def body(self) -> dict:
        n = int(self.headers.get("Content-Length", "0") or 0)
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except json.JSONDecodeError:
            return {}

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/api/ping":
            return self.send_json({"app": "agent-village", "name": socket.gethostname(), "version": 1})
        if not self.authed():
            return
        if url.path == "/api/state":
            with lock:
                recent = sorted(tasks.values(), key=lambda t: t["created"])[-60:]
                return self.send_json({"seq": seq, "tasks": [public(t) for t in recent],
                                       "agents": list(AGENTS.keys()), "machine": socket.gethostname()})
        if url.path == "/api/events":
            q = parse_qs(url.query)
            after = int(q.get("after", ["0"])[0])
            wait = min(25.0, float(q.get("wait", ["20"])[0]))
            deadline = time.time() + wait
            with changed:
                while seq <= after and time.time() < deadline:
                    changed.wait(timeout=max(0.1, deadline - time.time()))
                out = [e for e in events if e["seq"] > after]
            return self.send_json({"seq": seq, "events": out})
        if url.path == "/api/push":
            return self.send_json(push_info())
        m = re.fullmatch(r"/api/tasks/([0-9a-f]+)", url.path)
        if m and m.group(1) in tasks:
            return self.send_json(public(tasks[m.group(1)], full=True))
        self.send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)

    def do_POST(self):
        url = urlparse(self.path)
        if not self.authed():
            return
        data = self.body()
        if url.path == "/api/tasks":
            agent, prompt = data.get("agent"), (data.get("prompt") or "").strip()
            if agent not in AGENTS or not prompt:
                return self.send_json({"error": "Need a valid agent and prompt"}, HTTPStatus.BAD_REQUEST)
            return self.send_json(public(create_task(agent, prompt, bool(data.get("needsApproval")))))
        if url.path == "/api/push":
            if "enabled" in data:
                set_push(bool(data["enabled"]))
            if data.get("test"):
                push("test", None)
            return self.send_json(push_info())
        m = re.fullmatch(r"/api/tasks/([0-9a-f]+)/(approve|deny|cancel)", url.path)
        if m and m.group(1) in tasks:
            t = tasks[m.group(1)]
            if m.group(2) == "approve":
                decide(t, True)
            elif m.group(2) == "deny":
                decide(t, False)
            else:
                cancel(t)
            return self.send_json(public(t))
        self.send_json({"error": "Not found"}, HTTPStatus.NOT_FOUND)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

def lan_ip() -> str:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except OSError:
        return "127.0.0.1"


def tailscale_ips() -> list[str]:
    """Addresses in Tailscale's 100.64.0.0/10 range, if Tailscale is running."""
    try:
        out = subprocess.run(["ifconfig"], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return []
    ips = re.findall(r"inet (100\.(\d+)\.\d+\.\d+)", out)
    return [ip for ip, second in ips if 64 <= int(second) <= 127]


def main() -> None:
    global TOKEN
    for d in (DATA, WORKSPACE, REPORTS):
        d.mkdir(parents=True, exist_ok=True)
    if not TOKEN_FILE.exists():
        alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        TOKEN_FILE.write_text("".join(secrets.choice(alphabet) for _ in range(8)))
        TOKEN_FILE.chmod(0o600)
    TOKEN = TOKEN_FILE.read_text().strip()
    load()

    for a in AGENTS:
        threading.Thread(target=worker, args=(a,), daemon=True).start()

    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    bonjour = subprocess.Popen(["dns-sd", "-R", f"Agent Village ({socket.gethostname().split('.')[0]})",
                                "_agentvillage._tcp", "local", str(PORT)],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    awake = subprocess.Popen(["caffeinate", "-i", "-w", str(os.getpid())])

    def stop(*_):
        bonjour.terminate()
        awake.terminate()
        for p in list(procs.values()):
            p.terminate()
        os._exit(0)

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    print("\n  🏯  Agent Village server is running")
    print(f"      Address:      {lan_ip()}:{PORT}   (also found automatically on your Wi-Fi)")
    for ip in tailscale_ips():
        print(f"      Away address: {ip}:{PORT}   (Tailscale — works from anywhere)")
    print(f"      Pairing code: {TOKEN}")
    print(f"      Data folder:  {DATA}")
    print(f"      Claude Code:  {CLAUDE}\n")
    print("  In the app: MENU → CONNECT TO MAC, then enter the pairing code.\n")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
