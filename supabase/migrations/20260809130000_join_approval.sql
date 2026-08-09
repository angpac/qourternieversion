-- games.requires_approval has existed in the schema since the start but was
-- never wired to anything — no join flow checked it, so admins had no way
-- to actually gate who joins their game. This adds a real "pending"
-- approval step: when a game requires approval, new joiners land in a
-- pending state (no queue position) until an admin approves or rejects
-- them via the existing "admins manage roster" RLS policy (no new RPC
-- needed for that side — it's a plain update, same as pause/remove).
alter type player_status add value if not exists 'pending';
