import Foundation

struct GraphViewport: Codable, Equatable {
    var zoom: Double
    var offsetX: Double
    var offsetY: Double

    static let `default` = GraphViewport(zoom: 1.0, offsetX: 0, offsetY: 0)
}

struct KnowledgeGraphNode: Identifiable, Codable, Equatable {
    let id: UUID
    var cardID: UUID
    var positionX: Double
    var positionY: Double

    init(
        id: UUID = UUID(),
        cardID: UUID,
        positionX: Double,
        positionY: Double
    ) {
        self.id = id
        self.cardID = cardID
        self.positionX = positionX
        self.positionY = positionY
    }
}

struct KnowledgeGraphEdge: Identifiable, Codable, Equatable {
    let id: UUID
    var sourceNodeID: UUID
    var targetNodeID: UUID
    var label: String?

    init(
        id: UUID = UUID(),
        sourceNodeID: UUID,
        targetNodeID: UUID,
        label: String? = nil
    ) {
        self.id = id
        self.sourceNodeID = sourceNodeID
        self.targetNodeID = targetNodeID
        self.label = label
    }
}

struct KnowledgeGraph: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var title: String
    var viewport: GraphViewport
    var nodes: [KnowledgeGraphNode]
    var edges: [KnowledgeGraphEdge]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String,
        viewport: GraphViewport = .default,
        nodes: [KnowledgeGraphNode] = [],
        edges: [KnowledgeGraphEdge] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.viewport = viewport
        self.nodes = nodes
        self.edges = edges
    }

    mutating func touchUpdatedAt() {
        updatedAt = Date()
    }
}
