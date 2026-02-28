import SwiftUI

enum ZDListRenderMode: String, CaseIterable, Identifiable {
    case visual
    case performance

    static let storageKey = "App.ListRenderMode"
    static let defaultSelection: ZDListRenderMode = .visual

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .visual:
            return "视效优先"
        case .performance:
            return "性能优先"
        }
    }

    var detail: String {
        switch self {
        case .visual:
            return "适配液态玻璃视效，清晰透亮"
        case .performance:
            return "采用玻璃渐变视效，流畅美观"
        }
    }

    static func resolve(rawValue: String) -> ZDListRenderMode {
        ZDListRenderMode(rawValue: rawValue) ?? .defaultSelection
    }

    var profile: ZDListRenderProfile {
        profile(for: .knowledgeSquare)
    }

    func profile(for _: ZDListRenderScope) -> ZDListRenderProfile {
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
                questionPlacement: .topTrailing,
                questionOpacity: 1.0,
                questionBlurRadius: 0,
                questionFrostStrength: 0,
                edgeFadeStyle: .glass,
                edgeFadeWidth: 46,
                edgeFadeBlurRadius: 3.2,
                topBlurFadeStyle: .glass
            )
        case .performance:
            return ZDListRenderProfile(
                mode: .performance,
                glassQuality: .off,
                materialStrength: 0,
                blurStrength: 0,
                primaryShadowStrength: 0.42,
                showsSecondaryShadow: false,
                showsQuestionIcon: false,
                questionPlacement: .bottomTrailing,
                questionOpacity: 0.86,
                questionBlurRadius: 7.2,
                questionFrostStrength: 1.18,
                edgeFadeStyle: .none,
                edgeFadeWidth: 0,
                edgeFadeBlurRadius: 0,
                topBlurFadeStyle: .gradient
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

enum ZDQuestionIconPlacement: Equatable {
    case topTrailing
    case bottomTrailing
}

struct ZDListRenderProfile: Equatable {
    let mode: ZDListRenderMode
    let glassQuality: ZDListGlassQuality
    let materialStrength: Double
    let blurStrength: CGFloat
    let primaryShadowStrength: Double
    let showsSecondaryShadow: Bool
    let showsQuestionIcon: Bool
    let questionPlacement: ZDQuestionIconPlacement
    let questionOpacity: Double
    let questionBlurRadius: CGFloat
    let questionFrostStrength: Double
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
