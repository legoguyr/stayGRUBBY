# App Store submission drafts (for owner review)

Status: **DRAFT, November 22, 2026. Not legal advice, and not entered in App Store Connect.** The owner reviews and enters everything below. Legal text (Terms of Use, Community Guidelines) stays the owner's. Release requirements live in [V1_RELEASE_GATE.md](V1_RELEASE_GATE.md).

## 1. App changes already prepared (on `agent/claude`)

- **Privacy manifest** (`StayGrubby/PrivacyInfo.xcprivacy`):
  - `NSPrivacyTracking = false`, with no tracking domains.
  - Required-reason APIs, checked against Apple's reason list on November 22, 2026:
    - UserDefaults `CA92.1`: app-only storage.
    - Disk space `E174.1`: `AccountContentCache` shrinks the photo cache when the device is low on space, which users can notice. The value is never sent off the device.
    - File timestamp `C617.1`: modification dates of the cache's own files inside the app container.
  - `PrivacyManifestTests` keeps this list in step with the code.
- **Terms of Use and Community Guidelines, built ahead and inactive.** The server flag `legal_terms` (off) controls:
  - Links in Settings › Support & About.
  - The line in kitchen setup: "By continuing, you agree to the Terms of Use and Community Guidelines."
  - URLs are in `LegalDocuments`: `staygrubby.com/terms` and `staygrubby.com/community-guidelines`.
  - Activation order: owner approves the text → publish both pages with `sh Website/deploy-production.sh` → enable the flag. Never enable it before the pages are live.
  - Explicit, versioned acceptance records for existing accounts would be a separate backend decision for Codex. Not built.

## 2. Draft App Review notes

> StayGrubby is a personal cooking journal. You log each time you cook a Dish (a "cook"), rank it through quick this-or-that comparisons (Grub Rank), keep Recipes (Food Bible) and optionally share cooks with mutual friends ("Sous Chefs") on The Pass.
>
> **Sign-in:** Sign in with Apple only; please use your own Apple ID. A new account goes through a short kitchen setup (name and @username, private by default) and an optional four-page tour, then lands on an empty Grub Rank with "Rank a Dish".
>
> **Try it:** Rank a Dish → enter a name → Liked it. Add a second Dish to see a comparison. Scores unlock after 10 ranked cooks; until then the order is shown. Food Bible → + → Add a Recipe (typed, or paste text to organize it).
>
> **User-generated content safeguards (Guideline 1.2):** Sharing reaches only accepted Sous Chefs; profiles are private by default and there is no public feed. Every post, comment and shared Recipe has ⋯ → Report; Block is in a post's ⋯ menu and on each person in My Kitchen › Sous Chefs. Reports go to a staff review queue with audited hide/dismiss; text is screened server-side. Contact: support@staygrubby.com.
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

**Owner decision (Gemini):**
- Paste Recipe sends the pasted text to Google Gemini on an unbilled project. Under Google's unpaid terms it may be used to improve Google's products, as the Privacy Policy discloses.
- That text is already covered by "Other User Content › App Functionality".
- Decide with legal input whether that Google use needs more disclosure, or whether a paid or no-training configuration should come first. Moving to paid requires explicit billing approval under AGENTS.md.

## 4. Age-rating questionnaire recommendation

| Question area | Suggested answer | Why |
| --- | --- | --- |
| User-generated content | **Yes** | Posts, photos, comments, Recipes |
| Messaging / chat | **Yes** if comments count, otherwise No | Comments on posts between Sous Chefs; there are no direct messages. Owner confirms against the current wording. |
| Unrestricted web access | No | Links go only to staygrubby.com pages |
| Violence, sexual content, profanity, horror, gambling, contests | None | Not present in app-authored content |
| Alcohol / tobacco / drugs | None (or Infrequent/Mild if counting wine in example Recipes) | App-authored content has none; user Recipes fall under user-generated content |
| Medical / treatment information | None | Allergens are informational only, not medical advice (Terms must say so) |

The likely result is **13+** under Apple's current tiers, because of social UGC. The owner confirms the final tier in App Store Connect.

## 5. Reviewer sign-in with their own Apple ID: risks

1. **Report/Block can't be found (highest risk, Guideline 1.2).** A brand-new reviewer account has no Sous Chefs, so The Pass is empty, and posts, comments and Block can't be reached. Report on own content isn't offered. The reviewer may not find the safeguards. Options, owner's choice:
   - (a) **Screen recording in the review notes** showing Report and Block on a second account. No app change. Recommended.
   - (b) A dedicated reviewer test account set up as a Sous Chef with sample posts. Sign in with Apple can't share a login, so this means sending the reviewer a Sous Chef request from a staff account, which would need their username after sign-in. That's impractical.
   - (c) Seeded demo content for review accounts. That's a feature; not recommended now.
2. **Scores look "missing."** Scores unlock after 10 ranked cooks, so a reviewer ranking 2–3 Dishes sees order but no numbers. The unlock banner explains it; the notes mention it.
3. **Required kitchen setup (Guideline 5.1.1(v)).** New accounts must enter a name and @username before using the app. The username is needed for Sous Chefs. The name accepts a nickname, and nothing else personal is required. This is a low risk, and the notes explain it. If it's ever flagged, the fallback is making setup skippable until first sharing. That's a product change, owner decision.
4. **Paste Recipe quota.** On the unbilled Gemini project, a reviewer could hit a quota. The app already falls back to manual entry with a friendly cooldown (AGENTS.md). Typed Recipes always work.
5. **Feature flags.** Dish Variations and Recipe recovery are enabled for audience `everyone`, so reviewers get the same features as testers. Keep `legal_terms` off until the pages are live, or reviewers would hit broken links.
6. **Account deletion and sign-out** are reachable without content; nothing blocks them.

## 6. Owner decisions

1. Approve the Terms of Use and Community Guidelines text (including the Recipe, allergen and AI-estimate disclaimers in V1_RELEASE_GATE), then publish and enable `legal_terms`.
2. Apple's standard EULA or a custom one. Community Guidelines are needed either way.
3. Privacy labels as above, and the Gemini disclosure (§3).
4. Age-rating answers (§4), especially the messaging question.
5. Reviewer strategy for Report/Block (§5.1): screen recording recommended.
6. Who handles reports, and response times (open in V1_RELEASE_GATE).
