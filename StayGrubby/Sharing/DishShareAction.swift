import SwiftUI

/// Both entry points share the same card and export-safe copyable caption.
struct DishShareAction: View {
    let model: ShareCardModel
    var prominent = false
    var compact = false
    var toolbar = false
    var identifier = "detail-share-dish"
    var currentModel: (() -> ShareCardModel)? = nil
    @Environment(\.cookingMediaRoot) private var mediaRoot
    @State private var card: RenderedDishShareCard?
    @State private var notice: ShareCardNotice?

    var body: some View {
        Group {
            if toolbar {
                Button { prepare() } label: { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44) }
                    .buttonStyle(.plain).disabled(model.scoreText == nil)
                    .accessibilityIdentifier(model.scoreText == nil ? "dish-sharing-locked" : identifier)
                    .accessibilityLabel(model.scoreText == nil ? "Share locked. Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock sharing." : "Share Dish")
            } else if model.scoreText == nil {
                Label(compact ? "Share" : "Share Dish unlocks with your scores", systemImage: "lock.fill")
                    .font(compact ? SGTheme.TypeRole.headline : SGTheme.TypeRole.secondary).foregroundStyle(.secondary)
                    .accessibilityIdentifier("dish-sharing-locked")
                    .accessibilityLabel("Share locked. Rank \(ScoreUnlockPolicy.requiredRankedEntryCount) dishes or versions to unlock sharing.")
                    .frame(maxWidth: compact ? .infinity : nil, minHeight: compact ? SGTheme.Size.minimumTap : nil)
                    .background(compact ? SGTheme.ColorToken.elevatedSurface : .clear, in: RoundedRectangle(cornerRadius: SGTheme.Radius.field))
            } else {
                Button {
                    prepare()
                } label: {
                    Label(compact ? "Share" : "Share Dish", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(SGButtonStyle(prominent: prominent, compact: compact, prominentColor: SGTheme.ColorToken.buttonAccent))
                .accessibilityIdentifier(identifier)
                .accessibilityLabel("Share Dish")
                .accessibilityHint("Shares a branded image and copyable dish summary. Choose Save Image to save the card to Photos.")
            }
        }
        .shareCardSheet(card: $card, notice: $notice)
        .onChange(of: model.scoreText) { _, score in if score == nil { card = nil } }
    }
    private func prepare() {
        do { card = try ShareCardRenderer.render(model: currentModel?() ?? model, mediaRoot: mediaRoot) }
        catch { notice = .preparationFailed(error.localizedDescription) }
    }
}
