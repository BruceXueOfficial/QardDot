import SwiftUI

// MARK: - Page And Surface Containers

struct ZDPageScaffold<Content: View>: View {
    let title: String?
    let bottomPadding: CGFloat
    let topInset: CGFloat
    let horizontalPadding: CGFloat
    let contentSpacing: CGFloat
    let content: () -> Content

    init(
        title: String? = nil,
        bottomPadding: CGFloat = 12,
        topInset: CGFloat = ZDMainPageLayout.contentTopInset,
        horizontalPadding: CGFloat = ZDSpacingScale.default.pageHorizontal,
        contentSpacing: CGFloat = ZDSpacingScale.default.section,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.bottomPadding = bottomPadding
        self.topInset = topInset
        self.horizontalPadding = horizontalPadding
        self.contentSpacing = contentSpacing
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: contentSpacing) {
                if let title {
                    Text(title)
                        .font(ZDTypographyScale.default.pageTitle)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                }

                content()
            }
            .padding(.top, topInset)
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
        }
        .zdPageBackground()
        .zdTopScrollBlurFade()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ZDSurfaceCard<Content: View>: View {
    let cornerRadius: CGFloat
    let style: ZDSurfaceStyle
    let padding: CGFloat
    let content: () -> Content

    init(
        cornerRadius: CGFloat = 14,
        style: ZDSurfaceStyle = .regular,
        padding: CGFloat = 14,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.style = style
        self.padding = padding
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .zdSurfaceCardStyle(style, cornerRadius: cornerRadius)
    }
}

// MARK: - Buttons

struct ZDPrimaryButton: View {
    let text: String
    let icon: String?
    var isDisabled: Bool = false
    var fullWidth: Bool = true
    let action: () -> Void

    init(
        text: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.icon = icon
        self.isDisabled = isDisabled
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                }
                Text(text)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            .background(ZDThemeTokens.default.interactiveFill)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.zdAccentDeep.opacity(0.18), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct ZDIconButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let systemName: String
    var active: Bool = false
    var destructive: Bool = false
    var size: CGFloat = 36
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: size, height: size)
                .background(activeBackground)
                .zdSurfaceCardStyle(active ? .elevated : .clear, cornerRadius: 999, lineWidth: 1.15)
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if destructive {
            return .red
        }
        return active ? Color.zdAccentDeep : .primary.opacity(0.85)
    }

    private var activeBackground: Color {
        active
            ? Color.zdAccentDeep.opacity(colorScheme == .dark ? 0.2 : 0.16)
            : .clear
    }
}

// MARK: - Inputs And Headers

struct ZDSearchField: View {
    let title: String
    @Binding var text: String

    init(_ title: String = "搜索", text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .zdSurfaceCardStyle(.regular, cornerRadius: 12)
    }
}

struct ZDSectionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZDTypographyScale.default.sectionTitle)
                    .foregroundStyle(.primary.opacity(0.92))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 6)
            trailing
        }
    }
}

extension ZDSectionHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) {
            EmptyView()
        }
    }
}

// MARK: - Chips And Bars

struct ZDTagChip: View {
    let text: String
    var compact: Bool = false
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .lineLimit(1)
            .font(compact ? .system(size: 10, weight: .medium) : .caption.weight(.semibold))
            .foregroundStyle(emphasized ? Color.zdAccentDeep.opacity(0.9) : .secondary)
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.vertical, compact ? 3 : 6)
            .background(
                emphasized ? Color.zdAccentSoft.opacity(0.22) : Color.secondary.opacity(0.12)
            )
            .clipShape(Capsule())
    }
}

struct ZDFloatingActionBar<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .zdSurfaceCardStyle(.elevated, cornerRadius: 28, lineWidth: 1.05)
    }
}

// MARK: - Stats

struct ZDStatTile: View {
    let title: String
    let value: String
    let icon: String?

    init(title: String, value: String, icon: String? = nil) {
        self.title = title
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.zdAccentDeep.opacity(0.78))
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .zdSurfaceCardStyle(.regular, cornerRadius: 10, lineWidth: 1.0)
    }
}

private struct ZDCoreComponentsPreview: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZDPageScaffold(title: "Core Components", bottomPadding: 24, contentSpacing: 14) {
                ZDSectionHeader("基础卡片")

                ZDSurfaceCard(style: .regular) {
                    Text("这是 `ZDSurfaceCard`，用于统一容器卡片风格。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ZDSearchField("搜索卡片", text: $searchText)

                HStack(spacing: 10) {
                    ZDIconButton(systemName: "slider.horizontal.3", active: true) { }
                    ZDIconButton(systemName: "trash", destructive: true) { }
                    Spacer()
                }

                ZDPrimaryButton(text: "创建卡片", icon: "plus") { }

                ZDFloatingActionBar {
                    Text("浮动操作栏")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.9))
                    Spacer()
                    ZDTagChip(text: "示例", emphasized: true)
                }

                ZDSectionHeader("统计模块")
                ZDStatTile(title: "卡片总量", value: "128", icon: "rectangle.stack.fill")
            }
        }
    }
}

#Preview("Core Components Showcase") {
    ZDCoreComponentsPreview()
}
