# StayGrubby next release — UI/UX overhaul and product refinement

Canonical approved release specification, November 3, 2026. [Architecture](STAYGRUBBY_ARCHITECTURE.md) records implemented behavior; [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md) records sequencing. Baseline `b9871df88930699f22ed80b2c586996e4775ebd8` is sufficiently owner accepted to continue. This is a staged release, not permission to implement every screen in Stage 1 or distribute a build.

## Product direction

Editorial food photography + contemporary restaurant identity + polished native iOS interaction. **Content first. Actions second. Explanation only when necessary.** Reuse the official wordmark/assets, cream `#FAF3EC`, charcoal `#1F1F1F`, canonical logo red `#F10607` (supersedes the conceptual `#FF2D1F`), adaptive control tokens and existing semantic numerical scores. Preserve upright portrait, Dynamic Type, VoiceOver, Reduce Motion, readable light/dark controls and normally 44-point touch targets.

Prefer concise native menus/sheets and an identifiable compact primary-screen brand header; contextual native navigation remains on secondary screens. Remove explanations only when actions/content communicate the same meaning. Preserve safety/privacy/permission disclosures, destructive confirmations, recovery instructions and actionable AI uncertainty. No global string deletion, generic gradients, glass-heavy styling, glowing controls, excessive red/emoji decoration or recreated logo typography.

## Approved release scope — staged, not all implemented now

| Area | Required later refinement |
| --- | --- |
| Shared UI | Typography/spacing/surfaces/buttons/header/image/corner consistency; concise copy; secondary-screen audit; dark/accessibility/small-screen review |
| Cooking | New Dish redesign; editable Public Description + Private Notes; compact metadata; improved Tag a Sous Chef |
| Kitchen/profiles | My Kitchen redesign; unified own/other profile design; compact Signature Dishes; discovery/send-to-friend refinement |
| Social | Grub List hierarchy; modern Comments; Order Up! visual treatment; Recipe and Ranking/Dish sharing corrections |
| Food Bible | Filtering/presentation; Recipe Detail action consolidation and copy cleanup, preserving accepted identities/revisions/scaling/Creator |
| Photography | Multiple photos per actual cook/Dish version, cover/order/add/remove controls; preserve history/private media/restore |

Evaluate native context menus/long-press and suitable haptics only where they remove clutter. Basic native crop/reposition may be evaluated in the photography stage; it is optional and not Stage 1. Do not add bespoke gestures or an image-editing subsystem without need.

Stage 1 establishes the reusable UI/header and Dish-text/photo data foundations; its contained migration is deployed and its automated acceptance is recorded in [the Stage 1 review](NEXT_RELEASE_STAGE_1_REVIEW.md). Stage 2 adopts them across primary identity, cooking entry/metadata/tagging, Kitchen/profiles/Signature Dishes, Grub List and Grub Rank surrounding UI; see [the Stage 2 review](NEXT_RELEASE_STAGE_2_REVIEW.md). Dedicated Social + Sharing, Food Bible and photography work remain later stages. **Do not start Stage 3 automatically.**

## Owner findings carried into Social + Sharing — mandatory

- My Kitchen/profile sharing physically works.
- Recipe sharing is still broken: the owner observes browser behavior resembling a file download instead of a useful destination/fallback.
- Ranking/Dish sharing does not produce a useful copy/share result in the observed flow.
- Two-device social acceptance remains pending, but does not block this cycle.

These findings supersede any implication that prior origin/Simulator checks establish complete physical sharing acceptance. Stage 1 preserves the reports; it does not investigate/fix them unless its own data change causes a direct integration regression. The Social + Sharing stage must trace actual generated payloads/URLs/native sheets, browser MIME/disposition behavior and recipient app/web destinations, and retest on physical devices.

## Stage 1 data contract

Dish gains nullable `publicDescription` (2,000 Unicode scalars) and `privateNotes` (8,000). Existing `CookingAttempt.notes` remain private **per cook**; social `post_description` and Recipe descriptions stay separately authored. No Dish description existed previously. No text is copied, reclassified, concatenated, inferred or erased by migration. A small owner editor exposes new Dish fields without undertaking the New Dish redesign. Explicit manual post composition may prefill only Public Description; it remains reviewable and old posts are not rewritten. Automatic publication behavior is unchanged.

Private Notes are included only in owner-authorized local/private structured sync. Existing Dish owner RLS and session-derived APIs enforce access; social/profile/Recipe/recreation/share-card/link projections never select them. Saving text does not change ranking evidence, cook notes or Recipe content. Older clients omitting new keys preserve server values; explicit null deliberately clears a field.

Photography reuses **CookingAttempt → ordered CookingMedia[]**, immutable UUID-backed display/thumbnail files and existing private manifest/transport/cleanup. **Six photos per actual cook/version** is the bound, not six across a Dish's entire history: later cooks must not displace older photos. At existing 1,200-pixel display/360-pixel thumbnail preparation and 2 MiB per-variant validation this bounds one collection’s stored JPEG variants to at most 24 MiB; normal optimized output is usually smaller. Transfers stay sequential/bounded; no eager gallery download UI or unlimited new upload mode.

Each version's first ordered image is its cover; sort order, creation time and UUID resolve ties deterministically. Dish gallery architecture groups retained photos by stable version identity, newest sequence first. Existing ranking/social/export consumers continue using their actual cook's cover. No global Dish-cover identity moves photos between cooks or rewrites old snapshots. Legacy single photos retain IDs/order/files and need no migration or user action.

Domain operations append, reorder/set cover and remove one photo through existing atomic journal/tombstone transactions. Existing single-photo editor replaces/removes only the cover, preserving secondary images. Duplicate/retired IDs and preexisting file paths cannot be overwritten. New change envelopes advertise photo-collection support; old partial replace-all edits against multi-photo cooks are rejected safely, while intentional whole-cook deletion remains supported. No new conflict-merging behavior, bucket or photo byte protocol.

## Frozen systems and deferred features

Keep Bradley–Terry, accepted calibration/unlock/evidence, Dish/cook/item semantics, independent Recipes/revision history/cook snapshots, Run It Back ownership, Gemini-first Creator, Apple auth, relationships and Hands/Comments unchanged. No new provider calls/billing, secrets, resets, destructive real-account operations or distribution.

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
