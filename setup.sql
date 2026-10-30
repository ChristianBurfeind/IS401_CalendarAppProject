-- One-time setup for the Student Scheduler app. Paste into Supabase > SQL Editor > Run.
-- Safe to run more than once. It deletes no rows. It only:
--   1) removes any link between your tables and Supabase's built-in login system
--      (auth.users). The app keeps its own accounts in the User table, so IDs it creates
--      aren't in auth.users and would be rejected otherwise.
--   2) makes sure Tasks and Events each have a "User_ID" column whose type matches
--      your User table's user_id (uuid or number). If an earlier run created it with
--      the wrong type, that one column is converted and its values cleared.
--   3) removes "check" rules on your tables' columns (for example a rule that Default_View
--      must be one of a fixed list). The app writes its own values, and any mismatch would
--      be rejected one column at a time.
--   4) turns off Row Level Security so the app can read/write your tables while you test.

begin;

alter table public."user"
add column if not exists photo_path text;

alter table public."user"
add column if not exists avatar_id text;

-- Passwords are handled exclusively by Supabase Auth. Keep old values inaccessible.
alter table public."user"
alter column password
drop not null;

do $$
declare t record;
col text;
pol record;
cols text;
task_table text;
task_pk text;
task_uid text;
todo_pk text;
begin
    select tablename
    into strict task_table
    from pg_tables
    where schemaname='public' and lower(tablename)='tasks';
    select column_name
    into strict task_pk
    from information_schema.columns
    where table_schema='public' and table_name=task_table and lower(column_name)='task_id';
    select column_name
    into strict task_uid
    from information_schema.columns
    where table_schema='public' and table_name=task_table and lower(column_name)='user_id';
    for t in select tablename
    from pg_tables
    where schemaname='public' and lower(tablename) in ('user','settings','interests','tasks','events','to-do','to_do','todo')
    loop
        execute format('alter table public.%I enable row level security',
        t.tablename);
        for pol in select policyname
        from pg_policies
        where schemaname='public' and tablename=t.tablename
        loop
            execute format('drop policy %I on public.%I',
            pol.policyname,
            t.tablename);
            end
            loop;
            execute format('revoke all on public.%I from anon, authenticated',
            t.tablename);
            if lower(t.tablename)='user'
            then
                -- Column grants also keep legacy password hashes out of API responses.
                select string_agg(format('%I',
                column_name),',')
                into cols
                from information_schema.columns
                where table_schema='public' and table_name=t.tablename and column_name<>'password';
                execute format('grant select (%s), insert (%s), update (%s) on public.%I to authenticated',
                cols,
                cols,
                cols,
                t.tablename);
                execute format('create policy scheduler_owner on public.%I for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid())',
                t.tablename);
            elsif lower(t.tablename) in ('to-do','to_do','todo')
            then
                select column_name
                into strict todo_pk
                from information_schema.columns
                where table_schema='public' and table_name=t.tablename and lower(column_name)='task_id';
                execute format('grant select,insert,update,delete on public.%I to authenticated',
                t.tablename);
                execute format('create policy scheduler_owner on public.%I for all to authenticated using (exists(select 1 from public.%I task where task.%I=%I.%I and task.%I=auth.uid())) with check (exists(select 1 from public.%I task where task.%I=%I.%I and task.%I=auth.uid()))',
                t.tablename,
                task_table,
                task_pk,
                t.tablename,
                todo_pk,
                task_uid,
                task_table,
                task_pk,
                t.tablename,
                todo_pk,
                task_uid);
            else
                select column_name
                into strict col
                from information_schema.columns
                where table_schema='public' and table_name=t.tablename and lower(column_name)='user_id';
                execute format('grant select,insert,update,delete on public.%I to authenticated',
                t.tablename);
                execute format('create policy scheduler_owner on public.%I for all to authenticated using (%I=auth.uid()) with check (%I=auth.uid())',
                t.tablename,
                col,
                col);
            end if;
            end
            loop;
            -- Allow inserts that use existing serial/identity sequences for these tables only.
            for t in select distinct pg_get_serial_sequence(format('%I.%I',
            table_schema,
            table_name),
            column_name) as seq
            from information_schema.columns
            where table_schema='public' and lower(table_name) in ('user','settings','interests','tasks','events','to-do','to_do','todo')
            loop
                if t.seq is not null
                then execute format('grant usage,select on sequence %s to authenticated',
                t.seq);
            end if;
            end
            loop;
end $$;

insert into
  storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
  )
values
  (
    'profile-pictures',
    'profile-pictures',
    true,
    5242880,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update
set
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- Public means anyone with an image URL can view it. Writes remain owner-only.
drop policy if exists scheduler_picture_insert on storage.objects;

drop policy if exists scheduler_picture_select on storage.objects;

drop policy if exists scheduler_picture_delete on storage.objects;

create policy scheduler_picture_insert on storage.objects for insert to authenticated
with
  check (
    bucket_id = 'profile-pictures'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy scheduler_picture_select on storage.objects for
select
  to authenticated using (
    bucket_id = 'profile-pictures'
    and (storage.foldername (name)) [1] = auth.uid ()::text
  );

create policy scheduler_picture_delete on storage.objects for delete to authenticated using (
  bucket_id = 'profile-pictures'
  and (storage.foldername (name)) [1] = auth.uid ()::text
);

commit;
