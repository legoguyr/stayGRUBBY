# StayGrubby next release — UI/UX overhaul and product refinement

Canonical approved release specification, updated November 5, 2026. [Architecture](STAYGRUBBY_ARCHITECTURE.md) records implemented behavior; [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) records sequencing. Baseline `b9871df88930699f22ed80b2c586996e4775ebd8` is sufficiently owner accepted to continue. This is a staged release, not permission to implement every screen in Stage 1 or distribute a build.

## V1 Product Closeout supersession

Owner physical feedback supersedes Stage 5's large Kitchen Recipes preview/See All with a compact authorized Recipe-sheet control and restores Dishes Ranked emphasis. Meaningful version labels only; Recipe and Dish details share compact native Share/overflow treatment. New owner Recipes default to Sous Chefs with an editable compact toggle, never globally Public; existing private Recipes and explicit private copies remain private. Shared new Recipe creation/first sharing may produce one distinct authorized Grub List activity without pretending it is a cook/score or spamming revisions. Foreign creator credit is retained with exact cook provenance. [Current architecture](STAYGRUBBY_ARCHITECTURE.md#food-bible-and-recipes--architecture-v2) and [closeout evidence](V1_PRODUCT_CLOSEOUT_REVIEW.md) govern. Product Closeout → Release Gate → Release Candidate → App Store V1; no new normal feature stage.

## Current V1 sequencing supersession — Stage 5

**Stages 1–4 complete → Stage 5 Final Product Polish & V1 Readiness → Pre-App-Store Trust/Safety/Privacy/Compliance Gate → Release Candidate → APP STORE V1.** This replaces Photography as a pre-V1 stage and the earlier Stage 6 plan. Stage 5 is the final normal product-development cycle. Existing upload/multi-photo/ownership/sync/restore are sufficient for V1; crop/reposition/advanced gallery/editing are post-V1. Unit conversion is hidden, retained for post-V1; serving scaling stays. Kitchen owned-Recipe previews use existing cards and current server authorization. No full future Saved/private-public/admin/referral/follower system, provider tuning or distribution. [Current evidence](NEXT_RELEASE_STAGE_5_REVIEW.md), [release checklist](V1_RELEASE_GATE.md).

## Product direction

Editorial food photography + contemporary restaurant identity + polished native iOS interaction. **Content first. Actions second. Explanation only when necessary.** Reuse the official wordmark/assets, cream `#FAF3EC`, charcoal `#1F1F1F`, canonical logo red `#F10607` (supersedes the conceptual `#FF2D1F`), adaptive control tokens and existing semantic numerical scores. Preserve upright portrait, Dynamic Type, VoiceOver, Reduce Motion, readable light/dark controls and normally 44-point touch targets.

Prefer compact native controls over full-width UI when full-width emphasis is unnecessary. Prefer concise native menus/sheets and an identifiable compact primary-screen brand header; contextual native navigation remains on secondary screens. Remove explanations only when actions/content communicate the same meaning. Preserve safety/privacy/permission disclosures, destructive confirmations, recovery instructions and actionable AI uncertainty. No global string deletion, generic gradients, glass-heavy styling, glowing controls, excessive red/emoji decoration or recreated logo typography.

## Approved release scope — staged, not all implemented now

| Area | Required later refinement |
| --- | --- |
| Shared UI | Typography/spacing/surfaces/buttons/header/image/corner consistency; concise copy; secondary-screen audit; dark/accessibility/small-screen review |
| Cooking | New Dish redesign; editable Public Description + Private Notes; compact metadata; improved Tag a Sous Chef |
| Kitchen/profiles | My Kitchen redesign; unified own/other profile design; compact Signature Dishes; discovery/send-to-friend refinement |
| Social | Grub List hierarchy; modern Comments; Order Up! visual treatment; Recipe and Ranking/Dish sharing corrections |
| Food Bible | Filtering/presentation; Recipe Detail action consolidation and copy cleanup, preserving accepted identities/revisions/scaling/Creator |
| Photography | Existing working foundation is the V1 freeze; advanced crop/gallery/editing are post-V1 |

Evaluate native context menus/long-press and suitable haptics only where they remove clutter. Crop/reposition and advanced photography are explicitly post-V1. Do not add bespoke gestures or an image-editing subsystem without need.

Stage 1 establishes the reusable UI/header and Dish-text/photo data foundations; its contained migration is deployed and its automated acceptance is recorded in [the Stage 1 review](NEXT_RELEASE_STAGE_1_REVIEW.md). Stage 2 adopts them across primary identity, cooking entry/metadata/tagging, Kitchen/profiles/Signature Dishes, Grub List and Grub Rank surrounding UI; see [the Stage 2 review](NEXT_RELEASE_STAGE_2_REVIEW.md). The Stage 2 owner-correction follow-up consolidates Details, compacts entry/Kitchen/share controls, aligns Signature scores, adds authorized feed metadata/stable ages and read-only Grub Rank sorting, and verifies native tab clearance. Custom Tags are hidden from normal UI/search and Halal from selection; historical data/backend compatibility remain. Following/Followers require a future product/model decision, not invented counts. Stage 3 handles Social + Sharing; Stage 4 consolidates Food Bible/Recipes, with advanced photography now post-V1. Stage 2 is now OWNER ACCEPTED (November 4). The explicitly authorized Stage 3 social/sharing implementation and its remaining physical gate are recorded in [Stage 3 evidence](NEXT_RELEASE_STAGE_3_REVIEW.md). Stages 1–4 are complete; Stage 5 final polish is now explicitly authorized.

## Stage 3 social + sharing follow-through

Stage 2 was physically accepted; its duplicate notes/Details affordance corrections are contained in Stage 3. The Recipe-browser failure was traced to actual hosted assets-only drift, repaired and checked with real HTTP; local URL tests alone are insufficient. Dish/Signature exports now add useful copyable text alongside the accepted image, without private URLs or score-lock changes. Native person identity/selection, Comments composition, Sous Chef discovery, directed delivery and Order Up! remain one mutual-friend product. See [Stage 3 evidence](NEXT_RELEASE_STAGE_3_REVIEW.md) for exact deployment/test/data results and physical limitations.

Stage 4 addresses Recipe → specific Dish/cook/version/ranked-entry association through the same canonical selector, plus Food Bible filters consistent with Grub Rank using Recipe metadata. Stage 3 did not implement those; Stage 4 now supplies Recipe controls. Gallery/crop, followers, APNs, Stars/Discover, Creator changes and distribution remain outside Stage 4.

## Stage 1 data contract

Dish gains nullable `publicDescription` (2,000 Unicode scalars) and `privateNotes` (8,000). Existing `CookingAttempt.notes` remain private **per cook**; social `post_description` and Recipe descriptions stay separately authored. No Dish description existed previously. No text is copied, reclassified, concatenated, inferred or erased by migration. A small owner editor exposes new Dish fields without undertaking the New Dish redesign. Explicit manual post composition may prefill only Public Description; it remains reviewable and old posts are not rewritten. Automatic publication behavior is unchanged.

Private Notes are included only in owner-authorized local/private structured sync. Existing Dish owner RLS and session-derived APIs enforce access; social/profile/Recipe/recreation/share-card/link projections never select them. Saving text does not change ranking evidence, cook notes or Recipe content. Older clients omitting new keys preserve server values; explicit null deliberately clears a field.

Photography reuses **CookingAttempt → ordered CookingMedia[]**, immutable UUID-backed display/thumbnail files and existing private manifest/transport/cleanup. **Six photos per actual cook/version** is the bound, not six across a Dish's entire history: later cooks must not displace older photos. At existing 1,200-pixel display/360-pixel thumbnail preparation and 2 MiB per-variant validation this bounds one collection’s stored JPEG variants to at most 24 MiB; normal optimized output is usually smaller. Transfers stay sequential/bounded; no eager gallery download UI or unlimited new upload mode.

Each version's first ordered image is its cover; sort order, creation time and UUID resolve ties deterministically. Dish gallery architecture groups retained photos by stable version identity, newest sequence first. Existing ranking/social/export consumers continue using their actual cook's cover. No global Dish-cover identity moves photos between cooks or rewrites old snapshots. Legacy single photos retain IDs/order/files and need no migration or user action.

Domain operations append, reorder/set cover and remove one photo through existing atomic journal/tombstone transactions. Existing single-photo editor replaces/removes only the cover, preserving secondary images. Duplicate/retired IDs and preexisting file paths cannot be overwritten. New change envelopes advertise photo-collection support; old partial replace-all edits against multi-photo cooks are rejected safely, while intentional whole-cook deletion remains supported. No new conflict-merging behavior, bucket or photo byte protocol.

## Frozen systems and deferred features

Keep Bradley–Terry, accepted calibration/unlock/evidence, Dish/cook/item semantics, independent Recipes/revision history/cook snapshots, Run It Back ownership, Gemini-first Creator, Apple auth, relationships and Hands/Comments semantics unchanged. No new provider calls/billing, secrets, resets, destructive real-account operations or distribution.

Run It Back community averages, Apple Intelligence creation, advanced Recipe variations, broader discovery/statistics/creator tooling/monetization, Stars and existing future-roadmap features remain deferred unless separately approved.

## Formal Pre-App-Store Trust & Safety / Compliance gate

After public-beta learning and **before App Store release**, complete a separately scoped gate:

- objectionable-UGC filtering and moderation coverage;
- complete report → review → resolution workflow and operations;
- block/privacy enforcement audit;
- account deletion and associated UGC cleanup audit;
- published support/contact surfaces;
- privacy/data-flow audit and App Store privacy disclosures;
- Community Guidelines/Terms integration;
- App Review access strategy;
- Social Media and age-rating submission configuration.

Existing baseline beta/release safeguards still apply. Recording this future gate implements none of its compliance work, changes no App Store Connect settings and authorizes no upload.

## Stage 4 — current authorized consolidation, November 4

Reuse accepted browse/version selectors and native actions. Implement real Recipe metadata filters, directional browsing, explicit Recipe↔cook/version association with legacy Dish relationships preserved, deterministic Recipe-owned-photo→explicit linked cook→branded fallback, reader-only US/Metric conversion composed with servings, compact Recipe actions and focused copy/source consistency. No inference/backfill of historical Recipe usage, no photo ownership transfer, no Creator/ranking changes. Run It Back is presentation-hidden with capability/data retained. Future Saved Recipes/bookmarks remain distinct from Save as New; full privacy/admin/invitations/monetization remain roadmap only. Required release sequence and scope control are canonical in the [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md#required-first-app-store-release-milestone).


### Stage 4 owner corrections — November 4

Rank My Version retains existing pinned Recipe provenance; Link a Dish uses one searchable photographic list of actual versions. Creator attribution moves up, allergens down, repeated estimate helper paragraphs are removed with compact safety access retained. Deterministic reader conversion gains curated ingredient-specific densities and unambiguous measured-line compatibility. Canonical architecture owns the detailed boundaries. No new schema, provider, Stage 5 or distribution work; Saved Recipes and Recipe Social History remain explicitly post-App-Store V1.
