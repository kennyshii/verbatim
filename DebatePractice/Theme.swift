import SwiftUI

enum Theme {
    static let background = Color(red: 0.114, green: 0.145, blue: 0.251)
    static let surface = Color(red: 0.145, green: 0.180, blue: 0.306)
    static let surfaceHigh = Color(red: 0.180, green: 0.220, blue: 0.376)
    static let tint = Color(red: 0.165, green: 0.204, blue: 0.345)
    static let accent = Color(red: 0.933, green: 0.482, blue: 0.357)
    static let cream = Color(red: 0.965, green: 0.945, blue: 0.914)
    static let secondaryText = Color(red: 0.604, green: 0.639, blue: 0.749)
    static let border = Color(red: 0.204, green: 0.243, blue: 0.400)
    static let success = Color(red: 0.373, green: 0.788, blue: 0.561)
    static let danger = Color(red: 0.898, green: 0.341, blue: 0.309)
    static let sand = Color(red: 0.933, green: 0.482, blue: 0.357).opacity(0.16)
    static let sandText = Color(red: 0.965, green: 0.686, blue: 0.588)

    static let corner: CGFloat = 16
}

enum BrandFont {
    static func name(_ weight: Font.Weight, italic: Bool) -> String {
        let suffix: String
        switch weight {
        case .bold, .heavy, .black: suffix = "Bold"
        case .semibold: suffix = "SemiBold"
        case .medium: suffix = "Medium"
        default: suffix = italic ? "" : "Regular"
        }
        if italic { return suffix.isEmpty ? "EBGaramond-Italic" : "EBGaramond-\(suffix)Italic" }
        return "EBGaramond-\(suffix)"
    }

    static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 37
        case .title: return 31
        case .title2: return 25
        case .title3: return 22
        case .headline: return 19
        case .body: return 19
        case .callout: return 18
        case .subheadline: return 17
        case .footnote: return 15
        case .caption: return 14
        case .caption2: return 13
        @unknown default: return 19
        }
    }
}

extension Font {
    static func brand(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        .custom(BrandFont.name(weight, italic: italic), size: BrandFont.size(style), relativeTo: style)
    }

    static func brand(size: CGFloat, weight: Font.Weight = .regular, italic: Bool = false) -> Font {
        .custom(BrandFont.name(weight, italic: italic), size: size)
    }
}

extension View {
    func subtext(_ style: Font.TextStyle = .footnote) -> some View {
        font(.brand(style)).foregroundStyle(Theme.secondaryText)
    }

    func heading(_ style: Font.TextStyle = .headline, color: Color = Theme.cream) -> some View {
        font(.brand(style, weight: .semibold)).foregroundStyle(color)
    }
}

struct CardStyle: ViewModifier {
    var fill: Color = Theme.surface
    var radius: CGFloat = Theme.corner

    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

extension View {
    func card(fill: Color = Theme.surface, radius: CGFloat = Theme.corner) -> some View {
        modifier(CardStyle(fill: fill, radius: radius))
    }
}

struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.brand(.headline, weight: .semibold))
                .foregroundStyle(isEnabled ? Color(red: 0.114, green: 0.145, blue: 0.251) : Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isEnabled ? Theme.accent.opacity(configuration.isPressed ? 0.75 : 1) : Theme.surfaceHigh)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isEnabled ? Color.clear : Theme.border))
        }
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration)
    }

    private struct StyledLabel: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration

        var body: some View {
            configuration.label
                .font(.brand(.subheadline, weight: .semibold))
                .foregroundStyle(isEnabled ? Theme.cream : Theme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.surfaceHigh.opacity(configuration.isPressed ? 0.6 : 1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border))
                .opacity(isEnabled ? 1 : 0.6)
        }
    }
}

struct BrandHeader: View {
    var size: CGFloat = 40
    var showsName: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.22) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: size * 0.46)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + size * 0.04 }
            if showsName {
                Text("Verbatim")
                    .font(.brand(size: size * 0.82, weight: .bold))
                    .foregroundStyle(Theme.cream)
            }
        }
    }
}

struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.brand(.body))
            .foregroundStyle(Theme.cream)
            .tint(Theme.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border))
    }
}

extension View {
    func field() -> some View { modifier(FieldBackground()) }
}
