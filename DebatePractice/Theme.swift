import SwiftUI
import UIKit

enum Theme {
    static let background = dynamic(light: (0.965, 0.957, 0.937), dark: (0.09, 0.09, 0.085))

    static let surface = dynamic(light: (1, 1, 1), dark: (0.15, 0.15, 0.145))

    static let tint = dynamic(light: (0.894, 0.933, 0.933), dark: (0.13, 0.19, 0.20))

    static let sand = dynamic(light: (0.976, 0.925, 0.835), dark: (0.26, 0.21, 0.13))
    static let sandText = dynamic(light: (0.45, 0.30, 0.08), dark: (0.93, 0.80, 0.55))

    static let border = dynamic(light: (0.85, 0.83, 0.79), dark: (0.28, 0.28, 0.27))

    static let accent = dynamic(light: (0.12, 0.44, 0.47), dark: (0.40, 0.70, 0.72))
    static let danger = Color(red: 0.72, green: 0.24, blue: 0.20)

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

struct CardStyle: ViewModifier {
    var fill: Color = Theme.surface
    func body(content: Content) -> some View {
        content
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border))
    }
}

extension View {
    func card(fill: Color = Theme.surface) -> some View { modifier(CardStyle(fill: fill)) }
}
