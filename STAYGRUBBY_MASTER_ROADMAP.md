# StayGrubby Master Roadmap

**Canonical roadmap — updated November 16, 2026 for the accelerated public MVP.** This is the only future-sequencing document. [AGENTS.md](AGENTS.md) governs how work proceeds; [STAYGRUBBY_ARCHITECTURE.md](STAYGRUBBY_ARCHITECTURE.md) describes what is implemented; [PERSONAL_COOKING_INTELLIGENCE.md](PERSONAL_COOKING_INTELLIGENCE.md) holds the long-term intelligence direction and data inventory. Planned items are not implementation, deployment or distribution authorization.

**DISCOVER → SAVE → COOK → RANK → REMEMBER → SHARE → INSPIRE.** Personal cooking and comparison ranking stay central. Recipes, engagement, recommendations, sponsorship and commerce never change personal ranking evidence or scores.

## Development strategy — accelerated public MVP (owner decision, November 16, 2026)

**Target: public App Store MVP in January 2027; stretch: December 2026.** Classify every item as **MVP Required**, **Post-launch Priority** or **Future Roadmap**. Nothing deferred is dropped: every Post-launch and Future item stays in this document.

- **Finish and stabilize before expanding.** Completing, fixing and speeding up existing functionality outranks new features. A new feature enters the MVP only for product coherence, safety, privacy, platform compliance or data integrity.
- **LEGO-style modules.** Reuse the existing ranking, Recipe, social, authentication, migration and sync systems. Build reusable interfaces and privacy boundaries for known future features, but do not implement distant backend features early (no speculative tables, counters or event streams).
- **Operate cheaply.** Minimize Supabase storage, reads and writes: cache reads, coalesce requests, refresh only on change or staleness, never retry in storms.
- **Verification.** Focused tests that reuse existing verified evidence; Debug and Release compilation each cycle; broader regression once per release candidate. **Physical iPhone testing is owner-led through Xcode** (install over the existing app, never uninstall). **External TestFlight is optional, not a release milestone.**
- **Offline-first UX is not required.** Reliable local caching, data integrity and safe sync remain required.

### MVP phases and timeline

| Phase | Window | Scope | Status |
| --- | --- | --- | --- |
| S1 — MVP stabilization | Nov 16 – Nov 30, 2026 | Connected UI Phase 1 plus stabilization: one Dish page, consistent Dish/Recipe photos, read caching for Food Bible and The Pass, Dish cook count. Connected UI cohesion: Recipe preview on the Dish page, Food Bible cook status, My Kitchen statistics that open Grub Rank, Last cooked and Recent Cooks. Fix reproducible defects from the one consolidated owner Xcode review. | **Implemented Nov 16 (Claude); automated acceptance passed; one consolidated owner physical review pending.** |
| S2 — Public-release requirements | Dec 1 – Dec 20, 2026 | The MVP Required items below, chiefly moderation, social onboarding, legal/privacy documents and disclosures, account deletion review, security dispositions, Supabase capacity plan. | Started Nov 16. Moderation backend and Recipe report entry points tested locally. Owner-private authorization and text screening passed local verification. Image screening and exact social Dish identity, including iOS pagination/cache integration, are locally implemented. Zero-billing manual image review is implemented locally. Signed/staff rehearsal and deployment are pending. |
| S3 — Release candidate and submission | Stretch: Dec 21 – 31, 2026; target: Jan 2027 | Release build, one proportionate regression and Release verification, owner physical acceptance through Xcode, App Store metadata and submission (each step needs explicit owner approval). Optional external TestFlight. | Not started |

### MVP Required (public-release blockers)

Full checklist and evidence: [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md).

- **Stability and performance:** owner physical acceptance of Connected UI Phase 1 and the November 16 stabilization. This includes Saved Recipes once a Sous Chef shares a Recipe. Close any defect it finds.
- **Moderation and safety:** deploy and exercise the locally implemented report → review → resolution workflow across posts, comments, Recipes and profiles with the verified owner-private Recipe fix and prospective text screening. The image-screening candidate and exact per-Dish social lookup are implemented locally. Use the zero-billing human image-approval workflow, complete signed staged acceptance and staff the response process. Paid image providers and automatic classification are outside this MVP. [Moderation runbook](PUBLIC_MVP_MODERATION.md).
- **Social onboarding:** a unique username and an explicit privacy choice for new accounts; a resumable completion flow for legacy accounts (from Very Near Term below). People discovery stays opt-in until this ships.
- **Privacy and security:** focused review of audience rules, RLS, private Storage, account isolation, revocation, shared links and counts; App Store privacy disclosures matching actual processing (including external AI); disposition of security advisories and a signed Edge Function gateway smoke test. The migrated target excludes the development session function.
- **Account deletion:** account deletion with UGC/media cleanup reviewed on isolated test identities.
- **Legal:** Terms of Use, Community Guidelines, and Recipe/allergen/serving/estimate disclaimers. Verify that the hosted Privacy Policy is current and that support/contact exists.
- **App Store:** age rating and UGC answers, App Review sign-in access, production configuration/signing, no Release development bypass, homepage and `distribution.json` switch at release.
- **Ranking presentation:** conclude the score/order consistency investigation and implement the owner-approved presentation (no math change without explicit reopening).
- **Operations:** Confirm current migrated-project Dashboard disk headroom, wire and prove the external capacity alert, run signed integration in disposable non-production infrastructure, and exercise the release candidate smoke gate. [Backend readiness and priorities](BACKEND_MVP_READINESS.md#shortest-path-to-public-release).
- **Finish what exists:** Sharing stage C (one Share action, Post to The Pass vs Share) and the copy/consistency pass (stage G) limited to existing surfaces.

### Post-launch Priority

- **Connected UI Phase 2:**
  - open my Dish from my own post (owner-only `sourceAttemptID`)
  - Recipe preview on cook posts
  - Make This with exact-revision creator attribution
  - Makes/Saves aggregates and public totals
  - Saved Recipes paging
  - retire the `fork` RPCs once no supported client uses them
- **People and invitations:** people discovery for every account, improved Find Sous Chefs, invitation links, follow-request UX, threaded comment replies.
- **Polish:** welcome screen update and the pasta-machine loading animation; a Dish identity for legacy Recipes created before Dish identity (one known on the owner account) so they open the Dish page.
- **Retire legacy data:** stop writing and serving legacy `recipe_created` activity (migration).
- **Notifications:** push notifications after reliable in-app Tickets.

### Future Roadmap

Everything under **POST-V1**, **LONG TERM** and **DISTANT / DORMANT** below, unchanged: Want to Cook, Recipe Social History, privacy-tier evolution, Collections, Scan/Share Sheet import, insights and Stars, unit conversion, photography, rich previews, Community Discover, personalization, referrals, Run It Back redesign, moderation growth, source taxonomy, Personal Cooking Intelligence and the rest.

## Recent cycles

- **Build 6 preparation (Nov 15).** Build 5 is the owner-accepted internal baseline on the migrated Supabase target. The Build 6 candidate combines the local-first sync work (`f7b0c19`) with the deployed capacity monitor and acknowledgment write reductions (`5391519`, `7cffc50`) ([gates](V1_RELEASE_GATE.md#build-6-internal-candidate--november-15-2026)). Under the accelerated plan, external TestFlight distribution is optional. Build 5 remains supported, and server-side sync write throttling stays disabled.
- **Connected UI Phase 1 (Nov 15, `5862747`; integrated and pushed).** One Dish page with Dish & Ranking and Recipe tabs; Food Bible My Recipes / Saved Recipes (saves are access-rechecked references; copying retired from the new UI); My Kitchen Total Makes. The owner's Xcode test (Nov 16) confirmed tab switching, Link a Recipe, "Not cooked yet" and general navigation and sync. It reported:
  - inconsistent Dish/Recipe photos and relationships
  - an over-interactive Makes line
  - slow, repeated reloads in Food Bible and The Pass
- **MVP stabilization (Nov 16, Claude).** Hosted read-only audit: Recipe ↔ Dish linkage was already correct (every owned Recipe with a Dish identity points to a live cooked Dish; no conflicting legacy links). The defects were client-side:
  - **Header photo flipped between tabs.** The two Dishes whose Recipe has its own photo showed the cook photo on Dish & Ranking and the Recipe photo on Recipe. Food Bible cards and the Dish page also picked different cooks.
  - **Photos re-downloaded on every appearance.** Recipe photos were fetched (one RPC plus one download) each time they appeared, with no cache, and a failed fetch left an empty frame.
  - **Screens cleared and refetched.** Food Bible and The Pass cleared and refetched on every tab switch, return from background and back navigation, and every Storage download bypassed caching.

  The fixes:
  - one stable header photo rule
  - photo fallback to the Dish's own cook photo
  - an account-scoped bounded read cache with request coalescing and change-based invalidation
  - the noninteractive "Cooked N times" beside score and rank

  See [Read caching](STAYGRUBBY_ARCHITECTURE.md#read-caching-mvp-stabilization-november-16-2026).

- **Public MVP onboarding, moderation UI and cache lifecycle (Nov 16, Claude; automated acceptance passed, owner physical acceptance pending).**
  - New-account setup: unique username, explicit Private (default) / Public choice, optional photo; resumable; an existing account is offered it once.
  - Block confirmation and consistent privacy wording.
  - Hard-bounded, account-isolated media cache with expiry, orphan cleanup and cleanup on account switch, sign-out and deletion ([detail](STAYGRUBBY_ARCHITECTURE.md#read-caching-mvp-stabilization-november-16-2026), [UI](UI_ARCHITECTURE.md)).
  - **Codex dependencies:** an optional profile bio field; deploying the integrated [moderation and sharing migrations](PUBLIC_MVP_MODERATION.md#rehearsal-and-deployment), which enable revision-specific Recipe reports and the staffed queue.

- **Grub Rank navigation and connected Recipe sharing (Nov 16, Claude; automated acceptance passed, owner physical acceptance pending).**
  - My Kitchen statistics open Grub Rank in the counted view.
  - The composer recognizes the Dish's Recipe, with explicit consent for private Recipes.
  - Posts link the live Recipe and keep the posted revision.
  - A Recipe can join an existing post.
  - **Codex dependencies:**
    - deploy the verified `owned_recipe_share_option` fallback to `recipes.dish_id`. The existing owned-post lookup resolves the cook server-side, so post cards need no extra private identifier.
    - optionally, a post-card field for the latest accessible revision, so cards can label "updated since posted"

- **MVP UI stabilization and experience milestone (Nov 17, Claude; automated acceptance passed, owner physical acceptance pending).** Client-only; no schema, endpoint or write added.
  - Baseline UI failures root-caused (no app defect, no assertion removed):
    - the Food Bible test expected an empty library from a fixture that seeds an owned Recipe (Food Bible lists every owned Recipe since V2)
    - the Recipe-sharing test tapped the row's centre, which lands on the label; the switch itself is now tapped
  - Two stale Re-rank tests now open Re-rank from the Dish actions menu.
  - The Pass / Dish Details polish:
    - shared loading and error states
    - 86 returns to where the post was opened
    - the duplicate shared date was removed
    - refresh on return only when stale
    - the comments sheet has no keyboard pill over Send, and a failed Hands tap no longer hides the comments
    - `SharedCookLookup` is the single Dish identity integration point
  - Core flow fixes from the UI defect queue:
    - re-ranks say *Re-ranked*
    - the score-unlock milestone follows the cook's own result (Continue)
    - Edit Cook Save and the result Done are full width
    - the share composer copy says Sous Chefs and is shorter
  - Still open: Add Manually nested navigation (needs an embedded `RecipeEditor` mode; coordinate with Codex), low-score result wording (owner decision), result-screen button stack and composer Publish placement (Stage G/C).

- **The Pass redesign — feed, comments and Dish Details (Nov 17, Claude; automated acceptance passed, owner physical acceptance pending).** Client-only; no schema, endpoint or write added.
  - Cards lead with the Dish, photo and score and show the description as an expandable caption.
  - Comments stay in a sheet with Hands.
  - Dish Details shows the facts, Recipe and the creator's other shared cooks of the Dish (Recent / Highest Rated; locked scores never ranked) ([UI](UI_ARCHITECTURE.md)).
  - **Backend dependencies (Codex, Post-launch Priority unless noted):**
    - **Implemented locally in the Supabase/iOS integration milestone:** viewer-safe `dishKey`, exact per-Dish pagination and server Recent/Highest Rated sorting through `SharedCookLookup.swift`. Pending backend deployment; legacy responses omit inferred grouping.
    - a cooked-at snapshot on posts, so Dish Details can show the cooking date instead of the shared date
    - an optional comment Hands field (comment likes do not exist)
  - **Future (post-V1, not designed):** a *Shop This Dish* section (equipment, specialty ingredients, creator recommendations, affiliate links) fits as another Dish Details section. It needs its own privacy, disclosure and legal review before any product data exists.

## VERY NEAR TERM — Social & Discovery

*Classification (Nov 16): onboarding (username + privacy choice), reporting/blocking and moderation are **MVP Required**; discovery for all accounts, Find Sous Chefs, invitations, contact matching and threaded replies are **Post-launch Priority**.*


- Make people discovery available to every account by default with no feature-level off switch. Keep Public/Private choices and existing content authorization independent of discovery. Define the minimum profile identity discoverable under each choice before rolling out changes to existing privacy settings.
- Require a unique username and explicit privacy selection in new-account social onboarding. Photo and bio are optional. Legacy accounts with incomplete profiles get a resumable completion flow, with their accounts, existing choices and private cooking libraries preserved.
- Improve **Find Sous Chefs** with better bounded search using public profile fields. Add personalized invitation links and native sharing. Investigate optional, consent-based contact matching before collecting anything. Plan share/invitation achievements around genuinely new qualified signups and keep participation voluntary. Avoid rewards for raw sending volume.
- Carry forward follow-request UX improvements for the existing mutual Sous Chef relationship, threaded comment replies, reporting/blocking and moderation. Public rollout still requires the privacy and moderation gates below.

### Backend dependencies for the connected experience

| Area | Reuse now | Required before the dependent feature ships |
| --- | --- | --- |
| Dish and Recipe navigation | Owner-scoped Dish identity, `recipes.dish_id`, Recipe revisions, cook-post pointers, authorized profile/Recipe routes and existing owner recipe indexes | Shared UI routes and a safe unavailable state. Keep post-pinned revisions distinct from the current Recipe. |
| Saved Recipes and Make This | Private, idempotent `recipe_tickets` bookmark relation and existing save/remove/list actions. The Recipe reader checks current access. `recipe_cooks` already records the exact revision, source creator and accepted cook. | Check list paging and behavior after unshare, blocking or deletion before resurfacing legacy bookmarks. Keep My Recipes ownership separate. Retire the foreign-copy action in the new UI and make a compatibility decision for still-supported clients before changing its RPC. |
| Makes and Saves | Accepted completed cook provenance and unique account/Recipe bookmark pairs. Recipe and cook audiences and block rules already exist. | Define eligible completed cooks, save attribution and profile totals. Add narrowly scoped aggregate reads only when the surfaces need them. Private raw rows, identities, snapshots and counts of hidden events are excluded from public responses. No speculative counters or event stream. |
| Discovery and profile completion | Existing profiles, case-insensitive unique handles, handle reservation, avatar Storage, bounded username search, blocks, mutual relationship/request state and owner identity RPC. | Privacy-aware search projections separate from today's `discoverable` opt-in, plus explicit privacy selection, completion handling and optional bio. Preserve legacy private access during rollout. No blind discoverability backfill. |
| Invites and optional contact matching | Native share sheets, profile/deep-link routes and optional parsed `ref` parameter. Existing shared-cook invitations and Tickets are in-app flows. | Issue and redeem safe attribution once on genuine signup, with expiry, deduplication and abuse limits. Explicit consent, purpose and retention are prerequisites for optional Contacts exploration. No address book collection or new identity matching store in this phase. |
| Social safety | Existing request transitions, block enforcement, flat comments, report APIs and moderation states. | Thread parentage and visibility checks for replies, followed by focused authorization, reporting and staffed moderation review before public launch. |

## Existing Dish and UI foundations

**Foundation sequence recorded November 8, 2026.** The current priorities above extend the approved Dish identity and its existing UI foundation. The unified Dish foundation now comes first. Specification: [FOOD_ARCHITECTURE.md](FOOD_ARCHITECTURE.md). Plan, component candidates and the queued defect list: [UI_ARCHITECTURE.md](UI_ARCHITECTURE.md#9-system-wide-ui-overhaul--plan). The table preserves the original stage labels and their scope.

| Order | Stage | Scope | V1 |
| --- | --- | --- | --- |
| done | A — Foundations | **Implemented Nov 7 — owner accepted.** Shared photo/score/state/section/toolbar foundations, spacing tokens | — |
| done | B — Pickers / Search / Filtering | **Implemented Nov 7–8 — owner physical acceptance pending.** Direct Grub Rank chips, separate Sort, the projection toggle, Photo filter removed, Dietary groups | — |
| 0 | Integration + data prerequisite | **Integration done Nov 8** (`main` fast-forwarded to `7630e96`; push through GitHub Desktop pending). **Lifecycle migration deployed Nov 8** (fingerprints unchanged). The owner integrates `agent/claude` (contains Codex `a6de6b8` plus this checkpoint) into `main`. Authorize and deploy `20261108171024_recipe_cook_lifecycle` with fingerprints (release-gate item). **In parallel (other agent lane):** the score/order investigation below | Required |
| 1 | **D1 — Unified Dish Foundation** | **Implemented Nov 8; `dish_recipe_links` deployed Nov 8; owner physical acceptance pending.** Read model and association rules are app-side types; D2 wires them into Dish Detail. Data, model and terminology; no Dish Detail redesign. (a) `dish_recipe_links` additive migration (several Recipes per Dish, one Main, legacy `dish_recipes` read or copied with fingerprints, RLS, owner RPCs, compare-and-swap); needs Supabase authorization. (b) `Food` read model: related-Recipe union, deterministic Main default, Recipe-only Dishes. (c) Association policy as testable logic: automatic for explicit provenance, suggestions for loose matches. (d) `CookName` resolver plus a Rename path that leaves IDs, strengths and evidence unchanged (tests). (e) **Terminology rebrand across existing screens:** Version Title → Cook Name, New Version → Cook Again, All Versions → All Cooks (labels only; raw preference values kept), Version History → Recipe History, "N versions" → "N cooks", accessibility. (f) Confirm the Recipe content contract accepts the `dietary` key | Required |
| 2 | **D2 — Dish Detail** | **Implemented Nov 8; `food_bible_dish_resolution` deployed Nov 8; owner physical acceptance pending** ([§8.1](FOOD_ARCHITECTURE.md#81-dish-detail-and-the-recipe-face-current)). One Dish Detail from Grub Rank and Food Bible: `DishIdentityHeader`, `DishCooksSection` (Rename, Cook Again), `DishRecipesSection` (Main Recipe, Set as Main, Recipe used vs Linked), `DishActions` shell; Recipe-only "not cooked yet" state; Food Bible Cooked / Not cooked yet toggle; tagged collaborators on detail; owner validation of All Cooks wording in context | Required |
| 2b | **D3 — One Dish identity (owner decision)** | **Implemented and deployed Nov 8; owner physical acceptance pending.** Dish and Recipe become two views of one Dish (`recipes.dish_id`); Food Bible lists Dishes with Recipe content; Dish Detail "View Recipe"; no Rename, Link a Dish or Main Recipe UI; The Pass cook activity only ([FOOD_ARCHITECTURE §3](FOOD_ARCHITECTURE.md#3-one-dish-identity-owner-decision-11)) | Required |
| 3 | **F — Flows and editors** | **Implemented Nov 8–9; migrations deployed; owner physical acceptance pending.** `AddRecipeFlow` (New Dish + Recipe → Rank Now / Not Now; Add to a Ranked Dish; Use a Food Bible Recipe), post-ranking "Add a Recipe?", Cook Again start (Cook from the Recipe / Without), cook editor grouped This Dish / This cook, Recipe Diet (editor, reader, Food Bible Diet filter, cook prefill), search clear button, feature flag foundation. Nothing deferred within F | Required |
| 3b | **Filters + one-Dish audit (Nov 9)** | **Implemented; owner physical acceptance pending.** Grub Rank filters Course · Cuisine; Food Bible on the same chip/sheet components; one clear X for search + filters; Dish combine for the "Recipe Dish A + ranked Dish B" case ([§3.4](FOOD_ARCHITECTURE.md#34-one-canonical-dish-universe--combining-identities-owner-decision-12)); Recipe Diet suggested from ingredients at import | Required |
| 3b | F — Recipe Diet (as written) | Author-selected Recipe Diet field and Food Bible Dietary (Diet) filter | Desirable, deferrable |
| P0 | **Incident recovery — Nov 11** | **Repaired, deployed and owner-accepted (Nov 11: existing phone, fresh install, second phone). Open: Supabase reclaiming ~1.6 GB System disk; client fixes ship in the next TestFlight build.** Retry storm from `40001` business errors put the database in read-only mode ([record](supabase/README.md#p0-incident-retry-storm-read-only-database--november-11-2026)). `PT409` conflicts, schema guard, classified sign-in errors, revision-aware share retry, sharp Recipe fallback photos, database health check and the release smoke gate. Follow-ups, required before V1: a dedicated non-production Supabase project for live integration tests, an automated daily health check with an alert, and a Pro/disk capacity decision before public launch | Required |
| P1 | **iOS sync efficiency — Nov 15** | **Implemented; automated acceptance passed; owner physical acceptance pending.** Cloud-revision probe skips unchanged library downloads, coalesced foreground/connectivity triggers, settled photo pass, ambiguous-upload reconciliation, bounded jittered retries, recoverable server cooldowns, lighter The Pass polling ([sync](SYNC_ARCHITECTURE.md#current--local-first-sync-efficiency-november-15-2026)). **Backend dependency (Codex):** any server write throttle must use the documented cooldown contract and stay off until this client is the minimum supported build | Required |
| 4 | **C — Sharing** | **Nov 11 groundwork done:** "Grub List" renamed **The Pass**; The Pass is posted cooks only (client no longer models Recipe activity); cook photos post by default and render sharply. **Deferred until the Supabase infrastructure hold lifts:** retire legacy `recipe_created` items from `activity_page` and stop writing `recipe_activity` (migration). The November 11 Privacy Policy is already live and matches the app copy. Remaining: Post to The Pass vs external Share; one Share action (image + short `#stayGRUBBY` message + exact link) built into `DishActions`; composer simplification | Required |
| 5 | **E — Social / Kitchens** | The Pass, Tickets relocated to The Pass, My Kitchen stats (Dishes Ranked → Grub Rank · Recipes → Food Bible · Sous Chefs), Sous Chef Kitchen, Requests; tagged collaborators on cards; cook names on cards per snapshot rules | Required |
| 6 | **G — Copy / Celebrations / Final consolidation** | Copy purge, ranking result and celebrations (after the investigation concludes), accessibility/consistency | Required |

**Operational gate (November 14).** [Build 1.0 (5)](supabase/CLEAN_MIGRATION_PHASE_2A.md#endpoint-cutover-and-rollback) targets the migrated project and is available to internal Alpha Testers only. The owner waived the two live signed Edge Function probes for this rollout. The owner verified the in-place update, account, library, photos and sync. The target [automatic capacity monitor](supabase/README.md#automatic-target-monitoring) runs on the migrated project. The repeat-acknowledgment write reduction is live. Build 5 [Apple-only new-account signup](supabase/CLEAN_MIGRATION_PHASE_2A.md#build-5-apple-signup-check) is enabled and has produced new linked accounts. The [client sync changes](SYNC_ARCHITECTURE.md#current--local-first-sync-efficiency-november-15-2026) are included in the Build 6 candidate. The server remains compatible with Build 5. Wider distribution requires separate approval.

Why this order:

- D1 contains the only schema change. It also contains the copy rebrand, so every later stage is built on final words and data.
- D2 establishes the single screen that C, E and F attach to.
- F comes before C because the new-cook flow and the result screen that sharing starts from are reshaped in F.
- C and E are presentation work on top of that foundation.

D1 (a) and (d)/(e) touch different files and can be split across the two agent lanes. Avoid running D2 and F in parallel, because both edit Dish Detail and the cooking forms.

**Required pre-V1 investigation — Grub Rank score/order semantic consistency.** The displayed score is banded by reaction, while order follows Bradley–Terry strength, so a lower-ranked entry can show a higher score (observed: #9 · 2.6 above #11 · 7.6).

- Investigate how to keep score and order understandable while preserving all evidence, history, re-rank behavior, calibration and uncertainty.
- Investigation comes first; any math or calibration change needs the owner to explicitly reopen ranking.
- It can start now in parallel. It must conclude before D2 settles how Dish Detail presents score and rank, and before G finalizes results.

[Mechanism](STAYGRUBBY_ARCHITECTURE.md#ranking--protected).

**Unified food architecture — final, November 8, 2026 (documentation only).** The owner decided:

- Dish is the user-facing identity.
- A Dish can have several Recipes, with a selectable Main Recipe.
- Food Bible is the Recipe lens.
- Recipe revisions are Recipe History.
- Cooking Attempts can be renamed, with a "Version N" fallback.
- All Cooks and Cook Again are the new labels.
- Explicit provenance associates automatically; loose matches are suggested.
- As written vs as made applies to Diet as well as Contains.

The checkpoint `6214900` was reconciled with Codex `a6de6b8` (exact-revision provenance, link lifecycle, dated reactions — all preserved). Saved Recipes and attributed Make This move into the connected experience above. Want to Cook, Collections, contextual rank boards, Scan Recipe and Share Sheet import remain **post-V1**.

Each stage: implement → focused verification → owner acceptance where needed → update canonical docs as decisions become durable.

## THEN — V1 Release Gate

Moderation (UGC filtering, report → review → resolution, block enforcement), privacy/security review, account deletion and UGC cleanup review, Terms, Community Guidelines, Privacy Policy, Recipe/allergen/serving disclaimers, support/contact, Apple App Privacy, age rating, App Review access/sign-in, production configuration, advisories (leaked-password warning, production `development-test-session` function), incompatible-build retirement. Checklist: [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md). Privacy/moderation dependencies may move earlier.

Data integrity before V1 includes authorizing and deploying the locally verified Recipe cook lifecycle migration, confirming hosted restore and current-link retirement, and carrying forward the dated private reaction record. Personal Cooking Intelligence remains post-V1. [Data foundation follow-up](V1_DATA_FOUNDATION_AUDIT.md#november-8-follow-up).

## THEN — Release Candidate

Release candidate build (external TestFlight optional; owner physical testing through Xcode), one proportionate broader regression and Release verification, physical acceptance (including two-device Universal Links and real-device photos/auth/sync/sharing). Archive, build-number change, upload and distribution each need explicit owner approval.

## THEN — App Store V1

Metadata, screenshots, reviewer instructions, switch `Website/distribution.json` to the App Store listing and redeploy the full Worker, submission with explicit owner approval.

**V1 scope:** reliable cooking records, Grub Rank, Food Bible/Recipe workflows, My Kitchen, Sous Chefs, chronological The Pass, sharing, authentication/sync, privacy/account controls, moderation/compliance and polished dependable UX. **Not V1:** Discover, Personal Cooking Intelligence, Want to Cook, Collections, advanced recommendations.

## POST-V1 — near / medium term (Future Roadmap unless listed as Post-launch Priority above; order not final)

- **Want to Cook** — cooking intention distinct from cooking; bookmark + attributed cooking workflow. Targets a Dish (cooked or Recipe-only) or a Recipe — the first candidate to justify a stored Food identity. [Concept](PERSONAL_COOKING_INTELLIGENCE.md#5-approved-future-concepts-not-implemented), [fit](FOOD_ARCHITECTURE.md#10-future-compatibility-post-v1-nothing-here-is-authorized)
- **Recipe Social History** — an authorized detailed activity timeline beyond the near-term aggregate Makes and Saves.
- **Privacy/access-control evolution** — account maximum audience Public / Sous Chefs Only / Private with per-item visibility bounded by it; new items private by default
- **Collections / Cooking Series** (name not final) — Collection ↔ Dish many-to-many thematic context (members may be Recipe-only Dishes), distinct from a Dish's cooks; contextual rank boards are projections of the one global ranking
- **Scan Recipe** and **Share Sheet import** — additional Import Recipe sources feeding the same Gemini → review → Save pipeline
- **Cooking insights** and private **Stars ⭐** achievements/challenges
- **Recipe unit conversion** when reliable (implementation retained, controls hidden)
- **Photography** — crop/reposition, advanced gallery, editing
- **Rich external previews** — explicit share-safe preview artifact; never public general buckets; documented cache/revocation limits
- **Community Discover** as a major update (distinct Dishes & Rankings / Recipes areas). Basic people discovery is near-term.
- **Early personalization** — interpretable, cost-efficient
- **Push notifications** (APNs) after reliable in-app Tickets
- **Referrals** — counts only a genuinely new attributed signup; rewards undecided; core functionality never requires recruiting
- **Run It Back redesign** (entry points hidden, provenance preserved)
- **Moderation/administration growth** — roles separate from entitlements; broader dashboards only when scale requires
- **Source taxonomy** — My Own, Online, Cookbook, Restaurant, Friend / Family, Sous Chef, Other; optional metadata later
- Dedicated Recipe-only posts, feed filters, automatic Recipe-update posts (deferred)

## LONG TERM

Personal Flavor Profiles · Cooking Ability / Experience Profiles · advanced Personal Cooking Intelligence · sophisticated recommendations · social/group intelligence and shared cooking experiences · creator/commerce exploration (possible following model, partnerships, affiliate commerce; no conventional display ads; personal ranking stays free) · other justified intelligence features. All private by default; no new AI/paid infrastructure is authorized now. [Direction](PERSONAL_COOKING_INTELLIGENCE.md).

## DISTANT / DORMANT

Intelligent meal planning — do not prioritize, design or raise it until the owner explicitly revisits it.

## EXPLICITLY REJECTED / EXCLUDED

Do not resurrect without an explicit owner decision:

- Cookbook barcode / ISBN indexing or a cookbook search database
- Apple Foundation Models as a Recipe provider (not compiled in V1; on-device quality was insufficient)
- Lexical source-vocabulary guards, token-overlap checks, source reconstruction, method-to-ingredient recovery, a second AI judge or culinary fact-checking heuristics in Recipe Creator
- A StayGrubby daily AI allowance or date/30-day expiry
- Manual ranking order
- Speculative AI/data infrastructure or event collection without a current feature
- Renaming My Kitchen (e.g. "Knife Roll")
- Making general photo buckets public for link previews
- Algorithmic ordering of the current The Pass

Hidden but retained (not rejected): Custom Tags, Run It Back entry points, unit-conversion controls, dormant Want to Cook storage.

## Evidence and document ownership

Future planning lives **here** only. Historical stage plans and reviews ([NEXT_RELEASE_SPEC.md](NEXT_RELEASE_SPEC.md), stage reviews, [V1_PRODUCT_CLOSEOUT_REVIEW.md](V1_PRODUCT_CLOSEOUT_REVIEW.md), [V1_RANKING_INTEGRITY_REVIEW.md](V1_RANKING_INTEGRITY_REVIEW.md), [NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md](NEXT_TESTFLIGHT_IMPROVEMENTS_REVIEW.md) and earlier milestone reviews) retain dated decisions, commands, tests and deployments; their pending gates and sequences are not current instructions. Owner acceptance is never inferred from automated tests.

### Required first App Store release milestone

**S1 MVP stabilization (Nov 2026) → S2 public-release requirements (Dec 2026) → S3 release candidate and App Store submission (stretch late Dec 2026, target Jan 2027) → Post-launch Priority → Future Roadmap.** App Store MVP is a concrete milestone that optional ideas must not keep postponing. The earlier Build 4 → D1 → D2 → F → C → E → G sequence is complete through F and filters; C and G continue only as MVP Required finishing work on existing surfaces. No submission or distribution is authorized by a development checkpoint.
