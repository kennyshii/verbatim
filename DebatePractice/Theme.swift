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
        configuration.label
            .font(.headline)
            .foregroundStyle(Color(red: 0.114, green: 0.145, blue: 0.251))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Theme.surfaceHigh.opacity(configuration.isPressed ? 0.6 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.border))
    }
}

struct BrandHeader: View {
    var size: CGFloat = 40
    var showsName: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            if showsName {
                Text("Verbatim")
                    .font(.system(size: size * 0.62, weight: .bold, design: .default))
                    .foregroundStyle(Theme.cream)
            }
        }
    }
}

struct FieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
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
