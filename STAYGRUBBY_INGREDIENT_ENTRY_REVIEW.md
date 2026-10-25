# Natural ingredient entry — review

Starting checkpoint: `0770688b97d49775d1fef41015da654a3b78b5e4`, clean `main` matching the existing origin tracking ref. Owner changes were preserved. This cycle follows physical acceptance of Food Bible UX 2.0 and changes ingredient entry only. Final checkpoint IDs and push outcome are reported at completion; the review's own final commit is available with `git log -1 --format=%H -- STAYGRUBBY_INGREDIENT_ENTRY_REVIEW.md`.

## Architecture and compatibility

`IngredientParser` is pure deterministic Swift/Foundation, with no provider, network, service, database or platform intelligence dependency. It returns a `ParsedIngredient` containing exact quantity/range, normalized unit, name, preparation, note, original input and an internal confidence tier. Its conversion produces the existing `RecipeIngredient` fields and preserves the caller's UUID/order. There is no competing Recipe model.

`IngredientNumber` stores a reduced integer numerator/denominator. `IngredientQuantity` stores a lower bound and optional upper bound. They are derived exactly from the existing canonical quantity string; floating point is never the only source of truth. Canonical storage uses ASCII fractions/mixed fractions and hyphenated ranges. This prepares future scaling without adding arithmetic/scaling UI or density conversion. Supported numbers are bounded (up to six digits per typed number/fraction part, six decimal places, reduced numerator at most 1,000,000,000 and denominator at most 1,000,000). Unsupported values fall back to the original wording, rather than overflowing or rounding.

The persisted Codable shape, Recipe API, tables, migrations, revisions, Dish identity and sync workflow are unchanged. Existing structured rows require no migration. Simply opening/editing and submitting an unchanged row does not reparse it, even if it uses legacy wording or unfamiliar units. Legacy flat ingredients are still read through the existing stable component projection and are not automatically reinterpreted.

`IngredientEntryDraft` holds exact original lines and their baseline structured values in the presented editor, keyed by stable ingredient UUID. It is not encoded or uploaded. It survives normal background/foreground and section changes with the enclosing draft. It does not promise unsaved-draft recovery after force quit/process termination. After an intentional structured correction, the corrected fields become the formatter source for subsequent editing; after a successful cloud save/relaunch, the persisted structured fields reconstruct an equivalent editable line. Original spelling/order is not a new cloud field.

## Grammar and safety

- Numeric measurement at the beginning, or a recognized quantity/unit pair at the end. Attached units such as `300g`, `500ml`, `1lb` and `12oz` work.
- Whole numbers, decimals, ASCII fractions, mixed fractions, common Unicode fractions and ranges (`-`, `–`, `to`). Fractions are reduced exactly; display uses ½/¼/¾/⅓/⅔/⅛/⅜/⅝/⅞ when representable. Other fractions stay readable ASCII.
- Units: tablespoon/tablespoons/tbsp/tbs, teaspoon/teaspoons/tsp, cup/cups/c, ounce/ounces/oz, pound/pounds/lb/lbs, gram/grams/g, kilogram/kilograms/kg, milliliter/millilitre variants/ml/mL, liter/litre variants/l/L; clove, bunch, can, package/pkg, stick, slice, piece, head, sprig, pinch and dash with plural variants. Normalized units retain the approved `tbsp`, `tsp`, `cup`, `oz`, `lb`, `g`, `kg`, `mL`, `L` spellings. Count units get readable display plurals.
- Structural `of` is removed only immediately after a numeric measurement. `cream of mushroom soup` stays intact.
- Common suffix preparations: minced, diced, chopped, finely/roughly chopped, sliced/thinly sliced, peeled, grated, shredded, crushed, melted, softened, room temperature, divided, drained, rinsed, trimmed, zested, juiced, including simple `and` combinations. Prefix names such as `crushed tomatoes` are retained.
- `to taste`, `as needed`, `optional`, `plus more…`, flat parentheticals and explicit comma notes are preserved using preparation/note fields. No fabricated numeric amount for a handful/pinch/zest/juice phrase.
- Conservative exceptions preserve `7 spice`, `5 spice powder`, `00 flour`, percentages and size names such as `10-inch tortilla`. Numbers in the middle of names are not extracted. Bare trailing counts are limited to a small set of obvious counted ingredient nouns, such as cod fillets, eggs, onions and lemons.
- Nested/unbalanced parentheses, invalid/descending ranges, zero denominators and unfamiliar forms remain intact as freeform input. The original input remains available during editing. The parser is not a general NLP system; preview and Edit Details remain important for ambiguous wording.

| Input | Stored quantity / unit / name | Secondary text / display |
| --- | --- | --- |
| `1/4 cup of parsley` or `parsley ¼ cup` | `1/4` / `cup` / `parsley` | `¼ cup` |
| `parsley 300g` | `300` / `g` / `parsley` | `300 g` |
| `garlic, minced, 2 cloves` | `2` / `clove` / `garlic` | preparation `minced`; display `2 cloves` |
| `chicken thighs 1.5 lbs` | `1 1/2` / `lb` / `chicken thighs` | `1½ lb` |
| `¼–½ cup milk` | `1/4-1/2` / `cup` / `milk` | `¼–½ cup` |
| `1 can (28 oz) crushed tomatoes` | `1` / `can` / `crushed tomatoes` | note `28 oz` |
| `salt to taste` | empty / empty / `salt` | note `to taste` |
| `a good handful of parsley` | empty / empty / original line | no guessed measurement |
| `7 spice seasoning` | empty / empty / original line | ambiguous numeric food name preserved |

## Formatter and editor

`2db1b8a` checkpoints the deterministic parser/draft layer and its focused tests. `cb7d2f0` integrates the natural editor, native keyboard/correction controls, fraction display and UI coverage. The final documentation checkpoint is identified by the Git command above and reported in the final response.

`IngredientLineFormatter` provides editable-line reconstruction, readable quantity/unit display and VoiceOver wording with expanded common unit names. Its common-case round trips preserve semantic fields; arbitrary unusual structured rows are preserved exactly if unchanged rather than forced through a guessed grammar.

Primary flow: + Ingredient → one natural text field → type → Return → parsed formatted row → next blank line. A section-owned `IngredientLineField` wraps a native UITextField whose Return delegate returns false after synchronously committing/resetting text, retaining the same first responder across consecutive Returns. Its native keyboard accessory hosts explicit Paste/Done controls. Text selection stays native, fonts follow Dynamic Type and keyboard/foreground colors follow the current appearance. Programmatic scroll-to-input keeps the active line visible without an animation or first-responder change. This avoids destroying/recreating the text field for each next-row UUID, which testing showed could lose fast typed prefixes. Empty Return reuses its placeholder. Done/Save removes only editor-created blank placeholders. Clearing an existing meaningful row remains invalid until corrected or intentionally deleted.

Tap a formatted row to edit its retained/reconstructed line in place. Dedicated action handles remain independent of text selection and retain up/down, Move to… and confirmed Delete. Secondary Edit Details exposes Quantity, Unit, Ingredient, Preparation and Note; Done applies only to the local Recipe draft, with no network write. Cancel/interactive-dismiss protections also cover this correction sheet.

The native keyboard Paste action accepts explicit plain-text payloads and splits newline-separated ingredient lines within the active section; line splitting preserves the first row identity and inserts subsequent rows before the next existing ingredient. Blank lines are ignored. Native paste respects the selected range and keeps existing unselected input; its focused UI test includes an already-typed prefix. A stale paste/submission cannot target a different active row. Ordinary single-line paste works naturally; the explicit keyboard paste control is the predictable multiline path.

Only the established Recipe Save writes to the cloud. Pending text is resolved even without pressing Return. Failed saves retain the structured draft and original input for retry. The outer dirty-discard alert/swipe protections remain intact. No ingredient typing triggers a server write.

## Reading, search and persistence

The reader and resolved editor rows share the same quantity/name presentation, stacking at accessibility sizes. Amounts remain visually distinct; preparation and note stay secondary. No other reader/navigation redesign.

Canonical ingredients continue through existing flat search projections, so `parsley 300g` remains searchable as parsley regardless of input ordering. Tests use the existing isolated PostgreSQL harness to save/read, edit/save again, verify revisions/UUIDs/Dish link, and assert search contains normalized names, quantities and notes while ranked-item fingerprints stay intact. No real hosted Recipe is created or changed for testing.

## Verification and inspection

Final verification completed:

| Check | Result |
| --- | --- |
| Deterministic parser corpus | 73 explicit input cases passed, plus four semantic-equivalence groups, fraction/range boundaries, every unit alias, formatter round trips and deterministic repetition |
| Final Recipe regression | **35/35 passed**, zero failures/unexpected failures/skips: 25 native tests across parser, draft, Food Bible and cookbook search; 10 affected Food Bible UI tests |
| Final input refinement | **2/2 passed**, zero failures/skips: ten uninterrupted keyboard-entered ingredients plus natural edit/details/save/reopen, and four-line native paste with an existing typed prefix preserved |
| Backend persistence/Recipe checks | **51 assertions passed** (17 new ingredient save/read/edit/search checks, 34 existing Food Bible contract/security checks); isolated PostgreSQL only |
| Latest Debug | MCP build succeeded in 8.7 seconds after the final color-only adjustment; isolated Simulator launch/input/appearance inspected |
| Latest Release | Optimized simulator build succeeded after the final appearance adjustment; no archive/upload |
| Release isolation | No `--ui-test-store`, `--social-review`, `--development-library` or `--score-unlock-fixture` marker in application binary |
| Secret / whitespace | Privileged-secret/local-artifact scan: 337 text files, zero findings; working/staged whitespace checks passed |

Regression result: `/private/tmp/ingredient-final-regression.xcresult`. Final input result: `/private/tmp/ingredient-final-input-checks.xcresult`. Latest Release log: `/private/tmp/ingredient-release-final-appearance.log`. The narrow paste-selection fix followed the broad regression and was verified by the final two affected UI tests; the subsequent placeholder-only contrast adjustment was built in Debug/Release and inspected directly. No unrelated full suite was repeated. Tests cover the parser corpus/equivalences, formatter round trips, rational quantities, every unit alias, raw-input retention, pending Save, empty Return, stable IDs, stale events, multiline insertion, section moves, corrections, existing/legacy rows, privacy of raw draft state, persistence and search.

Development failures are retained as evidence: the initial growing text field treated Return as a newline and duplicated rows during rapid typing. The next attempt changed focus per row and lost typed prefixes. Both were genuine input regressions, not dismissed as test flakiness. The section-owned native UITextField Return delegate, separate native focus ownership and stale-event guards correct the cause; the rapid keyboard test retains exact content assertions. The initial native field needed separate focus ownership rather than an unregistered SwiftUI focus key. A paste-test setup failure came from an unavailable multiline Select All menu; the test now copies synthetic fixture text with native Command-A/Copy, retaining its exact four-row/order assertions. No real account data is copied or changed.

Inspected screenshots include blank/active software keyboard, ten-line Return flow, fractions, metric/range/freeform rows, long text, preparation/note, secondary structured correction, dark/light reader/editor, multiline paste, multi-section moves, partial input after app switching, accessibility text and Reduce Motion. Visual inspection corrected fraction count-unit agreement (`½ bunch`) and raised native placeholder contrast to the existing secondary-label color; the final placeholder was inspected in an isolated Simulator launch.

Accessibility: Dynamic Type, stacked amounts, meaningful Ingredient line/structured correction labels, contextual 44-point action handles, explicit quantities/names/preparation/notes and expanded VoiceOver units. No whole-row drag gesture intercepts text selection; no new custom animation depends on motion settings. Automated hierarchy/large-type review does not replace owner VoiceOver listening.

Performance: compiled boundary/preparation expressions, bounded line parsing and no work queue/network. The initial Simulator benchmark performed 14,600 parses in approximately 1.53 seconds (about 0.1 ms each, including test instrumentation); no fragile timing threshold gates tests. Validation avoids reparsing the document on each keystroke, and stable field/row identity preserves keyboard focus.

## Data and release boundaries

No migration, hosted deployment, new service, auth flow, Storage upload, sync-engine change or real-account fixture writes. All **35 hosted table/Storage fingerprint groups match** the current-cycle starting baseline, including **63 Storage objects**. Demo manifest remains `bedd790ea8487f3b1baad442acd9092a6890b0a38cede4951aef0018469b9a51`: 1 ranking, 12 Dishes, 15 attempts/items, 356 comparisons, 10 Sources, 21 tags, 48 memberships and 190 media files. The final isolated appearance install/launch was followed by the same successful audit. Protected ranking, sync, assets, configuration and project files are unchanged. No real hosted Recipe was mutated merely for testing. Ranking/Bradley–Terry/calibration/reactions/unlock/evidence/re-ranking remain frozen. Tickets stay hidden with their backend/data preserved.

**Known release blocker: physical Universal Links remain broken per owner testing and are intentionally deferred.** No link, website, AASA, signing or routing investigation/change occurs in this cycle. This feature's owner acceptance is independent of that deferred release issue. No TestFlight or App Store Connect changes.

Known limitations: English-oriented unit/modifier grammar, incomplete named-food disambiguation, no general recipe interpretation, no measurement conversion/scaling, no nested-parenthetical analysis, existing backend limits (100 ingredients per section and established Recipe row/text limits), no automatic loss-prone truncation and no process-death recovery for unsaved raw input. Unfamiliar wording is retained, with Edit Details as the correction path.


## Exact file inventory

12 files in this cycle:

- `StayGrubby/Social/IngredientParser.swift`
- `StayGrubby/Social/IngredientEntryDraft.swift`
- `StayGrubby/Social/IngredientEditingViews.swift`
- `StayGrubby/Social/IngredientLineField.swift`
- `StayGrubby/Social/RecipeEditor.swift`
- `StayGrubby/Social/RecipeReadingBody.swift`
- `StayGrubbyTests/IngredientParserTests.swift`
- `StayGrubbyTests/IngredientEntryTests.swift`
- `StayGrubbyUITests/FoodBibleUITests.swift`
- `Backend/tests/ingredient-persistence.test.mjs`
- `UI_ARCHITECTURE.md`
- `STAYGRUBBY_INGREDIENT_ENTRY_REVIEW.md`

## Owner physical checklist — iPhone 15

1. Update the existing app in place without deleting/resetting data. In a Recipe, tap + Ingredient and enter ten lines using Return only; check every quantity/name and the final empty line behavior.
2. Try `1/4 cup of parsley`, `parsley 300g`, `garlic, minced, 2 cloves`, `1½ lb chicken thighs`, `2 to 3 cloves garlic`, `salt to taste`, `7 spice`, and `1 can (28 oz) crushed tomatoes`.
3. Tap a resolved ingredient and change its natural line; verify its original input is available during the edit. Use Edit Details to correct quantity/unit/name/preparation/note. Cancel/Keep Editing/Discard should behave intentionally.
4. Use the keyboard paste control with four newline-separated ingredient lines. Confirm four rows in the correct section, no duplicates and no dropped text.
5. Add ingredients to two sections; switch sections, reorder, move and intentionally delete rows. Confirm active text, quantities, notes and row ordering survive.
6. Type a partial `2 tbsp oli...`, switch apps/background and return, then continue typing. Confirm dirty Cancel does not silently discard it.
7. Save, reopen, terminate/relaunch normally and reopen the saved Recipe; edit/save again. Test offline save failure and retry without resetting any data. Search Food Bible for parsley/garlic afterward. Real cloud sync/relaunch acceptance must be performed on the owner's account; automated fixtures never mutate it.
8. Review light/dark, large Dynamic Type, keyboard scrolling/dismissal, long/freeform ingredients, fractions/ranges and VoiceOver labels/selection. Ensure correction controls remain secondary and the editor feels simpler.

No AI, Foundation Models, Gemini, paid APIs, whole-recipe parser, import/OCR, timers, scaling UI, cooking mode, groceries or meal planning was implemented. Universal Links remain deferred.
