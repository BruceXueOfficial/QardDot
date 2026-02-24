import SwiftUI
import WebKit

struct GraphEditorScreen: View {
    @EnvironmentObject private var graphStore: KnowledgeGraphStore
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss

    let graphID: UUID

    @State private var selectedNodeID: UUID?
    @State private var showingAddMenu = false
    @State private var showingCardPicker = false
    @State private var showingConnectSheet = false
    @State private var pickerIntent: GraphPickerIntent = .standalone

    @State private var edgeEditorTargetID: UUID?
    @State private var edgeLabelDraft = ""

    @State private var selectedCard: KnowledgeCard?

    var body: some View {
        NavigationStack {
            if let graph = graphStore.graph(id: graphID) {
                ZDPageScaffold(title: nil, bottomPadding: 18, contentSpacing: 12) {
                    header(graph)
                    canvasSection(graph)
                    selectedNodeBar(graph)
                }
                .toolbar(.hidden, for: .navigationBar)
                .onAppear {
                    graphStore.pruneInvalidCardReferences(validCardIDs: Set(library.cards.map(\.id)))
                }
                .onChange(of: library.cards.map(\.id)) { _, ids in
                    graphStore.pruneInvalidCardReferences(validCardIDs: Set(ids))
                    let validNodeIDs = Set(graphStore.graph(id: graphID)?.nodes.map(\.id) ?? [])
                    if let selectedNodeID, !validNodeIDs.contains(selectedNodeID) {
                        self.selectedNodeID = nil
                    }
                }
            } else {
                missingGraphView
            }
        }
        .confirmationDialog("添加到图谱", isPresented: $showingAddMenu, titleVisibility: .visible) {
            if let selectedNodeID {
                Button("从选中节点添加卡片") {
                    pickerIntent = .child(sourceNodeID: selectedNodeID)
                    showingCardPicker = true
                }
            }

            Button("添加独立节点") {
                pickerIntent = .standalone
                showingCardPicker = true
            }

            if let graph = graphStore.graph(id: graphID), graph.nodes.count >= 2 {
                Button("连接已有节点 A -> B") {
                    showingConnectSheet = true
                }
            }

            Button("取消", role: .cancel) { }
        }
        .sheet(isPresented: $showingCardPicker) {
            GraphCardPickerSheet(
                title: pickerIntent.title,
                excludedCardIDs: excludedCardIDs
            ) { card in
                handleCardPicked(card)
            }
            .environmentObject(library)
        }
        .sheet(isPresented: $showingConnectSheet) {
            if let graph = graphStore.graph(id: graphID) {
                GraphConnectNodesSheet(
                    graph: graph,
                    nodeTitleProvider: cardTitle(forNodeID:)
                ) { sourceID, targetID, label in
                    _ = graphStore.connectNodes(
                        graphID: graphID,
                        sourceNodeID: sourceID,
                        targetNodeID: targetID,
                        label: label
                    )
                }
            }
        }
        .alert("编辑关系文字", isPresented: edgeEditorBinding) {
            TextField("关系说明（可选）", text: $edgeLabelDraft)

            Button("取消", role: .cancel) {
                edgeEditorTargetID = nil
            }

            Button("删除关系", role: .destructive) {
                if let edgeID = edgeEditorTargetID {
                    graphStore.deleteEdge(graphID: graphID, edgeID: edgeID)
                }
                edgeEditorTargetID = nil
            }

            Button("保存") {
                if let edgeID = edgeEditorTargetID {
                    graphStore.upsertEdgeLabel(
                        graphID: graphID,
                        edgeID: edgeID,
                        label: edgeLabelDraft
                    )
                }
                edgeEditorTargetID = nil
            }
        } message: {
            Text("你可以添加一个简短说明，展示在箭头上。")
        }
        .sheet(item: $selectedCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
    }

    private func header(_ graph: KnowledgeGraph) -> some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("graph_editor_close_button")

            VStack(alignment: .leading, spacing: 2) {
                Text(graph.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("节点 \(graph.nodes.count) · 关系 \(graph.edges.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            Button {
                showingAddMenu = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(ZDThemeTokens.default.interactiveFill)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("graph_editor_add_button")
        }
        .padding(.top, 4)
    }

    private func canvasSection(_ graph: KnowledgeGraph) -> some View {
        GraphWebEditorBridgeView(
            graph: graph,
            cardsByID: Dictionary(uniqueKeysWithValues: library.cards.map { ($0.id, $0) }),
            selectedNodeID: $selectedNodeID
        ) { event in
            handleWebEvent(event)
        }
        .frame(minHeight: 480)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.zdAccentDeep.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func selectedNodeBar(_ graph: KnowledgeGraph) -> some View {
        if let node = selectedNode(in: graph),
           let card = library.cards.first(where: { $0.id == node.cardID }) {
            ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 12) {
                HStack(spacing: 8) {
                    Text(card.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button("打开卡片") {
                        selectedCard = card
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.zdAccentDeep)

                    Button("添加子节点") {
                        pickerIntent = .child(sourceNodeID: node.id)
                        showingCardPicker = true
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.zdAccentDeep)
                }
            }
        }
    }

    private var missingGraphView: some View {
        ZDPageScaffold(title: nil, bottomPadding: 18, contentSpacing: 12) {
            ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                Text("图谱不存在或已删除")
                    .font(.headline.weight(.bold))

                Button("返回") {
                    dismiss()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.zdAccentDeep)
            }
        }
    }

    private var excludedCardIDs: Set<UUID> {
        guard let graph = graphStore.graph(id: graphID) else {
            return []
        }
        return Set(graph.nodes.map(\.cardID))
    }

    private func selectedNode(in graph: KnowledgeGraph) -> KnowledgeGraphNode? {
        guard let selectedNodeID else { return nil }
        return graph.nodes.first(where: { $0.id == selectedNodeID })
    }

    private func cardTitle(forNodeID nodeID: UUID) -> String {
        guard let graph = graphStore.graph(id: graphID),
              let node = graph.nodes.first(where: { $0.id == nodeID }),
              let card = library.cards.first(where: { $0.id == node.cardID }) else {
            return "未知卡片"
        }
        return card.title
    }

    private func handleCardPicked(_ card: KnowledgeCard) {
        switch pickerIntent {
        case .standalone:
            guard let graph = graphStore.graph(id: graphID) else { return }
            let seedX = -graph.viewport.offsetX / max(graph.viewport.zoom, 0.35)
            let seedY = -graph.viewport.offsetY / max(graph.viewport.zoom, 0.35)
            let x = seedX + Double.random(in: -60...60)
            let y = seedY + Double.random(in: -40...40)
            selectedNodeID = graphStore.addStandaloneNode(
                graphID: graphID,
                cardID: card.id,
                position: CGPoint(x: x, y: y)
            )

        case .child(let sourceNodeID):
            selectedNodeID = graphStore.addChildNode(
                graphID: graphID,
                fromNodeID: sourceNodeID,
                cardID: card.id,
                label: nil
            )
        }
    }

    private func handleWebEvent(_ event: GraphWebEvent) {
        switch event {
        case .ready:
            break

        case .selectionChanged(let nodeID):
            selectedNodeID = nodeID

        case .nodePositionsChanged(let positions):
            graphStore.updateNodePositions(graphID: graphID, positions: positions)

        case .viewportChanged(let viewport):
            graphStore.updateViewport(graphID: graphID, viewport: viewport)

        case .edgeTapped(let edgeID):
            guard let graph = graphStore.graph(id: graphID),
                  let edge = graph.edges.first(where: { $0.id == edgeID }) else {
                return
            }
            edgeEditorTargetID = edge.id
            edgeLabelDraft = edge.label ?? ""

        case .canvasTapped:
            selectedNodeID = nil
        }
    }

    private var edgeEditorBinding: Binding<Bool> {
        Binding(
            get: { edgeEditorTargetID != nil },
            set: { isPresented in
                if !isPresented {
                    edgeEditorTargetID = nil
                }
            }
        )
    }
}

private enum GraphPickerIntent {
    case standalone
    case child(sourceNodeID: UUID)

    var title: String {
        switch self {
        case .standalone:
            return "添加独立节点"
        case .child:
            return "从选中节点添加卡片"
        }
    }
}

private enum GraphWebEvent {
    case ready
    case selectionChanged(UUID?)
    case nodePositionsChanged([KnowledgeGraphStore.NodePositionUpdate])
    case viewportChanged(GraphViewport)
    case edgeTapped(UUID)
    case canvasTapped
}

private struct GraphWebEditorBridgeView: UIViewRepresentable {
    let graph: KnowledgeGraph
    let cardsByID: [UUID: KnowledgeCard]
    @Binding var selectedNodeID: UUID?
    let onEvent: (GraphWebEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: Coordinator.handlerName)

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        context.coordinator.bind(webView: webView)

        if let htmlURL = Self.graphEditorHTMLURL() {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        } else {
            webView.loadHTMLString(
                "<html><body style='font-family: -apple-system; padding: 24px;'>graph_editor.html not found.</body></html>",
                baseURL: nil
            )
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateFromSwift()
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: Coordinator.handlerName)
    }

    private static func graphEditorHTMLURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "graph_editor", withExtension: "html") {
            return direct
        }

        if let nested = Bundle.main.url(
            forResource: "graph_editor",
            withExtension: "html",
            subdirectory: "Features/KnowledgeGraph/Web"
        ) {
            return nested
        }

        if let resourceRoot = Bundle.main.resourceURL {
            let candidate = resourceRoot.appendingPathComponent("Features/KnowledgeGraph/Web/graph_editor.html")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        static let handlerName = "graphBridge"

        var parent: GraphWebEditorBridgeView

        private weak var webView: WKWebView?
        private var isReady = false
        private var lastSentGraphStamp = ""
        private var lastSentSelectionID: UUID?

        init(parent: GraphWebEditorBridgeView) {
            self.parent = parent
            super.init()
        }

        func bind(webView: WKWebView) {
            self.webView = webView
        }

        func updateFromSwift() {
            guard isReady else { return }

            let stamp = graphStamp(from: parent.graph)
            if stamp != lastSentGraphStamp {
                sendBootstrapGraph()
                lastSentGraphStamp = stamp
            }

            if parent.selectedNodeID != lastSentSelectionID {
                sendSelection(parent.selectedNodeID)
                lastSentSelectionID = parent.selectedNodeID
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            updateFromSwift()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == Self.handlerName else {
                return
            }

            guard let payload = normalizeBody(message.body),
                  let type = payload["type"] as? String else {
                return
            }

            switch type {
            case "ready":
                isReady = true
                parent.onEvent(.ready)
                sendBootstrapGraph()
                sendSelection(parent.selectedNodeID)
                lastSentGraphStamp = graphStamp(from: parent.graph)
                lastSentSelectionID = parent.selectedNodeID

            case "selectionChanged":
                let nodeID = (payload["nodeID"] as? String).flatMap(UUID.init(uuidString:))
                parent.onEvent(.selectionChanged(nodeID))

            case "nodePositionsChanged":
                let raw = payload["positions"] as? [[String: Any]] ?? []
                let updates = raw.compactMap { item -> KnowledgeGraphStore.NodePositionUpdate? in
                    guard let idString = item["nodeID"] as? String,
                          let id = UUID(uuidString: idString),
                          let x = Self.doubleValue(of: item["x"]),
                          let y = Self.doubleValue(of: item["y"]) else {
                        return nil
                    }
                    return KnowledgeGraphStore.NodePositionUpdate(nodeID: id, x: x, y: y)
                }
                if !updates.isEmpty {
                    parent.onEvent(.nodePositionsChanged(updates))
                }

            case "viewportChanged":
                guard let viewport = payload["viewport"] as? [String: Any],
                      let zoom = Self.doubleValue(of: viewport["zoom"]),
                      let offsetX = Self.doubleValue(of: viewport["offsetX"]),
                      let offsetY = Self.doubleValue(of: viewport["offsetY"]) else {
                    return
                }
                parent.onEvent(
                    .viewportChanged(
                        GraphViewport(zoom: zoom, offsetX: offsetX, offsetY: offsetY)
                    )
                )

            case "edgeTapped":
                if let edgeIDString = payload["edgeID"] as? String,
                   let edgeID = UUID(uuidString: edgeIDString) {
                    parent.onEvent(.edgeTapped(edgeID))
                }

            case "canvasTapped":
                parent.onEvent(.canvasTapped)

            default:
                break
            }
        }

        private static func doubleValue(of any: Any?) -> Double? {
            if let n = any as? NSNumber { return n.doubleValue }
            if let d = any as? Double { return d }
            if let i = any as? Int { return Double(i) }
            return nil
        }

        private func normalizeBody(_ body: Any) -> [String: Any]? {
            if let dict = body as? [String: Any] {
                return dict
            }

            if let text = body as? String,
               let data = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json
            }

            return nil
        }

        private func graphStamp(from graph: KnowledgeGraph) -> String {
            "\(graph.id.uuidString)-\(graph.updatedAt.timeIntervalSince1970)-\(graph.nodes.count)-\(graph.edges.count)-\(graph.viewport.zoom)-\(graph.viewport.offsetX)-\(graph.viewport.offsetY)"
        }

        private func sendBootstrapGraph() {
            let payload = GraphBootstrapPayload(graph: parent.graph, cardsByID: parent.cardsByID)
            guard let data = try? JSONEncoder().encode(payload),
                  let json = String(data: data, encoding: .utf8) else {
                return
            }

            evaluate(script: "window.bootstrapGraph && window.bootstrapGraph(\(json));")
            evaluate(script: "window.applyGraphPatch && window.applyGraphPatch(\(json));")
        }

        private func sendSelection(_ nodeID: UUID?) {
            let argument = nodeID.map { "\"\($0.uuidString)\"" } ?? "null"
            evaluate(script: "window.setSelection && window.setSelection(\(argument));")
        }

        private func evaluate(script: String) {
            webView?.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

private struct GraphBootstrapPayload: Codable {
    struct NodePayload: Codable {
        let id: String
        let cardID: String
        let x: Double
        let y: Double
        let title: String
        let tags: [String]
    }

    struct EdgePayload: Codable {
        let id: String
        let sourceNodeID: String
        let targetNodeID: String
        let label: String?
    }

    struct ViewportPayload: Codable {
        let zoom: Double
        let offsetX: Double
        let offsetY: Double
    }

    let id: String
    let title: String
    let viewport: ViewportPayload
    let nodes: [NodePayload]
    let edges: [EdgePayload]

    init(graph: KnowledgeGraph, cardsByID: [UUID: KnowledgeCard]) {
        id = graph.id.uuidString
        title = graph.title
        viewport = ViewportPayload(
            zoom: graph.viewport.zoom,
            offsetX: graph.viewport.offsetX,
            offsetY: graph.viewport.offsetY
        )

        nodes = graph.nodes.compactMap { node in
            guard let card = cardsByID[node.cardID] else {
                return nil
            }
            return NodePayload(
                id: node.id.uuidString,
                cardID: node.cardID.uuidString,
                x: node.positionX,
                y: node.positionY,
                title: card.title,
                tags: card.tags ?? []
            )
        }

        edges = graph.edges.map { edge in
            EdgePayload(
                id: edge.id.uuidString,
                sourceNodeID: edge.sourceNodeID.uuidString,
                targetNodeID: edge.targetNodeID.uuidString,
                label: edge.label
            )
        }
    }
}

private struct GraphConnectNodesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let graph: KnowledgeGraph
    let nodeTitleProvider: (UUID) -> String
    let onConfirm: (UUID, UUID, String?) -> Void

    @State private var sourceNodeID: UUID?
    @State private var targetNodeID: UUID?
    @State private var label = ""

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: nil, bottomPadding: 18, contentSpacing: 14) {
                header

                ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                    Text("来源节点 A")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("来源", selection: $sourceNodeID) {
                        ForEach(graph.nodes) { node in
                            Text(nodeTitleProvider(node.id))
                                .tag(Optional(node.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                    Text("目标节点 B")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("目标", selection: $targetNodeID) {
                        ForEach(graph.nodes) { node in
                            Text(nodeTitleProvider(node.id))
                                .tag(Optional(node.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

                ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                    Text("关系文字（可选）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("例如：前置知识 / 依赖 / 延伸", text: $label)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .zdSurfaceCardStyle(.clear, cornerRadius: 10)
                }

                ZDPrimaryButton(text: "创建关系", isDisabled: !canConfirm) {
                    guard let sourceNodeID, let targetNodeID else {
                        return
                    }
                    onConfirm(sourceNodeID, targetNodeID, label)
                    dismiss()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            sourceNodeID = graph.nodes.first?.id
            targetNodeID = graph.nodes.dropFirst().first?.id ?? graph.nodes.first?.id
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("连接已有节点")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 10)

            Button("取消") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private var canConfirm: Bool {
        guard let sourceNodeID, let targetNodeID else {
            return false
        }
        return sourceNodeID != targetNodeID
    }
}
