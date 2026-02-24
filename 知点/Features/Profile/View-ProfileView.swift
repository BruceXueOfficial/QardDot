import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: "个人", bottomPadding: 20, contentSpacing: 16) {
                statsCard
                storageCard
                aboutCard
            }
        }
    }

    private var statsCard: some View {
        ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 16) {
            ZDSectionHeader("知识库统计") {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.zdAccentDeep)
            }

            let items: [(String, String, String)] = [
                ("卡片总量", "\(library.cards.count)", "rectangle.stack.fill"),
                ("累计浏览", "\(library.totalViews)", "eye.fill"),
                ("文字模块", "\(library.textModuleCount)", "text.alignleft"),
                ("图片模块", "\(library.imageModuleCount)", "photo.fill"),
                ("代码模块", "\(library.codeModuleCount)", "curlybraces"),
                ("链接模块", "\(library.linkModuleCount)", "link")
            ]

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(items, id: \.0) { item in
                    ZDStatTile(title: item.0, value: item.1, icon: item.2)
                }
            }
        }
    }

    private var storageCard: some View {
        ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 16) {
            ZDSectionHeader("数据存储") {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.zdAccentDeep)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.zdAccentSoft)
                    .frame(width: 8, height: 8)
                Text("本地存储正常")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("数据保存在设备本地。加入 Apple Developer Program 后可开启 iCloud 同步。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutCard: some View {
        ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 16) {
            ZDSectionHeader("关于知点") {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.zdAccentDeep)
            }

            Text("知点 (QardDot) 是一款知识卡片管理工具，帮助你用卡片的方式整理和回顾知识。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("版本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1.0.0")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview("Profile") {
    ProfileView()
        .environmentObject(KnowledgeCardLibraryStore())
}
