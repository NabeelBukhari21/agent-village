import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var model: WorldModel
    @State private var game: VillageGame
    @State private var link: LiveLink
    @State private var panel: DashPanel?
    @State private var questAgentID = "hana"
    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnify: CGFloat = 1
    @State private var configured = false
    @State private var hudRects: [CGRect] = []
    @State private var dragBlocked = false
    @State private var insets = EdgeInsets()
    @Environment(\.displayScale) private var displayScale
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let model = WorldModel()
        _model = State(initialValue: model)
        _game = State(initialValue: VillageGame(model: model))
        _link = State(initialValue: LiveLink(model: model))
    }

    var body: some View {
        GeometryReader { geo in
            let phone = geo.size.width < 700
            let ps = PixelScale(display: displayScale, phone: phone)
            ZStack {
                SpriteView(scene: game, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .gesture(dragGesture)
                    .simultaneousGesture(magnifyGesture)
                    .simultaneousGesture(SpatialTapGesture(coordinateSpace: .named("root")).onEnded { v in
                        guard !inHUD(v.location) else { return }
                        let p = CGPoint(x: v.location.x + insets.leading, y: v.location.y + insets.top)
                        if let id = game.agent(atView: p) { select(id) }
                        else if model.selectedID != nil { select(nil) }
                    })
                    .ignoresSafeArea()

                RetroScreen().ignoresSafeArea()

                Group {
                    if phone { phoneHUD(size: geo.size) } else { desktopHUD(size: geo.size) }
                }
                .environment(\.pixelScale, ps)
            }
            .coordinateSpace(.named("root"))
            .onPreferenceChange(HUDRectsKey.self) { hudRects = $0 }
            .onAppear { insets = geo.safeAreaInsets }
            .onChange(of: geo.safeAreaInsets) { _, i in insets = i }
            .onAppear {
                guard !configured else { return }
                configured = true
                game.displayScale = displayScale
                game.size = geo.size
                game.setDefaultZoom(viewSize: geo.size)
                Chiptune.shared.start()
                SystemNotifier.shared.attach(model)
                link.autoConnect()
                openDeepLink()
            }
        }
        .background(Color(hex: 0x24452C))
        .onChange(of: scenePhase) { _, phase in SystemNotifier.shared.appActive = phase == .active }
        .onChange(of: model.isLive) { _, live in
            if live { SystemNotifier.shared.requestPermissionIfNeeded(); openDeepLink() }
        }
        .onChange(of: DeepLink.shared.pending) { _, _ in openDeepLink() }
    }

    // MARK: Layouts

    private func phoneHUD(size: CGSize) -> some View {
        VStack(spacing: 4) {
            if model.selectedID == nil && panel == nil {
                statusStrip.hudRegion()
            }
            HStack(alignment: .top, spacing: 4) {
                PartyBar(model: model, vertical: false) { select($0) }.hudRegion()
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    ClockChip(model: model, showTitle: false).hudRegion()
                    BellButton(model: model) { toggle(.alerts) }.hudRegion()
                }
            }
            BannerStack(model: model, onOpen: openNotice, onRead: { panel = .report($0) }).hudRegion()
            Spacer(minLength: 0)
            VStack(spacing: 4) { bottom(size: size) }.hudRegion()
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .animation(.easeOut(duration: 0.18), value: model.selectedID)
        .animation(.easeOut(duration: 0.18), value: panel)
    }

    private func desktopHUD(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                ClockChip(model: model, showTitle: true).hudRegion()
                BellButton(model: model) { toggle(.alerts) }.hudRegion()
                Spacer()
                statusStrip.hudRegion()
            }
            HStack(alignment: .top, spacing: 10) {
                PartyBar(model: model, vertical: true) { select($0) }.hudRegion()
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    BannerStack(model: model, onOpen: openNotice, onRead: { panel = .report($0) }).hudRegion()
                        .frame(width: 420)
                    if let panel {
                        panelView(panel)
                            .hudRegion()
                            .frame(width: 460)
                            .frame(maxHeight: size.height * 0.66)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Spacer()
                if let a = model.selected {
                    DialogueWindow(agent: a, model: model, width: 720, onNewQuest: openQuest, onRead: { id in model.selectedID = nil; panel = .report(id) }, onClose: { select(nil) })
                        .id(a.id)
                        .frame(maxWidth: 720)
                        .hudRegion()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    NavBar(model: model, current: panel, onOpen: toggle).hudRegion()
                }
                Spacer()
            }
            .overlay(alignment: .bottomTrailing) {
                if model.selectedID == nil { zoom.hudRegion() }
            }
        }
        .padding(16)
        .animation(.easeOut(duration: 0.18), value: model.selectedID)
        .animation(.easeOut(duration: 0.18), value: panel)
    }

    @ViewBuilder
    private func bottom(size: CGSize) -> some View {
        if let a = model.selected {
            DialogueWindow(agent: a, model: model, width: size.width - 20, onNewQuest: openQuest, onRead: { id in model.selectedID = nil; panel = .report(id) }, onClose: { select(nil) })
                .id(a.id)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let panel {
            panelView(panel)
                .frame(maxHeight: size.height * 0.6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            NavBar(model: model, current: panel, onOpen: toggle)
        } else {
            HStack { Spacer(); zoom }
            NavBar(model: model, current: panel, onOpen: toggle)
        }
    }

    private var statusStrip: some View {
        ViewThatFits(in: .horizontal) {
            StatusStrip(model: model, compact: false, onInbox: { toggle(.inbox) }, onStats: { toggle(.stats) })
            StatusStrip(model: model, compact: true, onInbox: { toggle(.inbox) }, onStats: { toggle(.stats) })
        }
    }

    private var zoom: some View {
        ZoomCluster(onZoomIn: { game.zoomBy(1.5) }, onZoomOut: { game.zoomBy(1 / 1.5) }, onHome: { select(nil); game.recenter() })
    }

    @ViewBuilder
    private func panelView(_ p: DashPanel) -> some View {
        switch p {
        case .log: LogPanel(model: model, onRead: { panel = .report($0) }) { panel = nil }
        case .report(let id): ReportPanel(model: model, resultID: id) { panel = .log }
        case .inbox: InboxPanel(model: model, onGoTo: { id in panel = nil; select(id) }) { panel = nil }
        case .quest: NewQuestPanel(model: model, agentID: $questAgentID) { panel = nil }
        case .stats: StatsPanel(model: model) { panel = nil }
        case .alerts: NoticeCenterPanel(model: model, onOpen: openNotice) { panel = nil }
        case .menu: MenuPanel(model: model, link: link, onRecenter: { panel = nil; select(nil); game.recenter() }) { panel = nil }
        }
    }

    // MARK: Actions

    private func toggle(_ p: DashPanel) {
        model.selectedID = nil
        panel = panel == p ? nil : p
    }

    private func openQuest(_ agentID: String) {
        questAgentID = agentID
        model.selectedID = nil
        panel = .quest
    }

    /// Where tapping a notification takes you.
    private func openNotice(_ n: AppNotice) {
        switch n.kind {
        case .approval where model.waitingAgent(for: n) != nil:
            panel = nil
            select(n.agentID)
        case .done:
            if let rid = n.resultID, model.results.contains(where: { $0.id == rid }) {
                model.selectedID = nil
                panel = .report(rid)
            } else {
                panel = nil
                select(n.agentID)
            }
        case .live, .info:
            model.selectedID = nil
            panel = .menu
        default:
            if let id = n.agentID { panel = nil; select(id) }
        }
    }

    /// Opens what a phone push alert points at: the agent waiting on that task, or its report.
    private func openDeepLink() {
        guard let target = DeepLink.shared.pending else { return }
        if let tid = target.taskID, let a = model.agents.first(where: { $0.task?.serverID == tid }) {
            DeepLink.shared.pending = nil
            select(a.id)
        } else if let tid = target.taskID, model.results.contains(where: { $0.id == tid }) {
            DeepLink.shared.pending = nil
            model.selectedID = nil
            panel = .report(tid)
        } else if link.isConnected, let tid = target.taskID {
            DeepLink.shared.pending = nil
            Task {
                let t = await link.task(tid)
                if let t, t.status == "done", let text = t.result {
                    model.storeResult(t.agent, serverID: t.id, title: t.title, text: text)
                    model.selectedID = nil
                    panel = .report(t.id)
                } else if let agentID = t?.agent ?? target.agentID {
                    select(agentID)
                }
            }
        } else if let agentID = target.agentID {
            // Still connecting: show the agent now; the task opens once the Mac answers.
            if model.selectedID != agentID { select(agentID) }
            if target.taskID == nil { DeepLink.shared.pending = nil }
        } else {
            DeepLink.shared.pending = nil
        }
    }

    private func select(_ id: String?) {
        if id != nil { Chiptune.shared.play(.select); panel = nil }
        model.selectedID = id
        if id != nil { game.focusSelected() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named("root"))
            .onChanged { v in
                if lastDrag == .zero { dragBlocked = inHUD(v.startLocation) }
                guard !dragBlocked else { lastDrag = v.translation; return }
                game.pan(dx: v.translation.width - lastDrag.width, dy: v.translation.height - lastDrag.height)
                lastDrag = v.translation
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private func inHUD(_ p: CGPoint) -> Bool { hudRects.contains { $0.contains(p) } }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let f = v.magnification / lastMagnify
                if f > 1.25 || f < 0.8 {
                    game.zoomBy(f > 1 ? 1.5 : 1 / 1.5)
                    lastMagnify = v.magnification
                }
            }
            .onEnded { _ in lastMagnify = 1 }
    }
}

// MARK: HUD hit regions (so map gestures ignore touches on the HUD)

struct HUDRectsKey: PreferenceKey {
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}

extension View {
    func hudRegion() -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: HUDRectsKey.self, value: [g.frame(in: .named("root"))])
        })
    }
}
