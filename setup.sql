-- One-time setup for the Student Scheduler app. Paste into Supabase > SQL Editor > Run.
-- It does NOT delete anything. It only:
--   1) adds a "User_ID" column to your Tasks and Events tables (so each task/event
--      belongs to a user; your ERD currently has no way to say whose they are), and
--   2) turns off Row Level Security so the app can read/write your tables while you test.

do $$
declare t record;
begin
  for t in select tablename from pg_tables
           where schemaname = 'public' and lower(tablename) in ('tasks', 'events') loop
    execute format('alter table public.%I add column if not exists "User_ID" int', t.tablename);
  end loop;

  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I disable row level security', t.tablename);
  end loop;
end $$;
