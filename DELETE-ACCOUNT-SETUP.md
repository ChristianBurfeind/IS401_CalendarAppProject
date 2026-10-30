# Add account deletion (one-time setup)

The HTML changes alone add the buttons and confirmation screens. Actual account deletion needs the SQL and Edge Function below. Until these are installed, a failed delete request keeps the user signed in and shows an error; the HTML does not pretend deletion succeeded.

## 1. Confirm database setup

Run `scheduler-setup.sql` once against the existing team schema, as described in `START-HERE.md`. It now includes the account-deletion trigger and policies along with profile and birthday setup. Installing it does not delete accounts or app rows.

If all three earlier scripts were already installed successfully, skip this step. Do not run the retired individual scripts or legacy `setup.sql` afterward. The combined script can be reapplied on the expected schema, but it replaces scheduler-table policies: review custom team policies first.

The cleanup covers the matching profile, settings, interests, task completions, tasks, and events. Extend it if you add user-owned tables.

## 2. Create the protected deletion function

1. In Supabase, open **Edge Functions**.
2. Choose **Deploy a new function → Via Editor** (the label may be **Create a new function**).
3. Name it exactly **delete-account**.
4. Replace the sample `index.ts` code with the complete contents of `supabase/functions/delete-account/index.ts` from this package.
5. Deploy the function.
6. Open the function's **Details/settings** and turn OFF **Verify JWT** / **Enforce JWT Verification** for this function. The provided handler independently verifies the bearer token using Supabase Auth's `getUser()` before accessing or deleting anything. This accommodates projects using current signing keys. Do not remove that verification code.

Hosted functions normally receive `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` automatically. The function uses these on the server. Do not put the service-role key in HTML, GitHub frontend code, or a browser request.

If your team prefers the CLI, the package includes `supabase/config.toml`. From the package root, run `supabase functions deploy delete-account --project-ref YOUR_PROJECT_REF --no-verify-jwt` after authenticating with the Supabase CLI. Use the dashboard route if you have not installed the CLI.

## 3. Keep your current HTML

Use your team's current `index.html` with the deletion button and two confirmations. No HTML or public key changes are needed just because the SQL files were combined. If the function already works, it does not need redeployment for this change.

## What deletion removes

After the user confirms twice:

1. The function verifies who is logged in; it never accepts a target account ID from the browser.
2. It checks that the database cleanup trigger is installed.
3. It removes all files in that user's `profile-pictures/<Auth UUID>/` folder through the Storage API.
4. It hard-deletes that user's Supabase Auth account. A database trigger removes their scheduler rows within that same database transaction.
5. The HTML clears that browser's app session/cache and returns to login.

The shared picture bucket and preset avatars stay available for everyone else. Other users' data remains intact. RLS gets an additional active-account check so a deleted user's still-unexpired access token cannot recreate scheduler rows or upload new profile pictures.

This removes the listed information from the live app database, Auth and picture storage. It does not promise immediate erasure from backups, platform logs, external copies or cached public images. A user can later register again with the same email as a new account; this does not restore deleted data.

Storage and database deletion cannot share one transaction. If picture removal succeeds but the Auth/database deletion fails, the account remains but pictures may already be removed. The UI reports a failure and allows a retry. If extra tables/foreign keys have been added since the shared schema, these may block deletion until their cleanup is included. The function only handles the app's profile-pictures bucket; other user-owned buckets need their own cleanup.

## Test with disposable accounts

Create test accounts A and B. Give both a photo, profile fields, a task, a completed task, an event, interests and settings.

- Cancel at the first confirmation: nothing changes.
- Continue, then choose **Keep my account** at the second confirmation: nothing changes.
- Complete both confirmations for A. Verify A disappears from **Authentication → Users**, `public.user`, its tasks/events/settings/interests and its to-do rows. Check the picture folder is empty.
- Verify account B can still log in and all B's data is unchanged.
- Try signing in as A: the old credentials should no longer work.
- From an authenticated API test, ensure an expired/invalid token is rejected and a body containing B's ID cannot target B.
- If the UI reports failure, check the function logs and share the error. Do not keep deleting test accounts until setup errors are resolved.

Automated checks passed for both confirmation cancellations, failed/successful frontend requests, all six field edit controls, authenticated function requests, cross-account targeting prevention, picture cleanup batches, and PostgreSQL cleanup on a simulated scheduler schema (including transaction rollback and blocking deleted users from recreating rows). These are local tests, not tests against your live Supabase project; the team has since reported successful live deletion; repeat the relevant checks for future changes.

Official references:

- https://supabase.com/docs/reference/javascript/auth-admin-deleteuser
- https://supabase.com/docs/guides/auth/managing-user-data
- https://supabase.com/docs/guides/functions/quickstart-dashboard
- https://supabase.com/docs/guides/functions/auth
