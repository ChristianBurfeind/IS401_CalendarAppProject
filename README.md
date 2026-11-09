[README.md](https://github.com/user-attachments/files/34565573/README-2.md)
# The Daily Blend

**BYU · IS 401 · Section 01 · Group 4**

Christian Burfeind, Nina Freeman, Addison Laker, Myles Madarieta

The Daily Blend is a web calendar for BYU students balancing school, work, church responsibilities, and social life. It brings tasks and events together to help students stay organized and feel accomplished.

The app is still in development. External calendar connections, activity discovery, reminders, and personalized suggestions are not yet complete.

## Project information

- **Live website:** [The Daily Blend](https://christianburfeind.github.io/IS401_CalendarAppProject/#login)
- **Trello board:** [Calendar Organizer · Group 4](https://trello.com/invite/b/6adf6df4f46fb08f117cf9ba/ATTI75b722587a81655ed2712b7e82219e803598B143/calendar-organizer-group-1-4)

## Features and progress

**Complete** features have passed the tests described in the notes. **Not complete** means development or end-to-end verification remains. Some unfinished features have interface and logic in place but still depend on backend setup or testing.

| Behavioral requirement | Status | Notes |
| --- | --- | --- |
| Create an account, confirm an email address, and log in. | Complete | Previously tested with Supabase. Signup validates the name, email, password, and optional fields. |
| Stay signed in after refreshing and log out when finished. | Complete | Previously tested across refreshes and reopening the app. |
| Edit and save personal profile information. | Complete | Previously tested; field character limits and name validation are in place. |
| Choose an avatar or upload, crop, and save a profile picture. | Complete | Supports avatar selection, file selection, drag and drop, cropping, and saving. |
| Save a birth date, see a calculated age, and receive an in-app birthday greeting. | Not complete | The age and greeting logic is implemented; saving and birthday display still need verification on the current live site. |
| Delete an account after two confirmation prompts. | Complete | Account deletion was tested with Supabase. Confirm related records and pictures during final release checks. |
| Add, edit, and delete events with dates, times, locations, and descriptions. | Not complete | The interface includes these actions, plus all-day and repeating events. Saved-data behavior needs verification against the current database schema. |
| View saved events in day, week, and month calendars. | Not complete | The three views and all-day event row are implemented. The day view starts at 6 a.m. by default and runs through midnight; confirm the intended full-day range and verify saved data. |
| Add tasks and mark them complete. | Not complete | Task creation and completion code is present; saving and persistence need verification. |
| Navigate between Calendar, To-Do, and Discovery using mobile bottom navigation. | Not complete | The bottom navigation is implemented; full mobile layout checks are pending. |
| Organize tasks and events by category and priority. | Not complete | Priority controls and custom types are present in the interface. The included SQL restricts task/event types to a fixed list, so saving custom types requires a compatible schema change. |
| Connect Canvas, Learning Suite, Workday, and another calendar. | Not complete | Canvas and Learning Suite feed-link and refresh controls are present in Settings; the Profile connection buttons remain placeholders. Importing depends on backend setup not included in this zip. Workday and other connections remain future work. |
| Receive homework reminders 24 hours before deadlines and social-event reminders four hours beforehand. | Not complete | The Summary page shows on-screen prompts for school tasks due today or tomorrow and social events starting within four hours that day. Scheduled, email, or browser notification delivery is not implemented. |
| Find, filter, and add relevant activities from Discover. | Not complete | Discover currently shows an empty state; real event sources, filtering, and saving are not implemented. |
| Receive notifications about newly posted events matching interests or major. | Not complete | Event matching and notification delivery are not implemented. |
| Save interests and settings that personalize the app. | Not complete | Profile interests and settings have save/load code; persistence and personalization need verification on the current site. |
| Keep the suggestions control available without sample suggestions. | Complete | Sample suggestions are absent, and the suggestions control remains in Settings for future use. |
| Use an AI workflow automation. | Not complete | Define and build the team's selected workflow. |
| Automatically track behavior for the team's four Key Results. | Not complete | Finalize the Key Results and implement automatic data tracking. |

Update this table as features pass end-to-end checks on the current version.

## Technology

- **Frontend:** HTML, CSS, and JavaScript
- **Backend and database:** Supabase with PostgreSQL
- **Accounts:** Supabase Auth
- **Profile pictures:** Supabase Storage
- **Account deletion:** Supabase Edge Function named `delete-account`

Passwords are handled by Supabase Auth. The setup script applies Row Level Security (RLS) policies to restrict access to users' own records in the tables it manages.

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

Detailed instructions are in `START-HERE.md` and `DELETE-ACCOUNT-SETUP.md`.

Use the team's current Supabase project and follow `START-HERE.md`. **`scheduler-setup.sql`** installs the account/profile, birthday, and account-deletion upgrades and can create missing core scheduler tables on the expected schema. It is not a migration for the legacy `profiles/id` schema. It supports reapplication on the expected schema, but replaces policies on the named tables, so review any team-added policies first. Do not run the legacy `setup.sql` afterward.

The frontend expects `calendars`, `calendar_connections`, and `scheduler_types` tables, `calendar_id` and all-day/repeating-event columns, and an `import-calendar` Edge Function. These are not created or included by this archive's setup files. If they are not already deployed in the team project, task/event persistence and calendar imports will need additional setup before they can be verified.

The account-deletion function source is `index.ts` at the project root; deploy it as `delete-account` following `DELETE-ACCOUNT-SETUP.md`. The guide refers to a nested source path that is not present in this archive, so use the included root-level `index.ts`. Its CLI instructions also reference `supabase/config.toml`, while the included `config.toml` is at the project root; use the dashboard deployment steps unless your team places the config in the expected CLI folder. Set Supabase Authentication's Site URL and allowed redirect URLs for the app's hosting/testing addresses. Keep privileged account-deletion credentials on the server.

## Definition of Done

Before marking the release Done, the team checks that:

- Pages look good and work on desktop and mobile.
- Features work from the user interface through Supabase to the database, and saved changes survive a refresh.
- Lighthouse Accessibility scores are **90 or higher** for the current version's relevant pages.
- This README lists behavioral requirements as Complete or Not complete.
- Code is merged into `main`.
- The latest changes are available at a public website URL.

Final release verification is still pending for desktop/mobile layouts, full end-to-end flows, Lighthouse, the merge to `main`, and confirming the public website has the latest changes.

## Testing and next steps

Use test accounts for any remaining end-to-end checks of signup/login, profile edits, picture uploads, tasks/events, settings, and data persistence. For deletion, test both Cancel options before deleting a disposable account. Confirm its Auth account, related records, and pictures are removed while another account's data remains intact.

Profile pictures are publicly readable by URL. Account deletion removes the profile, settings, interests, tasks, events, to-do status, and profile-picture folder. It does not immediately erase backups or logs. New user-owned tables must be added to the deletion cleanup.

The Trello board tracks sprint roles, assignments, estimates, OKRs, and upcoming work. Priorities include calendar connections, reminders, discovery, AI automation, usage tracking, and improvements from design feedback.
