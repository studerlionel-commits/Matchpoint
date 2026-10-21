# Matchpoint Fantasy

A season-long tennis fantasy league. For every Grand Slam, Masters 1000, ATP 500 and the ATP Finals you pick 5 players with 100 credits, give one of them ×2, and make one transfer per round. Winning a tournament's league earns victory points (2 for a Grand Slam, 1 otherwise), plus 1 for the most fantasy points over the season.

## How it fits together

- **Website**: `index.html`, a static page hosted on GitHub Pages.
- **Accounts and teams**: Supabase (email + password login). Settings live in `config.js`; the table and its security rules are in `supabase/schema.sql`.
- **Tournament data**: `data/index.json` (season + list of tournaments) and `data/tourneys/<id>.json` (field, prices, draw, results, match stats, Polymarket odds). A scheduled Claude task updates these files several times a day and pushes them here; GitHub Pages republishes within a minute or two.

## Anti-cheat

The database stamps every saved lineup with the server time (`savedAt`). A lineup only counts for a round if it was saved before that round's lock, and saved lineups can't be deleted.
