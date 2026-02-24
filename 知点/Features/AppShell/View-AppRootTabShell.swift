import SwiftUI

struct AppRootTabShell: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        TabView(selection: $selectedTab) {
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
                    Text("新增")
                }

            CardManagementView()
                .tag(AppTab.manage)
                .tabItem {
                    Image(systemName: selectedTab == .manage ? "archivebox.fill" : "archivebox")
                    Text("仓库")
                }

            ProfileView()
                .tag(AppTab.profile)
                .tabItem {
                    Image(systemName: selectedTab == .profile ? "person.circle.fill" : "person.circle")
                    Text("个人")
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
