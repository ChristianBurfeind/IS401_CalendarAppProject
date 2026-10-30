# The Daily Blend

**BYU · IS 401 · Section 01 · Group 4**

The Daily Blend is a web calendar for BYU students balancing school, work, church responsibilities, and social life. Our goal is to help students stay organized and feel accomplished by bringing their tasks and events into one place.

The app is still in development. Eventually, students will also be able to connect outside calendars and discover activities that match their interests.

## Project information

- **Live website:** Add URL here
- **Trello board:** Add link here
- **Team members:** Add names here

## Features and progress

Complete features have been implemented and tested as noted below. Not complete includes features that still need development or testing on the latest live website.

| Behavioral requirement | Status | Notes |
| --- | --- | --- |
| Create an account, confirm an email address, and log in. | Complete | Tested with Supabase. |
| Stay signed in after refreshing and log out when finished. | Complete | Account persistence remains after closing the tab or window and reopening. |
| Edit and save personal profile information. | Complete | Changes persist after saving. |
| Choose an avatar or upload, crop, and save a profile picture. | Complete | Supports file selection and drag and drop. |
| Save a birth date, see a calculated age, and receive an in-app birthday greeting. | Not complete | Implemented; live saving and birthday display still need verification. |
| Delete an account after two confirmation prompts. | Complete | Account deletion tested; confirm related data and pictures are removed during final checks. |
| Add, edit, and delete events with dates, times, locations, and descriptions. | Not complete | Verify all changes remain after refreshing. |
| View saved events in day, week, and month calendars. | Not complete | Verify each view with real saved data. |
| Add tasks and mark them complete. | Not complete | Verify tasks and completion status persist. |
| Organize tasks and events by category and priority. | Not complete | Verify saving and display. |
| Connect Canvas, Learning Suite, Workday, and another calendar. | Not complete | Buttons are Coming soon placeholders. |
| Receive homework reminders 24 hours before deadlines and social-event reminders four hours beforehand. | Not complete | Reminder delivery and timing need implementation and testing. |
| Find, filter, and add relevant activities from Discover. | Not complete | Verify real event sources and saved additions. |
| Receive notifications about newly posted events matching interests or major. | Not complete | Matching and notification behavior still need work. |
| Save interests and settings that personalize the app. | Not complete | Verify persistence and the effect of each setting. |
| Use an AI workflow automation. | Not complete | Define and build the team's selected workflow. |
| Automatically track behavior for the team's four Key Results. | Not complete | Finalize the OKRs and the tables/events that update them. |

Update this table as the team finishes and tests each feature.

## Technology

- **Frontend:** HTML, CSS, and JavaScript
- **Backend and database:** Supabase with PostgreSQL
- **Accounts:** Supabase Auth
- **Profile pictures:** Supabase Storage
- **Account deletion:** Supabase Edge Function named `delete-account`

Passwords are handled by Supabase Auth. Database Row Level Security (RLS) restricts users to their own records.

## Run the app locally

1. Clone the repository or download and unzip it from GitHub.
2. Open the project folder in VS Code.
3. In `index.html`, set the two configuration values using the team's Supabase project:

   ```javascript
   const SUPABASE_URL = "YOUR_PROJECT_URL";
   const SUPABASE_ANON_KEY = "YOUR_ANON_KEY";
   ```

   Use the base project URL ending in `.supabase.co` and the public publishable/anon key. Keep the placeholder comparisons in the `configured` block unchanged. Never put a secret or service-role key in the HTML.
4. Install **Live Server** by Ritwick Dey if needed. Right-click `index.html` and select **Open with Live Server**.
5. Create an account, use the newest confirmation email, and return to the app to log in.

Use the existing team database for normal development. Local Live Server testing does not publish the website.

### Supabase setup

Detailed instructions are in `START-HERE.md` and `DELETE-ACCOUNT-SETUP.md`. Keep those documents and the setup files in the repository.

For the team's existing base schema, the upgrades are applied in this order:

1. `auth-profile-setup.sql`
2. `birthday-setup.sql`
3. `delete-account-setup.sql`
4. Deploy `supabase/functions/delete-account/index.ts` as `delete-account`, following `DELETE-ACCOUNT-SETUP.md`.

Apply only upgrades that have not already been installed. These scripts require the existing scheduler tables; they do not build a new database from scratch. Do not rerun the legacy `setup.sql` afterward or rerun the Auth setup after deletion setup, because this can replace security protections.

Set Supabase Authentication's Site URL and allowed redirect URLs for the app's hosting/testing addresses. Keep privileged account-deletion credentials on the server.

## Definition of Done

Before marking work Done, our team checks that:

- Pages look good and work on desktop and mobile.
- Features work from the user interface through Supabase to the database, and saved changes survive a refresh.
- Lighthouse Accessibility scores are **90 or higher** for the current version's relevant pages.
- This README lists behavioral requirements as Complete or Not complete.
- Code is merged into `main`.
- The latest changes are available at a public website URL.

Current release verification is still pending for desktop/mobile layouts, full end-to-end flows, Lighthouse, the merge to `main`, and public deployment. Add the live URL and update these results after testing.

## Testing and next steps

Use test accounts to check signup/login, profile edits, picture uploads, tasks/events, settings, and data persistence. For deletion, test both Cancel options before deleting a disposable account. Confirm its Auth account, related records, and pictures are removed while another account's data remains intact.

Profile pictures are publicly readable by URL. Account deletion covers the app's configured records and picture folder; it does not immediately erase backups or logs. New user-owned tables will need to be added to the deletion cleanup.

Our Trello board tracks sprint roles, assignments, estimates, OKRs, and upcoming work. Priorities include calendar connections, reminders, discovery, AI automation, usage tracking, and improvements from our design feedback. Keep the feature table updated as this work is completed.
