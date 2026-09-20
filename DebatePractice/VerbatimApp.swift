import SwiftUI
import UIKit

@main
struct VerbatimApp: App {
    @StateObject private var app = AppState()

    init() {
        let cream = UIColor(red: 0.965, green: 0.945, blue: 0.914, alpha: 1)

        func brand(_ name: String, _ size: CGFloat, fallback: UIFont) -> UIFont {
            UIFont(name: name, size: size) ?? fallback
        }

        let title = brand("EBGaramond-SemiBold", 19, fallback: .systemFont(ofSize: 19, weight: .semibold))
        let largeTitle = brand("EBGaramond-Bold", 34, fallback: .systemFont(ofSize: 34, weight: .bold))
        let control = brand("EBGaramond-Medium", 17, fallback: .systemFont(ofSize: 17))
        let tabLabel = brand("EBGaramond-Medium", 12, fallback: .systemFont(ofSize: 12))

        UINavigationBar.appearance().titleTextAttributes = [.font: title, .foregroundColor: cream]
        UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitle, .foregroundColor: cream]
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: control], for: .normal)
        UISegmentedControl.appearance().setTitleTextAttributes([.font: control], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tabLabel], for: .normal)
        UITextField.appearance().font = brand("EBGaramond-Regular", 19, fallback: .systemFont(ofSize: 19))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
        }
    }
}
