import SwiftUI

enum ZDListRenderMode: String, CaseIterable, Identifiable {
    case visual
    case balanced
    case performance

    static let storageKey = "App.ListRenderMode"
    static let defaultSelection: ZDListRenderMode = .balanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visual:
            return "视觉优先"
        case .balanced:
            return "平衡优先"
        case .performance:
            return "性能优先"
        }
    }

    var detail: String {
        switch self {
        case .visual:
            return "广场与仓库都保留玻璃效果与问号图标。"
        case .balanced:
            return "广场保留玻璃与问号，仓库关闭玻璃与问号。"
        case .performance:
            return "广场与仓库都关闭玻璃效果与问号图标。"
        }
    }

    static func resolve(rawValue: String) -> ZDListRenderMode {
        ZDListRenderMode(rawValue: rawValue) ?? .defaultSelection
    }

    var profile: ZDListRenderProfile {
        profile(for: .knowledgeSquare)
    }

    func profile(for scope: ZDListRenderScope) -> ZDListRenderProfile {
        switch self {
        case .visual:
            return ZDListRenderProfile(
                mode: .visual,
                glassQuality: .full,
                materialStrength: 1.0,
                blurStrength: 1.0,
                primaryShadowStrength: 1.0,
                showsSecondaryShadow: true,
                showsQuestionIcon: true,
                edgeFadeStyle: .glass,
                edgeFadeWidth: 46,
                edgeFadeBlurRadius: 3.2,
                topBlurFadeStyle: .glass
            )
        case .balanced:
            switch scope {
            case .knowledgeSquare:
                return ZDListRenderProfile(
                    mode: .balanced,
                    glassQuality: .full,
                    materialStrength: 0.78,
                    blurStrength: 0.72,
                    primaryShadowStrength: 0.88,
                    showsSecondaryShadow: true,
                    showsQuestionIcon: true,
                    edgeFadeStyle: .glass,
                    edgeFadeWidth: 40,
                    edgeFadeBlurRadius: 2.2,
                    topBlurFadeStyle: .glass
                )
            case .warehouse:
                return ZDListRenderProfile(
                    mode: .balanced,
                    glassQuality: .off,
                    materialStrength: 0,
                    blurStrength: 0,
                    primaryShadowStrength: 0.52,
                    showsSecondaryShadow: false,
                    showsQuestionIcon: false,
                    edgeFadeStyle: .none,
                    edgeFadeWidth: 0,
                    edgeFadeBlurRadius: 0,
                    topBlurFadeStyle: .none
                )
            }
        case .performance:
            return ZDListRenderProfile(
                mode: .performance,
                glassQuality: .off,
                materialStrength: 0,
                blurStrength: 0,
                primaryShadowStrength: 0.28,
                showsSecondaryShadow: false,
                showsQuestionIcon: false,
                edgeFadeStyle: .none,
                edgeFadeWidth: 0,
                edgeFadeBlurRadius: 0,
                topBlurFadeStyle: .none
            )
        }
    }
}

enum ZDListRenderScope: Equatable {
    case knowledgeSquare
    case warehouse
}

enum ZDListGlassQuality: Equatable {
    case full
    case simplified
    case off
}

enum ZDListEdgeFadeStyle: Equatable {
    case glass
    case gradient
    case none
}

enum ZDTopBlurFadeStyle: Equatable {
    case glass
    case gradient
    case none
}

struct ZDListRenderProfile: Equatable {
    let mode: ZDListRenderMode
    let glassQuality: ZDListGlassQuality
    let materialStrength: Double
    let blurStrength: CGFloat
    let primaryShadowStrength: Double
    let showsSecondaryShadow: Bool
    let showsQuestionIcon: Bool
    let edgeFadeStyle: ZDListEdgeFadeStyle
    let edgeFadeWidth: CGFloat
    let edgeFadeBlurRadius: CGFloat
    let topBlurFadeStyle: ZDTopBlurFadeStyle

    var tracksEdgeFade: Bool {
        edgeFadeStyle != .none
    }
}

private struct ZDListRenderModeEnvironmentKey: EnvironmentKey {
    // Keep non-list pages on current visual path unless explicitly overridden.
    static let defaultValue = ZDListRenderMode.visual
}

private struct ZDListRenderScopeEnvironmentKey: EnvironmentKey {
    static let defaultValue = ZDListRenderScope.knowledgeSquare
}

extension EnvironmentValues {
    var zdListRenderMode: ZDListRenderMode {
        get { self[ZDListRenderModeEnvironmentKey.self] }
        set { self[ZDListRenderModeEnvironmentKey.self] = newValue }
    }

    var zdListRenderScope: ZDListRenderScope {
        get { self[ZDListRenderScopeEnvironmentKey.self] }
        set { self[ZDListRenderScopeEnvironmentKey.self] = newValue }
    }

    var zdListRenderProfile: ZDListRenderProfile {
        get { zdListRenderMode.profile(for: zdListRenderScope) }
        set { zdListRenderMode = newValue.mode }
    }
}
