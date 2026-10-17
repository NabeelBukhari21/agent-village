# Agent Village

**A pixel-art RPG dashboard for AI agents — for iPhone and Mac.**

Instead of a flat list of jobs and logs, your AI agents live in a little anime village. Each one walks to its workplace when it starts a task, shows what it's doing in speech bubbles, chats with the others in passing, and walks up to the Quest Board when it needs your approval.

<p align="center">
  <img src="docs/screenshots/dashboard.png" width="260" alt="Village overview with the stats bar and party">
  <img src="docs/screenshots/library-research.png" width="260" alt="Yuki researching at the library">
  <img src="docs/screenshots/night.png" width="260" alt="The village at night">
</p>

<p align="center">
  <img src="docs/screenshots/inbox-approval.png" width="260" alt="Approval inbox">
  <img src="docs/screenshots/new-quest.png" width="260" alt="Assigning a new quest">
  <img src="docs/screenshots/icon-light.png" width="120" alt="App icon">
  <img src="docs/screenshots/icon-dark.png" width="120" alt="Dark mode app icon">
</p>

## The agents

| Agent | Role | Workplace |
|---|---|---|
| **Hana** | Email (inbox triage, drafting replies) | Post Office |
| **Ren** | Mac operator & coder | Code Forge |
| **Yuki** | Research | Grand Library |
| **Kaito** | Data & files analysis | Star Observatory |

## Features

- **Living world** — agents path-find around the plaza, work at their stations with animated props (sparks at the forge, letters flying into the mailbox, orbiting magic books, a hologram chart), and chat when they bump into each other.
- **Human-in-the-loop approvals** — anything risky stops and waits for you. The agent walks to the Quest Board, the *Need You* counter pulses, and you approve or deny from the Inbox.
- **Assign your own quests** — pick an agent, type a task (or choose a common one), optionally require approval before it finishes. Each agent has a visible queue.
- **Dashboard panels** — Inbox, New Quest, Stats (per-agent work and usage), filterable Quest Log, Menu.
- **Day/night cycle** — lanterns and windows light up, fireflies come out.
- **Original chiptune audio** — a calm lo-fi loop and sound effects, synthesized in real time.

## How it's built

Everything is generated in code — there are no image or audio asset files besides the app icon.

- **SwiftUI + SpriteKit**, one multiplatform target for iOS and macOS.
- **Procedural pixel art** (`AgentVillage/Pixel/`): a small pixel canvas with auto-outlining, hue-shifted shading and Bayer dithering. Characters are hand-authored 16×24 palette-keyed sprites composed per agent (hair styles, outfits, expressions, walk cycles). Buildings, trees, the map and water animation are generated procedurally.
- **Custom bitmap font** — a hand-designed proportional 5×7 pixel font with word wrapping, used for all UI text and speech bubbles.
- **Real-time synthesizer** (`Game/Chiptune.swift`) — `AVAudioSourceNode` with pulse/triangle/noise voices, a sequencer for the music loop, and one-shot sound effects.
- **Simulation model** (`Model/`) — agent state machine (rest → walk → work → ask for approval → celebrate), waypoint routing around the plaza, encounters, quest queues and an event feed.
- `_archive_3d/` keeps the first prototype, a 3D RealityKit version of the village, before the project moved to pixel art.

## Status & roadmap

- [x] Pixel-art village, HUD and dashboard (agents currently run on simulated tasks)
- [x] Approvals inbox, custom quests, stats, quest log
- [ ] **Real agents**: a local "Village Server" on the Mac that runs Claude Code agents (web research, Gmail via MCP, local Mac tasks) and streams their progress to the app
- [ ] Control your Mac from your phone, from anywhere

## Running it

Open `AgentVillage.xcodeproj` in Xcode, pick an iPhone simulator, your own iPhone, or *My Mac*, and press Run. Requires Xcode 26+ (iOS 26 / macOS 26).

---

Built by **Syed Nabeel Raza**, pair-programming with Claude Code.
