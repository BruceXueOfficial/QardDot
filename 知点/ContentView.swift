import SwiftUI

struct ContentView: View {
    @StateObject private var library: KnowledgeCardLibraryStore
    @StateObject private var graphStore: KnowledgeGraphStore
    @StateObject private var aiChatViewModel: AiChatViewModel
    @State private var selectedTab: AppTab = .square
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(ZDListRenderMode.storageKey) private var listRenderModeRawValue = ZDListRenderMode.defaultSelection.rawValue

    @MainActor
    init() {
        _library = StateObject(wrappedValue: KnowledgeCardLibraryStore())
        _graphStore = StateObject(wrappedValue: KnowledgeGraphStore())
        _aiChatViewModel = StateObject(wrappedValue: AiChatViewModel())
    }

    @MainActor
    init(library: KnowledgeCardLibraryStore) {
        _library = StateObject(wrappedValue: library)
        _graphStore = StateObject(wrappedValue: KnowledgeGraphStore())
        _aiChatViewModel = StateObject(wrappedValue: AiChatViewModel())
    }

    private var selectedListRenderMode: ZDListRenderMode {
        ZDListRenderMode.resolve(rawValue: listRenderModeRawValue)
    }

    var body: some View {
        AppRootTabShell(selectedTab: $selectedTab)
            .environmentObject(library)
            .environmentObject(graphStore)
            .environmentObject(aiChatViewModel)
            .environment(\.zdTheme, .default)
            .environment(\.zdListRenderMode, selectedListRenderMode)
            .onAppear {
                graphStore.pruneInvalidCardReferences(validCardIDs: Set(library.cards.map(\.id)))
                aiChatViewModel.handleScenePhaseChange(scenePhase)
            }
            .onChange(of: library.cards.map(\.id)) { _, ids in
                graphStore.pruneInvalidCardReferences(validCardIDs: Set(ids))
            }
            .onChange(of: scenePhase) { _, newPhase in
                aiChatViewModel.handleScenePhaseChange(newPhase)
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
