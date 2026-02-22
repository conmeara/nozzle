import Foundation

enum OnboardingStrings {
    static let welcomeTitle = localized("onboarding_welcome_title", defaultValue: "Welcome to Nozzle!")
    static let welcomeSubtitle = localized(
        "onboarding_welcome_subtitle",
        defaultValue: "Your universal content management platform"
    )
    static let permissionsTitle = localized("onboarding_permissions_title", defaultValue: "Permissions")
    static let permissionsSubtitle = localized(
        "onboarding_permissions_subtitle",
        defaultValue: "Grant permissions for the best experience"
    )
    static let shortcutsTitle = localized("onboarding_shortcuts_title", defaultValue: "Keyboard Shortcuts")
    static let shortcutsSubtitle = localized(
        "onboarding_shortcuts_subtitle",
        defaultValue: "Customize your keyboard shortcuts"
    )
    static let demoTitle = localized("onboarding_demo_title", defaultValue: "Quick Demo")
    static let resourcesTitle = localized("onboarding_resources_title", defaultValue: "Resources")
    static let resourcesSubtitle = localized(
        "onboarding_resources_subtitle",
        defaultValue: "Learn prompt engineering and get help"
    )
    static let finishTitle = localized("onboarding_finish_title", defaultValue: "Ready to go!")
    static let finishSubtitle = localized(
        "onboarding_finish_subtitle",
        defaultValue: "nozzle is ready to boost your productivity"
    )

    private static func localized(_ key: String, defaultValue: String) -> String {
        NSLocalizedString(key, value: defaultValue, comment: "")
    }
}
