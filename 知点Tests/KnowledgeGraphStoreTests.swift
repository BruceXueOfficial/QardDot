import Foundation
import CoreGraphics
import Testing
@testable import 知点

struct KnowledgeGraphStoreTests {
    @Test
    func graphCodableRoundTrip() throws {
        let source = KnowledgeGraph(
            title: "测试图谱",
            viewport: GraphViewport(zoom: 1.2, offsetX: 120, offsetY: -80),
            nodes: [
                KnowledgeGraphNode(cardID: UUID(), positionX: 10, positionY: 20)
            ],
            edges: []
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(source)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KnowledgeGraph.self, from: data)

        #expect(decoded.title == source.title)
        #expect(decoded.viewport == source.viewport)
        #expect(decoded.nodes.count == 1)
        #expect(decoded.edges.isEmpty)
    }

    @MainActor
    @Test
    func createRenameDeleteGraphCRUD() {
        let store = KnowledgeGraphStore(graphs: [])

        let cardID = UUID()
        let graph = store.createGraph(title: "  我的图谱  ", seedCardID: cardID)

        #expect(store.graphs.count == 1)
        #expect(store.graph(id: graph.id)?.title == "我的图谱")
        #expect(store.graph(id: graph.id)?.nodes.count == 1)

        store.renameGraph(id: graph.id, title: "重命名图谱")
        #expect(store.graph(id: graph.id)?.title == "重命名图谱")

        store.deleteGraph(id: graph.id)
        #expect(store.graphs.isEmpty)
    }

    @MainActor
    @Test
    func standaloneNodeDisallowsDuplicateCardInSameGraph() {
        let cardA = UUID()
        let cardB = UUID()
        let store = KnowledgeGraphStore(graphs: [])
        let graph = store.createGraph(title: "去重", seedCardID: cardA)

        let first = store.addStandaloneNode(
            graphID: graph.id,
            cardID: cardB,
            position: CGPoint(x: 100, y: 100)
        )

        let duplicate = store.addStandaloneNode(
            graphID: graph.id,
            cardID: cardB,
            position: CGPoint(x: 200, y: 200)
        )

        #expect(first != nil)
        #expect(duplicate == nil)
        #expect(store.graph(id: graph.id)?.nodes.count == 2)
    }

    @MainActor
    @Test
    func edgeRulesDisallowSelfAndDuplicateDirectionButAllowReverse() {
        let cardA = UUID()
        let cardB = UUID()
        let cardC = UUID()
        let store = KnowledgeGraphStore(graphs: [])
        let graph = store.createGraph(title: "边规则", seedCardID: cardA)

        let nodeB = store.addStandaloneNode(
            graphID: graph.id,
            cardID: cardB,
            position: CGPoint(x: 50, y: 50)
        )
        let nodeC = store.addStandaloneNode(
            graphID: graph.id,
            cardID: cardC,
            position: CGPoint(x: 220, y: 120)
        )

        let currentGraph = store.graph(id: graph.id)
        let nodeA = currentGraph?.nodes.first?.id

        let selfEdge = store.connectNodes(
            graphID: graph.id,
            sourceNodeID: nodeB ?? UUID(),
            targetNodeID: nodeB ?? UUID(),
            label: nil
        )

        let aToB = store.connectNodes(
            graphID: graph.id,
            sourceNodeID: nodeA ?? UUID(),
            targetNodeID: nodeB ?? UUID(),
            label: "依赖"
        )

        let duplicateAToB = store.connectNodes(
            graphID: graph.id,
            sourceNodeID: nodeA ?? UUID(),
            targetNodeID: nodeB ?? UUID(),
            label: nil
        )

        let bToA = store.connectNodes(
            graphID: graph.id,
            sourceNodeID: nodeB ?? UUID(),
            targetNodeID: nodeA ?? UUID(),
            label: "反向"
        )

        #expect(nodeC != nil)
        #expect(selfEdge == nil)
        #expect(aToB != nil)
        #expect(duplicateAToB == nil)
        #expect(bToA != nil)
    }

    @MainActor
    @Test
    func pruneInvalidCardReferencesRemovesDanglingNodesAndEdges() {
        let cardA = UUID()
        let cardB = UUID()
        let store = KnowledgeGraphStore(graphs: [])
        let graph = store.createGraph(title: "裁剪", seedCardID: cardA)

        let nodeB = store.addStandaloneNode(
            graphID: graph.id,
            cardID: cardB,
            position: CGPoint(x: 140, y: 40)
        )

        let nodeA = store.graph(id: graph.id)?.nodes.first?.id
        _ = store.connectNodes(
            graphID: graph.id,
            sourceNodeID: nodeA ?? UUID(),
            targetNodeID: nodeB ?? UUID(),
            label: "关系"
        )

        store.pruneInvalidCardReferences(validCardIDs: Set([cardA]))

        let after = store.graph(id: graph.id)
        #expect(after?.nodes.count == 1)
        #expect(after?.nodes.first?.cardID == cardA)
        #expect(after?.edges.isEmpty == true)
    }
}
