# Matchpoint data update (runbook)

Run from the Claude chat that owns this repo, every 2 hours from 08:35 to 22:35 (Europe/Zurich).
The website reads everything in `data/`; never touch user accounts or teams (those live in Supabase).
Never invent results, stats or odds: leave a field null if you can't find it.

## 1. Sync
`cd /home/claude/matchpoint-site` (if missing: `git clone https://github.com/studerlionel-commits/Matchpoint /home/claude/matchpoint-site`), then `git pull --rebase origin main`.
Read `data/index.json`, every `data/tourneys/<id>.json`, and `data/status.json`.

## 2. Which tournaments
ATP men's singles: the 4 Grand Slams (category "Grand Slam", vp 2), all Masters 1000 (vp 1), all ATP 500 (vp 1), the ATP Finals (vp 1). id = `<city-slug>-<year>`.
- Add any such tournament starting within 10 days that has no file (status "upcoming", players [] until the entry list is out) and list its id in `data/index.json`.
- Fill players for an "upcoming" file once its entry list is published (status "pre-draw").

## 3. Update every tournament that isn't finished
Use WebSearch/WebFetch (the shell can't reach these sites).
- **News check:** "<tournament> <year> withdraws / wildcard / draw / qualifiers / order of play". Ignore articles from other years.
- **Draws:** atptour.com draw pages often show only qualifying; spaziotennis.com "Tabellone ATP …" and tennisworlditalia list full draws. Add all first-round matches as soon as the draw is out (that opens the draft).
- **Qualifiers / lucky losers:** replace placeholder players (ids q1, q2 …, status "tbd") with the real player: new id = surname slug, tag "Q" or "LL", fresh `prices`, status "entered", and change the placeholder id in `matches[]` too.
- **Order of play:** set `match.start` (ISO UTC) from the official schedule. For "followed by"/"not before" slots estimate EARLY (~90 min per earlier match on that court). Once a match has begun or ended, set the real start time if any source gives it and status "live"/"done". Players lock individually at `start`; a match with start null locks at its round's `lock`.
- **Results:** winner, `sets` [[gamesA,gamesB],…] (tiebreak sets as 7-6), `ret`/`wo`, `stats` {a:{aces,df,ue},b:{…}} (ue only at Grand Slams). Loser status "out", winner "in". Add next-round matches as soon as both players are known. ATP Finals: players stay "in" after group losses until eliminated.
- **Odds:** Polymarket gamma API via WebFetch (`/public-search?q=<city>`, `/events?tag_slug=atp&closed=false&limit=100`). Match moneyline → `odds {a,b}` before the match starts; never change after.

## 4. Prices (relative to each field)
Only for alive players whose next match hasn't started. s = normalized Polymarket title probability (floor 0.002) if a winner market exists, else rank^-0.9 × (2 × next-match win probability, or 1). x = (ln s − ln s_min)/(ln s_max − ln s_min); price = round(6 + 24·x^1.3).
**Price history rule:** never edit or delete `prices[]` entries. When a price changes, set `price` and append `{"from": "<ISO UTC now>", "price": <new>}`. The site only accepts a bought player at a price he really had.

## 5. Status, validate, push
- `data/status.json` = {"lastRun": "<ISO UTC now>", "by": "updater (in chat)", "summary": "<what changed / what was checked / errors>"} — every run.
- Validate: every JSON parses; each pre-draw/live field has exactly `drawSize` non-withdrawn players; every match player id exists in `players`.
- Commit as Claude <noreply@anthropic.com>: "Data update <YYYY-MM-DD HH:MM> UTC: <summary>", push to main.
- Keep Supabase awake: WebFetch `https://voilkvlecosxeugzzrja.supabase.co/rest/v1/entries?select=team&limit=1&apikey=sb_publishable_agbtM7bofr0goXi_N-CAYQ_raMlvtgX`.

## 6. Schedule the next run
Use send_later for the next slot (08:35, 10:35, …, 22:35 Europe/Zurich; after 22:35 → 08:35 next day) with the message "Matchpoint data update: follow UPDATER.md in the Matchpoint repo, then schedule the next run." Reply to Lionel with one short line only, unless something needs his attention.
