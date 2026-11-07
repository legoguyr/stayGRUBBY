import Foundation
import SwiftData

/// Read the accepted receipt snapshot, independent of other cooks and private photo backup.
@MainActor enum CookPublicationReadiness {
    static func revision(for attempt: CookingAttempt, binding: SyncStoreBinding?, requireCurrent: Bool = true) -> Int? {
        #if DEBUG
        if binding == nil, DebugReviewConfiguration.current.storeID != nil,
           ProcessInfo.processInfo.arguments.contains("--social-review") { return 0 }
        #endif
        guard let binding, binding.enabled, !binding.restorationRequired, binding.acceptedRevision >= 0,
              let data = binding.acceptedSnapshotData, let graph = try? CookingGraph.decode(data),
              let account = binding.accountID, graph.accountID == account,
              let dish = attempt.dish, let item = attempt.rankedItem,
              let rankID = graph.libraries.first?.globalRankingID, item.list?.id == rankID,
              item.id == attempt.rankedItemID, !attempt.isDeleted, !dish.isDeleted, !item.isDeleted,
              let acceptedCook = graph.attempts.first(where: { $0.id == attempt.id }),
              acceptedCook.dishID == dish.id, acceptedCook.rankedItemID == item.id,
              let acceptedDish = graph.dishes.first(where: { $0.id == dish.id }),
              let acceptedItem = graph.items.first(where: { $0.id == item.id }), acceptedItem.rankingID == rankID
        else { return nil }
        if requireCurrent {
            guard acceptedCook.versionTitle == attempt.versionTitle,
                  acceptedCook.sequenceNumber == attempt.sequenceNumber,
                  acceptedCook.categoryCode == attempt.categoryCode,
                  acceptedDish.name == dish.name, acceptedDish.cuisine == dish.cuisine,
                  acceptedDish.sourceID == dish.source?.id,
                  acceptedDish.publicDescription == dish.publicDescription,
                  acceptedItem.strength == item.strength,
                  acceptedItem.sessionDiagnosticsData == item.sessionDiagnosticsData
            else { return nil }
            if let source = dish.source, graph.sources.first(where: { $0.id == source.id }) != SourceTransfer(source) { return nil }
        }
        return binding.acceptedRevision
    }
}
