import SwiftUI

struct AiChatTestView: View {
    @StateObject private var viewModel = AiChatViewModel()
    @StateObject private var library = KnowledgeCardLibraryStore(
        cards: KnowledgeCardLibraryStore.bundledSeedCardsForPreview()
    )

    let fakeMessages: [ChatMessage] = [
        ChatMessage(
            id: UUID(),
            content: "你好！由于我现在不连接 API 服务器，我将只为你展示界面测试的内容。",
            type: .ai,
            createdAt: Date().addingTimeInterval(-300)
        ),
        ChatMessage(
            id: UUID(),
            content: "好的，我想看看这段界面的展示效果。",
            type: .user,
            createdAt: Date().addingTimeInterval(-240)
        ),
        ChatMessage(
            id: UUID(),
            content: "好的，这是一段很长的文本模拟回复。这个文本将会自动折叠展示在 UI 中并且不会超过安全边距。这里可以预览毛玻璃卡片的嵌套。\n\n- 这是列表的第一条\n- 这是列表的第二条\n- 还可以看一看代码或者公式的格式化。",
            type: .ai,
            createdAt: Date().addingTimeInterval(-180)
        ),
        ChatMessage(
            id: UUID(),
            content: "这看起来很酷！如果遇到了报错呢？",
            type: .user,
            createdAt: Date().addingTimeInterval(-120)
        ),
        ChatMessage(
            id: UUID(),
            content: "百炼接口报错：[Error 400] 模型处理请求失败，请检查输入格式参数。",
            type: .ai,
            createdAt: Date().addingTimeInterval(-60)
        )
    ]

    var body: some View {
        NavigationStack {
            AiChatPage()
                .environmentObject(viewModel)
                .environmentObject(library)
                .onAppear {
                    // 覆盖假数据以供 UI 预览
                    viewModel.messages = fakeMessages
                }
        }
    }
}

#Preview("AI Chat Test Page") {
    AiChatTestView()
}
