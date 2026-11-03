# Recipe + Social Integration — November 2, 2026

Current cycle: functional integration, **owner acceptance pending**. Gemini-first v27 and Food Bible Architecture V2 were explicitly owner-accepted at kickoff and remain frozen. Started clean on `main`, `8cec7b283a30d472b12176da9ce3015e912d0690`, aligned with origin. No resets, new AI calls, ranking/calibration changes, distribution or final UI polish.

## Canonical relationships and decisions

- **Recipe / RecipeRevision:** independent owner-controlled living document and immutable archived content. Optional Recipe-owned description survives edits, restore, Save as New and independent copies. Manual and reviewed Creator drafts use the same saved model; no downstream AI class.
- **Dish / CookingAttempt:** optional current Dish link is not historical evidence. Existing explicit Recipe-cook snapshot is authoritative when offering a Recipe for that cook. Otherwise the linked current Recipe is clearly labeled as a suggestion, not proof of what was cooked. Private cooking/ranking ownership is unchanged.
- **Grub List post / shared Recipe:** post stays the social object. `post_recipes` pins one existing Recipe/revision; no duplicate content archive, automatic attachment/backfill, new feed type or reaction system. OFF-by-default Include Recipe in the composer or Recipe Sharing on an existing post requires explicit confirmation and ownership. Enabling it intentionally sets the Recipe’s current-friends visibility; it is never public. Retries preserve the first prepared post and attachment; existing-post composition explains where to change it.
- **Shared reader:** destination is post UUID, never an unrestricted revision endpoint. Server authorizes current post access AND friends-visible owned Recipe. It returns the selected revision/description/content plus permitted creator/cook identity and social-photo fallback. Reuse the existing reader/components/scaling; no owner Edit/History/Link/Delete controls. Later current-Recipe edits and Dish unlinking leave the pinned content exact.
- **Run It Back / Tag a Sous Chef:** existing social claims, recipient item UUIDs, durable outbox, normal cook/rank flow and independent ownership remain. Only an explicitly shared accessible post attachment supplies Recipe provenance; an invitation/implicit Dish link alone does not. Creator attribution does not become recipient ownership or ranking evidence. Shared Cooking participants cannot share another owner’s Recipe through their own post without an independent copy.
- **Private copy:** explicit Save a Private Copy creates a new caller-owned private Recipe, revision 1, with description/content and server-derived source Recipe/revision/creator/post provenance in `recipe_forks`. Retries reuse the reserved UUID; edits never mutate the source. The owner reader displays source attribution. Foreign photo IDs are stripped; no automatic upload or media-ownership transfer. An owner’s existing Save as New behavior stays intact.

## Privacy and lifecycle

| Change | Further access / historical behavior |
| --- | --- |
| Recipe sharing OFF | Current and post-based friend Recipe/photo access denied; owner history remains |
| Remove Recipe from Post | Post remains; its Recipe reader/new snapshot transfer ends; Recipe-wide friends visibility is a separate setting |
| Friendship removal / either-direction block | Server Recipe/post/photo reads and new copies/claims obey current permissions; unblock does not restore friendship |
| Post deletion/source-cook retirement/moderation | Post-based Recipe reader/media authorization fails; independently friends-visible current Recipe is not silently made private |
| Recipe deletion/account erasure | Attachments/history access cascade away; surviving private fork source references nullify; recipient-owned copies/completed cooking evidence remain |
| Dish unlink | Neither object nor deliberate attachment/history is deleted |
| New Recipe revision | Current Food Bible evolves; historical post/cook stays pinned |

Closed/RLS tables and fixed-search-path owner-derived APIs enforce this boundary. No raw client grants, public Recipe directory, history browsing by friends, public/signed photo URLs or private cook-media fallback. Recipe-owned photos win, then separately consented authorized social photos, then fallback. Archived Recipe photos are readable only through active explicit attachments or current-Recipe authorization; other revision photos remain private. The existing immutable JPEG upload/hash/cleanup rules remain.

Independent copies, native exports and completed recipient cook snapshots cannot be remotely recalled; UI/policy explain this. Shared screens clear on background/refresh/error, not through claimed instantaneous remote erasure. Recipe tips/source fields are deliberately shared Recipe content; Personal Notes are never copied. Hands/comments/reporting and existing origin notifications stay on posts/origins; no new notification kind or broader notification fix.

## Verification and deployment

- Focused backend integration: **292 assertions passed** across nine selected files, including five all-existing-table migration preservation checks, 48 sharing/lifecycle checks, 19 media/ownership/Storage-policy checks, existing Recipe provenance, independent V2, Shared Cooking, interactions and descriptions.
- Focused native: **13 distinct tests /16 executions passed**, zero failures, across RecipeSocialTests, SocialPublicationTests and RecipesLinksTests. Includes explicit-only publication wire fields, pinned description/components/quantities, copy isolation and durable social origins/private graph protection. Debug build succeeded; existing unrelated concurrency warnings remain.
- The first MCP test invocation ignored the intended selection, ran unrelated tests and timed out. It was interrupted; it is **not** treated as focused acceptance. Direct Xcode `-only-testing` and disabled parallel testing use the existing single Simulator lane. No full suite is repeated.
- Bundled privacy policy updated for attachments/copies/revocation. Static policy generation and **seven local website tests pass**; the public website was not deployed. The initial root-level Python invocation had an import-path error; the documented Website-directory invocation passed.
- Three targeted Simulator flows pass: the existing Run It Back → independent cook/rank/provenance flow, plus dark composer off/on/cancel and light shared reader → independent private copy with owner controls absent. The initial switch assertion tapped its outer accessibility row; reusing the existing nested-switch helper plus a value wait resolved it without app/control changes or removed assertions. Final build also compiles owner-only attachment-presence state, so a private attachment can still be removed without revealing it to friends.
- The bundled policy date was updated to November 2; its static generator/test had hard-coded the previous date and were aligned. Seven final site tests pass; no website publication. Final policy SHA-256: `e3509dd4baae121a6543ac9be2212e12f9f92a7a48fa4dd0289944728d763d23`.
- Prepared migration: `20261103014017_recipe_social_integration.sql`. All 31 preexisting hosted migration hashes match before deployment. New hosted deployment/hash/RLS/data results and final checkpoint are recorded below at closeout.
- Offline read-only normal Simulator-store audit (copied SQLite/WAL, no source writes): **1 ranking /12 Dishes /15 attempts /15 items /356 comparisons /10 Sources**. UI test UUID libraries are separate.

No production fixture accounts/Recipes/posts/media are created by SQL tests; PGlite fixtures are disposable. UI/native fixtures use UUID-isolated stores/media roots and Debug-only mocks. No real Apple authorization/account deletion, secret changes, paid billing or provider calls. Prior live allowances remain exhausted. Public-policy publication, broader notification issue, Universal Links, standalone Recipe posts/feed filters and dedicated UI polish remain separate.

## One owner acceptance checklist (two existing friend accounts)

1. In the latest app, link your Recipe to a Dish (or use its existing cook snapshot). Open Share with Sous Chefs: Include Recipe starts OFF. Opt in, review the indicated revision/photo consent and publish; a post without a Recipe still works.
2. On the friend’s account, open the post → View Recipe. Review description/ingredients/components/servings. Confirm no owner edit/history controls. Save a Private Copy, edit its description and reopen; the original remains unchanged. Run It Back and complete/rank your own cook; check provenance.
3. Edit the original Recipe: the old post still reads the shared revision. Remove its attachment or turn Recipe sharing OFF: friend access ends. Verify a block/removal also denies access. Existing private copy/completed cook remains intact. Do not delete/reset either real account or ranking library.
