import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @AppStorage(ZDListRenderMode.storageKey) private var listRenderModeRawValue = ZDListRenderMode.defaultSelection.rawValue
    @AppStorage(AIProvider.storageKey) private var aiProviderRawValue = AIProvider.defaultSelection.rawValue

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: "个人页面", bottomPadding: 20, contentSpacing: 16) {
                statsCard
                storageCard
                performanceCard
                aiProviderCard
                aboutCard
            }
        }
    }

    private var listRenderMode: ZDListRenderMode {
        get { ZDListRenderMode.resolve(rawValue: listRenderModeRawValue) }
        nonmutating set { listRenderModeRawValue = newValue.rawValue }
    }

    private var listRenderModeBinding: Binding<ZDListRenderMode> {
        Binding(
            get: { listRenderMode },
            set: { listRenderMode = $0 }
        )
    }

    private var aiProvider: AIProvider {
        get { AIProvider.resolve(rawValue: aiProviderRawValue) }
        nonmutating set { aiProviderRawValue = newValue.rawValue }
    }

    private var aiProviderBinding: Binding<AIProvider> {
        Binding(
            get: { aiProvider },
            set: { aiProvider = $0 }
        )
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

//            HStack(spacing: 8) {
//                Circle()
//                    .fill(Color.zdAccentSoft)
//                    .frame(width: 8, height: 8)
//                Text("卡片数据存储本地")
//                    .font(.caption)
//                    .foregroundStyle(.secondary)
//            }

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("数据保存在设备本地，加入会员畅享 1TB 云端存储")
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

            HStack (spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("知点帮助你用卡片的方式整理和回顾知识。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            

            HStack (spacing: 6) {
                Text("应用版本")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("1.0.0")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var performanceCard: some View {
        ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 16) {
            ZDSectionHeader("视觉样式") {
                Image(systemName: "speedometer")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.zdAccentDeep)
            }

            Picker("渲染模式", selection: listRenderModeBinding) {
                ForEach(ZDListRenderMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profile.listRenderMode.picker")

            HStack (spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(listRenderMode.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
//            Text("影响全页面卡片样式：广场、新建、仓库与详情展示。")
//                .font(.caption2)
//                .foregroundStyle(.secondary)
        }
    }

    private var aiProviderCard: some View {
        ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 16) {
            ZDSectionHeader("智能助手") {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.zdAccentDeep)
            }

            Picker("AI 服务", selection: aiProviderBinding) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("profile.aiProvider.picker")

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(aiProvider.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Profile") {
    ProfileView()
        .environmentObject(KnowledgeCardLibraryStore())
}
