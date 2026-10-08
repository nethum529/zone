import ManagedSettings
import ManagedSettingsUI
import UIKit

// The Zone block screen. iOS shows it over a blocked app or website.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        zone
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        zone
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        zone
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        zone
    }

    private var zone: ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: ShieldLook.blurStyle,
            backgroundColor: ShieldLook.background,
            icon: ShieldLook.icon,
            title: .init(text: ShieldLook.title, color: ShieldLook.ink),
            subtitle: .init(text: ShieldLook.subtitle, color: ShieldLook.mute),
            primaryButtonLabel: .init(text: ShieldLook.button, color: ShieldLook.black),
            primaryButtonBackgroundColor: ShieldLook.bone
        )
    }
}
