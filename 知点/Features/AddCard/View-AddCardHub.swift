import SwiftUI

struct AddCardHubView: View {
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @EnvironmentObject private var graphStore: KnowledgeGraphStore
    @State private var showProfileSheet = false
    @State private var showManualCreation = false
    @State private var showImportCard = false
    @State private var showSmartChat = false
    @State private var showCreateGraph = false
    @State private var createdCard: KnowledgeCard?
    @State private var createdGraphID: UUID?

    var body: some View {
        NavigationStack {
            ZDPageScaffold(
                title: "新建内容",
                bottomPadding: 20,
                contentSpacing: 18,
                titleTrailing: { profileButton }
            ) {
                ZDSectionHeader("新建卡片")

                AddEntryCard(
                    icon: "square.and.pencil",
                    title: "手动新建",
                    subtitle: "自由编辑模块化知识卡片"
                ) {
                    showManualCreation = true
                }

                AddEntryCard(
                    icon: "doc.on.clipboard",
                    title: "导入卡片",
                    subtitle: "粘贴 JSON 快速导入知识卡片"
                ) {
                    showImportCard = true
                }

                AddEntryCard(
                    icon: "sparkles",
                    title: "智能对话",
                    subtitle: "AI 辅助生成知识卡片"
                ) {
                    showSmartChat = true
                }

                ZDSectionHeader("新建图谱")

                AddEntryCard(
                    icon: "point.3.connected.trianglepath.dotted",
                    title: "新建图谱",
                    subtitle: "从已有卡片构建知识图谱"
                ) {
                    showCreateGraph = true
                }
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(30)
        }
        .sheet(isPresented: $showManualCreation) {
            ManualCardCreationView(onCreate: handleCreation)
                .environmentObject(library)
        }
        .sheet(isPresented: $showImportCard) {
            ImportCardView(onCreate: handleCreation)
                .environmentObject(library)
        }
        .sheet(isPresented: $showSmartChat) {
            AiChatPage()
        }
        .sheet(isPresented: $showCreateGraph) {
            GraphCreationSheet { graphID in
                createdGraphID = graphID
            }
            .environmentObject(graphStore)
            .environmentObject(library)
        }
        .sheet(isPresented: createdGraphEditorBinding) {
            if let graphID = createdGraphID {
                GraphEditorScreen(graphID: graphID)
                    .environmentObject(graphStore)
                    .environmentObject(library)
            }
        }
        .sheet(item: $createdCard) { card in
            KnowledgeCardDetailScreen(card: card)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(30)
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AddTabDoubleTapped"))) { _ in
            // Double tapping 'Add' tab directly launches the AI import (smart chat) page
            showManualCreation = false
            showImportCard = false
            showCreateGraph = false
            showSmartChat = true
        }
    }

    private func handleCreation(_ card: KnowledgeCard) {
        showManualCreation = false
        showImportCard = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            createdCard = card
        }
    }

    private var createdGraphEditorBinding: Binding<Bool> {
        Binding(
            get: { createdGraphID != nil },
            set: { isPresented in
                if !isPresented {
                    createdGraphID = nil
                }
            }
        )
    }

    private var profileButton: some View {
        ZDProfileEntryButton {
            showProfileSheet = true
        }
    }
}

private struct AddEntryCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let title: String
    let subtitle: String
    var badge: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(ZDThemeTokens.default.interactiveFill)
                    .frame(width: 48, height: 48)
                    .background(
                        colorScheme == .dark
                            ? Color.zdAccentDeep.opacity(0.2)
                            : Color.zdAccentSoft.opacity(0.16)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary.opacity(0.88))

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if let badge {
                        ZDTagChip(text: badge, emphasized: true)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .zdSurfaceCardStyle(.regular, cornerRadius: 20, lineWidth: 1.2)
            .shadow(
                color: colorScheme == .dark ? Color.black.opacity(0.28) : Color.zdAccentDeep.opacity(0.12),
                radius: colorScheme == .dark ? 14 : 10,
                x: 0,
                y: colorScheme == .dark ? 6 : 4
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview("Add Card Hub") {
    AddCardHubView()
        .environmentObject(KnowledgeCardLibraryStore())
        .environmentObject(KnowledgeGraphStore())
}
