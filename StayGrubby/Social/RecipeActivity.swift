import SwiftUI

nonisolated struct RecipeActivity: Codable, Identifiable, Sendable {
    let id: UUID
    let createdAt: Double
    let author: SocialPerson
    let entry: CookbookEntry
    var isAuthor: Bool? = nil
}
nonisolated enum GrubListActivity: Codable, Identifiable, Sendable {
    case cook(SocialPost), recipe(RecipeActivity)
    var id: UUID { switch self { case .cook(let p): p.id; case .recipe(let r): r.id } }
    var createdAt: Double { switch self { case .cook(let p): p.createdAt; case .recipe(let r): r.createdAt } }
    private enum CodingKeys: String, CodingKey { case kind, post, recipe }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "cook": self = .cook(try c.decode(SocialPost.self, forKey: .post))
        case "recipe_created": self = .recipe(try c.decode(RecipeActivity.self, forKey: .recipe))
        default: throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Unsupported activity")
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .cook(let p): try c.encode("cook", forKey: .kind); try c.encode(p, forKey: .post)
        case .recipe(let r): try c.encode("recipe_created", forKey: .kind); try c.encode(r, forKey: .recipe)
        }
    }
}
nonisolated struct GrubListPage: Codable { var activities: [GrubListActivity] }

struct RecipeActivityCard: View {
    let activity: RecipeActivity
    let profile: () -> Void
    let open: () -> Void
    @Environment(AppLinkRouter.self) private var links
    @State private var reporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: SGTheme.Space.small) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: SGTheme.Space.small) {
                    Color.clear.aspectRatio(4 / 3, contentMode: .fit)
                        .overlay { RecipePhoto(id: activity.entry.photoID, dish: nil, name: activity.entry.recipeTitle) }
                        .clipped().clipShape(RoundedRectangle(cornerRadius: SGTheme.Radius.hero))
                        .accessibilityHidden(true)
                    SGEyebrow(text: "Recipe")
                    HStack {
                        Text(activity.entry.recipeTitle).font(SGTheme.TypeRole.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: SGTheme.Space.small)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).accessibilityHidden(true)
                    }
                }.foregroundStyle(SGTheme.ColorToken.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(activity.entry.recipeTitle)
                .accessibilityValue("Recipe").accessibilityHint("Opens Recipe")
                .accessibilityIdentifier("feed-recipe-open-\(activity.entry.recipeID)")
            HStack {
                Button {
                    if activity.isAuthor == true { links.openOwnKitchen() } else { profile() }
                } label: {
                    SocialPersonLabel(person: activity.author,
                                      detail: SocialPostPresentation.timestamp(Date(timeIntervalSince1970: activity.createdAt)), size: 36)
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                RecipeLinkShare(url: AppRoute.recipeURL(activity.entry.recipeID)).buttonStyle(.borderless)
                RecipeActions(sendContent: .recipe(activity.entry.recipeID)) {
                    if activity.isAuthor != true { Button("Report account", systemImage: "flag") { reporting = true } }
                }
            }
        }.padding(.vertical, SGTheme.Space.medium)
            .overlay(alignment: .bottom) { SGTheme.ColorToken.border.frame(height: SGTheme.Size.border) }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .contain).accessibilityIdentifier("feed-recipe-\(activity.id)")
            .sheet(isPresented: $reporting) { SocialReportEditor(kind: "profile", targetID: activity.author.id, close: { reporting = false }) }
    }
}
