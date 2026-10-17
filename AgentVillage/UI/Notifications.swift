import SwiftUI

// MARK: Styling per kind

extension AppNotice.Kind {
    var icon: String {
        switch self {
        case .approval: "ask"
        case .done: "check"
        case .failed: "cross"
        case .started: "sword"
        case .live: "work"
        case .info: "scroll"
        }
    }

    /// (top, bottom, accent) colors for the banner window.
    var colors: (UInt32, UInt32, UInt32) {
        switch self {
        case .approval: (0x7A2A12, 0x3E1408, 0xFFD23F)
        case .done: (0x1F6A44, 0x0D3622, 0x7DFFA8)
        case .failed: (0x8A2038, 0x45101E, 0xFF8FA3)
        case .started: (0x2A3A8C, 0x141C4A, 0x9EF6FF)
        case .live: (0x1F5A6A, 0x0D2C36, 0x7DFFE8)
        case .info: (0x34306E, 0x1E1B48, 0xF4E9D0)
        }
    }

    var expression: Expression {
        switch self {
        case .approval: .surprised
        case .done, .live: .happy
        case .failed: .sad
        default: .normal
        }
    }
}

// MARK: Banner stack

struct BannerStack: View {
    let model: WorldModel
    var onOpen: (AppNotice) -> Void
    var onRead: (String) -> Void
    @Environment(\.pixelScale) private var ps

    var body: some View {
        VStack(spacing: 4 * ps.ui) {
            ForEach(model.banners) { n in
                NoticeBanner(notice: n, model: model, onOpen: onOpen, onRead: onRead)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .scale(scale: 0.6, anchor: .top)).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: model.banners)
    }
}

/// One animated notification banner.
struct NoticeBanner: View {
    let notice: AppNotice
    let model: WorldModel
    var onOpen: (AppNotice) -> Void
    var onRead: (String) -> Void
    @Environment(\.pixelScale) private var ps
    @State private var appeared = Date()
    @State private var drag: CGSize = .zero
    @State private var bounce = false

    var body: some View {
        let (top, bottom, accent) = notice.kind.colors
        let agent = notice.agentID.flatMap { model.agent($0) }

        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(appeared)
            HStack(alignment: .center, spacing: 5 * ps.ui) {
                avatar(agent, accent: accent, t: t)
                VStack(alignment: .leading, spacing: 2 * ps.ui) {
                    HStack(spacing: 3 * ps.ui) {
                        PixelIcon(name: notice.kind.icon, scale: ps.small)
                        PixelText(text: notice.title, color: accent, outline: 0x100A1E)
                    }
                    PixelParagraph(text: notice.body, maxWidth: 230, color: 0xFFFFFF, size: ps.small)
                    actions(agent)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6 * ps.ui)
            .padding(.vertical, 5 * ps.ui)
            .frame(maxWidth: 420)
            .background(alignment: .leading) {
                // Accent stripe
                Rectangle().fill(Color(hex: accent)).frame(width: 2 * ps.ui).padding(.vertical, 2 * ps.ui).padding(.leading, 2 * ps.ui)
            }
            .overlay { shine(t: t) }
            .overlay(alignment: .bottom) { countdown(t: t, accent: accent) }
            .pixelWindow(top: top, bottom: bottom, accent: notice.kind == .approval && Int(t * 3) % 2 == 0 ? accent : 0xF4E9D0)
            .shadow(color: Color(hex: accent, opacity: 0.55), radius: 10)
            // Gentle wobble on approvals so they get noticed
            .rotationEffect(.degrees(notice.kind == .approval ? sin(t * 14) * max(0, 1.2 - t.truncatingRemainder(dividingBy: 4)) * 1.5 : 0))
        }
        .offset(x: drag.width, y: min(0, drag.height))
        .opacity(1 - min(0.8, abs(drag.width) / 300))
        .gesture(
            DragGesture(minimumDistance: 8)
                .onChanged { drag = $0.translation }
                .onEnded { v in
                    if abs(v.translation.width) > 90 || v.translation.height < -40 {
                        model.dismissBanner(notice.id)
                    } else {
                        withAnimation(.spring) { drag = .zero }
                    }
                }
        )
        .onTapGesture {
            model.markRead(notice.id)
            onOpen(notice)
        }
    }

    private func avatar(_ agent: AgentState?, accent: UInt32, t: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(hex: accent, opacity: 0.55), .clear], center: .center, startRadius: 2, endRadius: 30 * ps.small))
                .frame(width: 44 * ps.small, height: 44 * ps.small)
                .scaleEffect(1 + 0.08 * sin(t * 5))
            if let agent {
                PixelUI.portraitImage(agent.persona, notice.kind.expression)
                    .resizable().interpolation(.none)
                    .frame(width: 32 * ps.small, height: 32 * ps.small)
                    .offset(y: t < 0.5 ? -sin(t * .pi * 2) * 6 : 0)
            } else {
                PixelIcon(name: notice.kind.icon, scale: ps.title)
            }
            if notice.kind == .done { Sparkles(t: t, color: accent) }
        }
        .frame(width: 40 * ps.small, height: 40 * ps.small)
    }

    @ViewBuilder
    private func actions(_ agent: AgentState?) -> some View {
        switch notice.kind {
        case .approval:
            if let waiting = model.waitingAgent(for: notice) {
                HStack(spacing: 3 * ps.ui) {
                    PixelActionButton(title: "APPROVE", icon: "check", style: .good) {
                        model.approve(waiting)
                        model.dismissBanner(notice.id)
                    }
                    PixelActionButton(title: "DENY", icon: "cross", style: .bad) {
                        model.deny(waiting)
                        model.dismissBanner(notice.id)
                    }
                    PixelActionButton(title: "VIEW") {
                        model.markRead(notice.id)
                        onOpen(notice)
                    }
                }
                .padding(.top, 2 * ps.ui)
            }
        case .done:
            if let rid = notice.resultID, model.results.contains(where: { $0.id == rid }) {
                PixelActionButton(title: "READ REPORT", icon: "scroll", style: .accent) {
                    model.dismissBanner(notice.id)
                    onRead(rid)
                }
                .padding(.top, 2 * ps.ui)
            }
        default:
            EmptyView()
        }
    }

    /// A light band that sweeps across the banner once when it appears.
    private func shine(t: Double) -> some View {
        GeometryReader { g in
            let p = min(1.4, t / 0.7)
            LinearGradient(colors: [.clear, .white.opacity(0.35), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 60)
                .rotationEffect(.degrees(20))
                .offset(x: -80 + (g.size.width + 160) * p)
                .opacity(p < 1.3 ? 1 : 0)
        }
        .allowsHitTesting(false)
        .clipped()
    }

    @ViewBuilder
    private func countdown(t: Double, accent: UInt32) -> some View {
        if let exp = notice.expires {
            let total = exp.timeIntervalSince(notice.date)
            let left = max(0, 1 - t / max(0.1, total))
            GeometryReader { g in
                Rectangle()
                    .fill(Color(hex: accent, opacity: 0.85))
                    .frame(width: g.size.width * left, height: 1.5 * ps.ui)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 1.5 * ps.ui)
            .padding(.horizontal, 4 * ps.ui)
            .padding(.bottom, 3 * ps.ui)
            .allowsHitTesting(false)
        }
    }
}

/// Pixel sparkles that burst around a portrait.
private struct Sparkles: View {
    let t: Double
    let color: UInt32

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for i in 0..<8 {
                let a = Double(i) / 8 * 2 * .pi + t * 0.8
                let r = 10 + (t * 40).truncatingRemainder(dividingBy: 26)
                let fade = 1 - r / 36
                let p = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                let s: CGFloat = i % 2 == 0 ? 3 : 2
                ctx.fill(Path(CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)),
                         with: .color(Color(hex: i % 3 == 0 ? 0xFFFFFF : color, opacity: fade)))
            }
        }
        .frame(width: 70, height: 70)
        .allowsHitTesting(false)
    }
}

// MARK: Bell + notification center

struct BellButton: View {
    let model: WorldModel
    var action: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var ring = false

    var body: some View {
        Button {
            Chiptune.shared.play(.select)
            action()
        } label: {
            PixelIcon(name: "bell")
                .rotationEffect(.degrees(ring ? 14 : -14), anchor: .top)
                .padding(5 * ps.ui)
                .pixelWindow()
                .overlay(alignment: .topTrailing) {
                    if model.unreadCount > 0 {
                        PixelText(text: model.unreadCount > 9 ? "9+" : "\(model.unreadCount)", color: 0xFFFFFF, shadow: nil, size: ps.small)
                            .padding(.horizontal, 2 * ps.small)
                            .background(Color(hex: 0xE8366E))
                            .offset(x: 3 * ps.ui, y: -2 * ps.ui)
                            .transition(.scale)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: model.unreadCount) { old, new in
            guard new > old else { return }
            withAnimation(.easeInOut(duration: 0.09).repeatCount(6, autoreverses: true)) { ring.toggle() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { ring = false }
        }
        .animation(.spring, value: model.unreadCount)
    }
}

struct NoticeCenterPanel: View {
    let model: WorldModel
    var onOpen: (AppNotice) -> Void
    var onClose: () -> Void
    @Environment(\.pixelScale) private var ps
    @State private var unreadOnly = false

    var body: some View {
        PixelPanel(title: "ALERTS", icon: "bell", onClose: onClose) {
            VStack(alignment: .leading, spacing: 5 * ps.ui) {
                HStack(spacing: 2 * ps.ui) {
                    chip("ALL", !unreadOnly) { unreadOnly = false }
                    chip("UNREAD (\(model.unreadCount))", unreadOnly) { unreadOnly = true }
                    Spacer()
                    if model.unreadCount > 0 {
                        PixelActionButton(title: "READ ALL") { model.markAllRead() }
                    } else if !model.notices.isEmpty {
                        PixelActionButton(title: "CLEAR") { model.clearNotices() }
                    }
                }
                let list = model.notices.filter { !unreadOnly || !$0.read }
                if list.isEmpty {
                    HStack(spacing: 4 * ps.ui) {
                        PixelIcon(name: "bell", scale: ps.title)
                        PixelText(text: unreadOnly ? "You're all caught up!" : "No alerts yet.", color: 0x9AA3D6)
                    }
                    .padding(.vertical, 6 * ps.ui)
                }
                ForEach(list) { n in row(n) }
            }
        }
    }

    private func row(_ n: AppNotice) -> some View {
        let (_, _, accent) = n.kind.colors
        let agent = n.agentID.flatMap { model.agent($0) }
        return Button {
            Chiptune.shared.play(.select)
            model.markRead(n.id)
            onOpen(n)
        } label: {
            HStack(alignment: .top, spacing: 4 * ps.ui) {
                Rectangle().fill(n.read ? Color.clear : Color(hex: accent)).frame(width: 2 * ps.ui)
                if let agent {
                    PixelUI.portraitImage(agent.persona, n.kind.expression).resizable().interpolation(.none)
                        .frame(width: 24 * ps.small, height: 24 * ps.small)
                } else {
                    PixelIcon(name: n.kind.icon)
                }
                VStack(alignment: .leading, spacing: 1 * ps.ui) {
                    HStack(spacing: 3 * ps.ui) {
                        PixelIcon(name: n.kind.icon, scale: ps.small)
                        PixelText(text: n.title, color: n.read ? 0xC9D2FF : accent, shadow: nil, size: ps.small)
                        Spacer(minLength: 2)
                        PixelText(text: ago(n.date), color: 0x6A6F96, shadow: nil, size: ps.small)
                    }
                    PixelParagraph(text: n.body, maxWidth: 250, color: n.read ? 0x9AA3D6 : 0xFFFFFF, size: ps.small)
                }
            }
            .padding(3 * ps.ui)
            .background(Color(hex: 0x0C0818, opacity: n.read ? 0.2 : 0.45))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, _ on: Bool, _ action: @escaping () -> Void) -> some View {
        Button { Chiptune.shared.play(.select); action() } label: {
            PixelText(text: title, color: on ? 0xFFD23F : 0xC9D2FF, shadow: nil)
                .padding(.horizontal, 4 * ps.ui).padding(.vertical, 2 * ps.ui)
                .background(on ? Color(hex: 0x4A3A8C) : Color(hex: 0x0C0818, opacity: 0.35))
        }
        .buttonStyle(.plain)
    }

    private func ago(_ d: Date) -> String {
        let s = Int(Date().timeIntervalSince(d))
        if s < 60 { return "NOW" }
        if s < 3600 { return "\(s / 60)M AGO" }
        return "\(s / 3600)H AGO"
    }
}
