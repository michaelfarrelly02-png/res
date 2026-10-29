import SwiftUI
import UIKit

/// UIKit appearance settings for the tab bar and navigation bars,
/// which SwiftUI does not fully expose.
enum AppearanceConfigurator {
    static func apply() {
        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = UIColor(Theme.tabBarBackground)
        tabBar.shadowColor = UIColor.white.withAlphaComponent(0.06)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar

        let largeTitleFont = roundedFont(size: 34, weight: .heavy)
        let titleFont = roundedFont(size: 17, weight: .bold)

        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        transparent.titleTextAttributes = [.foregroundColor: UIColor.white, .font: titleFont]
        transparent.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: largeTitleFont]

        let blurred = UINavigationBarAppearance()
        blurred.configureWithDefaultBackground()
        blurred.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        blurred.backgroundColor = UIColor(Theme.tabBarBackground).withAlphaComponent(0.6)
        blurred.shadowColor = .clear
        blurred.titleTextAttributes = [.foregroundColor: UIColor.white, .font: titleFont]
        blurred.largeTitleTextAttributes = [.foregroundColor: UIColor.white, .font: largeTitleFont]

        UINavigationBar.appearance().scrollEdgeAppearance = transparent
        UINavigationBar.appearance().standardAppearance = blurred
        UINavigationBar.appearance().compactAppearance = blurred
    }

    private static func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}
