-- Student Scheduler: Supabase schema
-- Run this whole file once in Supabase: SQL Editor > New query > paste > Run.
-- Also turn OFF "Confirm email": Authentication > Providers > Email.

-- ---------- Tables ----------
create table public.profiles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  username   text unique not null,
  name       text not null default '',
  school     text not null default 'BYU',
  work       text not null default '',
  age        int,
  gender     text not null default '',
  major      text not null default '',
  photo      text not null default '',
  created_at timestamptz not null default now()
);

create table public.settings (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  notifications boolean not null default true,
  default_view  text    not null default 'day' check (default_view in ('day','week','month')),
  week_start    int     not null default 1 check (week_start in (0,1)),   -- 1 = Monday, 0 = Sunday
  theme         text    not null default 'royal' check (theme in ('royal','dark','forest','plum')),
  suggestions   boolean not null default true
);

create table public.interests (
  user_id  uuid not null references auth.users(id) on delete cascade,
  interest text not null,
  primary key (user_id, interest)
);

create table public.tasks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null,
  due_date    date not null,
  type        text not null default 'school' check (type in ('school','work','church','social','personal','career')),
  priority    smallint not null default 2 check (priority between 1 and 3),  -- 1 Urgent, 2 Standard, 3 Flexible
  description text not null default '',
  is_complete boolean not null default false,
  source      text,                                                           -- 'canvas' | 'workday' | 'other' when imported
  created_at  timestamptz not null default now()
);

create table public.events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title       text not null,
  event_date  date not null,
  start_time  time,
  end_time    time,
  location    text not null default '',
  type        text not null default 'social' check (type in ('school','work','church','social','personal','career')),
  priority    smallint not null default 2 check (priority between 1 and 3),
  description text not null default '',
  source      text,
  created_at  timestamptz not null default now()
);

create table public.linked_accounts (
  user_id   uuid not null references auth.users(id) on delete cascade,
  provider  text not null check (provider in ('canvas','workday','other')),
  is_linked boolean not null default true,
  primary key (user_id, provider)
);

-- Shared catalog of campus events shown on the Discovery page
create table public.discovery_events (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  event_date  date not null,
  start_time  time,
  end_time    time,
  category    text not null check (category in ('school','social','career')),
  location    text not null default '',
  description text not null default '',
  tags        text[] not null default '{}'   -- matched against a user's interests for "For You"
);

create index on public.tasks  (user_id, due_date);
create index on public.events (user_id, event_date);

-- ---------- Row Level Security: each user only sees their own rows ----------
alter table public.profiles         enable row level security;
alter table public.settings         enable row level security;
alter table public.interests        enable row level security;
alter table public.tasks            enable row level security;
alter table public.events           enable row level security;
alter table public.linked_accounts  enable row level security;
alter table public.discovery_events enable row level security;

create policy "own rows" on public.profiles        for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.settings        for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.interests       for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.tasks           for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.events          for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own rows" on public.linked_accounts for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "read catalog" on public.discovery_events for select to authenticated using (true);

-- ---------- Auto-create profile + settings when someone signs up ----------
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (user_id, username, name)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
          coalesce(new.raw_user_meta_data->>'username', ''));
  insert into public.settings (user_id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------- Sample Discovery events (dates are relative to the day you run this) ----------
insert into public.discovery_events (title, event_date, start_time, end_time, category, location, description, tags) values
 ('IS Career Fair',        current_date + 1, '13:00', '15:00', 'career', 'Wilk Ballroom',     'Meet employers hiring IS majors.',     '{career,business}'),
 ('AI in Business Club',   current_date + 3, '19:00', '20:00', 'career', 'TNRB 150',          'Guest speaker on AI in industry.',     '{career,ai}'),
 ('BYU Soccer Game',       current_date,     '19:00', '21:00', 'social', 'South Field',       'Home match under the lights.',         '{sports,social}'),
 ('Resume Workshop',       current_date + 2, '16:00', '17:00', 'career', 'Career Center',     'Polish your resume for recruiters.',   '{career}'),
 ('Campus Devotional',     current_date + 2, '11:00', '12:00', 'school', 'Marriott Center',   'Weekly campus devotional.',            '{faith}'),
 ('Study Skills Seminar',  current_date + 4, '12:00', '13:00', 'school', 'Library 3rd Floor', 'Midterm prep strategies.',              '{school}'),
 ('Ward Game Night',       current_date + 5, '19:30', '21:30', 'social', 'Stake Center',      'Board games and snacks.',              '{social,games}');
