-- Matchpoint Fantasy: per-player locks.
-- Every save of a round's lineup is kept (oldest first) in that lineup's "history", stamped by the server.
-- The site replays these versions and ignores any change that touched a player after his match started.
-- Paste into Supabase → SQL Editor → New query → Run. Safe to run again.

create or replace function public.stamp_lineups() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  t text; r text; newl jsonb; oldl jsonb; hist jsonb;
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
        newl := (new.leagues -> t -> 'lineups' -> r) - 'savedAt' - 'history';
        oldl := case when tg_op = 'UPDATE' then old.leagues -> t -> 'lineups' -> r else null end;
        if oldl is null then
          newl := newl || jsonb_build_object('savedAt', to_jsonb(now()), 'history', '[]'::jsonb);
        elsif newl is distinct from (oldl - 'savedAt' - 'history') then
          -- changed: archive the previous version (with its own server time) and stamp the new one
          hist := coalesce(oldl -> 'history', '[]'::jsonb) || jsonb_build_array(oldl - 'history');
          newl := newl || jsonb_build_object('savedAt', to_jsonb(now()), 'history', hist);
        else
          -- unchanged: keep the server's previous stamp and history, whatever the client sent
          newl := oldl;
        end if;
        new.leagues := jsonb_set(new.leagues, array[t, 'lineups', r], newl);
      end loop;
    end if;
  end loop;
  new.updated_at := now();
  return new;
end $$;
