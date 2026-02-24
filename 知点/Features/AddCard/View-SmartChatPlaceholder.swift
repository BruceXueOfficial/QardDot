import SwiftUI

struct SmartChatPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .zdPageBackground()

                VStack(spacing: 20) {
                    Spacer()

                    // 图标动画
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.zdAccentSoft.opacity(0.22),
                                        Color.zdAccentMist.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)

                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.zdAccentDeep.opacity(0.92), Color.zdAccentSoft.opacity(0.84)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    ZDSurfaceCard(cornerRadius: 20, style: .regular, padding: 18) {
                        VStack(spacing: 10) {
                            Text("智能对话")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)

                            ZDTagChip(text: "即将上线", emphasized: true)

                            Text("通过 AI 对话，自动提取要点并生成知识卡片")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 30)

                    Spacer()
                    Spacer()
                }
            }
            .navigationTitle("智能对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                        .font(.subheadline)
                }
            }
        }
    }
}

#Preview("Smart Chat") {
    SmartChatPlaceholderView()
}
