-- The Daily Blend: combined scheduler upgrades
-- Run the WHOLE file in Supabase SQL Editor against the existing team schema.
-- This is not an empty-database bootstrap. Export a backup first.
-- Replaces policies on the named scheduler tables; review any custom policies first.
-- No accounts or app rows are deleted by installation.
-- One transaction: either all upgrades commit, or all changes roll back.
BEGIN;

-- Accounts, profile pictures, and ownership policies
-- Existing test accounts and their data remain, but are NOT claimed by new signups.
-- Only public.user, settings, interests, tasks, events and to-do are changed.
-- Existing policies on these tables are replaced so broad old policies cannot bypass ownership.

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

-- Date of birth
-- Existing numeric ages cannot reveal an exact birthday and are left untouched.

alter table public."user"
  add column if not exists birth_date date;

-- Earlier setup granted access column-by-column: include the new column.
grant select (birth_date), insert (birth_date), update (birth_date)
  on public."user" to authenticated;

-- Keep existing rows, RLS and account-deletion protections unchanged.
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public."user"'::regclass
      and conname = 'scheduler_birth_date_not_future'
  ) then
    alter table public."user"
      add constraint scheduler_birth_date_not_future
      check (birth_date is null or birth_date <= current_date) not valid;
  end if;
end;
$$;

notify pgrst, 'reload schema';

-- Account deletion protections and cleanup
-- Installing this script does not delete any accounts or rows.
-- It installs transactional app-data cleanup when an Auth user is deleted.

create or replace function public.scheduler_account_active()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1 from auth.users where id = auth.uid()
  );
$$;
revoke all on function public.scheduler_account_active() from public, anon;
grant execute on function public.scheduler_account_active() to authenticated;

-- A deleted user's outstanding JWT must not be able to recreate their rows.
-- Restrictive policies are ANDed with the existing owner policies.
do $$
declare
  target record;
begin
  for target in
    select tablename from pg_tables
    where schemaname = 'public'
      and lower(tablename) in (
        'user', 'settings', 'interests', 'tasks', 'events',
        'to-do', 'to_do', 'todo'
      )
  loop
    execute format(
      'drop policy if exists scheduler_active_account on public.%I',
      target.tablename
    );
    execute format(
      'create policy scheduler_active_account on public.%I '
      'as restrictive for all to authenticated '
      'using ((select public.scheduler_account_active())) '
      'with check ((select public.scheduler_account_active()))',
      target.tablename
    );
  end loop;
end;
$$;

drop policy if exists scheduler_active_picture_account on storage.objects;
create policy scheduler_active_picture_account on storage.objects
as restrictive for all to authenticated
using (
  bucket_id <> 'profile-pictures'
  or (select public.scheduler_account_active())
)
with check (
  bucket_id <> 'profile-pictures'
  or (select public.scheduler_account_active())
);

create or replace function public.scheduler_cleanup_deleted_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  target record;
  user_column text;
  task_table text;
  task_key text;
  task_owner text;
  todo_key text;
begin
  -- Resolve upper/lower-case names as the HTML data layer does.
  select tablename into strict task_table
  from pg_tables
  where schemaname = 'public' and lower(tablename) = 'tasks';

  select column_name into strict task_key
  from information_schema.columns
  where table_schema = 'public' and table_name = task_table
    and lower(column_name) = 'task_id';

  select column_name into strict task_owner
  from information_schema.columns
  where table_schema = 'public' and table_name = task_table
    and lower(column_name) = 'user_id';

  -- To-do entries depend on task IDs, so remove them before their parent tasks.
  for target in
    select tablename from pg_tables
    where schemaname = 'public'
      and lower(tablename) in ('to-do', 'to_do', 'todo')
  loop
    select column_name into strict todo_key
    from information_schema.columns
    where table_schema = 'public' and table_name = target.tablename
      and lower(column_name) = 'task_id';

    execute format(
      'delete from public.%I as todo using public.%I as task '
      'where todo.%I = task.%I and task.%I = $1',
      target.tablename, task_table, todo_key, task_key, task_owner
    ) using old.id;
  end loop;

  -- Delete children first and the public profile last. Never delete other users.
  for target in
    select tablename from pg_tables
    where schemaname = 'public'
      and lower(tablename) in ('settings', 'interests', 'events', 'tasks', 'user')
    order by case lower(tablename)
      when 'settings' then 1
      when 'interests' then 2
      when 'events' then 3
      when 'tasks' then 4
      when 'user' then 5
    end
  loop
    select column_name into strict user_column
    from information_schema.columns
    where table_schema = 'public' and table_name = target.tablename
      and lower(column_name) = 'user_id';

    execute format(
      'delete from public.%I where %I = $1',
      target.tablename, user_column
    ) using old.id;
  end loop;

  return old;
end;
$$;
revoke all on function public.scheduler_cleanup_deleted_user()
  from public, anon, authenticated;

drop trigger if exists scheduler_cleanup_before_auth_delete on auth.users;
create trigger scheduler_cleanup_before_auth_delete
before delete on auth.users
for each row execute function public.scheduler_cleanup_deleted_user();

-- The Edge Function checks this before it removes any pictures.
create or replace function public.scheduler_delete_preflight()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select exists (
    select 1
    from pg_trigger as trigger
    join pg_proc as routine on routine.oid = trigger.tgfoid
    join pg_namespace as namespace on namespace.oid = routine.pronamespace
    where trigger.tgrelid = 'auth.users'::regclass
      and trigger.tgname = 'scheduler_cleanup_before_auth_delete'
      and trigger.tgenabled in ('O', 'A')
      and routine.proname = 'scheduler_cleanup_deleted_user'
      and namespace.nspname = 'public'
  );
$$;
revoke all on function public.scheduler_delete_preflight()
  from public, anon, authenticated;
grant execute on function public.scheduler_delete_preflight() to service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
