# The Daily Blend: start here

## 1. Database setup (once per Supabase project)

Use the team's existing Supabase project and scheduler tables. Each teammate does not need a separate database setup.

- If all three earlier upgrades have already been run successfully, skip this step. Combining the files does not add a new feature.
- Otherwise, export a backup, open Supabase's SQL Editor, paste **all of `scheduler-setup.sql`**, and run it once.
- It installs account/profile security, profile-picture storage, birth dates, and account-deletion database cleanup together. It keeps existing app rows. If any statement fails, the transaction rolls back; resolve the error before proceeding.
- It requires the existing base schema, including `public.user`, its legacy `password` column, and the scheduler tables. It does not create an empty project from scratch.
- The complete script can be reapplied on the expected schema, including after partial installation of the old upgrades. It replaces policies on the named scheduler tables; review any custom policies your team added before reapplying it.
- Remove `auth-profile-setup.sql`, `birthday-setup.sql`, and `delete-account-setup.sql` from the current repository files in favor of this combined file. Git history retains older versions. Do not run the legacy `setup.sql` afterward.

## 2. Account-deletion function

Follow `DELETE-ACCOUNT-SETUP.md` to deploy the separate server function if it is not already working. SQL alone cannot deploy it. An already working function does not need redeployment for this packaging change.

## 3. Open the frontend

1. Keep the team's current `index.html`, including its branding and recent edits.
2. Set `SUPABASE_URL` to the project's base URL ending in `.supabase.co` and `SUPABASE_ANON_KEY` to its public publishable/anon key. Keep placeholder comparisons in the `configured` block unchanged.
3. Never use a secret/service-role key in HTML.
4. Open the project in VS Code, right-click `index.html`, and select **Open with Live Server**. Use the same address when testing saved sessions.
5. Configure Supabase Authentication's Site URL and allowed redirect URLs for your deployed/local addresses. Keep email signup enabled.
6. Create an account, open the newest confirmation email if confirmation is enabled, then return to the app and log in with your email and password.

## 4. Quick checks

- Save profile information and reload to check persistence.
- Select an avatar or upload a JPEG/PNG/WebP photo up to 5 MB using file selection or drag and drop. Reposition/zoom, then save. Cancel should discard picture changes.
- Only the saved crop remains after refreshing; re-upload the original to recover cropped-out areas. Picture URLs are publicly readable, while uploads/deletes are owner-restricted.
- Save a birth date and verify calculated age. On the birthday, signed-in pages display a dismissible greeting; confetti respects reduced-motion preferences. February 29 birthdays are observed February 28 in non-leap years. No email or background birthday notification is sent.
- Test tasks/events and settings after refreshing. Check a second account cannot access the first account's private records.
- Use disposable accounts for deletion tests, including both Cancel options and verification of related row/file removal.

Legacy username-only accounts are not automatically transferred to new email/password accounts. Passwords are handled by Supabase Auth. The four calendar-connection buttons remain disabled placeholders.
