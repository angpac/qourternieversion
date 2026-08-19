# Qourt — Testing Checklist

Running list of everything to manually verify, updated as features are built. Test on a real device where possible (Sign In With Apple, camera/QR, Watch pairing all need one).

## Court card clarity (new, needs focused testing)
- [ ] An open court now shows a dashed border, a "+" icon, and "Tap to assign players" instead of just the word "Open" — should read as clearly tappable
- [ ] An active match shows both teams on one line, e.g. "Kiko & Sam vs Mika & Jo", instead of three stacked lines
- [ ] A singles match still reads correctly as "Name vs Name" on one line
- [ ] Long names on a doubles match wrap to a second line instead of getting cut off

## Bug fix: courts stuck "occupied" with no players (fixed, needs verification)
- [ ] **Recovery for the exact issue reported**: open any court showing "No players, tap to fix" → the sheet shows a clear red error card and a "Clear court & assign players" button instead of a blank scoreboard
- [ ] Tapping "Clear court & assign players" is now one step: it clears the broken match AND immediately opens the team-builder for that same court, no need to close and re-tap the court a second time
- [ ] Going forward, `startMatch` now hard-refuses to create a match with an empty team under any circumstances, confirm this by trying to break it: rapidly tapping "Start round" / adding walk-ins / toggling auto-fill while courts are still loading shouldn't ever produce an empty-looking court again
- [ ] Auto-fill re-checks each court immediately before writing to it (not just once at the start of the pass), reduces risk of two near-simultaneous triggers double-booking or racing on the same court

## Mid-match player substitution (new, needs focused testing)
- [ ] Court Detail (tap an active court) → "Players on court" lists all 4 (or 2, for singles/lanes) players individually with a "Sub" button each
- [ ] Tapping "Sub" shows the current queue to pick a replacement from; empty queue shows a clear empty state, not a crash
- [ ] Picking a replacement shows a confirmation dialog naming both players and explicitly framing this as an exception (not routine pairing changes) before anything happens
- [ ] Confirming: the outgoing player goes to the back of the queue, the incoming player takes their spot on court, the match/score/court are otherwise untouched
- [ ] Works mid-match with a non-zero score, the score is preserved exactly through the substitution
- [ ] Cancelling at either step (queue picker or confirmation) makes no changes
- [ ] Works the same across every rotation format, including on a Challenge Court/Kingminton lane and inside a King of the Court round in progress
- [ ] The substituted-in player's own Live Status view updates to show them on court within a couple seconds; the substituted-out player's view updates to show them queued

## Manage courts: rename + reorder (new, needs focused testing)
- [ ] Live Dashboard toolbar → "Manage courts" → tapping a court opens a rename prompt, saves and reflects immediately on the dashboard
- [ ] Any format: courts can always be renamed, regardless of format or whether a match is in progress
- [ ] Non-King of the Court, non-Kingminton format: "Edit" button appears, drag handles let you reorder courts freely
- [ ] King of the Court, no round currently active: reordering works, and the footer explains that order determines ladder rank (bottom to top)
- [ ] King of the Court, a round **is** currently active: reordering is disabled with an explanatory footer, no "Edit" button shown, renaming still works
- [ ] Half-Court Kingminton (lane-split courts): reordering is disabled entirely (lanes share position pairwise), renaming still works per-lane
- [ ] Reordering persists correctly after leaving and reopening "Manage courts", and after a full app relaunch

## Queue copy: "matches ahead" hint (new, needs focused testing)
- [ ] Doubles game, queued at position 5 or higher: a second line appears under "You're #N in line" like "About 1 more match before yours"
- [ ] Singles game: the same hint uses a match size of 2, not 4
- [ ] Positions 1 to 4 in a doubles game (or 1 to 2 in singles) show no extra line, since you're already in the next match
- [ ] Peg Board never shows this hint, on iOS or web, since the Picker pulls from a pool rather than strict queue order
- [ ] Web guest client shows the identical hint and wording as iOS

## Roster: matches-played count (new, needs focused testing)
- [ ] Admin's Roster shows "N played" next to each player, reflecting only confirmed matches in this specific ongoing game (not their all-time history across other games)
- [ ] The count updates live within a couple seconds of a match being confirmed, no manual refresh needed
- [ ] A player who hasn't played yet this game shows "0 played", not blank or an error
- [ ] Use this to sanity-check that one player didn't rack up way more court time than another during a session, this is the whole point of the feature

## Manual rotation format (new, needs focused testing)
- [ ] "Manual" is the first option in the Rotation format list on Create a Game, above King of the Court
- [ ] Selecting Manual shows no format-specific settings and no "Manually match players" toggle (it's implied, not optional)
- [ ] A Manual game's courts never auto-fill from the queue, even with several players waiting, admin always taps in and builds each match by hand
- [ ] After a match ends, all players return to the back of the queue, same as Four Off Four On's generic behavior, so the admin can immediately build the next match manually

## Copy audit: no em dashes (new, spot-check)
- [ ] Spot-check a handful of screens (Create a Game, Roster/Co-admin invite screens, Tournament setup, error banners) to confirm punctuation reads naturally with the em dashes removed, nothing was left awkwardly worded
- Note: this pass covered user-facing text only (`Text`/`Label`/error messages/share text) across iOS, watchOS, the widget extension, and the web app. Code comments were left as-is since they're not shown to anyone.

## Live Activities — Lock Screen / Dynamic Island (new, needs a real device — Simulator support is unreliable)
- [ ] Join a game as a player → a Live Activity appears showing "You're #N in line" on the Lock Screen and (iPhone 14 Pro+) the Dynamic Island
- [ ] Getting assigned to a match updates the same activity to show the court, teammate(s) vs opponent(s), and starts the score at 0–0 — check this specifically **while the app is backgrounded**, since that's the whole point (relies on the push-to-update path, not just the app's own local update)
- [ ] While the match is in progress and the app is foregrounded, the activity's score updates live as the admin adjusts it
- [ ] Stepping out / leaving the game / the match ending eventually clears the activity (may take a moment — ActivityKit doesn't dismiss instantly on every state change in this v1)
- [ ] Dynamic Island compact/minimal views show a sensible icon + score-or-queue-number at a glance; expanding it (long-press) shows the full detail
- [ ] Denying "Allow Live Activities" (or having it off in Settings) doesn't break anything else — app still fully usable, just no Live Activity
- [ ] **Known limitation**: only the "you're up!" match-assignment moment pushes a Live Activity update while backgrounded — queue position shifting as others join/leave, and live score changes, only update the activity while your own app happens to be in the foreground. Full live fidelity in the background would need additional DB triggers (queue position changes, score changes), deliberately not built yet — see `ROADMAP.md`.

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
- [ ] Swipe an ended game → "Archive" → it disappears from the Ended section and collapses into an "Archived (N)" disclosure row
- [ ] Tapping "Archived (N)" expands it with a chevron; swipe → "Unarchive" moves one back to the Ended section; tapping the row again collapses it back down
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

## Clubs (new, needs focused testing — schema groundwork for multi-admin/multi-sport)
- [ ] Settings → "Manage Clubs" (admin role only — not shown for Play role)
- [ ] Create a club: name + pick from common sports (Badminton, Pickleball, etc.) + a custom "Other" sport — all save correctly
- [ ] A brand-new admin account with no clubs sees the empty state, not an error
- [ ] Tapping a club shows its sports, its club admin invite code (share-able), and current club admins (empty at first)
- [ ] A second account → Settings → Manage Clubs → "+" → "Join as club admin" → enter the code → the club appears in their list too
- [ ] **Key behavior**: once someone is a club admin, they automatically administer every game already linked to that club — without being added to that specific game's own co-admin list. Verify by creating a game under the club as the owner, then confirming the newly-joined club admin can open and fully manage that game (start matches, roster, etc.) immediately.
- [ ] A club admin removed from "Club admins" immediately loses access to every game under that club (not just new ones)
- [ ] Create a game → if you belong to at least one club, a "Club" picker appears (defaulting to "None") to optionally link the new game to it; if you belong to no clubs, the picker doesn't show at all
- [ ] A game created with no club selected behaves exactly as before — no club picker ever appears again for that game, no regression to solo one-off games
- [ ] **Known scope for now**: no persistent club member roster yet — players still join each game individually by code/QR even under a club. That's flagged as a deliberate next step, not a bug.

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
- [ ] **New**: tapping "Done" on Invite Players drops the admin straight into that game's own Live Dashboard, not back on the My Games list, on both iPhone (pushes in) and iPad (selects it in the split view)

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

## iPad (new, needs focused testing)
- [ ] My Games on iPad shows a real two-column split view — game list on the left, dashboard/summary/bracket on the right — not just a scaled-up iPhone screen
- [ ] Rotating iPad to portrait/narrower multitasking collapses to a single column that behaves like iPhone (tap a game → it pushes in); rotating back to landscape/full-screen restores the two-column layout
- [ ] Tapping a game in the sidebar updates the detail pane without losing your place in the list
- [ ] "Create a game" / "Start from a template" / "Join as co-admin" now open as sheets (not pushes) — each has a working Cancel button, and finishing/cancelling returns you to exactly where you were
- [ ] The Live Dashboard's courts grid already uses the extra iPad width automatically (more courts per row) — confirm it looks right with both few and many courts
- [ ] Nothing regressed on iPhone — My Games still behaves exactly as a single push-navigation stack (this was true before the iPad work and must still be true)

## Cross-cutting
- [ ] Same game, one browser tab as "player" + iPhone as "admin" simultaneously — confirms realtime end-to-end
- [ ] Apple Watch: shows queue position or court+score, matches phone's signed-in account (no separate sign-in)

## Apple Watch (player-only)
The Watch is a player companion for now — hosting a game stays on the iPhone.
- [ ] Queued: shows `#N` and `of M in line`; position `#1` reads "You're up next"
- [ ] "Skip my turn" moves you to resting; screen shows "You're resting", not a blank/"No active game"
- [ ] "I'm ready" puts you at the **back** of the line, not your old spot
- [ ] "Leave game" asks to confirm first, then drops to "No active game"
- [ ] Pending (approval-required game): shows "Waiting for approval" with "Cancel request"
- [ ] Host sends an announcement from the phone → banner appears on the wrist within ~2s
- [ ] Player-targeted announcement reaches only that player's Watch, game-wide reaches everyone
- [ ] On court: report score → "Waiting for host", host confirms on phone → Watch updates
- [ ] Signed in as an **admin**: the "Hosting" card explains courts/scoring are on the iPhone, and it shows even when the admin has no active game as a player
- [ ] Signed in as a **non-admin**: no "Hosting" card at all
- [ ] TestFlight external build installs and runs correctly for your teammate (once Apple's review clears)

---
*This file gets updated as more features are built — treat it as the master list, not a one-time snapshot.*
