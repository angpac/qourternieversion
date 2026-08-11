-- A fully manual format for admins who just want to build every match by
-- hand from the queue, no automatic pairing/rotation algorithm at all —
-- distinct from the "manually match players" toggle other formats have,
-- which is optional and overridable; this format is always manual.
alter type rotation_format add value if not exists 'manual';
