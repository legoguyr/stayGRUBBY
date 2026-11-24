# App Store submission drafts (for owner review)

Status: **DRAFT, updated November 24, 2026. Not legal advice, and not entered in App Store Connect.** The owner reviews and enters everything below. Legal scope is §0. Release requirements live in [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md).

## 0. Legal scope for launch (owner decision, November 24, 2026)

Bare minimum for App Store approval. No iOS, Gemini or backend change.

**Required for submission**
- **Privacy Policy** (`https://staygrubby.com/privacy`, already live). Corrections for accuracy only: 18-and-older statement, shared-Recipe reports and staff review of reported content, Google Gemini in Service providers. **Published November 24** (`889d131`).
- **Apple's standard EULA.** Nothing to write; App Store Connect uses it by default.
- **Guideline 1.2 safeguards** (built): Report, Block, server-side text screening, staff Moderation queue, published contact (support page). The short **Community Guidelines** page (`Legal/CommunityGuidelines.md`, about 200 words: zero tolerance, report/block, 24-hour review aim, food-safety note, contact) is live at `https://staygrubby.com/community-guidelines` (November 24) and is linked in the App Review notes.
- **18+:** App Store age rating 18+, plus one sentence each in the Privacy Policy and the Community Guidelines. Gemini's terms need it; no Terms document is needed for it.
- Privacy labels, age-rating questionnaire, screenshots, metadata and App Review notes (§3–§6).

**Optional, removed from launch scope**
- Custom Terms of Use (draft deleted; it stays in git history), arbitration, liability cap, governing law and venue, legal-notice postal address, operator legal name, custom EULA.
- `legal_terms` activation. The flag stays **off**; its Settings links and kitchen-setup agreement line stay dormant in the app, unchanged. `/terms` is not published.
- Branch `claude/legal-pages-activation` (superseded by `claude/legal-minimum`).

**Residual review risk, not a blocker:** App Review sometimes asks under 1.2 that users *agree* to terms stating zero tolerance. If that happens, the fix needs no new build: publish a `/terms` page (Apple EULA link plus the Community Guidelines) and turn `legal_terms` on, which shows the existing agreement line.

## 1. App changes in build 1.0 (9) (on `main`)

- **Privacy manifest** (`StayGrubby/PrivacyInfo.xcprivacy`):
  - `NSPrivacyTracking = false`, with no tracking domains.
  - Required-reason APIs, checked against Apple's reason list on November 22, 2026:
    - UserDefaults `CA92.1`: app-only storage.
    - Disk space `E174.1`: `AccountContentCache` shrinks the photo cache when the device is low on space, which users can notice. The value is never sent off the device.
    - File timestamp `C617.1`: modification dates of the cache's own files inside the app container.
  - `PrivacyManifestTests` keeps this list in step with the code.
- **Legal links, dormant.** The server flag `legal_terms` (off, and not part of launch; §0) controls Settings links to `staygrubby.com/terms` and `/community-guidelines` and a kitchen-setup agreement line. Unchanged in the app; never enable it unless both pages are live.

## 2. Draft App Review notes

> StayGrubby is a personal cooking journal. You log each time you cook a Dish (a "cook"), rank it through quick this-or-that comparisons (Grub Rank), keep Recipes (Food Bible) and optionally share cooks with mutual friends ("Sous Chefs") on The Pass.
>
> **Sign-in:** Sign in with Apple only; please use your own Apple ID. A new account goes through a short kitchen setup (name and @username, private by default) and an optional four-page tour, then lands on an empty Grub Rank with "Rank a Dish".
>
> **Try it:** Rank a Dish → enter a name → Liked it. Add a second Dish to see a comparison. Scores unlock after 10 ranked cooks; until then the order is shown. Food Bible → + → Add a Recipe (typed, or paste text to organize it).
>
> **User-generated content safeguards (Guideline 1.2):** Sharing reaches only accepted Sous Chefs; profiles are private by default and there is no public feed. Every post, comment and shared Recipe has ⋯ → Report; Block is in a post's ⋯ menu and on each person in My Kitchen › Sous Chefs. Reports go to a staff review queue with audited hide/dismiss; text is screened server-side. Zero-tolerance Community Guidelines: https://staygrubby.com/community-guidelines. Contact: support@staygrubby.com.
>
> **Moderation:** Reports go to StayGrubby staff, who review them in the app's staff-only Moderation screen and can hide content or dismiss the report; every decision is recorded. Reviewers don't need staff access.
>
> **Account deletion:** My Kitchen → Settings → Account & Sync → Delete account… (confirmed, with Apple re-authorization).
>
> **Note:** The Pass, Sous Chefs, comments and Report/Block need a second account that is a Sous Chef. [Owner: attach the screen recording or demo details chosen in §5.]

## 3. Proposed privacy-label answers (App Store Connect › App Privacy)

Tracking: **No.** No analytics, advertising or crash-reporting SDKs (Privacy Policy, "How information is used").

| Data type | Collected | Linked to user | Purpose | Source in the app |
| --- | --- | --- | --- | --- |
| Contact Info › Email Address | Yes | Yes | App Functionality | Sign in with Apple email (may be a private relay address), Supabase Auth |
| Contact Info › Name | Yes | Yes | App Functionality | Display name in kitchen setup and profile |
| Identifiers › User ID | Yes | Yes | App Functionality | Account and auth IDs |
| User Content › Photos or Videos | Yes | Yes | App Functionality | Cook, Recipe and profile photos |
| User Content › Other User Content | Yes | Yes | App Functionality | Cooks, notes, rankings, Recipes, comments, descriptions, reports |
| Usage Data, Diagnostics, Location, Contacts, Health, Financial, Browsing/Search History, Sensitive Info | No | — | — | Not collected by StayGrubby |

**Third parties:**
- **Supabase** (database, Auth, Storage, Edge Functions) and **Apple** (Sign in with Apple) process data only to run the app, so they're covered by App Functionality.
- **Google Gemini** receives Paste Recipe text (§3a). On the unpaid tier, Google may also use that text for its own product improvement. While that's true, add **Other Purposes** to *User Content › Other User Content*, or move to paid so App Functionality alone stays accurate. Owner decision.

### 3a. Gemini (Paste Recipe): confirmed configuration, November 22, 2026

- **Path:** app → authenticated Supabase Edge Function `recipe-import` → `generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent`, called with the project key `STAYGRUBBY_GEMINI_API_KEY` from the server, never the app. The owner confirmed the project has no billing, so it's **unpaid**.
- **Sent to Google:**
  - Only the text the user pastes: up to 12,000 characters, or 32 KB.
  - StayGrubby's fixed formatting instructions and lists of cuisines and allergen codes.
  - No account ID, email, name, photos, other Recipes, Dishes or rankings. Google also sees ordinary network request data from Supabase's servers.
- **Consent:**
  - The app requires `cloudConsent: true`. Before the first submission per account, a notice names Google Gemini and the unpaid-service terms, with Continue, Cancel/Add Manually and the Privacy Policy.
  - Cancelling sends nothing, and typed Recipes never use AI.
  - The Privacy Policy, under "Paste Recipe and external AI processing", says the same.
- **Kept by StayGrubby:** short-burst usage counters only, deleted with the account. Logs carry request ID, stage, status and validation codes, never the Recipe text. A result is saved only when the user taps Save.
- **Google's terms** (Gemini API Additional Terms, effective March 23, 2026, read November 22, 2026):
  - **Unpaid services:** Google may use content and responses to improve its products, and human reviewers may read them. Google warns against sending sensitive or personal information.
  - **Paid services:** not used for product improvement, and logged for a limited period only for abuse prevention and legal requirements.
  - **Compliance blockers (legal review needed):**
    - The terms require API users to be 18 or older, and say the API must not be used for apps likely to be accessed by people under 18.
    - Developers may offer **only paid services** to users in the **EEA, Switzerland and the UK**.

### 3b. Gemini terms: verified reading and options (November 22, 2026; not legal advice)

**What the terms say:**
- **Gemini API** (Additional Terms, effective March 23, 2026, plus Google APIs ToS):
  - *Age Requirements*: "18 or older to use the APIs" binds the developer, who is an adult, so that part is met. A **separate, unconditional** obligation bars using the Services in an application "likely to be accessed by individuals under the age of 18." Paying doesn't change it. Whether a 13+ App Store app is "likely accessed" by minors is a judgment the terms leave open, but a 13+ rating effectively admits it.
  - *Use Restrictions*: only Paid Services may be used to make an app available to users in the EEA, Switzerland or the UK. The trigger is where the users are. All of those countries are listed as available regions.
  - The terms also say the API is for professional or business purposes, "not for consumer use." The phrase is undefined. A developer-operated server feature inside a consumer app is the developer's use, but that's a point for legal review.
- **Vertex AI** (Google Cloud Service Specific Terms §20, last modified April 2, 2026):
  - §20(d) has the same under-18 restriction.
  - No paid-only or regional end-user rule.
  - §18: no training on customer data without permission.

**Can the free tier comply?**
Only if all of the following hold:
1. The app is **not likely accessed by under-18s**, in practice an **18+ age rating**.
2. **No users in the EEA, UK or Switzerland** can use Paste Recipe. Either exclude those App Store territories, or switch Paste Recipe off there.
3. Google's product-improvement use and human review stay disclosed, which they already are, and labelled (§3).

The public TestFlight link has no age or region limit today. External testers who are under 18 or in those regions are an exposure now. Decide whether to limit the link or tell testers.

*Superseded the same day:* the owner first chose option 3 below (18+, unpaid tier, EEA/UK/Switzerland excluded), then decided on **global availability with all features, no 18+ rating solely for Gemini, and free AI for users** (§3c).

**Recommendation (keeps the feature):**
1. **Rate the app 18+.** That addresses the one restriction every Google option shares. It's a cooking app, so the reach cost is small. Confirm with legal advice.
2. **Move to the paid Gemini API** by enabling billing on the existing project. It needs no code change, has no regional limits, and stops Google using the text. It needs billing approval under AGENTS.md. At flash-lite pricing, for short bounded requests, the expected cost is low. Vertex AI is equivalent but needs a server change.
3. If billing waits, the free tier needs (1) plus excluding EEA/UK/Switzerland territories.
4. Option to check with legal: limit only Paste Recipe to adults with Apple's Declared Age Range, instead of rating the whole app 18+. The terms restrict the *application*, so this may not be enough.

**Smallest safe change if Paste Recipe must be disabled:**
- **Server, immediately, covers every installed build:** remove the `STAYGRUBBY_GEMINI_API_KEY` secret. `recipe-import` then returns `not_configured`, the app keeps the pasted text, and Add Manually works. Users who tap Paste Recipe see "Recipe formatting isn't configured yet," so it's safe but rough.
- **App, next build:**
  - Hide the single entry point, the **Paste Recipe** button in `AddRecipeFlow.sourceButtons`, behind a server flag such as `recipe_paste_ai`. Like other flags it's off until enabled, so it can be turned back on where compliant.
  - Add Manually, Recipe editing and ingredient parsing are unaffected, since that parsing happens on the device.
  - The Privacy Policy and labels can keep the Gemini text, or drop it when it's off for everyone.
- Neither change touches data or ranking.

### 3c. Global availability review (November 23, 2026; research only, not legal advice)

**Owner final decision for the current launch (November 23, 2026):** keep Gemini exactly as implemented (unpaid tier, existing consent notice), make the app available in **all** App Store regions including the EU, UK and Switzerland, and set the minimum age to **18** (age rating; since November 24 stated in the Privacy Policy and Community Guidelines, with no custom Terms; §0). Alternative providers are not to be revisited unless the owner asks. The research below is kept as the record. Recorded residual point: Google's Use Restrictions allow only Paid Services when an app is made available to EEA, Swiss or UK users; the unpaid tier in those regions is an owner-accepted risk.

**Owner requirements:** available worldwide including the EEA, UK and Switzerland; Paste Recipe everywhere; AI free for users; no 18+ rating only to satisfy the provider; avoid paid billing if a compliant free option exists.

**Gemini cannot meet them, on any Google option.** Gemini API Additional Terms (effective March 23, 2026, now at aistudio.google.com/docs/terms): *Age Requirements* bar any API Client "likely to be accessed by individuals under the age of 18", with no paid/unpaid exception; *Use Restrictions* allow only Paid Services for apps made available to EEA, Swiss or UK users, and say the API is for professional or business purposes, "not for consumer use". Vertex AI (Service Specific Terms §20(d), modified April 2, 2026) has the same under-18 bar. A 13+ app is likely accessed by minors, so billing alone does not fix it.

**No compliant free option was found.** Gemini's unpaid tier is the only free production API among those reviewed, and it fails both the age and the EEA/UK/CH rules. Mistral's and OpenAI's free plans are consumer chat, not production APIs.

| Provider (cheapest suitable model) | Under-18 users | EEA/UK/CH | Training on API data | Price per 1M tokens (in / out) | Est. per Paste Recipe* |
| --- | --- | --- | --- | --- | --- |
| Google Gemini 3.5 Flash-Lite, paid | **Prohibited** (all tiers, Vertex too) | Paid only | No (paid) | $0.30 / $2.50 | ~$0.007 |
| **Anthropic Claude Haiku 5.5** | Allowed with safeguards (Usage Policy + "organizations serving minors" guidance) | Supported (Supported Regions Policy, effective Nov 12, 2026) | No by default | $0.10 / $0.50 | **~$0.002** |
| OpenAI GPT-6 Luna | Requires parent/guardian consent (Services Agreement §3.3) | Not confirmed | No by default | $0.10 / $0.50 | ~$0.002 |
| Mistral (Small) | Requires "legally adequate consent" (Commercial Terms §2.2(c)) | GDPR processor; consumer EU terms not read | Opt-out | Not confirmed | — |

\*Assumes about 6,000 input tokens (instructions, schema, up to 12,000 pasted characters) and 2,000 output tokens. At 1,000 imports a month ≈ $2; at 10,000 ≈ $16–20. Reviewed provider prices are list prices on November 23, 2026; confirm before enabling billing.

**Recommendation:** replace Gemini with **Anthropic Claude Haiku 5.5** behind the existing `recipe-import` Edge Function, keep the app 13+ and global, and keep Paste Recipe free to users (StayGrubby pays roughly $0.002 per import; existing burst limits cap abuse). It is the cheapest option found that permits teen users without parental consent, serves the EEA/UK/CH, and does not train on the text. OpenAI is equal on price but requires parental consent for minors and its country list was not confirmed. *Disclosure: this assessment was written by Claude, an Anthropic model; the comparison rests on each provider's published terms and the owner may want independent legal review.*

**Anthropic compliance requirements (minors guidance):** tell users they are interacting with an AI system (the Paste Recipe consent notice already does, once it names the new provider); keep content safeguards (output is a structured, user-reviewed Recipe draft with server validation; nothing is published automatically); restrict access to intended users (App Store 13+ rating plus Terms minimum age); comply with child-safety and privacy law and state that compliance on the website; Anthropic may audit.

**What changes (each needs owner approval; none started):**
1. **Provider account and billing** (Anthropic API key as a Supabase secret). Paid, so it needs explicit billing approval under AGENTS.md.
2. **Edge Function adapter** in `supabase/functions/recipe-import/handler.ts`: swap the Gemini request/response for the Anthropic Messages API with the same instructions and JSON schema; keep validation, limits and graceful fallback. Deno tests updated. Function deployment needs approval.
3. **Quality re-acceptance:** run the existing Recipe Creator live regression on the new model and get owner acceptance (the Gemini path is the owner-accepted standard; AGENTS.md).
4. **App build 1.0 (10):** the consent notice currently names Google Gemini and its unpaid-data terms (`RecipeImportView`), and build 1.0 (9) contains that text. Change it to name the new provider (or a server-supplied provider name). Submission should use 1.0 (10).
5. **Privacy Policy** "Paste Recipe and external AI processing" section and App Store privacy labels (drop *Other Purposes*). Published text: owner approval.
6. Terms: minimum age 13 with parental-permission wording, provider named.

**Launch impact:** about 1–2 working days of implementation and tests plus owner quality acceptance; no data migration, ranking or schema change.

**If the owner prefers no provider change:** Gemini stays compliant only with an 18+ rating and either paid billing (global) or excluded EEA/UK/CH territories (§3b). Both conflict with the stated requirements.

## 4. Age-rating questionnaire recommendation

| Question area | Suggested answer | Why |
| --- | --- | --- |
| User-generated content | **Yes** | Posts, photos, comments, Recipes |
| Messaging / chat | **Yes** if comments count, otherwise No | Comments on posts between Sous Chefs; there are no direct messages. Owner confirms against the current wording. |
| Unrestricted web access | No | Links go only to staygrubby.com pages |
| Violence, sexual content, profanity, horror, gambling, contests | None | Not present in app-authored content |
| Alcohol / tobacco / drugs | None (or Infrequent/Mild if counting wine in example Recipes) | App-authored content has none; user Recipes fall under user-generated content |
| Medical / treatment information | None | Allergens are informational only, not medical advice (Community Guidelines say so) |

The questionnaire alone would likely give **13+**. **Final: 18+** (owner, November 23), because Google's Gemini terms bar apps likely to be accessed by under-18s (§3a, §3c).

## 5. Reviewer sign-in with their own Apple ID: risks

1. **Report/Block can't be found (highest risk, Guideline 1.2).** A brand-new reviewer account has no Sous Chefs, so The Pass is empty, and posts, comments and Block can't be reached. Report on own content isn't offered. The reviewer may not find the safeguards. Options, owner's choice:
   - (a) **Screen recording in the review notes** showing Report and Block on a second account. No app change. Recommended.
   - (b) A dedicated reviewer test account set up as a Sous Chef with sample posts. Sign in with Apple can't share a login, so this means sending the reviewer a Sous Chef request from a staff account, which would need their username after sign-in. That's impractical.
   - (c) Seeded demo content for review accounts. That's a feature; not recommended now.
2. **Scores look "missing."** Scores unlock after 10 ranked cooks, so a reviewer ranking 2–3 Dishes sees order but no numbers. The unlock banner explains it; the notes mention it.
3. **Required kitchen setup (Guideline 5.1.1(v)).** New accounts must enter a name and @username before using the app. The username is needed for Sous Chefs. The name accepts a nickname, and nothing else personal is required. This is a low risk, and the notes explain it. If it's ever flagged, the fallback is making setup skippable until first sharing. That's a product change, owner decision.
4. **Paste Recipe quota.** On the unbilled Gemini project, a reviewer could hit a quota. The app already falls back to manual entry with a friendly cooldown (AGENTS.md). Typed Recipes always work.
5. **Feature flags.** Dish Variations and Recipe recovery are enabled for audience `everyone`, so reviewers get the same features as testers. `legal_terms` stays off for launch (§0).
6. **Account deletion and sign-out** are reachable without content; nothing blocks them.

## 5a. App Review demonstration plan (safe test data)

Goal: one short screen recording, under 2 minutes, attached in App Review notes. It shows Report Post, Report Comment, Report Recipe, Block account and account deletion. No real user's content appears.

**Recommended: TestFlight build with two disposable accounts.**
1. **Accounts.** Create two disposable Apple IDs, A and B, not used by real people. Sign in to TestFlight build 8 on two devices, or sign out and in on one. Set them up as `review_a` and `review_b`, private.
2. **Sous Chefs.** A sends B a Sous Chef request (Find Sous Chefs → @review_b), and B accepts under Requests.
3. **Content.** B ranks one throwaway cook, shares it to The Pass with a short neutral caption, and attaches a typed throwaway Recipe shared with Sous Chefs. B also comments on its own post.
4. **Record on A, with iOS screen recording:**
   - The Pass → B's post → ⋯ → **Report post** → choose a reason → Send.
   - Open the comment → ⋯ → **Report comment** → Send.
   - Open the attached Recipe → ⋯ → **Report Recipe** → Send.
   - B's post → ⋯ → **Block account** → confirm. B's content disappears. Also show My Kitchen › Sous Chefs → Blocked Accounts.
   - My Kitchen → Settings → Account & Sync → **Delete account…** → confirm → Apple re-authorization → back at the welcome screen.
5. **Cleanup:**
   - Delete account B in the app too.
   - Dismiss the three test reports in Settings → Moderation (after `staff_moderation` is on), which records them in the audit.
   - Production writes are limited to these two disposable accounts and their deletion. Nothing touches real users' data.

**Fallback, no production writes:** record the same steps in a Debug simulator review store (`--social-review-ready --social-review-feed`), which has fixture Sous Chefs and posts. Account deletion can't be shown there because it needs real Sign in with Apple, so pair it with a still of the Delete account flow. Debug builds show a Developer Tools section, so stay out of Settings while recording.

## 6. Final App Store Connect checklist — build 1.0 (9)

Status November 23, 2026: archive **StayGrubby 1.0 (9)** is in Xcode Organizer (`~/Library/Developer/Xcode/Archives/2026-11-23`), built from `main`-equivalent app code with the moderation interface and corrected privacy manifest. Release checks pass (no preview/developer tools/test fixtures; manifest CA92.1/E174.1/C617.1, no tracking; Sign in with Apple and `applinks:staygrubby.com` entitlements; `ITSAppUsesNonExemptEncryption` false; iOS 17.0; iPhone only). A local App Store Connect export signed by Apple Distribution succeeded. **Uploaded November 23** (owner-approved); not submitted for review or released. 1.0 (9) is the submission build (Gemini unchanged).

| Area | Entry | Status |
| --- | --- | --- |
| App Information | Name StayGrubby; subtitle (≤30 chars) e.g. "Rank what you cook"; category **Food & Drink** (secondary optional: Lifestyle); content rights: contains third-party content **Yes** (user-generated) | Owner enters |
| URLs | Privacy Policy `https://staygrubby.com/privacy` (live); Support `https://staygrubby.com/support` (live); Marketing `https://staygrubby.com` | Ready |
| License agreement | Apple standard EULA (App Store Connect default; no custom EULA or Terms) | Final (owner, November 24) |
| Age rating | **18+** (owner, November 23). Answer §4 truthfully; if the questionnaire computes a lower tier, use App Store Connect's option to choose a higher rating (confirm the control when entering). | Owner enters |
| App Privacy | §3 table **plus Other Purposes on User Content › Other User Content** (unpaid Gemini); Tracking No | Owner enters |
| Export compliance | Uses only exempt encryption (HTTPS); `ITSAppUsesNonExemptEncryption = false` is in the build | Ready |
| Pricing and availability | Free; **all territories**, including the EU, UK and Switzerland (owner, November 23) | Owner enters |
| Screenshots | iPhone 6.9" portrait 1320×2868. **Draft set captured November 23** in `AppStoreDrafts/` (local, git-ignored): Grub Rank, The Pass, Food Bible, Recipe, from the isolated `--development-persona` kitchen (fictional cook and Sous Chefs; Debug build, no production data). The persona has no food photos, so images show the StayGrubby placeholder: final screenshots need owner-supplied food photos (no fabricated imagery) and a This-or-That frame | Owner photos needed |
| Promotional text / description / keywords | §6a | Drafted; owner pastes |
| App Review information | Notes §2; attach the Report/Block recording (draft `AppStoreDrafts/report-block-demo.mp4`, about 40 s on the fixture kitchen: Report post → Send → Report sent; Block account → confirm → posts removed; the §5a two-account TestFlight recording remains the stronger option and also shows account deletion); contact name, phone, email; sign-in: "Sign in with Apple — use your own Apple ID" (no demo credentials) | Recording pending |
| Version release | Manual release after approval recommended | Owner choice |

## 6a. Metadata drafts (November 24, 2026; owner reviews and pastes)

Lengths checked against App Store Connect limits. No health, allergen or nutrition claims.

| Field | Draft | Limit |
| --- | --- | --- |
| Name | StayGrubby | 18 / 30 |
| Subtitle | Rank what you cook | 18 / 30 |
| Promotional text | Rank everything you cook with quick this-or-that picks. Keep the Recipes worth making again, and share your best cooks with your Sous Chefs. | 140 / 170 |
| Keywords | cooking journal,recipe,recipes,home cook,food diary,meal log,ranking,rank,cook,dish,kitchen,foodie | 98 / 100 bytes |
| Primary category | Food & Drink (secondary optional: Lifestyle) | — |
| Copyright | 2026 StayGrubby (owner may use the legal holder's name) | — |
| Support URL | https://staygrubby.com/support | live |
| Marketing URL | https://staygrubby.com | live |
| Privacy Policy URL | https://staygrubby.com/privacy | live, November 24 |
| What's New | Not shown for a first version | — |

**Description** (1203 / 4000):

```text
StayGrubby is a cooking journal that ranks what you make.

RANK WHAT YOU COOK
Log a cook, say how it went, then pick between two things you made. No stars, no sliders: quick this-or-that picks build your Grub Rank, and your top three are your Signature Dishes. Scores unlock once you have ranked ten cooks.

EVERY COOK IN ONE PLACE
Each Dish keeps every time you made it, with photos, notes and the date. Cook Again to log the next one and see whether it beat the last.

FOOD BIBLE
Keep the Recipes worth making again. Type a Recipe, or paste one and StayGrubby organizes it into an editable draft you review before saving. Adjust servings, link a Recipe to a Dish and keep its history.

THE PASS
Post a cook to The Pass for your Sous Chefs, the friends you choose. They can Give Hands 🙌 and comment. Your profile is private by default, and your Grub Rank, notes and unshared cooks always stay private.

SAFE BY DESIGN
Report and block from any post, comment, shared Recipe or profile. Reports are reviewed by the StayGrubby team.

StayGrubby is for people 18 and older. Sign in with Apple.
Privacy Policy: https://staygrubby.com/privacy
Community Guidelines: https://staygrubby.com/community-guidelines
```

**App Review information:** notes are §2 (paste the quoted block; it links the Community Guidelines). Sign-in: "Sign in with Apple — please use your own Apple ID"; no demo credentials. Attach the Report/Block recording (§5a; draft `AppStoreDrafts/report-block-demo.mp4`). Contact name, phone and email: owner enters.

## 7. Activation order (each step needs explicit owner approval)

1. ✅ **Done November 23** — **Enroll `@grubwithguy` as sole admin.** Account `79237ea0-…87e` verified read-only (active since October 13, one sign-in link, unique username, no staff yet). Run Codex's `enroll_initial_admin.sql` with the ID pinned (prepared privately; the only change is the pin line). Verify exactly one admin and one audit row; counts unchanged. Harmless before the build: no flag, no UI.
2. ✅ **Done November 23 (uploaded, not submitted)** — **Upload build 1.0 (9)** (internal TestFlight availability is automatic; no external release needed) and install it on the owner's iPhone.
3. **Enable `staff_moderation`** with Codex's `enable_staff_interface.sql` (aborts unless only the pinned owner is enrolled). Only staff receive the flag. Owner checks My Kitchen › Settings › Staff › Moderation (empty queue today). Rollback: set only that flag's `enabled` to false.
4. ✅ **Done November 24** — **Privacy correction and Community Guidelines published** (`889d131`); live-link gate passed, `/terms` stays unpublished.
5. **App Store submission** of 1.0 (9) once §6 entries and the review recording are complete. `legal_terms` stays off (§0).

## 8. Owner decisions

1. **AI and age — FINAL (owner, November 23):** keep Gemini as implemented (unpaid), all App Store regions, minimum age 18 in the Terms (§3c). Submit build 1.0 (9); no provider, billing, consent or app change.
2. **Legal scope — FINAL (owner, November 24):** bare minimum (§0). Privacy correction and Community Guidelines approved and published November 24.
3. **EULA — FINAL:** Apple's standard EULA.
4. Privacy labels as above. While on the unpaid tier, add Other Purposes for Other User Content because of Google's product-improvement use (§3).
5. Age-rating answers (§4), especially the messaging question.
6. Reviewer demonstration (§5a): two disposable TestFlight accounts recommended, with the fixture recording as fallback.
7. Who handles reports, and response times (open in V1_RELEASE_GATE).
