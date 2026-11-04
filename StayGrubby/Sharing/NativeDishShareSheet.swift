import SwiftUI
import UIKit

nonisolated enum NativeShareOutcome: Equatable {
    case cancelled, shared, imageSaved, imageSaveFailed, sharingFailed

    static func make(activity: UIActivity.ActivityType?, completed: Bool, error: Error?) -> Self {
        if error != nil { return activity == .saveToCameraRoll ? .imageSaveFailed : .sharingFailed }
        guard completed else { return .cancelled }
        return activity == .saveToCameraRoll ? .imageSaved : .shared
    }

    var notice: ShareCardNotice? {
        switch self {
        case .cancelled, .shared: nil
        case .imageSaved: .imageSaved
        case .imageSaveFailed: .imageSaveFailed
        case .sharingFailed: .sharingFailed
        }
    }
}

/// Accepted rendered image plus a copyable caption made only from export-safe facts.
/// No private cook URL, account metadata, notes, history or cloud operation.
struct NativeDishShareSheet: UIViewControllerRepresentable {
    let card: RenderedDishShareCard
    var onCompletion: (NativeShareOutcome) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        Self.makeActivityController(for: card, onCompletion: onCompletion)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}

    static func makeActivityController(for card: RenderedDishShareCard,
                                       onCompletion: @escaping (NativeShareOutcome) -> Void) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems(for: card), applicationActivities: nil)
        controller.completionWithItemsHandler = { activity, completed, _, error in
            let outcome = NativeShareOutcome.make(activity: activity, completed: completed, error: error)
            Task { @MainActor in onCompletion(outcome) }
        }
        return controller
    }
    static func activityItems(for card: RenderedDishShareCard) -> [Any] {
        guard let caption = caption(for: card) else { return [] }
        return [card.image, caption]
    }
    static func caption(for card: RenderedDishShareCard) -> String? {
        if let model = card.model, let score = model.scoreText {
            return ["#stayGRUBBY", model.title, model.versionSubtitle, "\(score) / 10"].compactMap { $0 }.joined(separator: "\n")
        }
        if let model = card.topThreeModel, model.rows.count == 3, model.rows.allSatisfy({ $0.dish.scoreText != nil }) {
            return (["#stayGRUBBY", "Signature Dishes"] + model.rows.map { "\($0.dish.title) · \($0.dish.scoreText!) / 10" }).joined(separator: "\n")
        }
        return nil
    }
}
