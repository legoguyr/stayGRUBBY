#if INTERNAL_TESTING
import SwiftUI

/// Present only in the `Internal` configuration (scheme "StayGrubby Internal"). `marker` is shown in
/// Settings, so it stays in the binary; `DevelopmentTools/check_release_excludes_internal.sh` rejects any
/// app or archive containing it before App Store or external TestFlight submission.
enum InternalBuild {
    static let marker = "STAYGRUBBY-INTERNAL-TESTING-BUILD"
}

/// Settings › Internal Testing: names the build type and opens the first-run preview.
struct InternalTestingSettingsSection: View {
    let preview: () -> Void
    var body: some View {
        Section {
            LabeledContent("Build", value: "Internal Testing").foregroundStyle(SGTheme.ColorToken.accent)
                .accessibilityIdentifier("internal-build-label")
            Button("Preview First-Time Experience", action: preview).accessibilityIdentifier("internal-preview-open")
        } header: { Text("Internal Testing") } footer: {
            Text("Internal TestFlight group only. Never add this build to external testing or submit it for App Store review. The preview uses temporary data and never changes your account. \(InternalBuild.marker)")
        }
    }
}
#endif
