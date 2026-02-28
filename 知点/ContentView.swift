import SwiftUI

struct ContentView: View {
    @StateObject private var library: KnowledgeCardLibraryStore
    @StateObject private var graphStore: KnowledgeGraphStore
    @State private var selectedTab: AppTab = .square
    @AppStorage(ZDListRenderMode.storageKey) private var listRenderModeRawValue = ZDListRenderMode.defaultSelection.rawValue

    @MainActor
    init() {
        _library = StateObject(wrappedValue: KnowledgeCardLibraryStore())
        _graphStore = StateObject(wrappedValue: KnowledgeGraphStore())
    }

    @MainActor
    init(library: KnowledgeCardLibraryStore) {
        _library = StateObject(wrappedValue: library)
        _graphStore = StateObject(wrappedValue: KnowledgeGraphStore())
    }

    private var selectedListRenderMode: ZDListRenderMode {
        ZDListRenderMode.resolve(rawValue: listRenderModeRawValue)
    }

    var body: some View {
        AppRootTabShell(selectedTab: $selectedTab)
            .environmentObject(library)
            .environmentObject(graphStore)
            .environment(\.zdTheme, .default)
            .environment(\.zdListRenderMode, selectedListRenderMode)
            .onAppear {
                graphStore.pruneInvalidCardReferences(validCardIDs: Set(library.cards.map(\.id)))
            }
            .onChange(of: library.cards.map(\.id)) { _, ids in
                graphStore.pruneInvalidCardReferences(validCardIDs: Set(ids))
            }
    }
}

#Preview {
    ContentView(
        library: KnowledgeCardLibraryStore(
            cards: KnowledgeCardLibraryStore.bundledSeedCardsForPreview()
        )
    )
}
