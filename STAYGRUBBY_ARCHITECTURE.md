# StayGrubby — current product and architecture

**Canonical current-state overview — reconciled November 7, 2026 at Build 4 (`c09c18e`).** This file says what StayGrubby *is and does today*. [AGENTS.md](AGENTS.md) says how to work; the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) says what comes next; [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) is the design-system specification; [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md) is release state. Dated review files are evidence for their checkpoints, not current truth. Never describe roadmap features as implemented.

Status vocabulary used across canonical docs: **Implemented and verified** · **Implemented, awaiting verification** (usually owner physical acceptance) · **Approved future** · **Proposed / exploratory** · **Explicitly deferred** · **Explicitly excluded / rejected**.

## Product

StayGrubby (`#stayGRUBBY`) is a personal cooking journal built around comparison ranking. Users record what they actually cook, rank it against what they have cooked before, build a meaningful history, keep the Recipes worth making again, and optionally share that experience with people they know.

**Cook → Rank → Remember → Share → Interact → Run It Back** (core loop) · **DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE** (broader loop).

Cooking, saving a Recipe and publishing a post are separate actions. Saving or discovering never means something was cooked or ranked. Popularity, engagement and social activity never change personal ranking. StayGrubby is not a generic social network, a short-video food feed, a generic Recipe manager, an AI chatbot around Recipes, or gamification disconnected from cooking. Long-term it grows into a private, personalized cooking intelligence built from normal use ([PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md); approved future, not implemented).

## Current state — Build 4

**StayGrubby 1.0 (4)** is a signed Release archive (iOS 17.0 minimum) uploaded to App Store Connect on November 7, 2026; Apple reported processing. Tester groups, notes and notifications are owner-controlled; no tester notification was sent automatically. Build 4 contains: Dish Already Shared reconciliation; rank-at-sharing snapshots; editing Sous Chef tags on existing cooks; the benchmark-gated Too Tough anti-stall rule; Recipe activity navigation from Grub List; My Kitchen / Sous Chef Kitchen unification groundwork; Tickets and restrained 86 wording; beta/referral-ready Universal Link fallbacks; iOS 17 compatibility. Owner physical acceptance passed for ranking, Already Shared, Recipe navigation/sharing, Edit Cook tagging and Universal Links (the last before the November 7 website recovery; iOS/AASA behavior was unchanged by it). Evidence: [NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md](NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md), [TESTFLIGHT_READINESS_REVIEW.md](TESTFLIGHT_READINESS_REVIEW.md). Build 4 functionality is closed unless a genuine regression appears.

Historical: 1.0 (1) was uploaded Internal Only before later features; builds 2–3 are superseded. Distribution, build numbers and submissions always require explicit current instruction.

## End-to-end system map

```
iPhone app (SwiftUI + SwiftData, iOS 17+, portrait)
 ├─ local SwiftData cooking store + structured outbox (account-scoped)   ── offline-capable
 ├─ account-scoped photo files (display + thumbnail JPEG)
 │
 ├─ Sign in with Apple ──► Supabase Auth ──► permanent account (staygrubby.accounts)
 ├─ authenticated RPCs ──► Supabase `api` schema (security invoker) ──► private `staygrubby` cores (security definer, RLS)
 ├─ private Storage buckets (cooking/profile/recipe/social photos) via owner-checked manifests
 ├─ Edge Functions: recipe-import (Gemini), delete-account (Apple revocation + staged erasure)
 │
 └─ Universal Links ◄── staygrubby.com (Cloudflare Worker `staygrubby` + static assets)
                         └─ AASA, browser fallbacks, /beta → TestFlight invitation
```

The website never reads Supabase. Links are pointers; the app authenticates and authorizes every destination.

## Navigation

Four authenticated tabs: **The Pass / Grub Rank (initial) / Food Bible / My Kitchen**. My Kitchen holds identity, Signature Dishes, Recipes entry, authorized own posts, Sous Chefs and Settings. **Tickets** is the in-app notification center and, by owner decision, belongs to the The Pass experience; Build 4 still also exposes it in the My Kitchen header with the unread badge on the My Kitchen tab — relocation is UI overhaul Stage E. Run It Back entry points are hidden; Want to Cook has no V1 surface. Detail: [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md).

## Domain boundaries

| Domain | Current implementation and ownership |
| --- | --- |
| Dish | Stable cooking identity/name, default Course/Cuisine/Source, optional Public Description (2,000 scalars) and owner-only Private Notes (8,000); no independent score |
| CookingAttempt | An actual cook/version: date, optional version title, private per-cook notes, Course snapshot, tags, up to six ordered cook-owned photos, sequence number |
| RankedItem | One ranking identity per attempt: BT strength, uncertainty, session diagnostics (initial/latest reaction, private dated completed reactions, comparison/skip/undo counts, stop reason) |
| Ranking evidence | One global RankingList; individual immutable-ID Comparison observations (winner or tie, timestamp); evidence is authoritative |
| Recipe | Server-owned UUID, owner, visibility (`private` / Sous Chefs), structured content, current revision, immutable revision history |
| Recipe provenance | Exact snapshots for explicitly associated cooks (`recipe_cooks`), private current cook links, legacy Dish-family links, forks, pinned creator attribution |
| Social | Optional profile, mutual Sous Chefs, explicit posts with safe snapshots, Hands/comments, Shared Cooking, Tickets, reports/blocks |
| Account/media | Apple/Supabase identity → permanent account; account-isolated store, outbox and private photo backup |

**One canonical Dish universe (owner decisions, November 8–9, 2026).** Grub Rank and Food Bible are lenses over one set of Dishes; two identities for the same real-world Dish are combined, never linked (`DishIdentityStore.combine`: cooks, ranking evidence, photos and Dish text move losslessly; FOOD_ARCHITECTURE §3.4). Dish and Recipe are two views of the same Dish: one Dish UUID connects Recipe content and revisions (`recipes.dish_id`, at most one owned Recipe per Dish), cooks, ranking evidence, photos and future sharing/intelligence. The schema stays normalized (no merged table). Creating a Recipe in Food Bible creates its Dish (no cooks yet; never in Grub Rank); Add Recipe on a Dish writes that Dish's Recipe; Rank My Version cooks into the Recipe's Dish; exact per-cook revision provenance (`recipe_cooks`) is unchanged. Dish Detail shows "View Recipe"; the Recipe reader is the same Dish's Recipe face with its cooks or "Not cooked yet"; Food Bible lists Dishes with Recipe content and filters Cooked / Not cooked yet; The Pass shows Dish/cook activity only. Cook names are edited in Edit Cook (`CookName`; no separate Rename). `20261108221250_dish_recipe_identity` is **deployed** (November 8: all 5 production Recipes took their existing Dish; no other data changed); D1 `dish_recipe_links`, `dish_recipes` and `recipe_cook_links` remain as transitional structures. Contract: [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md).

## Cooking library

New Dish and New Version each create an independent attempt and ranked item in the one global ranking. Edit and re-rank preserve identities. Top Version / All Versions are projections that keep true global ranks; filters never create another ranking. Required inputs for a new cook: trimmed Dish name, known cooked date (defaults to today), valid Course (Main default) and a completed ranking session; everything else is optional. Legacy unknown-date records remain editable.

Course uses controlled options. Dietary, Contains, custom tags and legacy free labels stay distinct in storage. Custom Tags are hidden from entry/search while stored values round-trip. Dietary is presented as Diet (Dairy-Free, Gluten-Free, Vegan, Vegetarian) and Certification (Halal, Kosher), each alphabetical; Halal was restored to selection on November 7, 2026 with unchanged stored codes. Avoid is a presentation filter over existing metadata, never a medical guarantee. Cuisine uses stable canonical IDs plus account-owned custom values; no inference/backfill. DishSource (My Own, Cookbook, Online, Restaurant, Friend / Family, Other) is manual inspiration, separate from Recipe creator attribution.

All cooking mutations go through the cooking/ranking services so references, evidence cleanup and durable sync stay consistent. Never delete domain rows directly. Multi-photo: six photos per cook, stable order, first is cover; advanced gallery/crop/editing is post-V1.

Version labels show only when meaningful (intentional title or multiple versions). A lone untitled cook shows no "Version 1" in rows/detail/accessibility/comparison; stored titles and sequence numbers are unchanged. (Known defect: the reaction screen still builds "Version 1"; queued in UI_ARCHITECTURE.)

## Ranking — protected

**Frozen unless the owner explicitly reopens it.** Initial Liked / It was fine / Didn't like → adaptive pairwise comparisons → Too Tough (tie) / Skip / Undo. Bradley–Terry over all retained individual observations, including repeats. Re-rank adds fresh evidence to the same item behind an explicit assessment boundary; earlier comparisons remain immutable full-weight observations. Uncertainty/model-aware stopping; acquisition checks the same global fit that commit persists. Build 4 anti-stall: after Too Tough, corrective acquisition may observe the same pair at most twice. No manual ordering. The engine uses Foundation/Accelerate and is independent of SwiftUI, SwiftData, Recipes and social. Specification: [RANKING_MODEL.md](RANKING_MODEL.md); calibration: [STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md); integrity correction: [V1_RANKING_INTEGRITY_REVIEW.md](V1_RANKING_INTEGRITY_REVIEW.md).

**Order and displayed score are distinct.** Order comes from fitted BT strength. The displayed 1–10 score is presentation only (`ScoreCalibration`, version 1): the item's latest semantic reaction (else initial) selects a band — Liked 7.0–10.0, Fine 4.8–7.8, Didn't like 1.0–5.8, unknown legacy 1.0–10.0 — and strength places it within the band. Within one reaction group, score follows order; across groups it need not. A Didn't-like Dish whose comparisons place it above Liked Dishes therefore shows, for example, **#9 · 2.6 above #11 · 7.6** (observed November 7 in the Simulator). This is mathematically explained but reads as broken.

**Pre-V1 investigation — Grub Rank score/order semantic consistency** (approved; investigation first, no math change yet). Determine how the displayed score and order can stay understandable and coherent while preserving BT evidence, historical comparisons, re-rank behavior, calibration, uncertainty and every existing user's history. Do not resolve it by hiding the inconsistency without understanding it. Any ranking or calibration change requires explicit owner reopening. Tracked in the roadmap and release gate.

Scores unlock at **ten** eligible saved ranked attempts; re-rank never increments eligibility; deleting below ten relocks presentation without destroying evidence. Native colors: coral 1.0–4.9, orange 5.0–7.5, gold 7.6–10.0; exports always brand red. The hosted `ranking_assessment_client_guard` rejects writes from clients that do not declare `rankingAssessmentVersion: 1` when assessment diagnostics exist; old queued payloads are never relabeled; a rejection keeps local work and stops automatic retries. Retire incompatible old TestFlight builds during authorized distribution work.

Completed initial ranks and re-ranks record a private dated reaction in the existing ranked-item diagnostics, including reaction-only sessions. A completed entry has a stable ID, time, reaction and kind. It commits with the cook or re-rank transaction and syncs through the same owner-scoped payload. Existing undated reactions are retained without inferring missing events. The history is separate from the inputs for fitting, score calibration and eligibility. Cook deletion removes it from active history and account deletion removes account-owned storage.

## Food Bible and Recipes — Architecture V2

Recipe means **how I make something**; Dish means **what I cooked and ranked**. Either exists alone. (This section describes the current Build 4 implementation; the decided unified presentation is in [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md).) Food Bible indexes Recipe UUIDs once each (standalone owned Recipes plus eligible Recipes linked to the caller's Dishes) through bounded `library_index` pagination. Add Recipe offers **Paste Recipe / Add Manually**, neither requiring a Dish. Recipe Detail keeps **Rank My Version** primary, with compact Share/Send and overflow (Edit, Version History, Save as New, Link a Dish, 86 Recipe). Linking uses the photographic Dish/version selector. New Recipe creation plus exact linking is atomic.

Owner-private `recipe_cook_links`: at most one current cook per Recipe and one current Recipe per cook, compare-and-swap guarded. A current link is a deliberate association, not proof a Recipe was used. Cook Detail distinguishes **Recipe used** (immutable snapshot) from **Linked Recipe** or legacy family link. Never infer which Recipe an old cook used from today's link.

Recipes use authenticated online APIs with ownership/visibility and expected-revision guards — no offline SwiftData cookbook. Food Bible search/filter/sort runs locally over authorized pages (Course, Cuisine, Contains, Avoid, manual Source; directional time/name sort). Unknown metadata stays unknown; there is no Recipe Dietary field. `RecipeContent` holds title, description, components with ingredient lines/structured ingredients and steps, yield, prep/cook/elapsed minutes with origins, Course, Cuisine, source/link/original creator, tips, allergen assessment (Contains/Possible) and photo ID; exact rational quantities; stable component/ingredient/step IDs.

Save keeps the Recipe ID, checks the revision and archives an immutable revision. History is owner-only. Restore creates a **new** revision. Save as New creates an independent private identity. Recipe-origin cook snapshots stay immutable through later edits. Serving adjustment is a deterministic display-only projection (1–100 servings; ranges/vague yields disabled; no unit conversion). As Written / US / Metric conversion exists but is hidden for V1. Recipe photo precedence: Recipe-owned → explicitly linked cook → branded fallback. New owner-authored Recipes default to **Share with Sous Chefs** (never Public); copies and Save as New stay private.

Rank My Version reserves the Recipe identity and exact revision, then runs the normal cook/rank flow. Recipe-origin cooks pin optional foreign creator attribution; self-origin cooks get no self-credit. Owner-accepted November 2; frozen except evidenced defects. Detail: [FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md), [NEXT_RELEASE_STAGE_4_REVIEW.md](NEXT_RELEASE_STAGE_4_REVIEW.md), [V1_PRODUCT_CLOSEOUT_REVIEW.md](V1_PRODUCT_CLOSEOUT_REVIEW.md).

`20261108171024_recipe_cook_lifecycle` is deployed (November 8; no pending repairs or stale links existed, so no row changed). It completes a reserved Recipe revision when the matching owner/item cook sync commits and repairs earlier provable matches without choosing a current association. A new visible Recipe-origin cook can fill a vacant exact link. Sync deletion retires the current exact link. Completion RPC retries acknowledge the saved cook without recreating an unlinked association. Existing authorized legacy Dish-family links and historical Recipe-used snapshots retain their separate semantics. See the [data foundation follow-up](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up).

Recipe/allergen/serving estimate limitations require Terms/disclaimer/safety coverage before V1 (not solely the Privacy Policy, not repeated in readers).

### Recipe Creator — Gemini-first, contract 4

**Messy input → Gemini constructs a structured Recipe → technical validation → editable RecipeDraft → user review/edit → explicit Save.** Source text is context, **not a vocabulary whitelist**; this November 2 owner decision supersedes lexical guards and source reconstruction. Gemini owns culinary interpretation, prose, sections, ingredient allocation, chronology, title/description, cuisine/allergen proposals and reasonable optional estimates. StayGrubby validates bounded JSON, types, nonempty content, enums, caps, corrupt quantities and acyclic explicit dependencies, then maps ingredient lines through the existing IngredientParser. No token-overlap checks, method-to-ingredient recovery, second AI judge or culinary fact-checking. Native mapping enforces the 40 KB draft bound; Review never saves automatically.

Edge Function `recipe-import` **v27**, JWT verification on, server-only Gemini key, 3 requests/account/minute burst guard. No daily cap, date expiry, billing or automatic retry; provider cooldown degrades to manual/deterministic entry. First-use external-AI disclosure per account. **Gemini is the only V1 AI provider; Apple Foundation Models are not compiled or offered.** Owner accepted November 2. [Style guide](RECIPE_STYLE_GUIDE.md).

## Accounts, private sync and media

Onboarding → native Sign in with Apple → Supabase Auth → permanent account resolution → verified account-store readiness → app. No production guest mode; new accounts start empty; sign-out returns to onboarding. SwiftData is the local working store; mutations atomically persist domain changes plus durable outbox operations; owner-derived RPCs return receipts with expected revisions. Hydration never refits/reranks. Tombstones prevent resurrection; conservative conflict rejection is deliberate. Coordinated account deletion verifies a fresh Apple grant, clears account-scoped Storage, erases the graph, then removes Auth and local account data. The read-only hosted source has a known cooking-photo manifest FK blocker. The local correction passed the disposable test and is required in the clean target before import. Physical Apple deletion remains a disposable-account test. Detail: [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md). Sign-in, restore and setup failures are classified (`AccountFailureKind`: connection, service, sign-in, other) and the gate shows a matching message with a short support code, never server text.

**Photos.** `LocalPhotoStore` writes metadata-stripped display (≤1,200 px) and thumbnail (≤360 px) JPEGs under account-scoped roots; originals are never copied. Backup/restore uses immutable account/media/hash paths, server-owned manifests binding account/asset/path/hash/size, SHA-256 and JPEG bound checks. Cooking, Recipe, social and avatar photos are separate assets in separate private buckets; linking or sharing never transfers photo ownership. Social photos are separately consented copies: posting uploads the cook's existing display JPEG byte-for-byte (no re-encode) into `social-photos`, because Sous Chefs must never get read access to the owner-only `cooking-photos` bucket. Every other lens (Dish, cook, Recipe fallback, combine) references the same stored cook asset; nothing is copied or recompressed to display it elsewhere. Each frame requests the rendition its size needs (`SGPhotoRole.usesThumbnailRendition`): the 360 px thumbnail only for fixed small rows, display for tiles, cards, Food Bible cards and heroes. Detail: [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md).

## Feature flags

`staygrubby.feature_flags(key, enabled, audience, description, updated_at)` is owner-managed (SQL/dashboard), RLS-closed and never client-writable; `api.feature_flags('get')` returns the keys enabled for the signed-in account. Today only `audience = 'everyone'` can be on; `internal` and `beta` are reserved and resolve to off until a reviewed membership model exists (a cohort table read by `staygrubby.feature_flag_api` only). The app loads flags at sign-in (`FeatureFlagService`, `\.featureFlags`); offline, older servers and errors mean every flag is off. A flag never makes an unfinished feature shippable. Known keys: `dish_aggregate_scores` (future, off). Migration `20261108234407_feature_flags` is **deployed** (November 8; empty table, no flag enabled).

## Supabase system map

The app still points to **`lgjxbpycphhsswxoncmz`** ("StayGrubby", us-east-1, PostgreSQL 17), currently read-only on 48 audited migrations. The clean **#stayGRUBBY** target (`ayjflxstqmnuoiphbyek`) is empty. Its authorized setup must apply all 49 local migrations, including the verified account-erasure correction, before any data transfer. The [live preflight](supabase/CLEAN_MIGRATION_PHASE_2A.md#phase-2b-live-preflight) records the remaining device, target access and cutover gates. Tooling/history: [Backend/README.md](Backend/README.md), [supabase/README.md](supabase/README.md).

| Layer | Contents and boundary |
| --- | --- |
| `staygrubby` schema (private) | 41 tables, all RLS-enabled. Cooking: `accounts`, `auth_account_links`, `account_libraries`, `rankings`, `dishes`, `dish_sources`, `cooking_attempts`, `ranked_items`, `comparisons`, `tags`, `attempt_tags`, `media`, `media_backups`, `sync_operations`, `sync_imports`. Recipes: `recipes`, `recipe_revisions`, `recipe_photos`, `recipe_cooks`, `recipe_cook_links`, `dish_recipes` (legacy family), `recipe_forks`, `recipe_activity`, `recipe_tickets` (dormant Want to Cook), `recipe_import_usage`/`_reservations`. Social: `profiles`, `profile_routes`, `username_reservations`, `friendships`, `social_posts`, `post_recipes`, `social_likes` (Hands), `social_comments`, `social_notifications` (Tickets), `social_reports`, `social_blocks`, `shared_cooks`, `shared_participants`, `cooking_origins`. Ops: `account_deletion_jobs`. Many tables intentionally have no client policy (deny-all); access is only through functions. |
| `api` schema | Client-callable RPCs, security invoker, **authenticated only — no anon execute**. Session-derived ownership, expected revisions, idempotency keys. Older `*_before_*` function versions are retained for compatibility (known backend debt). |
| Private cores | Security-definer functions with fixed search paths; not executable by clients. |
| `development` schema | `recipe_test_identity`, `recipe_test_login`; closed to clients, service-only RPCs. |
| Storage | `cooking-photos`, `profile-photos`, `recipe-photos`, `social-photos` — **all private**, JPEG only, 2 MB. Reads authorized through ownership or current Recipe/post access. |
| Edge Functions | `recipe-import` v27 (Gemini); `delete-account` v7; `development-test-session` v1 (see below). |
| Advisors (Nov 7) | 28 INFO "RLS enabled, no policy" (intended); 1 WARN leaked-password protection (release-gate disposition; Auth is Apple-only). |

**`development-test-session` is deployed to production.** It mints a session for a single marked development identity only after a project administrator issues a random 256-bit proof (SHA-256 stored, five-minute expiry, single use); JWT verification stays on; the development tables are closed. It exists for authorized live Recipe Creator regression. Its continued presence in production is a release-gate review item. [DevelopmentTools/README.md](DevelopmentTools/README.md).

**Conflict errors (permanent, Nov 11 2026 incident):** functions raise `PT409` for deterministic "changed; reload" conflicts, never `40001`/`40P01`, which PostgREST retries without limit. The schema test enforces this; clients accept PT409 and legacy 40001 (`StayGrubbyConflict`). Capacity thresholds, data retention classes and the health check: [supabase/README.md](supabase/README.md#database-capacity-and-health-permanent).

Deployment rules: migrations and Edge Function deployments need authorization in the current cycle; append migrations, never edit applied SQL; capture fingerprints for risky data work; never weaken RLS/grants to pass tests.

## Social — implemented, release hardening pending

Optional display name, editable @username, discoverability off by default, private avatar, anti-recycling profile routes. Mutual Sous Chef requests (accept/decline/remove) and authoritative two-way blocks. No follower model or public web profiles.

**The Pass** (the social feed; formerly "The Pass" — the API keeps `social_feed`/`activity_page` and `feed` identifiers) is a paginated chronological feed of current Sous Chefs' intentionally posted **cooks only**. Creating, importing or editing a Recipe never appears there (owner decision, November 8 and 11, 2026); a cook post can still offer its Recipe. Deployed servers still return legacy `recipe_created` items (`recipe_activity`), which the client never presents (`PassPage` keeps them only for the pagination cursor); retiring them server-side is a deferred migration. Posts carry safe snapshots: title, version title, score text, achievement, and (Build 4 clients) creator rank and ranked count at sharing; older posts keep score-only. Hands 🙌, Comments, reports, moderation state. Posting defaults OFF and is chosen per new cook; edit/re-rank never silently posts. When a cook with a photo is posted, the photo is included by default (visible toggle to post without it; owner decision, November 11, 2026). The composer reconciles an already published cook to **Already on The Pass**. Private Notes never become post descriptions. Visibility is rechecked for friendship, blocks, moderation, active accounts and deletion; links and Tickets grant no access.

**Shared Cooking / Tag a Sous Chef:** invitations, consent, join/decline/cancel, independent personal cooks, eight-person limit. Edit Cook can change participants (optimistic selection token); removing someone preserves their independent cook. Tagged collaborators are not yet shown on cards (decided future presentation).

**Tickets:** in-app only, no APNs. One account-mounted foreground coordinator polls every 30 s (60 s after failures); background/sign-out cancels it. Kinds: `request`, `accepted`, `invited`, `joined`, `recreated`, `like` (Hands), `comment`, `recipe_shared`, `post_shared`. `api.social_send` delivers an authorized Recipe/post pointer to current Sous Chefs with existing access (100/hour bound, idempotent); it grants nothing and is not chat.

Comprehensive UGC filtering and an operated moderation process remain V1 release-gate work. Detail: [SOCIAL_ARCHITECTURE.md](SOCIAL_ARCHITECTURE.md).

## Recipe + Social Integration — current contract

Recipes are private by default and optional for cooking or posting. A Dish link, AI creation or automatic post preference never opts into Recipe sharing. A composer's OFF-by-default **Include Recipe**, or the author's Recipe Sharing action on a post, deliberately makes the Recipe Sous-Chef-visible and pins one archived revision (`post_recipes` → `recipe_revisions`). The consent covers that revision's fields and Recipe photo, never Personal Notes or private cooking photos. The shared reader resolves by post UUID, reauthorizes, and returns only the pinned revision, attribution and authorized photo fallback. Recipes owned by someone else cannot be delegated through your post.

**Save a Private Copy** creates a new owned Recipe (revision 1) with `recipe_forks` provenance; foreign photo IDs are omitted. Making a Recipe private revokes further reads; removing an attachment revokes that post's reader; deleting the source removes live attachments and nulls fork source references; existing copies and recipient snapshots cannot be recalled. Detail: [RECIPE_SOCIAL_INTEGRATION_REVIEW.md](RECIPE_SOCIAL_INTEGRATION_REVIEW.md).

## Sharing, links and the website

**Internal vs external.** *Post to The Pass* creates StayGrubby social activity. *Share* is external (native share sheet). Build 4 external sharing: Dish/cook and Signature Dishes share a branded rendered image plus an export-safe caption — **no URL**; published posts, Recipes and profiles share HTTPS pointers. Private cook/rank/history/notes never become URLs or captions.

**Links are authenticated pointers, not public content:** `/@username`, `/p/<post UUID>`, `/r/<Recipe UUID>` (living Recipe), `/p/<post UUID>/recipe` (pinned revision). Optional single `?ref=<16–64 char opaque token>` is carried to the app-open URL and never affects access; no referral counting exists. UUID links survive edits. Own-profile links select My Kitchen. A link never bypasses RLS, friendship, block or visibility checks.

**Universal Link ownership.** App ID `5DSB36G7LZ.com.guyrettig.StayGrubby`; AASA (`Website/association.json`) covers `/@*`, `/p/*`, `/r/*` and is served at `/.well-known/apple-app-site-association` and `/apple-app-site-association`; the app registers `applinks:staygrubby.com` and the `staygrubby://open/...` scheme for the explicit fallback button. Installed app → native destination after authentication/authorization. Not installed → generic, `noindex`, no-store fallback HTML with the configured TestFlight invitation (`Website/distribution.json`; switch to the App Store URL at V1) and Support/Privacy links. Apple caching and the recipient's browser can keep same-domain navigation in Safari.

**Website** (Cloudflare Worker `staygrubby`, account `a53a5efe…`, `staygrubby.com`): `link-worker.mjs` is a stateless GET/HEAD handler in front of static assets (`ASSETS` binding, `run_worker_first` for `/`, `/@*`, `/%40*`, `/p/*`, `/r/*`, `/kitchen`, `/beta`, `/privacy`, `/support`, both AASA paths). It fetches no Supabase data and sets no cookies. workers.dev and preview URLs are disabled.

> **Assets-only publishing is NOT a valid StayGrubby production deployment.** It leaves Home, Privacy and static AASA working while every `/beta`, post, Recipe and profile fallback returns an empty 404. This happened three times (Stage 3, Stage 5, and after Build 4 on November 7). The only production path is `sh Website/deploy-production.sh` (local tests → full Worker + assets deploy from `Website/wrangler.jsonc` → `verify_live_links.py`, failing on any live mismatch). Procedure and incident history: [Website/README.md](Website/README.md#source-verification-and-deployment).

**External preview constraint.** All buckets are private and every `api` function requires authentication, so the Worker cannot build photo-rich Open Graph previews from user content today, and fallbacks carry no OG tags. Approved direction: never make the general photo buckets public; a future rich preview must use an explicit share-safe preview artifact containing only what the user intentionally exposes, treated as a privacy boundary, with documented cache/revocation limits (iMessage and social platforms cache previews per URL and may show deleted content). Until then the approved fallback is one Share action carrying the share card image + a short `#stayGRUBBY` message + the exact content link (UI overhaul Stage C). See [roadmap](STAYGRUBBY_MASTER_ROADMAP.md).

Rendered exports: photo card 1080 × 1350, no-photo 1080 × 1080, Top 3 1080 × 1350; brand-red scores; score lock respected; private rank/movement never exported. [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md).

## Privacy model (current)

Private by default; explicit per-action sharing; Personal/Private Notes always owner-only; RLS and owner-derived APIs on every operation; private Storage; two-way blocks; current-access rechecks on every read; account deletion clears media before graph/Auth erasure. Allergens are informational, never medical or cross-contact guarantees; kosher/halal is never inferred. The hybrid account-maximum/per-item audience model is approved future work, not implemented. Canonical policy: [StayGrubby/Legal/PrivacyPolicy.md](StayGrubby/Legal/PrivacyPolicy.md), bundled offline and published at `/privacy`. Data-governance principles for future work: [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md#6-privacy-and-data-governance).

## Design

Reuse `StayGrubby/DesignSystem` and asset-catalog artwork. Logo red **#F10607** (`SGTheme.Brand.red`, sampled from the canonical asset; supersedes conceptual #FF2D1F), cream **#FAF3EC**, charcoal **#1F1F1F**; adaptive control tokens for accessible controls. Full specification, known defects and the Stage A–G overhaul plan: [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md).

## Debug fixtures and test safety

- Every Debug review fixture requires `--ui-test-store <UUID>`, which creates an isolated temporary SwiftData store and media root. Fixtures never touch normal account, guest or demo roots. All fixture/review code is compile-time excluded from Release.
- `--social-review*`, `--shared-review`, `--stage*-review`, `--recipes-review*`, `--sharing-fixture <case>`, `--score-unlock-fixture N` (N ∈ 0, 1, 9, 10, 12), `--discovery-fixture` and similar use in-memory mocks with no Auth or Supabase traffic. Appearance/type: `--test-light`, `--test-dark`, `--test-large-type`, `--test-reduce-motion`.
- `--development-persona` uses the same UUID gate and a separate persona store/media namespace. The fictional cooking library persists locally. Recipe and social fixtures use the existing in-memory transport and reload on launch. See [launch instructions](DevelopmentTools/README.md#preloaded-development-persona).
- `--recipe-live-regression` calls the live Gemini path and runs only with a matching approval ID from an owner-authorized budget. Never run it without a current-cycle grant.
- Never use real accounts or real data as disposable fixtures; never create test data in the owner's account; never run destructive account tests against the owner.

## Verification

Follow AGENTS.md's minimum-confidence table.

**Known unit-test debt (observed November 7, 2026 at `cfe67df`, unchanged by UI Stage A):** `CuisineTests.dishEditsInheritanceAndFiltersNeverChangeRankingEvidence` and `Stage2CookingEntryTests.editingAndCancellingDraftsPreserveEvidenceAndOriginalCookNotes` fail their exact item/comparison snapshot equality; `RankingsPresentationTests.normalTopThreeOmitsMilestoneClaimWhileActualUnlockMayIncludeIt` and `SharingPresentationTests.nativeCompletionDeliversSuccessfulSaveAfterItsCallback` still expect image-only share items, while exports now carry image + caption; (`DishSourceTests.simplifiedSourceOptionsAndOriginalURLsPersistWithoutRankingChanges` passes since Halal returned to the Dietary options in the Stage B owner revision.) Pre-existing UI-test debt confirmed on a clean `941a949` export (unchanged by UI Stage B): `CookingDiscoveryUITests.testEditingFromSearchUpdatesResultsWhilePreservingFiltersAndScore` and `PolishUITests.testContainsEditPersistenceAndAvoidAnySelectionWithIndependentClear` still look for a top-level "Edit Cook" button (now in the Dish Detail overflow), both `CuisineUITests` tests cannot reach `dish-cuisine`, and `V1RevisionUITests.testLockedLargeTypeRerankCancellationAndVersionThresholdCrossing` fails its re-rank action path; both `Phase2CReviewUITests` comparison/detail tests also look for top-level "Re-rank" / "Edit Cook" buttons (confirmed failing on `941a949`). Also stale on a clean `1fde015` export (November 11): `ProductStructureUITests.testFourTabsKitchenFriendsHitAreaAndSingleProfileEditor` expects a Food Bible empty state the Recipe fixture no longer has, and `DesignReviewUITests.testSocialRecipeAndEditorInBothAppearances` taps a top-level `recipe-edit` that D3 moved into the Recipe actions menu. Update these tests to the current overflow/Details navigation before the release gate. Diagnose before the release gate. The two evidence-snapshot failures touch protected ranking tests: establish whether the test or the behavior is stale before changing either. In particular: documentation-only changes need consistency/link/secret checks only; website deployments need `deploy-production.sh` and its live gate; schema work needs migration/hash, RLS/security tests and fingerprints; release candidates need one broader regression and Release verification.

## Task-specific source map

| Task | Read next |
| --- | --- |
| Cooking/ranking/calibration | [COOKING_MODEL.md](COOKING_MODEL.md), [RANKING_MODEL.md](RANKING_MODEL.md), [score review](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md) |
| Auth/account/sync | [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md) |
| Photos | [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md) |
| Social | [SOCIAL_ARCHITECTURE.md](SOCIAL_ARCHITECTURE.md) |
| Dish + Recipe relationships, Main Recipe, cook naming, lenses, Add Recipe | [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md), [V1 data audit](V1_DATA_FOUNDATION_AUDIT.md) |
| Food Bible/Recipe | sections above, [Architecture V2 review](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md), [Recipe Style Guide](RECIPE_STYLE_GUIDE.md), [Creator ownership audit](RECIPE_CREATOR_REVIEW.md) |
| UI/share images | [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md) |
| Future intelligence / data planning | [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md) |
| Backend/tooling | [Backend/README.md](Backend/README.md), [supabase/README.md](supabase/README.md), [DevelopmentTools/README.md](DevelopmentTools/README.md) |
| Website/links | [Website/README.md](Website/README.md) |
| Release | [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md), [TESTFLIGHT_READINESS_REVIEW.md](TESTFLIGHT_READINESS_REVIEW.md) |

Stage-by-stage implementation history (Stages 1–5, Product Closeout, ranking integrity, iOS compatibility, Next-Version integration) lives in the dated reviews linked above and in [UI_ARCHITECTURE_HISTORY.md](UI_ARCHITECTURE_HISTORY.md). Hosted counts and test totals in reviews are dated observations, not live guarantees.
