-- One-time setup for the Student Scheduler app. Paste into Supabase > SQL Editor > Run.
-- Safe to run more than once. It deletes no rows. It only:
--   1) removes any link between your tables and Supabase's built-in login system
--      (auth.users). The app keeps its own accounts in the User table, so IDs it creates
--      aren't in auth.users and would be rejected otherwise.
--   2) makes sure Tasks and Events each have a "User_ID" column whose type matches
--      your User table's user_id (uuid or number). If an earlier run created it with
--      the wrong type, that one column is converted and its values cleared.
--   3) turns off Row Level Security so the app can read/write your tables while you test.

do $$
declare t record; uid_type text; cur_type text; cur_name text; want text;
begin
  -- 1) drop foreign keys that point at auth.users (and the one named profiles_user_id_fkey)
  for t in
    select cl.relname as tbl, con.conname as con
      from pg_constraint con
      join pg_class cl on cl.oid = con.conrelid
      join pg_namespace n on n.oid = cl.relnamespace
      join pg_class rf on rf.oid = con.confrelid
      join pg_namespace rn on rn.oid = rf.relnamespace
     where con.contype = 'f' and n.nspname = 'public'
       and (rn.nspname = 'auth' or con.conname = 'profiles_user_id_fkey')
  loop
    execute format('alter table public.%I drop constraint %I', t.tbl, t.con);
  end loop;

  -- 2) User_ID column on Tasks and Events, same type as User.user_id
  select data_type into uid_type from information_schema.columns
   where table_schema = 'public' and lower(table_name) = 'user' and lower(column_name) = 'user_id';
  want := case when uid_type = 'uuid' then 'uuid' else 'integer' end;

  for t in select tablename from pg_tables
           where schemaname = 'public' and lower(tablename) in ('tasks', 'events') loop
    cur_name := null; cur_type := null;
    select column_name, data_type into cur_name, cur_type from information_schema.columns
     where table_schema = 'public' and table_name = t.tablename and lower(column_name) = 'user_id';
    if cur_name is null then
      execute format('alter table public.%I add column "User_ID" %s', t.tablename, want);
    elsif (cur_type = 'uuid') <> (want = 'uuid') then
      execute format('alter table public.%I alter column %I type %s using null', t.tablename, cur_name, want);
    end if;
  end loop;

  -- 3) open access for testing
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I disable row level security', t.tablename);
  end loop;
end $$;
