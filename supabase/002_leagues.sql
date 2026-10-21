-- Matchpoint Fantasy: private leagues.
-- Paste into Supabase → SQL Editor → New query → Run. Safe to run again.

create table if not exists public.leagues (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (char_length(name) between 1 and 40),
  code       text not null unique default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)),
  owner      uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.league_members (
  league_id uuid not null references public.leagues on delete cascade,
  user_id   uuid not null references auth.users on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

alter table public.leagues enable row level security;
alter table public.league_members enable row level security;

-- helper that checks membership without tripping over the members table's own rules
create or replace function public.is_league_member(l uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.league_members where league_id = l and user_id = auth.uid())
$$;

drop policy if exists "Members see their leagues" on public.leagues;
create policy "Members see their leagues" on public.leagues
  for select to authenticated using (owner = auth.uid() or public.is_league_member(id));

drop policy if exists "Anyone logged in can create a league" on public.leagues;
create policy "Anyone logged in can create a league" on public.leagues
  for insert to authenticated with check (owner = auth.uid());

drop policy if exists "Owner can rename" on public.leagues;
create policy "Owner can rename" on public.leagues
  for update to authenticated using (owner = auth.uid()) with check (owner = auth.uid());

drop policy if exists "Owner can delete" on public.leagues;
create policy "Owner can delete" on public.leagues
  for delete to authenticated using (owner = auth.uid());

drop policy if exists "Members see fellow members" on public.league_members;
create policy "Members see fellow members" on public.league_members
  for select to authenticated using (public.is_league_member(league_id));

drop policy if exists "Members can leave" on public.league_members;
create policy "Members can leave" on public.league_members
  for delete to authenticated using (user_id = auth.uid());

-- the creator automatically joins their league
create or replace function public.add_league_owner() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.league_members (league_id, user_id) values (new.id, new.owner) on conflict do nothing;
  return new;
end $$;

drop trigger if exists add_league_owner on public.leagues;
create trigger add_league_owner after insert on public.leagues
  for each row execute function public.add_league_owner();

-- joining only works with the invite code
create or replace function public.join_league(p_code text) returns public.leagues
language plpgsql security definer set search_path = public as $$
declare l public.leagues;
begin
  if auth.uid() is null then raise exception 'Log in first'; end if;
  select * into l from public.leagues where code = upper(trim(p_code));
  if not found then raise exception 'No league with that code'; end if;
  insert into public.league_members (league_id, user_id) values (l.id, auth.uid()) on conflict do nothing;
  return l;
end $$;

revoke all on function public.join_league(text) from public, anon;
grant execute on function public.join_league(text) to authenticated;
