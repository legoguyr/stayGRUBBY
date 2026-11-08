# StayGrubby UI architecture — current design-system specification

**Canonical current UI truth — reconciled November 7, 2026 at Build 4 (`c09c18e`); UI overhaul Stage A foundation and Stage B browsing/selection added November 7, 2026.** This file states how StayGrubby screens look and behave *now*, the rules every UI change follows, and the queued work for the system-wide UI overhaul. It replaces the former newest-first stack of dated sections, which is preserved verbatim in [UI_ARCHITECTURE_HISTORY.md](UI_ARCHITECTURE_HISTORY.md) as evidence. Product/technical architecture lives in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md); sequencing in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md); workflow rules in [AGENTS.md](AGENTS.md).

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
| Neutral tokens | `separator`, `border`, `placeholderMark` (quiet wordmark ink), `unavailable` (locked/disabled affordance, always paired with a symbol or text) |
| Spacing | Scale `hairline 3 · xSmall 6 · small 10 · medium 16 · large 24 · xLarge 32`, plus semantic names: `compact 8` (label/value stacks), `stack 12` (rows inside a section), `margin 16` (app page margin), `readingMargin 20` (Recipe reader/editor/import pages), `group 20` (groups within an editorial section), `section 28` (between major sections). New layout code uses the names; share-card exports keep their fixed layout values. |
| Type/radius/size/motion | `SGTheme.TypeRole`, `Radius` (`chip 10 · field 12 · card 16 · hero 18`), `Size` (incl. `minimumTap 44`, `toolbarSymbol 17`), motion timing. Rounded identity/title/score roles. |

**Accent rule.** Red means brand identity, the one primary action in a region (e.g. Rank My Version, Add, New Dish +), selection/active state, unread dots, and destructive 86 via native destructive roles. Toolbar utilities (share, overflow, settings, Tickets bell, Sous Chefs), metadata, secondary labels, row text and reorder/utility controls stay neutral. The app shell sets `.tint(accent)` globally, so neutral surfaces must opt out explicitly with `sgUtilityTint()` or `SGRowButtonStyle` — an inherited tint was the cause of the Tickets red-text bleed (`.secondary` resolves against the tint).

## 4. App shell and navigation

**Implemented:** `ContentView` owns four native tabs — **Grub List / Grub Rank (initial) / Food Bible / My Kitchen** — each with its own `NavigationStack`. Primary tabs show the compact official wordmark through `SGPrimaryBrandTitle`. Cooking forms are modal sheets. Onboarding/Sign in with Apple and account readiness sit above the shell. No fifth tab.

**Tickets** (in-app notifications, 🎟️): *Decided* — Tickets belongs to the Grub List experience. *Current Build 4 implementation* still also exposes Tickets in the My Kitchen header and puts the unread badge on the **My Kitchen** tab (`ContentView.swift`). Moving the entry point and badge to Grub List is Stage E work; do not add further My Kitchen Tickets surfaces.

**Run It Back** entry points stay hidden pending redesign. **Want to Cook** has no V1 surface (approved post-V1 feature; see roadmap).

## 5. Shared components — current inventory

| Need | Use (Implemented) |
| --- | --- |
| Photo framing | `sgPhotoFrame(_ role: SGPhotoRole)` — see 5.1 |
| Missing photo | `SGPhotoPlaceholder` — the only placeholder (replaced `SGFoodPlaceholder` and the SF `photo` glyph) |
| Scores | `SGScore(text:role:identifier:)` for already-gated text; `ScoreBadge(score:)` gates a local ranked item then uses `SGScore`; `LockedScoreIndicator` — see 5.2 |
| Toolbar utility | `SGToolbarIcon(symbol:)` + `sgUtilityTint()` — see 5.3 |
| List row buttons | `SGRowButtonStyle` (neutral text hierarchy under the app tint) |
| Buttons | `SGButtonStyle` (prominent = primary, default = secondary, `compact`), native destructive roles, `SGIconButton` |
| Section titles | `SGSectionHeader(title:) { optional trailing action }` — headline weight, header trait, no container |
| Content states | `SGContentState(title:symbol:message:) { optional action }` on native `ContentUnavailableView`; `SGLoadingState(label:)` |
| Header/titles | `SGPrimaryBrandTitle(page:)` in the native principal toolbar; `StayGrubbyHeader` for the Grub Rank search/creation inset |
| Creation | `SGCreationChoices` (New Dish / New Version reveal) |
| Lists/rows/cards | `SGEditorialList`, `SGDestinationLabel`, `sgCard`, `RankedDishRow`, `SignatureRankHero`, `SGSelectionRow`, `SGFormSection` |
| Option lists / sheets | `SGOptionList` (non-lazy scrolling rows), `SGOptionSheet` (standalone editing sheet with Done), `SGSelectionRow`, `SGOptionNote`, `SGOptionGroupLabel`; `DietaryChoices` / `DietarySelector`, `SGAllergenSelector` (Contains), `CuisinePicker` / `CuisineOptions`; `CookVersionSelectionView` / `CookVersionIdentity`; `SocialPersonLabel` + `SocialPersonSelectionRow` for people — see 5.4 |
| Browse controls | `SGSearchField`, `SGFilterChip` + `SGFilterGroupSheet` (direct groups), `SGFilterButton` + `SGFilterSheet` + `SGFilterGroupLink` (larger sets), `SGFilterGroupPage`, `SGBrowseSortMenu`, `SGBrowseToggle`, `SGBrowseControlLabel` — see 5.4 |
| Photos (loading) | `DishPhoto`, `RecipePhoto`, `SocialPhoto` load bytes; `SGHeroMedia` (Dish/Signature hero fade); `CookingPhotoEditor` |
| Tags/allergens | `TagChip`, `SourceSummary`, `SGAllergenChoices` / Contains selector |
| Sharing | `SocialLinkShareAction` (compact = toolbar utility), native activity controller for rendered exports |

Retired in Stage B: `SGSelectionSheet` (→ `SGOptionSheet` / `SGFilterGroupPage`), the old uneven horizontally scrolling filter chips, the Grub Rank Top Version / All Versions segmented control, the combined Sort & View menu and Grub Rank's single Filters sheet (both removed in the owner revision), and Food Bible's Photo filter. Retired in Stage A: `SGFoodPlaceholder` (→ `SGPhotoPlaceholder`), unused `SGEmptyState` (→ `SGContentState`), per-screen score text/medallion code (→ `SGScore`).

### 5.1 Photo roles

| Role | Shape | Corner | Used by |
| --- | --- | --- | --- |
| `.thumbnail` | 86 pt square | 12 | Grub Rank rows |
| `.compactThumbnail` | 44 pt square | 10 | Dish/version selection, Dish Detail version rows |
| `.tile` | square, flexible width | 12 | Signature Dishes, Kitchen post grid |
| `.card` | 4:3, flexible width | 18 | Grub List posts, Recipe activity |
| `.cookbook` | 0.9 portrait, flexible width | 12 | Food Bible grid |
| `.hero` | full width × 260 pt | 18 | Recipe reader, shared Recipe reader, Recipe history (Dish hero uses `SGHeroMedia` with the same corner) |

Flexible roles size a clear aspect box first, so loading never shifts layout. **Placeholder language:** warm `elevatedSurface` plus a monochrome `#stayGRUBBY` mark in `placeholderMark` (mark width = 55% of the frame's short side, capped at 104 pt, so wide/short frames stay quiet; frames under 64 pt show the surface only). It stays recognizable without turning a screen of missing photos into a wall of red logos. The full-color wordmark is for identity (headers, share cards). No synthetic food imagery. Placeholders are decorative (`accessibilityHidden`); the photo view owns the label ("No photo for …").

### 5.2 Score roles

`.standard` (open semantic-colored rounded numerals: rows, Signature tiles, detail, versions), `.outOfTen` (same numerals + "/ 10": ranking result, composer summary), `.medallion` (Dynamic-Type-scaled ring: Grub List card). All use `ScoreColor` bands, announce "Score N", and fall back to `LockedScoreIndicator` (lock + "Score locked" + hint) when text is nil. Presentation only — no calibration, order or unlock logic lives here. Rendered exports keep brand red.

### 5.3 Toolbar and action rules

- Toolbar utilities: `SGToolbarIcon` (17 pt medium SF Symbol, 44 pt target) + `sgUtilityTint()` — neutral in light and dark. Unavailable utilities use `ColorToken.unavailable` with an accessibility label stating why.
- One accent toolbar action at most per screen, and only for the screen's primary action (Add Recipe +, Mark All Read).
- Tickets bell: neutral `bell`; with unread, `bell.badge` in palette mode with only the dot in accent.
- Overflow menus keep native destructive roles for 86 actions.
- Action roles: primary `SGButtonStyle(prominent: true)` (one per region) · secondary `SGButtonStyle()` · compact utility `SGButtonStyle(compact: true)` or a native text button · toolbar as above · destructive native role · list rows `SGRowButtonStyle`. Native controls stay native where appropriate; targets stay ≥ 44 pt.

### 5.4 Search, filter, sort and selection (Stage B, owner-revised)

**Library screens keep browse chrome compact and even; common filters are one tap away.**

- **Grub Rank** (three short rows): (1) wordmark · search · + (search swaps the row for `SGSearchField` + Done); (2) one even row of `SGFilterChip`s — Course · Cuisine · Dietary · Avoid — each equal width, showing its title only; active is the accent (red) title on the selected fill — no count, and identical geometry active or inactive. Each opens that group alone in an `SGFilterGroupSheet`. All four groups are multi-select: tapping options toggles them and never dismisses the sheet; the user taps Done (group Clear empties that group). (3) `SGBrowseSortMenu` (labelled with the current order) · `SGBrowseToggle` "All Versions" (spoken "Show All Versions"; Off = Top Version, On = All Versions, same stored preference) · an `xmark` Clear All button visible only while filters are active; its slot is reserved while hidden so activating or clearing filters moves nothing. At large text sizes the chips wrap to a 2×2 grid and the toggle drops below Sort (`ViewThatFits`) — never clipped or horizontally scrolled.
- **Food Bible** (search-led): always-visible `SGSearchField`, then `SGFilterButton` ("Filters" / "Filters n") · Sort · clear. Its five groups (Course, Cuisine, Contains, Avoid, Source) do not fit one even chip row, so it keeps the single `SGFilterSheet`.
- **Rule:** up to four common groups → direct chips; more → one Filters sheet whose root lists groups (`SGFilterGroupLink`). Both open the same `SGFilterGroupPage` (options, group Clear, Done that closes everything). Sort is always its own compact menu; view modes are a toggle, never inside Sort.

An empty library shows no browse controls (and Grub Rank no search button). The "n of N · Global ranks" result line is the first line of content, not pinned chrome.

- **Search:** `SGSearchField` is the one field for library screens and in-sheet lists (New Version Dish choice, Recipe filter values, Find Sous Chefs): magnifier, plain field, clear button, search return key, autocorrection off. Lists inside navigation that already use native `.searchable` (Cuisine, Send to Sous Chefs, Kitchen Recipes) keep it. Do not add search where a list is short.
- **Filters:** every capability survives: Grub Rank Course/Cuisine/Dietary/Avoid; Food Bible Course/Cuisine/Contains/Avoid/Source. There is no photo browse filter anywhere (owner decision, November 7, 2026: unnecessary complexity; photo storage/display unaffected).
- **Sort:** a native `Menu` with a "Sort by" section, checkmark on the current choice, score orders disabled while locked.
- **Selection rows:** `SGSelectionRow` (title + check circle, selected surface, `isSelected` trait). Editing a cook's attributes (Dietary, Contains) uses `SGOptionSheet` without filter wording; filters keep their short semantics note ("Shows cooks with any selected label"). Dietary is shown by `DietaryChoices` in two alphabetical groups under quiet `SGOptionGroupLabel`s — **Diet** (Dairy-Free, Gluten-Free, Vegan, Vegetarian) and **Certification** (Halal, Kosher) — with no explanatory note in the editor. Presentation only: stored `DietaryTag` codes are unchanged.
- **Picker entry rows** in editors (Details: Cuisine, Source, Dietary, Contains) use neutral title, secondary value and quiet chevron, matching native `navigationLink` pickers — not accent-red labels.

## 6. Screen contracts (Implemented unless marked)

**Grub Rank.** Single global ranking; rows show rank, square photo/placeholder, Dish, meaningful version label, Course and gated score. Header: identity/search row, then direct Course · Cuisine · Dietary · Avoid chips, then Sort · All Versions toggle · clear (5.4). Search plus Course / Cuisine / Dietary / Avoid filters compose with AND across groups; within a group Course, Cuisine and Dietary match any selected value and Avoid excludes any selected allergen; filters never renumber (rows keep true global rank, gaps allowed). Top Version (default) / All Versions via the All Versions toggle. Read-only Sort: Grub Rank (default), Highest/Lowest Score (unavailable while locked; relock resets), Newest/Oldest Cooked, A–Z/Z–A. Cream unlock-progress banner inside scroll content until 10 eligible entries. #1 uses the hero treatment.

**Comparison and ranking flow (protected).** Initial Reaction (Liked / It was fine / Didn't like) → two equal square choices with centered OR, Dish/version only, never scores → Undo / Too Tough / Skip. Single haptic, immediate answer, accessibility stacking. Re-rank reuses the same flow. Result screen shows the persisted cook, private rank/movement and the rendered share-card preview; first unlock offers the Top 3 card.

**New Dish / New Version / Edit Cook.** Order: photos → Dish Name → Version Title → Public Description → Date Cooked (defaults to today) → Private Notes → Details sheet (Course, Cuisine, Source, Dietary, Contains) → Tag a Sous Chef 🧑‍🍳 (horizontal avatar row + searchable sheet, eight-person limit) → Share with Sous Chefs toggle. Required: Dish name, date, valid Course. Custom Tags are hidden from entry; Dietary offers Diet and Certification (incl. Halal) groups. Edit Cook reuses tagging.

**Dish Detail.** Native back + compact Share + overflow (Edit Cook, Re-rank, post sharing, 86). Hero photo, identity, score/rank, metadata, Recipe relationship row, Versions. Lone untitled cook shows no "Version 1".

**Food Bible.** Recipe cards keyed by Recipe UUID; search field, then Filters · Sort (5.4); Filters sheet groups Course, Cuisine, Contains, Avoid, Source (no Photo filter); directional sort. Add Recipe → Paste Recipe / Add Manually. Recipe Detail: creator near title, Rank My Version primary, servings scaling, Ingredients/Method typography, Contains/Possible after method, compact safety disclosure, provenance last; Share/Send/overflow toolbar. Unit-conversion controls hidden.

**Grub List.** Chronological, current Sous Chefs only. Card: person identity → title → 4:3 photo/fallback → description → Recipe availability → Hands 🙌 / Comments. Compact semantic score circle when unlocked. Stable post ages (calendar date after seven days). Recipe creation activity is visibly a Recipe, never a cook/score. Comments: detented sheet, keyboard-aware composer, overflow Delete/Report.

**My Kitchen / Sous Chef Kitchen.** Centered identity, Sous Chefs control, Signature Dishes trio (three square photos, aligned scores), Recipes entry, authorized posts. Visitor Kitchens show only authorized content, never private rankings/notes. *Decided (Stage E):* stats row **Dishes Ranked → Grub Rank · Recipes → Food Bible · Sous Chefs → Sous Chefs**, no redundant mini-previews; visitor Kitchen uses the same structure with only authorized values. The current compact Recipes sheet will be replaced by navigation to Food Bible for the owner.

**Settings.** Grouped native rows; Profile editor, Sharing Preferences, Account & Sync (sign-out, Delete Account), safety, offline Privacy Policy reader, Support.

## 7. Vocabulary in UI

Grub Rank · Signature Dish / Signature Dishes · Grub List · My Kitchen · Sous Chefs · Requests · Tag a Sous Chef 🧑‍🍳 · Hands 🙌 / Give Hands 🙌 · Tickets 🎟️ / New Ticket · Rank My Version · Post to Grub List (internal) vs **Share** (external). Restrained 86: `86 (Delete)`, `86 this Dish?`, "Are you sure you want to 86 this Dish? This can’t be undone.", `86 Dish / Recipe / Cook / Comment / Post`. `Delete Account` stays conventional. Utility words stay plain: Comments, Search, Settings, Edit, Share, New Dish, New Version, Re-rank, Block, Report. Never "Profile" for My Kitchen, nor "friends", "likes" or "notifications", in user-facing copy. (Open owner decision: the Settings identity editor — name, username, photo, discovery — is still titled "Profile"; renaming it is deferred to Stage E.) Keep "Your taste decides". Do not rename My Kitchen. Future achievements: Stars ⭐ (not implemented).

## 8. Score presentation

Scores unlock at ten eligible saved ranked entries; locked states never render a number (UI, accessibility, previews, exports). Displayed score comes from reaction-conditioned `ScoreCalibration`; order comes from Bradley–Terry strength. These can disagree across reaction groups (see the pre-V1 investigation in [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md#ranking--protected)). UI work must not hide, reorder or recolor around that disagreement until the investigation decides the presentation.

## 9. System-wide UI overhaul — plan

A true consolidation across screens, not per-screen polish. Candidate shared systems: `SGPhotoFrame(role:)`, `ScoreBadge(size:)`, one Share menu/action model, `SGOptionSheet`, generalized `SGSelectionRow`, `SGFilterBar`, `SGEditorScaffold`, `SGContentState`, `SGSectionHeader` rule, shared toolbar/tint rules, and Recipe/Food Bible values routed through `SGTheme`.

| Stage | Scope |
| --- | --- |
| A — Foundations | **Implemented November 7, 2026 — owner accepted.** Tokens/accent rule, photo roles + placeholder, score roles, section/content states, toolbar/row action styles, foundational defects |
| B — Pickers / Search / Filtering | **Implemented November 7, 2026 — automated + Simulator checks passed, owner physical acceptance pending.** Owner review revision (same day): direct Grub Rank filter chips, separate Sort, All Versions toggle, Photo filter removed, Dietary note removed with Halal restored and alphabetized groups. Final owner correction (November 8): multi-select Course/Cuisine, sheets stay open until Done, active chips use color only (no count) with no layout movement; shared search field, option sheets, Dietary editor |
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
| ~~Reaction screen labels a lone first cook "Version 1"~~ | Fixed in A |
| ~~`1 versions`~~ (also fixed `1 Sous Chefs`, `1 recipes`) | Fixed in A |
| ~~Unlock milestone says "from Profile"~~ | Fixed in A |
| ~~Tickets row tint bleeds red into handle/message/time~~ (fixed in A via `SGRowButtonStyle`); rows still run four lines | E |
| ~~Sous Chef Kitchen Recipes row shows two chevrons~~ | Fixed in A |
| Add Recipe → Add Manually shows both Back and Cancel (nested navigation) | F |
| Keyboard Done pill overlaps the Comment Send button and New Dish Continue bar (iOS 26) | A / F |
| ~~Grub Rank Avoid chip clipped~~ (even equal-width chips that wrap at large text) | Fixed in B |
| ~~Empty Grub Rank still shows segmented control and filters~~ | Fixed in B |
| ~~Dietary editor reuses filter view and shows filter helper text~~ (`DietarySelector`) | Fixed in B |
| ~~Raw Account ID shown in Account & Sync~~ (now Debug-only diagnostics) | Fixed in A |
| Unnecessary "0 New Tickets" state | E |
| ~~Dark-mode unlock-banner treatment~~ (adaptive surface/text/track) | Fixed in A |
| ~~Doubled spacing on Dish Detail~~ (stacked section padding and empty provenance gap) | Fixed in A |
| ~~Share icon tint differs between Dish Detail and Recipe Detail~~ (toolbar rule) | Fixed in A |
| Own Recipe activity shows name + handle while own post shows "You" | E |
| Internal share composer says "friends" / "friends-visible" / "revision 1"; about eight paragraphs of copy; Publish is a plain buried row | C |
| Result screen: three–four stacked buttons hide much of the share-card preview | G |
| "Your dish is ranked!" used for low-score and re-rank results | G |
| Unlock milestone replaces the new Dish's own result, so its rank/score is never shown | G |
| Too Tough on a repeated pair gives no feedback (behavior protected; presentation only) | G |
| Tagged Sous Chef leaves no visible trace on Dish Detail / Grub List card (decided: show collaborators on the card, wording not final, e.g. "Guy + Alex cooked this") | D / E |
| Rank My Version does not explain Recipe provenance or that it creates a new Dish rather than a version of an existing one | F |
| Recipe editor uses red for nearly everything | F |
| ~~No-photo cards form a wall of giant wordmarks; SF-symbol placeholders elsewhere~~ (`SGPhotoPlaceholder`) | Fixed in A |
| Edit Cook Save is compact while Continue is full-width | F |

Separately tracked (not UI, protected system, needs evidence first): the ingredient parser split "toasted and crushed" into reversed lines and singularized "1½ cups".

## 11. Preserve

Comparison screen; Initial Reaction; re-rank reuse of the ranking flow; #1 hero; editorial rank presentation; Signature Dishes trio; `ScoreColor` semantics; score lock; exported share cards (1080 × 1350 photo, 1080 × 1080 no-photo, Top 3 1080 × 1350); Send to Sous Chefs; Tag avatar interaction and eight-person limit; Comments mechanics; Recipe reader typography; serving scaling; Rank My Version; ingredient editing, paste/import, parser/reorder architecture; creator/source disclosure; canonical wordmark; cream/charcoal/red identity; accessibility targets; four-tab structure; chronological Grub List; Hands 🙌; restrained 86; Delete Account; Privacy Policy reader; "Your taste decides".

## 12. Verification for UI changes

Follow AGENTS.md: build, directly affected UI tests and focused Simulator inspection in light/dark and at an accessibility text size for small UI; targeted Simulator flow verification for navigation/flow changes. Debug review fixtures require `--ui-test-store <UUID>` (isolated store and media root) and are compile-time excluded from Release; see [fixture rules](STAYGRUBBY_ARCHITECTURE.md#debug-fixtures-and-test-safety).

**Stage A verification (November 7, 2026).** Debug build; 20 focused UI tests passed (score unlock, Kitchen/Account, Signature alignment, Tickets read-all, Food Bible empty state, Recipe share/Send, Dish Detail actions, re-rank result); full unit suite 390/396 with 6 failures that are pre-existing or order-dependent (see [architecture — Verification](STAYGRUBBY_ARCHITECTURE.md#verification)). Simulator review of Grub Rank, Dish Detail, Food Bible, Recipe Detail, Grub List, Tickets and My Kitchen in light and dark, locked and unlocked scores, missing photos, and accessibility text size.

**Stage B verification (November 7, 2026).** Debug build; unit suite unchanged from the documented baseline (390/396). UI: 29 affected tests run after updating them to the new Filters sheet / Sort & View structure (no assertion removed; group-count checks now read the sheet rows); 24 pass, including: discovery search/filter/creation, Polish result + Avoid flows, score calibration, review-environment sheet scaling, Signature and browse controls, Food Bible filters/sorting, display-mode persistence, large-type branding. Five failures are pre-existing (see [architecture — Verification](STAYGRUBBY_ARCHITECTURE.md#verification)); the Cuisine filter path they cannot reach was verified by hand. Simulator: Grub Rank populated/locked/empty, Filters sheet and group pages, active filters, Sort & View, search, All Versions, Food Bible + Filters, Details → Dietary editor, light/dark, accessibility text size.

**Stage B owner-revision verification (November 7, 2026).** Debug build; unit suite 391/396 (the documented baseline minus the DishSource failure, resolved by restoring Halal). UI: 31 affected tests run; 24 pass after updating helpers to the direct chips and the All Versions switch, moving `CookingUITests`' All Versions step after its first cook (empty libraries show no controls), expecting Halal, and adding a guarded single-select retry while a group sheet settles. Seven failures are pre-existing and fail identically on `941a949` (see [architecture — Verification](STAYGRUBBY_ARCHITECTURE.md#verification)). Simulator: populated Grub Rank light/dark, active Avoid chip with ✕, All Versions on/off, accessibility text size (chips wrap 2×2, toggle below Sort), Food Bible Filters without Photo, New Dish → Details → Dietary (Diet / Certification groups, no note).

**Stage B final owner correction (November 8, 2026).** Course and Cuisine browse filters became sets (browse-only `CookingFilters` state, never stored; no Dish/Cook metadata change). `CuisineOptions` gained a filter mode (multi-select toggles, group Clear, Done) while editors keep single choice that dismisses. Chips dropped the visible count; the Clear All slot is reserved. Verified by unit tests (multi-course OR keeps global ranks; suite 391/396, the documented baseline) and `CookingDiscoveryUITests` asserting the sheet stays open across selections and that chip, Sort and All Versions frames are identical before and after activation (13 affected UI tests: 12 pass, 1 pre-existing Edit Cook failure). Simulator: light Course (Main + Side) and Cuisine (two choices) stay open until Done, red chip without count, ✕ in its reserved slot, ✕ clears all with no movement; dark accessibility size with Avoid active keeps the 2×2 grid unchanged.
