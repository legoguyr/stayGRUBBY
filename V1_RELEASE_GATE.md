# StayGrubby V1 Release Gate

Canonical next-cycle checklist — November 5, 2026. Stage 5 plus its focused owner-feedback Product Closeout is the final normal product work. This gate authorizes no submission, upload, credential change, paid service or destructive real-account test. Record evidence/owner decisions here during the separately requested gate; unchecked items are not compliance claims.

## Hard V1 blockers / required gate evidence

- [ ] UGC filtering appropriate to the product; working Report/Block entry points and enforcement across posts, comments, Recipes (including the new creation activity), profiles and shared destinations. Review account-level Recipe activity reporting/hidden-profile enforcement and whether object-level Recipe moderation is required; the activity does not reuse cooking-post moderation IDs.
- [ ] A complete report → review → resolution capability and staffed moderation process, escalation/contact and auditable outcomes. Broad admin dashboards are not required merely to satisfy this operational need.
- [ ] Focused privacy/security review of current audience rules, RLS/private Storage, account isolation, revocation, shared links and data flows. No private activity may leak through profiles/counts.
- [ ] Account deletion and associated UGC/media cleanup review using isolated/test identities. Preserve valid synchronization history semantics; do not require deleting Guy's real account. Real Apple revocation testing is intentionally deferred and needs a separately authorized disposable account/device procedure where necessary.
- [ ] Publish/approve Terms of Use and Community Guidelines. Neither dedicated document is currently supplied by the existing website builder; this is genuine release-gate work.
- [ ] Appropriate Recipe/allergen/serving/quantity-estimate disclaimers and actionable safety coverage. Do not put non-privacy limitations solely in the Privacy Policy or repeat them throughout readers.
- [ ] Publish the updated bundled Privacy Policy describing new-Recipe Sous-Chef-default sharing and distinct Recipe activity through the canonical router-preserving website deployment; verify exact hosted policy and live sharing routes before distributing the updated build. No policy publication is claimed by this product closeout.
- [ ] Confirm current Privacy Policy, external-AI consent and actual social/cloud/photo/data processing; update App Store privacy disclosures accordingly.
- [ ] Verify public Support/contact and policy destinations, contact ownership and response process. Stage 5 supplies Settings access, not an operations/compliance certification.
- [ ] Complete age-rating/social-media/UGC considerations using current platform requirements during the gate.
- [ ] Verify Sign in with Apple, account readiness/sign-out, offline ready-account behavior and App Review access strategy. Automated fixtures cannot establish physical Apple authorization.
- [ ] Disposition existing security advisories, including the leaked-password linter warning against the intended Apple-only Auth configuration. Do not change Auth settings merely to suppress a warning.
- [ ] Production configuration/signing/entitlements/portrait identity, client-safe configuration, secrets/local-artifact scan and no Release development bypass.
- [ ] One release-candidate regression/crash review proportionate to final changes, including real-device photos/auth/sync/sharing/accessibility where needed; resolve actual blockers without reopening frozen systems.
- [ ] Prepare and owner-approve a release TestFlight candidate; obtain owner approval before archive/build-number changes/upload/distribution.
- [ ] Prepare App Store metadata/screenshots, reviewer instructions and final submission checklist. Obtain explicit owner approval before submission/publication.

## Recommended but deferrable

- Additional device/text-size coverage beyond supported representative checks, low-impact copy/pixel refinements, expanded beta feedback and nonessential analytics.
- Broader performance profiling only if observed latency/memory/crash evidence warrants it.
- Larger moderation tooling only when necessary scale/operations evidence exists; roles and entitlements remain separate.

## Post-V1 — not release blockers

- Crop/reposition/advanced galleries/editing and optional photography improvements; existing upload/ownership/multi-photo/sync/restore remain V1.
- Recipe Unit Conversion improvements (controls hidden), Saved Recipes/bookmarks (name TBD), privacy-aware Recipe Social History/Made X times, Run It Back redesign and broader Source integrations.
- Public discovery/feed, optional Contacts, referral/invite analytics, five-tier referral progression/rewards, manual entitlements/tester tooling, broader admin/follower/push/community/creator systems and monetization.
- A referral counts only after an attributed genuinely new successful signup. Core functionality cannot require recruiting friends. Rewards are undecided; no AI daily allowance, billing or paid-provider setup is introduced by this roadmap.

Follow [AGENTS](AGENTS.md) and [Master Roadmap](STAYGRUBBY_MASTER_ROADMAP.md): only product coherence, safety/privacy/platform compliance, integrity and a credible first public release justify moving a feature ahead of V1. Do not start another normal feature stage automatically.
