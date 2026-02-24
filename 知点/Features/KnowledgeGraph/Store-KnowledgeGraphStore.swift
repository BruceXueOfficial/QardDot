import Foundation
import CoreGraphics
import Combine

@MainActor
final class KnowledgeGraphStore: ObservableObject {
    struct NodePositionUpdate {
        var nodeID: UUID
        var x: Double
        var y: Double
    }

    @Published private(set) var graphs: [KnowledgeGraph]

    private static let graphsFileName = "knowledge_graphs.json"
    private let canvasMin: Double = -6000
    private let canvasMax: Double = 6000

    private var deferredSaveWorkItem: DispatchWorkItem?

    init(graphs: [KnowledgeGraph]? = nil) {
        if let graphs {
            self.graphs = graphs
            return
        }

        if let loaded = Self.loadGraphsFromDisk() {
            self.graphs = loaded
        } else {
            self.graphs = []
        }
    }

    func graph(id: UUID) -> KnowledgeGraph? {
        graphs.first(where: { $0.id == id })
    }

    @discardableResult
    func createGraph(title: String, seedCardID: UUID?) -> KnowledgeGraph {
        let normalizedTitle = normalizedTitle(from: title)
        var nodes: [KnowledgeGraphNode] = []

        if let seedCardID {
            nodes = [
                KnowledgeGraphNode(
                    cardID: seedCardID,
                    positionX: 0,
                    positionY: 0
                )
            ]
        }

        let graph = KnowledgeGraph(
            title: normalizedTitle,
            viewport: .default,
            nodes: nodes,
            edges: []
        )
        graphs.insert(graph, at: 0)
        saveToDisk()
        return graph
    }

    func renameGraph(id: UUID, title: String) {
        guard let index = indexOfGraph(id: id) else { return }
        graphs[index].title = normalizedTitle(from: title)
        graphs[index].touchUpdatedAt()
        saveToDisk()
    }

    func deleteGraph(id: UUID) {
        let before = graphs.count
        graphs.removeAll { $0.id == id }
        guard graphs.count != before else { return }
        saveToDisk()
    }

    @discardableResult
    func addStandaloneNode(graphID: UUID, cardID: UUID, position: CGPoint) -> UUID? {
        guard let index = indexOfGraph(id: graphID) else { return nil }
        guard !graphs[index].nodes.contains(where: { $0.cardID == cardID }) else {
            return nil
        }

        let node = KnowledgeGraphNode(
            cardID: cardID,
            positionX: clamp(position.x),
            positionY: clamp(position.y)
        )
        graphs[index].nodes.append(node)
        graphs[index].touchUpdatedAt()
        saveToDisk()
        return node.id
    }

    @discardableResult
    func addChildNode(
        graphID: UUID,
        fromNodeID: UUID,
        cardID: UUID,
        label: String?
    ) -> UUID? {
        guard let index = indexOfGraph(id: graphID) else { return nil }
        guard let sourceNode = graphs[index].nodes.first(where: { $0.id == fromNodeID }) else { return nil }
        guard !graphs[index].nodes.contains(where: { $0.cardID == cardID }) else {
            return nil
        }

        let baseX = sourceNode.positionX + 260
        let baseY = sourceNode.positionY + Double.random(in: -84...84)

        let node = KnowledgeGraphNode(
            cardID: cardID,
            positionX: clamp(baseX),
            positionY: clamp(baseY)
        )
        graphs[index].nodes.append(node)

        _ = connectNodes(
            graphID: graphID,
            sourceNodeID: fromNodeID,
            targetNodeID: node.id,
            label: label,
            saveAfterMutation: false
        )

        graphs[index].touchUpdatedAt()
        saveToDisk()
        return node.id
    }

    @discardableResult
    func connectNodes(
        graphID: UUID,
        sourceNodeID: UUID,
        targetNodeID: UUID,
        label: String?
    ) -> UUID? {
        connectNodes(
            graphID: graphID,
            sourceNodeID: sourceNodeID,
            targetNodeID: targetNodeID,
            label: label,
            saveAfterMutation: true
        )
    }

    func updateNodePositions(graphID: UUID, positions: [NodePositionUpdate]) {
        guard let index = indexOfGraph(id: graphID), !positions.isEmpty else {
            return
        }

        var positionByID: [UUID: NodePositionUpdate] = [:]
        for item in positions {
            positionByID[item.nodeID] = item
        }

        var didChange = false
        for nodeIndex in graphs[index].nodes.indices {
            let nodeID = graphs[index].nodes[nodeIndex].id
            guard let next = positionByID[nodeID] else { continue }

            let x = clamp(next.x)
            let y = clamp(next.y)
            if graphs[index].nodes[nodeIndex].positionX != x || graphs[index].nodes[nodeIndex].positionY != y {
                graphs[index].nodes[nodeIndex].positionX = x
                graphs[index].nodes[nodeIndex].positionY = y
                didChange = true
            }
        }

        guard didChange else { return }
        graphs[index].touchUpdatedAt()
        scheduleDeferredSave()
    }

    func updateViewport(graphID: UUID, viewport: GraphViewport) {
        guard let index = indexOfGraph(id: graphID) else {
            return
        }

        let normalized = GraphViewport(
            zoom: min(max(viewport.zoom, 0.35), 2.2),
            offsetX: clamp(viewport.offsetX),
            offsetY: clamp(viewport.offsetY)
        )

        guard graphs[index].viewport != normalized else {
            return
        }

        graphs[index].viewport = normalized
        graphs[index].touchUpdatedAt()
        scheduleDeferredSave()
    }

    func upsertEdgeLabel(graphID: UUID, edgeID: UUID, label: String?) {
        guard let graphIndex = indexOfGraph(id: graphID) else { return }
        guard let edgeIndex = graphs[graphIndex].edges.firstIndex(where: { $0.id == edgeID }) else { return }

        let normalizedLabel = normalizedLabelValue(from: label)
        guard graphs[graphIndex].edges[edgeIndex].label != normalizedLabel else {
            return
        }

        graphs[graphIndex].edges[edgeIndex].label = normalizedLabel
        graphs[graphIndex].touchUpdatedAt()
        saveToDisk()
    }

    func deleteEdge(graphID: UUID, edgeID: UUID) {
        guard let graphIndex = indexOfGraph(id: graphID) else { return }
        let before = graphs[graphIndex].edges.count
        graphs[graphIndex].edges.removeAll { $0.id == edgeID }
        guard graphs[graphIndex].edges.count != before else { return }
        graphs[graphIndex].touchUpdatedAt()
        saveToDisk()
    }

    func pruneInvalidCardReferences(validCardIDs: Set<UUID>) {
        var didMutate = false

        for graphIndex in graphs.indices {
            let previousNodeCount = graphs[graphIndex].nodes.count
            graphs[graphIndex].nodes.removeAll { !validCardIDs.contains($0.cardID) }
            let nodeIDs = Set(graphs[graphIndex].nodes.map(\.id))
            let previousEdgeCount = graphs[graphIndex].edges.count
            graphs[graphIndex].edges.removeAll {
                !nodeIDs.contains($0.sourceNodeID) || !nodeIDs.contains($0.targetNodeID)
            }

            if graphs[graphIndex].nodes.count != previousNodeCount || graphs[graphIndex].edges.count != previousEdgeCount {
                graphs[graphIndex].touchUpdatedAt()
                didMutate = true
            }
        }

        if didMutate {
            saveToDisk()
        }
    }

    // MARK: - Helpers

    private func connectNodes(
        graphID: UUID,
        sourceNodeID: UUID,
        targetNodeID: UUID,
        label: String?,
        saveAfterMutation: Bool
    ) -> UUID? {
        guard let index = indexOfGraph(id: graphID) else { return nil }
        guard sourceNodeID != targetNodeID else { return nil }

        let nodeIDs = Set(graphs[index].nodes.map(\.id))
        guard nodeIDs.contains(sourceNodeID), nodeIDs.contains(targetNodeID) else {
            return nil
        }

        let hasDuplicateDirection = graphs[index].edges.contains {
            $0.sourceNodeID == sourceNodeID && $0.targetNodeID == targetNodeID
        }
        guard !hasDuplicateDirection else {
            return nil
        }

        let edge = KnowledgeGraphEdge(
            sourceNodeID: sourceNodeID,
            targetNodeID: targetNodeID,
            label: normalizedLabelValue(from: label)
        )
        graphs[index].edges.append(edge)
        graphs[index].touchUpdatedAt()

        if saveAfterMutation {
            saveToDisk()
        }

        return edge.id
    }

    private func indexOfGraph(id: UUID) -> Int? {
        graphs.firstIndex(where: { $0.id == id })
    }

    private func normalizedTitle(from raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名图谱" : trimmed
    }

    private func normalizedLabelValue(from raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, canvasMin), canvasMax)
    }

    private func clamp(_ value: CGFloat) -> Double {
        clamp(Double(value))
    }

    private func scheduleDeferredSave() {
        deferredSaveWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.saveToDisk()
        }
        deferredSaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static func loadGraphsFromDisk() -> [KnowledgeGraph]? {
        let url = documentsDirectory.appendingPathComponent(graphsFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([KnowledgeGraph].self, from: data)
    }

    private func saveToDisk() {
        deferredSaveWorkItem?.cancel()
        deferredSaveWorkItem = nil

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(graphs) else {
            return
        }

        let url = Self.documentsDirectory.appendingPathComponent(Self.graphsFileName)
        try? data.write(to: url, options: .atomic)
    }
}
