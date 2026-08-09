# Qourt — Testing Checklist

Running list of everything to manually verify, updated as features are built. Test on a real device where possible (Sign In With Apple, camera/QR, Watch pairing all need one).

## Push notifications (new, needs focused testing — one setup step outstanding)
- [ ] **Outstanding before iOS/Watch push can actually deliver**: create an APNs Auth Key in the Apple Developer portal (Certificates, IDs & Profiles → Keys → +, enable Apple Push Notifications service) and send the Key ID + downloaded `.p8` file — I'll set them as `APNS_KEY_ID` / `APNS_AUTH_KEY` Supabase secrets. Until then, APNs sends silently no-op (logged, not crashed); Web Push already works end-to-end since those VAPID keys are self-generated.
- [ ] First sign-in on iPhone prompts for notification permission; accepting registers a device token (check `apns_device_tokens` table has a row for that profile)
- [ ] Same on Apple Watch — registers its own separate token row for the same profile
- [ ] Web guest: "Enable notifications" button on `/status` prompts for browser permission and (once VAPID is confirmed working) creates a `push_subscriptions` row
- [ ] Admin starts a match → all 4 assigned players get a "You're up!" push (once APNs is configured) / web push, even if the app isn't in the foreground
- [ ] Admin sends an announcement to "Everyone" → every player in the game gets a push with the message
- [ ] Admin sends an announcement to a specific player → only that player gets a push
- [ ] Declining the permission prompt doesn't break anything else — app/web still fully usable without push
- [ ] King of the Court round rotation and Challenge Court/Kingminton "winner stays" refills also trigger "You're up!" for the newly-assigned players (both are just more `match_players` inserts, same trigger)

## Tournament mode (new, needs focused testing — the biggest feature this session)
- [ ] Create a game with format "Tournament — Single Elimination" or "Tournament — Double Elimination" — courts step is singles-only for tournaments (locked, not a toggle)
- [ ] Players join via the normal join code/QR before the bracket is generated — they land in the queue like any other format
- [ ] Live Dashboard for a tournament game shows "Bracket" content instead of the queue/courts grid; "Set up tournament" appears until a bracket exists
- [ ] Set up tournament → seed by skill / random / manual (drag to reorder) → "Generate bracket" locks it in
- [ ] Non-power-of-2 player counts (e.g. 5, 6, 7) get correct byes — some players skip straight to round 2 without playing round 1
- [ ] "Ready to play" section shows matches where both sides are known; tapping one lets you assign it to any open court
- [ ] Scoring a match and ending it advances the winner into the correct next-round slot automatically, live on any other admin/player device within ~2s
- [ ] **Double elimination only**: the loser of a winners-bracket match correctly drops into the losers bracket instead of being eliminated; only a losers-bracket loss (or the Grand Final) eliminates someone
- [ ] **Double elimination known limitation**: the Grand Final is a single match — if the losers-bracket finalist wins it, they're declared champion outright (no "bracket reset" second match, unlike some tournament software)
- [ ] **Known limitation**: losers-bracket dropdown pairing is index-aligned, not seeded to avoid immediate rematches — two players who already played might meet again sooner than ideal
- [ ] Once the final match is confirmed, a "Champion" banner appears for both admin and players
- [ ] Players (non-admin) see a read-only mirror of the same bracket — no start/score controls, updates live as the admin plays matches
- [ ] Ending the tournament game still works from the toolbar, and Game Summary is still reachable afterward

## QR camera scanner (new, needs focused testing — needs a real device, Simulator has no camera)
- [ ] Player → Join a game → "Scan QR code" prompts for camera permission the first time
- [ ] Pointing the camera at another device/printout showing the Invite screen's QR code auto-fills the join code and returns to the join form
- [ ] Denying camera permission shows a clear message (not a crash) with a path back to manual code entry
- [ ] Scanning works whether the code was previously granted or is granted mid-flow (the "not determined" → "authorized" transition updates the view without needing to reopen the sheet)
- [ ] Scanning a QR that encodes the full join URL (`.../join/CODE`) and a QR/text that's just the bare code both work
- [ ] Camera session actually stops when the sheet is dismissed (no lingering camera indicator/battery drain)

## My Games — Ongoing/Ended grouping + Archive (new, needs focused testing)
- [ ] Admin's My Games list is grouped into "Ongoing" and "Ended" sections instead of one flat list
- [ ] Tapping an **ongoing** game opens its live dashboard/bracket as before
- [ ] Tapping an **ended** game opens Game Summary directly, not a dead dashboard
- [ ] Swipe an ended game → "Archive" → it disappears from the Ended section and collapses into a "Show N archived games" row
- [ ] Tapping "Show archived" reveals them; swipe → "Unarchive" moves one back to the Ended section
- [ ] Archiving a game never deletes anything — its roster, matches, and Game Summary stats are all still exactly correct after archiving/unarchiving
- [ ] Player role's My Games list is unaffected (still a flat list — archiving is admin-only)
- [ ] A co-admin sees the same grouping/archive behavior as the owner for a shared game

## Templates (new, needs focused testing)
- [ ] Game Summary screen (after ending a game) → "Save this setup as a template" → prompts for a name, saves courts/format/settings (not name/date/location)
- [ ] My Games → "+" menu → "Start from a template" → shows saved templates
- [ ] Tapping a template opens Create a Game with courts, format, and rotation settings pre-filled — name/date/location still blank for the admin to fill in fresh
- [ ] Swipe-to-delete a template removes it
- [ ] Empty state shown when no templates saved yet
- [ ] Templates are per-admin — a different admin account doesn't see someone else's saved templates
- [ ] "Create a game" (not from a template) always starts from a clean, default form even after previously using a template in the same session

## Co-admin management (new, needs focused testing)
- [ ] Live Dashboard → "Co-admins" shows a share-able invite code, separate from the player join code
- [ ] A second account (signed in as Admin role) → My Games → "+" menu → "Join as co-admin" → enter the code → the game appears in their My Games list
- [ ] The co-admin can fully operate the Live Dashboard (start matches, edit roster, send announcements, end game) — same as the owner
- [ ] Owner can remove a co-admin from the "Co-admins" screen; that person loses access and the game disappears from their My Games list
- [ ] A co-admin can also open "Co-admins" and remove other co-admins (symmetric trust, same as the Roster's admin-manages-players model)
- [ ] Games created **before** this feature don't have an invite code yet (shows "—") — confirm this doesn't crash, just means no one can be invited to that specific older game
- [ ] A random/wrong invite code shows a clear error, not a crash

## Join approval (new, needs focused testing)
- [ ] Create a game with "Require approval to join" **on**
- [ ] Joining via code (iOS) or web guest lands the joiner in "Waiting for approval" — not the queue, no queue position shown
- [ ] Admin's Roster shows a "Waiting for approval" section at the top with Approve (✓) / Reject (✗) per pending player
- [ ] Approve → player moves to the back of the queue and their app/web view updates to the normal queued state within ~2s (realtime)
- [ ] Reject → player's view shows "You've left this game"; they disappear from Roster's active sections (shown under Removed)
- [ ] Pending player can "Cancel request" themselves (iOS and web) before the admin acts
- [ ] Auto-fill (see below) never pulls a pending player into a match — only actually-queued players are eligible
- [ ] Game created with approval **off** (default): joining behaves exactly as before, straight into the queue, no pending step
- [ ] **Known limitation**: a signed-in app player who cancels/gets rejected cannot re-request through the join code afterward (pre-existing behavior — `join_game_by_code` no-ops for any existing row regardless of status); admin can bring them back manually via Roster → Restore to queue. Web guests don't hit this since each guest join creates a fresh row.

## Auth & onboarding
- [ ] Sign in with Apple (fresh account) → lands on "What's your name?" if Apple didn't share a name
- [ ] Sign in with Apple (returning account) → name persists, does NOT reset to "Player"
- [ ] Choose Admin vs Play after sign-in
- [ ] Settings → edit name, edit default skill level, both persist across relaunch
- [ ] Settings → Switch Role → My Games list changes to the other role's games
- [ ] Settings → Sign out → back to Sign In screen

## Admin: Create a game
- [ ] Create a game for each of the 5 rotation formats (King of the Court, Peg Board, Four Off Four On, Challenge Court, Half-Court Kingminton)
- [ ] Rotation settings screen shows the right fields per format
- [ ] "Manually match players" toggle saves
- [ ] Courts are auto-created matching the court count chosen
- [ ] Lands on Invite Players after creation (QR, join code, share link all present)

## Admin: Auto-fill vs manual matching (new, needs focused testing)
- [ ] Game created with "Manually match players" **off** (default): as soon as enough players are queued to fill an open court, a match starts there automatically, no admin tap needed
- [ ] Auto-fill respects singles vs doubles per court (lane-split courts only pull 1 per side)
- [ ] Auto-fill works right when the game starts (courts sit empty until enough people join, then fill themselves without any admin action)
- [ ] Auto-fill works again after a match ends and there are enough waiting players for that now-open court
- [ ] Peg Board is exempt — courts never auto-fill from the queue directly; only the Picker's own pick starts a match
- [ ] Game created with "Manually match players" **on**: open courts stay open no matter how many players are queued, until the admin taps in and builds teams by hand
- [ ] With auto-fill on, admin can still tap an open court and build a custom match by hand before enough players queue up for it to auto-fill

## Admin: Live Dashboard
- [ ] Courts grid shows correct number of courts, "Open" state
- [ ] Add player (walk-in) appears in Queue immediately
- [ ] Tap open court → **Build teams** flow: pick players into Team A / Team B, Start disabled until both full
- [ ] Started match shows on court card with both team names
- [ ] Tap active court → **Court Detail**: +/- buttons update score live, visible to a player/web guest watching within ~2s
- [ ] End match → players return to back of queue
- [ ] Roster button → shows all players grouped by On court/Queue/Resting/Removed; skill level edit, pause, remove, restore all work
- [ ] Send Announcement → "Everyone" and a specific player both work; recipient sees it
- [ ] Invite Players button reopens the same QR/code/link anytime
- [ ] End Game → banner appears, join code/link/QR stop working (verify via web join attempt), "View game summary" link shows correct match/player totals
- [ ] Pull-to-refresh works
- [ ] Reconnecting banner appears when network drops (airplane mode toggle test)

## Mid-match pause/remove correctness (new, needs focused testing)
- [ ] While a player is on court in an active match, Roster → **Pause** them → when that match ends, they stay `resting` (do NOT get silently requeued)
- [ ] While a player is on court, Roster → **Remove** them → when that match ends, they stay `removed` (do NOT get silently requeued)
- [ ] Their still-on-court teammate(s)/opponents requeue normally when the match ends
- [ ] Same test on a **Challenge Court/Kingminton lane** (winner-stays): if a *winning* player is paused/removed mid-match, the court doesn't try to keep defending short-handed — it goes back to open and streak resets, remaining live winner(s) requeue
- [ ] Same test on a **King of the Court** round: if a player on a team is paused/removed before the round rotates, their team doesn't rotate onto a new court short-handed — the still-on-court teammate(s) requeue instead, court sits open that round
- [ ] A player can never self-serve Skip/Leave while actively on court (only while queued/resting) — confirms the only way to interrupt a live match is an admin action

## Admin: King of the Court round timer (new, needs focused testing)
- [ ] Round timer card appears only for King of the Court games
- [ ] "Start round" begins a live countdown matching the round length chosen at setup
- [ ] Countdown reaches 0 → auto-rotates if "auto-rotate" was left on: winner moves up a court, loser moves down, top-court winner stays, bottom-court loser stays
- [ ] "End round now" manually triggers the same rotation early
- [ ] Rotation correctly starts fresh matches on the new courts with the right teams
- [ ] Two admin devices on the same game both see the same round timer/state (realtime sync)
- [ ] **Known limitation**: if no admin dashboard is open when the timer hits 0, auto-rotation won't fire until one reopens — confirm this matches expectations, not a bug

## Admin: Half-Court Kingminton (new, needs focused testing)
- [ ] Creating a Half-Court Kingminton game creates **two lane courts per physical court** ("Court 1 · Lane A" / "Lane B"), not one
- [ ] Starting a match on a lane only asks for 1 player per side (singles), even if the game was set up as "Doubles"
- [ ] Winner stays on the lane after a win; loser returns to queue
- [ ] Next challenger is pulled from the queue automatically to fill the lane
- [ ] No win cap — winner keeps defending indefinitely (unlike Challenge Court)
- [ ] Both lanes on the same physical court operate independently (a match ending on Lane A doesn't affect Lane B)

## Admin: Challenge Court (new, needs focused testing)
- [ ] Creating a Challenge Court game marks the first court as the Challenge Court (🔥 badge appears once a streak starts)
- [ ] Winning team stays on court after a win; only the loser returns to queue
- [ ] A new challenger is automatically pulled from the front of the queue to fill the loser's spot
- [ ] Win streak counter increments correctly each defense, shown on the court card
- [ ] Hitting the win cap (2 or 3, per game setup) forces the defending team off too, even though they won — court goes back to open
- [ ] If the queue is empty, the defender just waits on an open court instead of crashing/erroring
- [ ] Confirm this only applies to the designated Challenge Court, not other courts in the same game

## Peg Board / Racket Staking (new, needs focused testing)
- [ ] Whoever is at the front of the queue sees "You're the Picker!" — only them, not anyone else
- [ ] Picker sees the next `picker_pool_size` (default 10) players in line, excluding themselves
- [ ] Picking exactly 3 and starting builds a 2v2 match (Picker + pick 1 vs pick 2 + pick 3) on the first open court
- [ ] "Start match" stays disabled until exactly 3 are picked
- [ ] If two people are queued at the very front simultaneously (race), only the true front-of-line can successfully start a match — the RPC should reject anyone else with "You are not the Picker right now"
- [ ] After the match ends, all 4 players (including the former Picker) return to the back of the line, and whoever is now at the front becomes the new Picker
- [ ] If no court is open when the Picker tries to start, they get a clear error instead of a crash
- [ ] Same behavior on web guest client as iOS (picker card + pool + team assignment)

## Player (iOS app)
- [ ] Join a game by code
- [ ] Join via a **tapped Universal Link / scanned QR** with the app installed → opens the app directly to Join (not Safari), pre-filled with the code, forces Play role
- [ ] **New**: when the code arrives pre-filled (link tap or in-app scan), the Join screen shows the actual **game name** as the headline ("Joining Sunday Open Play") with the code small underneath — not a plain-looking text field or a bare code. Confirms people no longer ask "what's the code" after scanning. "Not this game?" switches back to manual/rescan.
- [ ] Scanning/tapping a link for an **ended** game shows "This game has ended" immediately, before the name/skill form even shows, with a way to try another code — not a failure only after filling out the whole form
- [ ] Default skill level from Settings pre-fills the join form
- [ ] Live Status: queue position updates live as others join/leave ahead of you
- [ ] On court: teammates/opponents/score show correctly, score updates live as admin adjusts it
- [ ] Report score → shows "waiting for confirmation" until admin confirms
- [ ] Skip my turn → resting state → "I'm ready to play" → back in queue
- [ ] Leave game → removed state; rejoin still possible via code
- [ ] Last match result banner shows correct win/loss + score after a match ends
- [ ] Announcement banner shows admin's message, targeted vs. everyone both work
- [ ] Roster button shows full player list read-only
- [ ] History & Stats: this-game match list + all-time stats across multiple games for the same account
- [ ] Reconnecting banner appears when network drops
- [ ] **New**: Live Status shows the player's own name and skill level at the top, above everything else — an admin can glance at a player's phone to confirm who they are

## Web guest client (qourt-web.vercel.app)
- [ ] Join via `/` form and via `/join/CODE` link, both work
- [ ] **New**: landing on `/join/CODE` (from a scanned QR) shows the actual **game name** as the headline, code small underneath, with a short "you scanned the code, just add your name" note — not a plain input someone might miss. "Not this game?" switches to manual entry.
- [ ] **New**: `/status` shows the guest's own name and skill level at the top (game name as a small line above it) — same identity-check purpose as iOS
- [ ] Landing on `/join/CODE` for an ended game shows "This game has ended" right away, before asking for a name
- [ ] Live status matches iOS feature-for-feature: queue position, on-court view, live score
- [ ] Report score, skip turn, leave game, last-match result — all work same as iOS
- [ ] Announcement banner shows live
- [ ] Joining an **ended** game shows a clear error, not a crash

## Cross-cutting
- [ ] Same game, one browser tab as "player" + iPhone as "admin" simultaneously — confirms realtime end-to-end
- [ ] Apple Watch: shows queue position or court+score, matches phone's signed-in account (no separate sign-in)
- [ ] TestFlight external build installs and runs correctly for your teammate (once Apple's review clears)

---
*This file gets updated as more features are built — treat it as the master list, not a one-time snapshot.*
