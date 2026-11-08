import Foundation
import Testing
@testable import StayGrubby

/// Dish Detail collaborators (tagged Sous Chefs).
struct DishRecipesTests {

    @Test func collaboratorLineNamesActiveTaggedSousChefsOnly() {
        func person(_ name: String) -> SocialPerson { SocialPerson(id: UUID(), displayName: name, username: name.lowercased(), relationship: .friends) }
        func event(_ people: [(String, String)]) -> SharedCookingEvent {
            SharedCookingEvent(id: UUID(), owner: person("Guy"), metadata: .init(title: "Chili"), isOwner: true,
                               participants: people.map { .init(person: person($0.0), state: $0.1) })
        }
        let line = SharedCookingEvent.collaboratorLine(event([("Alex", "joined"), ("Sam", "pending"), ("Kim", "declined"), ("Lee", "removed")]))
        #expect(line.hasPrefix("Cooked with ") && line.contains("Alex") && line.contains("Sam"))
        #expect(!line.contains("Kim") && !line.contains("Lee"))
        #expect(SharedCookingEvent.collaboratorLine(event([("Kim", "declined")])) == "Cooked Together · participants")
    }
}
