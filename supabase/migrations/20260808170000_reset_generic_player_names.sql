-- Pre-fix, every sign-in overwrote display_name with the "Player" fallback
-- whenever Apple didn't share a name (i.e. every sign-in after the first).
-- Clear that placeholder so affected accounts see the new name-setup step
-- instead of being stuck with a name they never actually chose.
update profiles set display_name = '' where display_name = 'Player';
