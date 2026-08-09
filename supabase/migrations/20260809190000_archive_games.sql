-- Lets an admin tidy up My Games without losing anything — archiving only
-- hides a game from the default list; the game, its roster, matches, and
-- Game Summary stats are untouched and still reachable.
alter table games add column archived boolean not null default false;
