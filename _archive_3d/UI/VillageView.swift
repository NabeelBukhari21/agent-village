import RealityKit
import SwiftUI

struct VillageView: View {
    @State private var model: WorldModel
    @State private var projector: Projector
    @State private var scene: VillageScene
    @State private var showLog = false
    @State private var lastDrag: CGSize = .zero
    @State private var lastMagnify: CGFloat = 1

    init() {
        let model = WorldModel()
        let projector = Projector()
        _model = State(initialValue: model)
        _projector = State(initialValue: projector)
        _scene = State(initialValue: VillageScene(model: model, projector: projector))
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 700
            ZStack {
                RealityView { content in
                    content.camera = .virtual
                    scene.install(in: &content)
                }
                .gesture(orbitGesture)
                .simultaneousGesture(zoomGesture)
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    if let id = scene.agent(near: v.location) { select(id) } else if model.selectedID != nil { select(nil) }
                })
                .onAppear { projector.viewSize = geo.size }
                .onChange(of: geo.size) { _, s in projector.viewSize = s }

                // Soft anime vignette + bloom tint
                RadialGradient(colors: [.clear, Color(hex: 0x1A1030, opacity: 0.45)], center: .center, startRadius: geo.size.width * 0.35, endRadius: geo.size.width * 0.85)
                    .allowsHitTesting(false)

                WorldOverlay(model: model, projector: projector) { select($0) }

                hud(compact: compact, size: geo.size)
            }
        }
        .ignoresSafeArea()
        .background(Color(hex: 0x0B1033))
        .sheet(isPresented: $showLog) { QuestLogSheet(model: model) }
    }

    @ViewBuilder
    private func hud(compact: Bool, size: CGSize) -> some View {
        VStack(spacing: 10) {
            // Top row
            if compact {
                VStack(spacing: 8) {
                    HStack {
                        TitlePlate(model: model, compact: true)
                        Spacer()
                    }
                    ResourceBar(model: model, compact: true)
                    PartyFrames(model: model, horizontal: true) { select($0) }
                }
            } else {
                HStack(alignment: .top) {
                    TitlePlate(model: model, compact: false)
                    Spacer()
                    ResourceBar(model: model, compact: false)
                }
            }

            if let calling = model.pending.first, model.selectedID != calling.id {
                ApprovalBanner(agent: calling) { select(calling.id) }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(alignment: .top) {
                if !compact {
                    PartyFrames(model: model, horizontal: false) { select($0) }
                }
                Spacer()
            }

            Spacer()

            // Bottom: dialogue or quest log
            if let a = model.selected {
                DialogueBox(agent: a, model: model, compact: compact) { select(nil) }
                    .id(a.id)
                    .frame(maxWidth: 760)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HStack(alignment: .bottom) {
                    QuestTicker(model: model) { showLog = true }
                    Spacer()
                    if !compact {
                        ControlDock(model: model, onZoomIn: { scene.zoom(by: 1.25) }, onZoomOut: { scene.zoom(by: 0.8) }, onHome: { scene.recenter() })
                    }
                }
                if compact {
                    HStack {
                        Spacer()
                        ControlDock(model: model, onZoomIn: { scene.zoom(by: 1.25) }, onZoomOut: { scene.zoom(by: 0.8) }, onHome: { scene.recenter() })
                    }
                }
            }
        }
        .padding(.horizontal, compact ? 12 : 20)
        .padding(.top, compact ? 54 : 20)
        .padding(.bottom, compact ? 30 : 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: model.selectedID)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: model.pending.count)
    }

    private func select(_ id: String?) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { model.selectedID = id }
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                let d = CGSize(width: v.translation.width - lastDrag.width, height: v.translation.height - lastDrag.height)
                lastDrag = v.translation
                scene.orbit(dx: d.width, dy: d.height)
            }
            .onEnded { _ in lastDrag = .zero }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                scene.zoom(by: v.magnification / lastMagnify)
                lastMagnify = v.magnification
            }
            .onEnded { _ in lastMagnify = 1 }
    }
}
