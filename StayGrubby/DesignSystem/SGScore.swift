import SwiftUI

/// Native in-app score presentation. Callers pass text that has already passed the
/// score gate (`ScoreUnlockState.scoreText`) or an authorized server snapshot; `nil`
/// means locked. Exported/rendered share cards keep their own brand-red treatment.
/// Presentation only: no score math, calibration, order or unlock decisions here.
enum SGScoreRole {
    /// Rows, Signature tiles, detail and version rows: open semantic-colored numerals.
    case standard
    /// Result/composer summary: the same numerals followed by "/ 10".
    case outOfTen
    /// The Pass card: numerals inside a quiet ring, scaled with Dynamic Type.
    case medallion
}

struct SGScore: View {
    let text: String?
    var role: SGScoreRole = .standard
    /// Applied to the visible score only, so the locked indicator keeps `score-locked`.
    var identifier: String? = nil
    @ScaledMetric(relativeTo: .headline) private var medallionDiameter = 52.0

    var body: some View {
        if let text {
            let color = SGTheme.ScoreColor.color(forDisplayedScore: text)
            Group {
                switch role {
                case .standard:
                    Text(text).font(SGTheme.TypeRole.score)
                case .outOfTen:
                    Text("\(text) / 10").font(SGTheme.TypeRole.score)
                case .medallion:
                    Text(text).font(.headline.weight(.bold)).monospacedDigit()
                        .frame(width: medallionDiameter, height: medallionDiameter)
                        .background(SGTheme.ColorToken.surface, in: Circle())
                        .overlay { Circle().stroke(color.opacity(0.6), lineWidth: 1.5) }
                }
            }
            .foregroundStyle(color).fixedSize()
            .accessibilityLabel("Score \(text)")
            .modifier(OptionalIdentifier(identifier: identifier))
        } else {
            LockedScoreIndicator()
        }
    }
}

private struct OptionalIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier { content.accessibilityIdentifier(identifier) } else { content }
    }
}
