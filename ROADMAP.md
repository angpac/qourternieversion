# Qourt — Roadmap / Deferred Work

Things deliberately scoped out of a feature when it was built, kept here instead of lost in chat. Not a backlog of bugs — see `TESTING_CHECKLIST.md` for that.

## Clubs

- **Persistent club member roster.** Clubs and club admins exist (`clubs`, `club_admins` tables; an admin who joins a club automatically admins every game under it). What's still missing: a `club_members` table so regulars are tracked once at the club level instead of rejoining by code/QR for every single game. Once that exists, a new game under a club could auto-populate its queue from the club's member list instead of starting empty.
- **Multi-sport.** `clubs.sports` is already a free-form array (not locked to badminton), and most rotation formats (King of the Court, Peg Board, Challenge Court, etc.) are sport-agnostic mechanics already. What's still badminton-specific: terminology ("court," doubles/singles), and default point targets. Worth revisiting once a second sport is actually being run through the app.

## Live Activities

- **Full background live-updating.** Only match-assignment ("you're up!") pushes a Live Activity update while the app is backgrounded — that's the one moment wired into the existing `match_assigned` DB trigger/Edge Function path. Queue position changing as others join/leave, and live score changes during a match, currently only update the activity while the player's own app happens to be in the foreground (ActivityKit's local update path). To make those live in the background too would need new DB triggers on `game_players` (queue position/status changes) and `matches` (score changes) that call the same Edge Function, sending Live Activity push updates the same way match-assignment already does.
- **Reliable end-of-activity cleanup.** The activity ends when the player's own status changes to resting/removed/pending (via the client), but there's no explicit handling for "the game itself ended while I was still queued/on court" — it'll eventually go stale and ActivityKit auto-expires it, but nothing proactively ends it in that case.
