import SwiftUI

struct AppRootTabShell: View {
    @Binding var selectedTab: AppTab
    
    @State private var lastAddTabTapTime: Date = .distantPast

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .add {
                    let now = Date()
                    // Detect double tap: tap again on already selected tab within 500ms
                    if selectedTab == .add && now.timeIntervalSince(lastAddTabTapTime) < 0.5 {
                        NotificationCenter.default.post(name: .init("AddTabDoubleTapped"), object: nil)
                        // Reset to avoid tripple-tap causing two events
                        lastAddTabTapTime = .distantPast
                    } else {
                        lastAddTabTapTime = now
                    }
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            KnowledgeSquareView()
                .tag(AppTab.square)
                .tabItem {
                    Image(systemName: selectedTab == .square ? "square.grid.2x2.fill" : "square.grid.2x2")
                    Text("广场")
                }

            AddCardHubView()
                .tag(AppTab.add)
                .tabItem {
                    Image(systemName: selectedTab == .add ? "plus.circle.fill" : "plus.circle")
                    Text("新建")
                }

            CardManagementView()
                .tag(AppTab.manage)
                .tabItem {
                    Image(systemName: selectedTab == .manage ? "archivebox.fill" : "archivebox")
                    Text("仓库")
                }
        }
        .tint(ZDThemeTokens.default.accent.opacity(0.94))
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(ZDThemeTokens.default.surface.opacity(0.86), for: .tabBar)
    }
}

#Preview("App Root Tabs") {
    AppRootTabShell(selectedTab: .constant(.square))
        .environmentObject(KnowledgeCardLibraryStore())
        .environmentObject(KnowledgeGraphStore())
}
