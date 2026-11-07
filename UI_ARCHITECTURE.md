# StayGrubby UI architecture — current design-system specification

**Canonical current UI truth — reconciled November 7, 2026 at Build 4 (`c09c18e`).** This file states how StayGrubby screens look and behave *now*, the rules every UI change follows, and the queued work for the system-wide UI overhaul. It replaces the former newest-first stack of dated sections, which is preserved verbatim in [UI_ARCHITECTURE_HISTORY.md](UI_ARCHITECTURE_HISTORY.md) as evidence. Product/technical architecture lives in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md); sequencing in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md); workflow rules in [AGENTS.md](AGENTS.md).

Status words: **Implemented** (in Build 4 source), **Decided** (owner decision not yet implemented), **Planned** (overhaul work), **Known defect** (observed, not yet fixed).

## 1. Principles

**Content first. Actions second. Explanation only when necessary.**

- Editorial food photography, contemporary restaurant identity, strong type, intentional whitespace, restrained motion and polished native interaction.
- Avoid generic gradients, excessive glass, glowing buttons, generic component-kit appearance, kitschy chef/fork decoration, unnecessary emoji and explanatory copy that restates what a control does.
- Keep text that carries safety, privacy, permission, uncertainty, recovery, provenance or destructive meaning. Remove redundant slogans per screen, never by global string deletion.
- Prefer compact native controls over full-width UI when full-width emphasis is not needed. One primary action per screen region.
- **Reuse Before Reinvention** (AGENTS.md): before creating a picker, selector, sheet, menu, search/filter/sort control, card, editor, photo treatment, score treatment, content state or toolbar, inspect accepted equivalents. Prefer direct reuse → generalize → shared component → unique implementation only for genuinely different behavior. Location alone never justifies a different control.

## 2. Platform requirements (Implemented, mandatory)

- iPhone, **upright portrait only** (single `UIInterfaceOrientationPortrait` value in Debug and Release; no per-screen orientation code). No iPad work.
- iOS 17.0 minimum. `sgIndependentToolbarBackground` applies the glass toolbar treatment only on iOS 26+; iOS 17–18 use native toolbar appearance.
- Light and dark appearance; Dynamic Type without size clamps (accessibility sizes stack rather than shrink text); VoiceOver labels/values including score and lock state; Reduce Motion removes spatial animation; touch targets normally ≥ 44 points; native keyboard Done for multiline entry.
- Scores, selection and state never rely on color alone.

## 3. Brand and tokens (Implemented)

Source of truth: `StayGrubby/DesignSystem/StayGrubbyTheme.swift` (`SGTheme`). Change tokens there, not per screen.

| Token | Value / rule |
| --- | --- |
| Brand identity | `#stayGRUBBY`, always with the hashtag. Use the asset-catalog wordmark/icons; never reconstruct the wordmark in type. |
| `SGTheme.Brand.red` | **`#F10607`** — sampled from the canonical logo asset; takes precedence over the conceptual `#FF2D1F`. Used for identity and exported/rendered share-card scores. |
| `Brand.cream` / `Brand.charcoal` | `#FAF3EC` / `#1F1F1F` |
| `ColorToken.accent` | Adaptive control red (light `#CB1015`, dark `#FF6B63`); `buttonAccent` `#CB1015` for white-text contrast. Use for interactive controls instead of literal brand red. |
| Surfaces | Adaptive `background`, `surface`, `elevatedSurface`, `focusBackground`; opaque content surfaces. Glass only for interactive chrome (system tab bar, iOS 26 toolbar). |
| `ScoreColor` | Native in-app scores only: muted coral 1.0–4.9, orange 5.0–7.5, gold 7.6–10.0, adaptive shades. Exports and embedded rendered previews always use `Brand.red`. |
| Type/space/radius/size/motion | `SGTheme.TypeRole`, `Space`, `Radius`, `Size`, motion timing. Rounded identity/title/score roles. |

## 4. App shell and navigation

**Implemented:** `ContentView` owns four native tabs — **Grub List / Grub Rank (initial) / Food Bible / My Kitchen** — each with its own `NavigationStack`. Primary tabs show the compact official wordmark through `SGPrimaryBrandTitle`. Cooking forms are modal sheets. Onboarding/Sign in with Apple and account readiness sit above the shell. No fifth tab.

**Tickets** (in-app notifications, 🎟️): *Decided* — Tickets belongs to the Grub List experience. *Current Build 4 implementation* still also exposes Tickets in the My Kitchen header and puts the unread badge on the **My Kitchen** tab (`ContentView.swift`). Moving the entry point and badge to Grub List is Stage E work; do not add further My Kitchen Tickets surfaces.

**Run It Back** entry points stay hidden pending redesign. **Want to Cook** has no V1 surface (approved post-V1 feature; see roadmap).

## 5. Shared components — current inventory

| Need | Use (Implemented) |
| --- | --- |
| Buttons | `SGButtonStyle` (prominent/secondary), native destructive roles, `SGIconButton` (44 pt, Reduce Motion aware) |
| Header/titles | `SGPrimaryBrandTitle(page:)` in the native principal toolbar; `StayGrubbyHeader` for the Grub Rank search/creation inset |
| Creation | `SGCreationChoices` (New Dish / New Version reveal) |
| Lists/rows/cards | `SGEditorialList`, `SGDestinationLabel`, `sgCard`, `RankedDishRow`, `SignatureRankHero`, `SGSelectionRow`, `SGFormSection` |
| Selection sheets | `SGSelectionSheet`; `CookVersionSelectionView` / `CookVersionIdentity` for Dish-version selection; `SocialPersonLabel` + `SocialPersonSelectionRow` for people |
| Browse controls | `SGBrowseSortMenu`, `SGBrowseControlLabel` (shared by Grub Rank and Food Bible) |
| Photos | `DishPhoto` (display/thumbnail loading), `SGHeroMedia` (detail/result hero), `SGFoodPlaceholder`, official-wordmark social/cookbook placeholder, `CookingPhotoEditor` |
| Scores/tags | `ScoreBadge`, `TagChip`, `SourceSummary`, `SGSectionHeader` |
| Allergens | `SGAllergenChoices` / Contains selector, shared with Avoid (opposite semantics kept separate) |
| Content states | `SGEmptyState`, `ProgressView`, contextual retry |
| Sharing | `SocialLinkShareAction` (native `ShareLink`, `square.and.arrow.up`), native activity controller for rendered image exports |

Known gaps (Planned in Stage A): there is no single photo frame, score badge size scale, option sheet, filter bar, editor scaffold, content-state wrapper or toolbar tint rule, and roughly 99 hard-coded padding values bypass `SGTheme.Space`.

## 6. Screen contracts (Implemented unless marked)

**Grub Rank.** Single global ranking; rows show rank, square photo/placeholder, Dish, meaningful version label, Course and gated score. Search plus Course / Dietary / Avoid filters compose with AND; filters never renumber (rows keep true global rank, gaps allowed). Top Version (default) / All Versions projection. Read-only Sort menu: Grub Rank (default), Score (unavailable while locked; relock resets), Recently Cooked, Oldest, Alphabetical. Cream unlock-progress banner inside scroll content until 10 eligible entries. #1 uses the hero treatment.

**Comparison and ranking flow (protected).** Initial Reaction (Liked / It was fine / Didn't like) → two equal square choices with centered OR, Dish/version only, never scores → Undo / Too Tough / Skip. Single haptic, immediate answer, accessibility stacking. Re-rank reuses the same flow. Result screen shows the persisted cook, private rank/movement and the rendered share-card preview; first unlock offers the Top 3 card.

**New Dish / New Version / Edit Cook.** Order: photos → Dish Name → Version Title → Public Description → Date Cooked (defaults to today) → Private Notes → Details sheet (Course, Cuisine, Source, Dietary, Contains) → Tag a Sous Chef 🧑‍🍳 (horizontal avatar row + searchable sheet, eight-person limit) → Share with Sous Chefs toggle. Required: Dish name, date, valid Course. Custom Tags and Halal are hidden from entry. Edit Cook reuses tagging.

**Dish Detail.** Native back + compact Share + overflow (Edit Cook, Re-rank, post sharing, 86). Hero photo, identity, score/rank, metadata, Recipe relationship row, Versions. Lone untitled cook shows no "Version 1".

**Food Bible.** Recipe cards keyed by Recipe UUID; search, Filter sheet (Course, Cuisine, Contains, Avoid, Source, Recipe photo — the photo filter stays inside the Filter sheet), directional sort. Add Recipe → Paste Recipe / Add Manually. Recipe Detail: creator near title, Rank My Version primary, servings scaling, Ingredients/Method typography, Contains/Possible after method, compact safety disclosure, provenance last; Share/Send/overflow toolbar. Unit-conversion controls hidden.

**Grub List.** Chronological, current Sous Chefs only. Card: person identity → title → 4:3 photo/fallback → description → Recipe availability → Hands 🙌 / Comments. Compact semantic score circle when unlocked. Stable post ages (calendar date after seven days). Recipe creation activity is visibly a Recipe, never a cook/score. Comments: detented sheet, keyboard-aware composer, overflow Delete/Report.

**My Kitchen / Sous Chef Kitchen.** Centered identity, Sous Chefs control, Signature Dishes trio (three square photos, aligned scores), Recipes entry, authorized posts. Visitor Kitchens show only authorized content, never private rankings/notes. *Decided (Stage E):* stats row **Dishes Ranked → Grub Rank · Recipes → Food Bible · Sous Chefs → Sous Chefs**, no redundant mini-previews; visitor Kitchen uses the same structure with only authorized values. The current compact Recipes sheet will be replaced by navigation to Food Bible for the owner.

**Settings.** Grouped native rows; Profile editor, Sharing Preferences, Account & Sync (sign-out, Delete Account), safety, offline Privacy Policy reader, Support.

## 7. Vocabulary in UI

Grub Rank · Signature Dish / Signature Dishes · Grub List · My Kitchen · Sous Chefs · Requests · Tag a Sous Chef 🧑‍🍳 · Hands 🙌 / Give Hands 🙌 · Tickets 🎟️ / New Ticket · Rank My Version · Post to Grub List (internal) vs **Share** (external). Restrained 86: `86 (Delete)`, `86 this Dish?`, "Are you sure you want to 86 this Dish? This can’t be undone.", `86 Dish / Recipe / Cook / Comment / Post`. `Delete Account` stays conventional. Utility words stay plain: Comments, Search, Settings, Edit, Share, New Dish, New Version, Re-rank, Block, Report. Never "Profile", "friends", "likes" or "notifications" in user-facing copy. Keep "Your taste decides". Do not rename My Kitchen. Future achievements: Stars ⭐ (not implemented).

## 8. Score presentation

Scores unlock at ten eligible saved ranked entries; locked states never render a number (UI, accessibility, previews, exports). Displayed score comes from reaction-conditioned `ScoreCalibration`; order comes from Bradley–Terry strength. These can disagree across reaction groups (see the pre-V1 investigation in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md#ranking--protected)). UI work must not hide, reorder or recolor around that disagreement until the investigation decides the presentation.

## 9. System-wide UI overhaul — plan (Planned, not started)

A true consolidation across screens, not per-screen polish. Candidate shared systems: `SGPhotoFrame(role:)`, `ScoreBadge(size:)`, one Share menu/action model, `SGOptionSheet`, generalized `SGSelectionRow`, `SGFilterBar`, `SGEditorScaffold`, `SGContentState`, `SGSectionHeader` rule, shared toolbar/tint rules, and Recipe/Food Bible values routed through `SGTheme`.

| Stage | Scope |
| --- | --- |
| A — Foundations | Shared visual/component foundations; spacing tokens; toolbar tint rule; low-risk confirmed defects |
| B — Pickers / Search / Filtering | Consolidate selectors, filter bars, search patterns (Grub Rank, Food Bible, Kitchen, people) |
| C — Sharing | Separate Post to Grub List from external Share; one Share action (image + short `#stayGRUBBY` message + exact link); composer simplification |
| D — Detail screens | Dish Detail / Recipe Detail consolidation |
| E — Social / Kitchens | Grub List, Tickets relocation, My Kitchen stats, Sous Chef Kitchen, Sous Chefs, Requests |
| F — Forms / Editors | New Dish, New Version, Edit Cook, Recipe editor, related forms |
| G — Copy / Celebrations / Final consolidation | Copy purge, ranking result/celebration states (after the score/order investigation), accessibility/consistency pass |

Each stage updates this file as decisions become durable (AGENTS.md living documentation).

## 10. Known defects queued for the overhaul

Observed during the November 7 Simulator immersion and source audit (Build 4). Not yet fixed; do not fix outside the overhaul unless a release blocker.

| Defect | Likely stage |
| --- | --- |
| Reaction screen labels a lone first cook "Version 1" (`AddCookingView` builds its own label instead of `meaningfulVersionLabel`) | A |
| `1 versions` pluralization in `DishSelectionView` | A |
| Unlock milestone says "from Profile" instead of My Kitchen (`TopThreeShareCard.swift`) | A / G |
| Tickets row button tint bleeds red into handle/message/time; rows run four lines | E |
| Sous Chef Kitchen Recipes row shows two chevrons | E |
| Add Recipe → Add Manually shows both Back and Cancel (nested navigation) | F |
| Keyboard Done pill overlaps the Comment Send button and New Dish Continue bar (iOS 26) | A / F |
| Grub Rank Avoid chip clipped | B |
| Empty Grub Rank still shows segmented control and filters | B |
| Dietary editor reuses filter view and shows filter helper text | B / F |
| Raw Account ID shown in Account & Sync | E |
| Unnecessary "0 New Tickets" state | E |
| Dark-mode unlock-banner treatment | A |
| Doubled spacing on Dish Detail | D |
| Share icon tint differs between Dish Detail (charcoal) and Recipe Detail (red) | A |
| Own Recipe activity shows name + handle while own post shows "You" | E |
| Internal share composer says "friends" / "friends-visible" / "revision 1"; about eight paragraphs of copy; Publish is a plain buried row | C |
| Result screen: three–four stacked buttons hide much of the share-card preview | G |
| "Your dish is ranked!" used for low-score and re-rank results | G |
| Unlock milestone replaces the new Dish's own result, so its rank/score is never shown | G |
| Too Tough on a repeated pair gives no feedback (behavior protected; presentation only) | G |
| Tagged Sous Chef leaves no visible trace on Dish Detail / Grub List card (decided: show collaborators on the card, wording not final, e.g. "Guy + Alex cooked this") | D / E |
| Rank My Version does not explain Recipe provenance or that it creates a new Dish rather than a version of an existing one | F |
| Recipe editor uses red for nearly everything | F |
| No-photo Recipe and Grub List cards form a wall of giant wordmarks; SF-symbol placeholders elsewhere | A |
| Edit Cook Save is compact while Continue is full-width | F |

Separately tracked (not UI, protected system, needs evidence first): the ingredient parser split "toasted and crushed" into reversed lines and singularized "1½ cups".

## 11. Preserve

Comparison screen; Initial Reaction; re-rank reuse of the ranking flow; #1 hero; editorial rank presentation; Signature Dishes trio; `ScoreColor` semantics; score lock; exported share cards (1080 × 1350 photo, 1080 × 1080 no-photo, Top 3 1080 × 1350); Send to Sous Chefs; Tag avatar interaction and eight-person limit; Comments mechanics; Recipe reader typography; serving scaling; Rank My Version; ingredient editing, paste/import, parser/reorder architecture; creator/source disclosure; canonical wordmark; cream/charcoal/red identity; accessibility targets; four-tab structure; chronological Grub List; Hands 🙌; restrained 86; Delete Account; Privacy Policy reader; "Your taste decides".

## 12. Verification for UI changes

Follow AGENTS.md: build, directly affected UI tests and focused Simulator inspection in light/dark and at an accessibility text size for small UI; targeted Simulator flow verification for navigation/flow changes. Debug review fixtures require `--ui-test-store <UUID>` (isolated store and media root) and are compile-time excluded from Release; see [fixture rules](STAYGRUBBY_ARCHITECTURE.md#debug-fixtures-and-test-safety).
