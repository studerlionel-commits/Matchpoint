-- Matchpoint Fantasy: accounts' teams.
-- Paste this whole file into Supabase → SQL Editor → New query → Run. Safe to run again.

create table if not exists public.entries (
  user_id    uuid primary key references auth.users on delete cascade,
  team       text not null check (char_length(team) between 1 and 32),
  leagues    jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.entries enable row level security;

drop policy if exists "Anyone can read teams" on public.entries;
create policy "Anyone can read teams" on public.entries
  for select to anon, authenticated using (true);

drop policy if exists "Users create their own entry" on public.entries;
create policy "Users create their own entry" on public.entries
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists "Users edit their own entry" on public.entries;
create policy "Users edit their own entry" on public.entries
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Anti-cheat: the server stamps every lineup with the time it was really saved (savedAt).
-- The site only counts a lineup for a round if it was saved before that round locked,
-- and a lineup can never be deleted once saved.
create or replace function public.stamp_lineups() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  t text; r text; newl jsonb; oldl jsonb;
begin
  new.leagues := coalesce(new.leagues, '{}'::jsonb);
  if tg_op = 'UPDATE' then
    -- put back any tournament or round that the update tried to remove
    for t in select jsonb_object_keys(coalesce(old.leagues, '{}'::jsonb)) loop
      if new.leagues -> t is null then
        new.leagues := jsonb_set(new.leagues, array[t], old.leagues -> t);
      end if;
      for r in select jsonb_object_keys(coalesce(old.leagues -> t -> 'lineups', '{}'::jsonb)) loop
        if new.leagues -> t -> 'lineups' -> r is null then
          if new.leagues -> t -> 'lineups' is null then
            new.leagues := jsonb_set(new.leagues, array[t, 'lineups'], '{}'::jsonb);
          end if;
          new.leagues := jsonb_set(new.leagues, array[t, 'lineups', r], old.leagues -> t -> 'lineups' -> r);
        end if;
      end loop;
    end loop;
  end if;
  for t in select jsonb_object_keys(new.leagues) loop
    if jsonb_typeof(new.leagues -> t -> 'lineups') = 'object' then
      for r in select jsonb_object_keys(new.leagues -> t -> 'lineups') loop
        newl := new.leagues -> t -> 'lineups' -> r;
        oldl := case when tg_op = 'UPDATE' then old.leagues -> t -> 'lineups' -> r else null end;
        if oldl is null or (newl - 'savedAt') is distinct from (oldl - 'savedAt') then
          new.leagues := jsonb_set(new.leagues, array[t, 'lineups', r, 'savedAt'], to_jsonb(now()));
        else
          new.leagues := jsonb_set(new.leagues, array[t, 'lineups', r, 'savedAt'], coalesce(oldl -> 'savedAt', to_jsonb(now())));
        end if;
      end loop;
    end if;
  end loop;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists stamp_lineups on public.entries;
create trigger stamp_lineups before insert or update on public.entries
  for each row execute function public.stamp_lineups();
