# StayGrubby — current product and architecture

**Canonical current-state overview — updated November 2, 2026.** Read [AGENTS.md](AGENTS.md) for development rules and the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) for planned work. This overview reconciles the implementation and owner decisions; dated domain/review sections remain evidence for their checkpoints, not claims that their old counts, gates or future boundaries still apply.

## Product and navigation

StayGrubby is a food/cooking platform centered on comparison-based ranking of things people actually cook, a personal cookbook/Recipe experience and explicit social sharing.

**Cook → Rank → Remember → Share → Interact**

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE**

Cooking, saving a Recipe and publishing a social post are separate actions. Saving/discovering does not mean something was cooked/ranked. Popularity never changes personal ranking.

The native SwiftUI/SwiftData iPhone application targets iOS 26.5 and supports **upright portrait only**, with light/dark appearance and accessibility within portrait. Project/target/scheme/module is `StayGrubby`; bundle ID is `com.guyrettig.StayGrubby`.

The four authenticated tabs are **Grub List / Grub Rank / Food Bible / My Kitchen**; Grub Rank is initial. My Kitchen contains authorized own social posts, identity, Signature Dishes, Sous Chefs and Settings. Tickets are deliberately hidden from normal V1 navigation; their underlying implementation/data remain preserved.

## Domain boundaries

| Domain | Current implementation and ownership |
| --- | --- |
| Dish | Stable personal cooking identity/name, default Course, optional primary Cuisine and optional DishSource; no independent score |
| CookingAttempt | An actual cook/version of a Dish: date, optional version title, private notes, Course snapshot, tags and cook-owned media |
| RankedItem | Unique ranking identity per attempt; holds estimated strength/uncertainty and display diagnostics |
| Ranking evidence | One global cooking RankingList with individual immutable-ID Comparison observations; evidence is authoritative |
| Recipe | Server-owned UUID, owner/visibility, structured content, current revision; Dish links are separate relationships |
| Recipe history/provenance | Stable current identity, immutable archived content, restore-as-new revision and exact snapshots for explicitly associated cooks; Dish linkage alone is not proof a historical cook used the latest Recipe |
| Social | Optional profile, mutual friendship, explicit posts/safe snapshots, Hands/comments, invitations/recreations and notifications |
| Account/media | Apple/Supabase identity maps to permanent account; account-isolated working store, structured outbox and private photo backup |

### Cooking library

New Dish and New Version both create an independent attempt/item in the same global ranking. Edit and re-rank preserve existing attempt/item identities. Top Version / All Versions are projections, preserving true global ranks; filters do not create another ranking.

Course uses the controlled existing options. Dietary, Contains, custom tags and legacy free-label compatibility remain distinct. Avoid is a presentation/filter selection over existing metadata, not a medical guarantee. Cuisine uses stable canonical IDs plus account-owned custom values; no inference/backfill into existing Dishes is implied. DishSource is optional manual inspiration/attribution with My Own, Cookbook, Online, Restaurant, Friend / Family and Other UI choices; legacy storage codes remain compatible. It is separate from Recipe creator/source attribution.

All personal cooking mutations go through the existing cooking/ranking services so references, evidence cleanup and durable synchronization remain consistent. Do not directly delete domain rows as a shortcut.

### Ranking — accepted and frozen

Initial Liked / Fine / Didn't Like assessment, adaptive comparisons, Too Tough ties, Skip and Undo feed the established ranking workflow. Bradley–Terry uses retained individual evidence, including repeated observations; re-rank adds evidence to the same item. The engine uses Foundation/Accelerate independently of SwiftUI, SwiftData, Recipes and social services.

**Order and displayed score are related but distinct.** Order comes from fitted strengths. The accepted reaction-conditioned `ScoreCalibration` supplies the current displayed score; the older relative diagnostic transform in the technical specification is not the current UI mapping. Reactions do not rewrite the Bradley–Terry objective. See [RANKING_MODEL.md](RANKING_MODEL.md) and [calibration details](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md), rather than duplicating formulas here.

Numerical scores unlock at ten eligible saved ranked attempts/versions. Re-rank does not increment eligibility; deleting below ten relocks presentation without destroying evidence. UI, accessibility, previews and exports obey the gate. Native numerical colors are muted coral 1.0–4.9, orange 5.0–7.5, gold 7.6–10.0; exported card scores always use brand red. Recipe/social work must preserve all ranking, calibration, evidence and visibility behavior.

## Food Bible and Recipes — Architecture V2

Recipe means **how I make something**; Dish means **what I cooked/ranked**. Either exists alone. Food Bible now indexes Recipe UUIDs, including standalone owned Recipes and eligible Recipes explicitly linked to the caller’s Dishes, exactly once. Multiple retained links do not duplicate cards. Existing UUIDs, content, history and links are preserved without backfill or copying. Older cookbook endpoints remain compatible; the new bounded `library_index` uses Recipe UUID pagination.

Food Bible Add Recipe offers **Paste Recipe / Add Manually**, neither requiring a Dish. Existing Dish-context creation can save an explicit link. Recipe Detail supports linking to an existing cooked Dish, safe unlinking, normal edit, Version History/inspection/restore and Save as New Recipe. Unlinking removes only the relationship; both objects and Food Bible membership survive. A Dish has one current Recipe link; conflicting replacement requires deliberate unlinking. Existing Make This/Cook It Again provenance is retained; no new broad social/cooking flow is introduced.

Recipes use authenticated online APIs with ownership/visibility and expected-revision guards, not a second offline SwiftData cookbook. Personal cooking remains locally usable offline. Food Bible search/filter/sort stays local over bounded authorized pages, now including unlinked Recipes, descriptions and Recipe metadata, with linked Dish fallback. Recipe cuisine/Course leads Food Bible; Dish cuisine/default Course and actual cook assertions still lead Grub Rank and current cooking-post snapshots. Recipe edits do not overwrite Dish/cook metadata or change ranking/filter semantics. Explicit Recipe-to-cook draft prefills remain reviewable.

`RecipeContent`/editable `RecipeDraft` retain stable component/ingredient/step IDs, legacy compatibility and exact rational quantities. Optional short description, yield, times/origins, Course/Cuisine, source/creator/link/tips and allergens remain Recipe-owned. Recipe description is editable/removable, with guidance for 1–3 useful sentences. Reviewed Recipe Contains/Possible is the primary ingredient-derived allergen surface. Existing cook-specific Contains/dietary/legacy tags are retained under cook-specific controls and remain searchable/filterable; no guessed metadata migration, religious inference or medical guarantee is introduced.

Normal Save keeps the Recipe ID, checks current revision and archives a new immutable content revision. History is owner-only and paginated. Restore copies archived content exactly into a **new** current revision, preserving current audience and prior history (including legacy flat content and photo references). Save as New opens an independent private draft/identity/history. Stale editing cannot silently recreate a deleted Recipe. Exact RecipeCook revision/content snapshots remain immutable through later Recipe edits/restores; an explicit cook association is ownership/revision checked and cannot replace a different existing snapshot. Never infer which Recipe an old cook used from today’s Dish link. Detaching/deleting Recipes preserves independent cooking/evidence and retained cook snapshots.

Reader serving adjustment is a deterministic **display-only** projection over the existing exact rational quantity parser. Usable canonical serving counts (plain counts or explicit serves/servings/people/portions, 1–100) enable adjustment; ranges/loaf yields/vague yields do not. Integer/fraction/decimal/count/metric/US-volume/range quantities scale proportionally without unit conversion. Unmeasured, ambiguous, to-taste/as-needed and per-person quantities stay written; source methods/times stay canonical. Changing displayed servings never saves quantities or changes historical snapshots. There is no AI scaling math or requirement for Creator to invent yield.

Recipe-owned optional photos take precedence over linked cook photography, then the branded fallback. `LocalPhotoStore.prepare` supplies metadata-stripped optimized JPEG bytes; existing account-generation-guarded media transport adds the private `recipe-photos` bucket. Server-owned immutable manifests bind account/asset/path/hash/size; a verified upload completes before a Recipe can reference it. Download checks SHA-256/JPEG bounds. Photo bytes are separate from cooking media and do not alter its sync. Current friends can read a photo only through an accessible current Recipe; history is owner-only. Old referenced photos survive replacement/removal for archived revisions/cook snapshots; a bounded owner-authorized RPC/Storage policy supports unreferenced upload cleanup, and account deletion clears all Recipe bytes before graph/Auth erasure. The new bucket starts empty; no existing media is moved.

Ingredient entry/paste and native within/between-component row ordering are unchanged. Explicit Save, revision conflict protection, dirty/cancel protection and editable import review remain. Unsaved force-quit recovery is not claimed. See [Architecture V2 verification/release state](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md); owner physical acceptance of V2 remains separate from accepted Creator mechanics.

### Recipe Creator — Gemini-first, contract 4

**Messy input → Gemini understands/constructs a structured Recipe → technical validation → editable RecipeDraft → user review/edit → explicit Save.** Source text is context for Gemini, **not a vocabulary whitelist**. This permanent November 2 owner decision supersedes the former lexical guards and source-reconstruction recovery, including v19–v26 assumptions in historical reviews. Earlier V1/refinement physical acceptance remains historical evidence; existing Recipe/cooking ownership and deterministic serving adjustment remain intact.

Gemini owns culinary interpretation, correction of clear speech noise, professional prose, meaningful sections, ingredient allocation, chronology, title/short description, cuisine/allergen proposals and reasonable optional yield/time estimates. It should preserve supplied amounts, per-person bases and useful preparation details, avoid invented precise quantities/settings, and keep uncertainty/options clear. These are model/content-review responsibilities; StayGrubby does not attempt to prove them by matching source words, phrases or tokens. Minor imperfect editorial choices do not block a useful draft. The user is the final content reviewer.

The transport returns title, optional description/yield/source/metadata, and components with ingredient **lines**, ordered instruction **strings** and optional explicit prerequisite indexes. Ingredient lines naturally retain amounts/units/preparation/alternatives, then the existing exact IngredientParser maps them into native fields without changing serving math. Contract 4 adds description directly to the existing RecipeContent description; contracts 1–3 remain structurally accepted, with no new description field sent to older clients. Updated native code requests contract 4. Old installed clients with lexical guards need the latest build; no distribution/upload is implied.

StayGrubby validates bounded JSON/types/core arrays, nonempty usable content, supported metadata/enums, component/row/text caps, corrupt quantities and valid acyclic/in-range explicit dependencies. Only dependency ordering is applied, not inferred chronology. Invalid optional metadata/description is omitted, missing metadata remains unknown, and estimates/provenance need no literal source quotation. Inconsistent optional totals are cleared. Provider prose, names, ingredient allocations, duplicate rows and method text are preserved; no source-based reconstruction, ingredient extraction from methods, deduplication, modifier repair, fact-lock or second AI judge remains. Native mapping enforces the existing 40 KB save-compatible draft bound; Review never saves automatically.

Gemini remains the standard consented Paste Recipe provider; Apple infrastructure remains dormant in normal creation. Request/provider/output/field bounds, JWT/live-session ownership, server-only key and 3/account/minute abuse protection remain. There is no daily product cap, recurring date/30-day expiry, billing setup or automatic provider retry. Provider cooldown retains friendly Cloud AI messaging and manual/deterministic fallback. First-use external-AI disclosure/account-scoped acknowledgement and Add Manually are unchanged. Saved Recipe identities/revisions/photos, cook snapshots, ranking, social data and serving projection were not altered.

**Deployed v27 / JWT enabled** implements this boundary. Retained real French-toast, Shakshuka and kale outputs all map offline; three separately authorized fresh v27 calls also returned usable drafts with descriptions, and their actual responses passed native edit/serialization checks. All **3/3** new calls are consumed; the earlier 6/6 and 3/3 ledgers are unchanged. Final focused evidence: 69 function tests, 4 budget tests, 22 distinct native tests /28 executions pass. No broad UI/backend or Release suite. Drafts are not perfect: bread-count/temperature interpretation, chile specificity, equipment in an ingredient list or wording may need owner edits. That is not a claim of kitchen testing, source-perfect output or physical acceptance. **GEMINI-FIRST RECIPE CREATOR PIPELINE VALIDATED — OWNER PHYSICAL ACCEPTANCE PENDING.** See [dated evidence and one owner test](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md#november-2--gemini-first-architecture-correction).

## Accounts, private sync and media

Production flow is onboarding → native Sign in with Apple → Supabase authentication → permanent account resolution → verified account-store readiness → authenticated app. New real accounts start empty; sign-out returns to onboarding. Session restoration is implemented; brief cold-start transition polish remains separate. No production guest mode. Debug development-library access is compile-time excluded from Release, isolated and unable to authenticate/provision/upload as a real account. Physical device-local development storage is separate from the Simulator library.

SwiftData is the local working cooking store. Mutations atomically persist domain changes plus durable outbox operations; authenticated owner-derived RPCs provide receipts, expected revisions, retries, snapshots and restoration. Hydration preserves identities/numeric evidence without refitting/reranking or creating upload intent. Existing conservative conflict rejection is deliberate; new conflict merging is not implemented. Tombstones/causal history prevent deleted cooks from resurrecting; raw server row counts need not become zero after deletion.

Local cook photos use account-scoped file roots and metadata, with optimized display/thumbnail variants privately backed up/restored using immutable account/media/hash paths and validated bytes. Profile reports pending/current state and retry. Social and avatar media have separate private buckets, permissions and cleanup. Test UUID stores/media roots must never write into the normal account/guest/demo roots.

Private application tables have RLS and least-privilege grants; narrow server APIs derive permanent ownership from a verified live session. Client-safe Supabase configuration is distinct from privileged server credentials. Store readiness and generation/cancellation guards prevent account-switch/stale-response leakage.

Coordinated account deletion is implemented: deliberate native confirmation/fresh Apple verification, server-side Apple verification/revocation and idempotent staged private/social media, database, Auth and local cleanup. The real physical Apple revocation/deletion test is intentionally deferred, **not a blocker to ongoing development**. Never perform it against the owner's account as routine verification.

## Social — implemented, with release hardening still needed

Optional display name, editable @username, discoverability off by default, private avatar and permanent anti-recycling profile routes are implemented. Mutual Sous Chef requests/accept/decline/remove and authoritative blocks exist. There is no public/private follower model, creator following system or public web profile product.

Grub List is a paginated chronological current-friends feed of explicit cooking posts/safe snapshots, with separately consented private social photos, Hands/comments and reporting/moderation states. Sharing defaults start OFF and can be overridden per new cook. Edit/re-rank/restore does not silently create a new post. Private Personal Notes never become public/shareable Post Descriptions. Social engagement, saves or friends' scores never alter the cooking graph/ranking. Visibility is reauthorized for friendship, blocks, moderation and deletion; a deep link/notification grants no access by itself.

Shared Cooking supports invitations, consent, joining/declining/cancellation and independent personal cooks. Run It Back carries eligible safe metadata/Recipe provenance through existing snapshots and normal cook/rank flows, never another person's evidence or score. In-app **Order Up!** notifications and read state exist; APNs/push does not. The observed Tag a Sous Chef notification issue belongs to the planned broader social/notification cycle, not a claimed fix.

Recipe visibility/provenance infrastructure is not a dedicated Recipe-only feed or combined Recipe/rank post product. Those post types, filters and update-sharing policy remain planned. Blocking/reporting/closed APIs are implemented; comprehensive UGC filtering and operational moderation response remain external-release work.

## Design, sharing, privacy and distribution

Reuse `StayGrubby/DesignSystem` (`SGTheme`, existing controls/header/editorial components) and canonical asset-catalog artwork. Supplied logo red is **#F10607**, cream **#FAF3EC**, charcoal **#1F1F1F**; adaptive app controls use existing contrast-adjusted tokens. Food imagery/type/whitespace lead; decoration and motion remain restrained. [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md) provides detailed contracts; [design review](STAYGRUBBY_DESIGN_SYSTEM_REVIEW.md) retains evidence.

Native local share images remain separate from social publishing: existing photo cards 1080 × 1350, no-photo fallback 1080 × 1080 and Top 3 1080 × 1350. Approved typography/layout, score-lock protection and evidence-backed achievements remain. Exports/embedded rendered previews always use brand-red scores; native results use semantic score colors. Private global rank/movement does not export. Future Stars is distinct from existing factual share achievements.

The canonical policy is [StayGrubby/Legal/PrivacyPolicy.md](StayGrubby/Legal/PrivacyPolicy.md), bundled offline and rendered by the existing static website. `staygrubby.com`, `/privacy`, `privacy@staygrubby.com` and `support@staygrubby.com` foundations are established. Latest local policy is effective October 28 and describes independent Recipes/photos and first-use Paste Recipe disclosure, researched against current Google terms. Publication is **pending owner Cloudflare login**: the connected API lacks the upload-session authorization-header capability and the temporary official Wrangler CLI reports unauthenticated. No credentials/configuration were changed. Do not mistake source/render tests for publication. App Privacy answers completed for older releases require review for subsequent social/AI practices before wider distribution.

Owner-confirmed **1.0 (1) Internal Only TestFlight upload succeeded historically**, before later features; it is not evidence that current HEAD was uploaded or externally approved. External TestFlight, release candidate/App Store 1.0, updated policy publication, UGC operations, physical Universal Links correction/verification and current privacy/reviewer metadata remain separate authorized release work. Profile route/AASA/fallback infrastructure exists, but physical Universal Links are owner-reported broken/deferred. No new distribution is authorized by this document.

## Task-specific source map

| Task | Read next |
| --- | --- |
| Cooking/ranking/calibration | [COOKING_MODEL.md](COOKING_MODEL.md), [RANKING_MODEL.md](RANKING_MODEL.md), [score review](STAYGRUBBY_PRODUCT_STRUCTURE_SCORE_REVIEW.md) |
| Auth/account/structured sync | [ACCOUNT_ARCHITECTURE.md](ACCOUNT_ARCHITECTURE.md), [SYNC_ARCHITECTURE.md](SYNC_ARCHITECTURE.md) |
| Photos | [MEDIA_SYNC_ARCHITECTURE.md](MEDIA_SYNC_ARCHITECTURE.md) |
| Social | [SOCIAL_ARCHITECTURE.md](SOCIAL_ARCHITECTURE.md), relevant Shared/Social UX review only as needed |
| Food Bible/Recipe | Current Recipe section above, [Architecture V2 review](FOOD_BIBLE_ARCHITECTURE_V2_REVIEW.md), [Food Bible UX 2 review](STAYGRUBBY_FOOD_BIBLE_UX_2_REVIEW.md), [Creator ownership audit](RECIPE_CREATOR_REVIEW.md), [Recipe Style Guide](RECIPE_STYLE_GUIDE.md), [refinement evidence](RECIPE_CREATOR_REFINEMENT_REVIEW.md) |
| UI/share images | [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md), [V1_SHARING_ARCHITECTURE.md](V1_SHARING_ARCHITECTURE.md) |
| Backend/tooling | [Backend/README.md](Backend/README.md), [supabase/README.md](supabase/README.md), [DevelopmentTools/README.md](DevelopmentTools/README.md) |
| Release/privacy/website | [release evidence](STAYGRUBBY_V1_RELEASE_READINESS_REVIEW.md), [Website/README.md](Website/README.md), canonical policy, current release stage in the Master Roadmap |

Repository evidence is the source of implementation detail. Hosted counts/hashes and past test totals in review files are dated observations, not live guarantees or instructions to rerun everything. The October 28 V2 cycle deploys only the additive Recipe migration and Recipe-bucket account cleanup; current evidence and limitations are recorded in the V2 review. No distribution is authorized by documentation.
