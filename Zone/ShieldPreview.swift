#if DEBUG
import SwiftUI
import UIKit

// Debug only. The simulator does not show Screen Time shields, so this draws a copy of the
// Zone block screen with the values of the shield extension, for screenshots.
// Open it with: xcrun simctl launch <device> com.nethum.zone -ZoneShieldPreview YES
// The layout copies Apple's block screen (ScreenTimeUI, BlockingUI-Translucent-iOS):
// icon, 15 pt gap, title (large title, bold), subtitle (body), and a 167 x 50 capsule button
// 48 pt above the bottom safe area. The text block sits in the middle of the space above the button.
struct ShieldPreview: View {
    var body: some View {
        ZStack {
            Color(uiColor: ShieldLook.background)
                .ignoresSafeArea()
            Blur(style: ShieldLook.blurStyle)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                message
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding([.horizontal, .top], 8)
                ShieldButton(title: ShieldLook.button)
                    .frame(width: 167, height: 50)
                    .padding(.bottom, 48)
            }
        }
        // Apple's shield uses the plain system font, not the app's rounded one.
        .fontDesign(.default)
        .preferredColorScheme(.dark)
    }

    private var message: some View {
        VStack(spacing: 0) {
            if let icon = ShieldLook.icon {
                Image(uiImage: icon)
                    .padding(.bottom, 15)
            }
            Text(ShieldLook.title)
                .font(.largeTitle.bold())
                .foregroundStyle(Color(uiColor: ShieldLook.ink))
                .minimumScaleFactor(0.5)
            Text(ShieldLook.subtitle)
                .font(.body)
                .foregroundStyle(Color(uiColor: ShieldLook.mute))
        }
        .multilineTextAlignment(.center)
    }
}

private struct Blur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {}
}

// A bone capsule with a black label, like the shield button on a device.
// iOS 26 draws the real button as tinted glass. A glass UIButton in the app always makes
// its label white, so the preview uses a plain filled button.
private struct ShieldButton: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = ShieldLook.bone
        configuration.baseForegroundColor = ShieldLook.black
        configuration.cornerStyle = .capsule
        configuration.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 17, weight: .semibold)])
        )
        return UIButton(configuration: configuration)
    }

    func updateUIView(_ button: UIButton, context: Context) {}
}
#endif

