import SwiftUI

struct GraphWarehouseView: View {
    @EnvironmentObject private var graphStore: KnowledgeGraphStore
    @EnvironmentObject private var library: KnowledgeCardLibraryStore

    @State private var selectedGraphID: UUID?
    @State private var showingCreateSheet = false
    @State private var renameTarget: KnowledgeGraph?
    @State private var renameDraft = ""
    @State private var deleteTarget: KnowledgeGraph?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if sortedGraphs.isEmpty {
                emptyState
            } else {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(sortedGraphs) { graph in
                        graphCard(graph)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            GraphCreationSheet { graphID in
                selectedGraphID = graphID
            }
            .environmentObject(graphStore)
            .environmentObject(library)
        }
        .sheet(isPresented: selectedGraphSheetBinding) {
            if let graphID = selectedGraphID {
                GraphEditorScreen(graphID: graphID)
                    .environmentObject(graphStore)
                    .environmentObject(library)
            }
        }
        .alert("重命名图谱", isPresented: renameAlertBinding, presenting: renameTarget) { _ in
            TextField("图谱名称", text: $renameDraft)
            Button("取消", role: .cancel) {
                renameTarget = nil
            }
            Button("保存") {
                if let id = renameTarget?.id {
                    graphStore.renameGraph(id: id, title: renameDraft)
                }
                renameTarget = nil
            }
        } message: { _ in
            Text("请输入新的图谱名称")
        }
        .alert("确认删除", isPresented: deleteAlertBinding, presenting: deleteTarget) { graph in
            Button("取消", role: .cancel) {
                deleteTarget = nil
            }
            Button("删除", role: .destructive) {
                graphStore.deleteGraph(id: graph.id)
                deleteTarget = nil
            }
        } message: { graph in
            Text("删除「\(graph.title)」后不可恢复，确认继续？")
        }
        .onChange(of: library.cards.map(\.id)) { _, ids in
            graphStore.pruneInvalidCardReferences(validCardIDs: Set(ids))
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("ShowGraphCreateSheet"))) { _ in
            showingCreateSheet = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 10)


        }
    }

    private func graphCard(_ graph: KnowledgeGraph) -> some View {
        ZDSurfaceCard(cornerRadius: 16, style: .regular, padding: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(graph.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 10)

                Menu {
                    Button("重命名") {
                        renameDraft = graph.title
                        renameTarget = graph
                    }

                    Button("删除", role: .destructive) {
                        deleteTarget = graph
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                ZDTagChip(text: "节点 \(graph.nodes.count)", compact: true, emphasized: true)
                ZDTagChip(text: "关系 \(graph.edges.count)", compact: true)
                Spacer(minLength: 0)
                Text(graph.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                selectedGraphID = graph.id
            } label: {
                HStack(spacing: 6) {
                    Text("打开图谱")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.zdAccentDeep)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.zdAccentDeep.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        ZDSurfaceCard(cornerRadius: 16, style: .regular, padding: 18) {
            Text("还没有图谱")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text("点击右上角“新建”或在“新增”页创建图谱。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingCreateSheet = true
            } label: {
                Text("创建第一个图谱")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .zdSurfaceCardStyle(.regular, cornerRadius: 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var sortedGraphs: [KnowledgeGraph] {
        graphStore.graphs.sorted { lhs, rhs in
            max(lhs.updatedAt, lhs.createdAt) > max(rhs.updatedAt, rhs.createdAt)
        }
    }

    private var selectedGraphSheetBinding: Binding<Bool> {
        Binding(
            get: { selectedGraphID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedGraphID = nil
                }
            }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { show in
                if !show {
                    renameTarget = nil
                }
            }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { show in
                if !show {
                    deleteTarget = nil
                }
            }
        )
    }
}

struct GraphCreationSheet: View {
    @EnvironmentObject private var graphStore: KnowledgeGraphStore
    @EnvironmentObject private var library: KnowledgeCardLibraryStore
    @Environment(\.dismiss) private var dismiss

    let onCreated: (UUID) -> Void

    @State private var title = ""
    @State private var seedCard: KnowledgeCard?
    @State private var showingCardPicker = false

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: nil, bottomPadding: 18, contentSpacing: 14) {
                header

                ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                    Text("图谱名称")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextField("输入图谱名称", text: $title)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .zdSurfaceCardStyle(.clear, cornerRadius: 10)
                }

                ZDSurfaceCard(cornerRadius: 14, style: .regular, padding: 14) {
                    HStack {
                        Text("初始知识卡片")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 10)

                        if seedCard != nil {
                            Button("清空") {
                                seedCard = nil
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        }
                    }

                    if let seedCard {
                        CardTitleTile(card: seedCard, isSelectionMode: false, isSelected: false)
                    } else {
                        Text("可选。设置后会作为第一个节点。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingCardPicker = true
                    } label: {
                        Text(seedCard == nil ? "选择卡片" : "更换卡片")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.zdAccentDeep)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.zdAccentDeep.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                ZDPrimaryButton(text: "创建图谱") {
                    let graph = graphStore.createGraph(title: title, seedCardID: seedCard?.id)
                    onCreated(graph.id)
                    dismiss()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingCardPicker) {
            GraphCardPickerSheet(
                title: "选择初始卡片",
                excludedCardIDs: []
            ) { card in
                seedCard = card
            }
            .environmentObject(library)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("新建图谱")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            Spacer(minLength: 10)

            Button("取消") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}

#Preview("Graph Warehouse") {
    GraphWarehouseView()
        .environmentObject(KnowledgeGraphStore())
        .environmentObject(KnowledgeCardLibraryStore())
}
