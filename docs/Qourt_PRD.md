**Qourt**

*An app that helps badminton community admins seamlessly manage social session court rotations and execute internal tournaments, featuring real-time player queue visibility and live, multi-court scoreboard tracking.*

Author: Ernest · Status: Draft v1 · Date: August 7, 2026

> **New to PRDs? Start here.**
> A PRD (Product Requirements Document) is a plan that describes what a product should do and why, before anyone builds it. It answers three questions: who is this for, what problem does it solve, and exactly what should the product do. The Glossary further down defines any terms you're not sure about, and each rotation format below has a picture showing how players move.

---

## The problem

Qourt is an app that helps badminton community admins seamlessly manage social session court rotations and execute internal tournaments, featuring real-time player queue visibility and live, multi-court scoreboard tracking. That one line is our validated challenge response: it is what we are building, and it is the test every feature in this document should be measured against.

Badminton open-play sessions and internal tournaments are usually run by hand: a whiteboard, a pegboard, a printed bracket, or someone shouting names. The admin spends the whole session managing the line and updating the bracket instead of playing, and players are never quite sure when it's their turn, which court to go to, or what the score is.

Qourt replaces the manual system. An admin sets up a session on their iPhone, whether it's open-play rotation or a bracket tournament, and the app handles the queue, the courts, the timers, the brackets, and the scores. Players see everything live on their own phone, so nobody has to keep asking "am I up next?"

## What we want to achieve

- An admin can set up a game in under two minutes, with no manual bookkeeping after that.
- Every player, whether they have the app or not, can see their place in line, their court, who they're playing with, and the score, in real time.
- The app supports five rotation formats that real badminton admins already use, so it fits how people already play instead of forcing a new system.
- An admin can also run a structured tournament, single or double elimination, with a live bracket and a live scoreboard across every court, not just open-play rotation.
- Joining a game is fast: scan a QR code, tap a link, or type a short code. No account needed for a casual guest.
- Players can check their status on Apple Watch, so they don't have to keep pulling out their phone.
- An admin can run more than one game at once from a single account, each fully isolated: its own roster, courts, queue, and join code.

### What we're not building yet

- An Android version of the app.
- Any payment or subscription features.
- Chat or messaging between players.

## Glossary: key terms used in this document

If a word below is unfamiliar the first time you see it in this document, come back here.

| Term | What it means |
|---|---|
| PRD | Product Requirements Document. A plan describing what to build and why, written before development starts. |
| Admin | The organizer running the game: sets it up, manages players, and keeps things moving. |
| Player | Anyone joining the game to play, whether through the app or a web browser. |
| Game (session) | One organized open-play event, from setup to the last match. |
| Court | A physical badminton court being tracked by the app. |
| Queue | The waiting line of players who are not currently on a court. |
| Rotation format | The specific set of rules for how players move between the queue and the courts (there are five, see How Rotation Works). |
| Skill level | A simple rating (Beginner, Intermediate, Advanced) used to keep matches fair. |
| QR code | A square barcode a phone camera can scan to open the game instantly. |
| Join code | A short text code (like a 6-character password) used to join a game without scanning anything. |
| Push notification | An alert that pops up on a phone or watch, even if the app isn't open. |
| Self-report | When a player enters their own match score instead of the admin doing it. |
| Web guest | A player who joins from a browser link instead of installing the app. |
| Tournament | A structured, bracket-based competition run within a session, separate from open-play rotation. |
| Bracket | The tree-shaped chart showing which players face each other and how the winner is decided. |
| Seed | A player's starting position in the bracket. Seeding can be random or based on skill level. |

## Decisions we've already made

A few open questions came up while writing this PRD. Here is what we assumed, and why, so anyone reading can challenge these before real design work starts.

- **Player profiles are saved:** Signing in with Apple creates one identity for a player that is reused everywhere. Their skill level and match history follow them from game to game. This is simple to build since Apple sign-in is already required, and players will like seeing their own stats build up over time.
- **Admins can run multiple games at once:** an admin account is not limited to one active game. This is a bigger lift than it sounds, and it touches more than the setup screen: the live dashboard needs a game switcher, notifications must be scoped to the right game so a player in Game A never gets pinged for Game B, and every join code or QR code has to stay unique across all of an admin's active games, not just one.
- **Web guests see everything live, and get real notifications:** a player without the app still sees the same live queue, court, and score information as an app user, and now also gets browser push notifications (Web Push) for the same events an app player would get, court assignment, timer warnings, score confirmations. Watch support still doesn't apply, there's no app to pair a Watch to. On iOS Safari specifically, push only works if the guest has added the page to their Home Screen; on desktop or Android, it works straight from the open tab, no install needed.
- **The app is free:** no payment features in this version. A paid tier for admins or clubs may come later, but it is not part of this plan.
- **One rotation format per game:** an admin picks a single format for the whole game. Mixing formats (for example, one Challenge Court inside a King of the Court ladder) is a possible future feature, not part of this version.
- **Tournaments seed by skill level by default:** seeding by skill level avoids lopsided early-round matches, which is what most community tournaments already do by hand. An admin can switch to random seeding, or drag players to reorder the bracket manually, at setup.

## Who uses the app

| Who | In plain terms | What they need most |
|---|---|---|
| Admin | Runs the game: sets up courts, manages players, starts rounds, records scores. | Spend time coaching and playing, not doing bookkeeping. |
| Player (app) | Has the app, signed in with Apple, joins a game to play. | Know where to be and when, without having to ask. |
| Web guest | No app. Joins from a QR code or link in their phone's browser. | Join in seconds and still see what's happening live. |

## Where the app runs

| Where | What happens there |
|---|---|
| iPhone app | The full admin and player experience. Sign In With Apple is the only way to log in. |
| Apple Watch | A companion for notifications and a quick glance at status, for both players and admins. |
| Web browser | For guests without the app: scan a QR code or open a link, type a name, and see live status. |
| Android | Not included in this first version. |

## How rotation works

An admin picks exactly one of these five formats when setting up a game. Each one has its own rules for how players move between the queue and the courts.

| Format | How long a match lasts | Good for |
|---|---|---|
| King of the Court | Timed rounds, 7-10 minutes (admin can change this) | A ladder where players climb toward a top court. |
| Peg Board / Racket Staking | One normal doubles game | A single fair line where a rotating "Picker" builds balanced matches. |
| Four Off, Four On | One game to 21 points | Making sure everyone swaps out roughly every 15 minutes. |
| Challenge Court | One normal doubles game, with a win limit | One high-energy court where winners defend, but can't dominate forever. |
| Half-Court Kingminton | Short games: first to 3 or 5 points | Keeping a big crowd moving on a small number of courts. |

### King of the Court

- Courts are ranked from bottom to top. The top court is called the King's Court.
- A timer runs each round, usually 7-10 minutes. There is no point target.
- When time runs out: the winner on each court moves up one court, and the loser moves down one court.
- The winner on the King's Court stays there to defend it.
- The loser on the Bottom Court stays there to try again.
- A waiting player takes the spot of whoever just dropped off the Bottom Court.

*[Insert diagram: King of the Court rotation]*

**An admin can adjust:**
- Number of courts, and how long each round lasts.
- Singles or doubles.
- Rotate automatically when the timer ends, or let the admin trigger it manually.
- Manually move any player between courts or the queue at any time.

### Peg Board / Racket Staking

- Everyone stands in a single line, one spot per player (in a physical game, this is one peg or racket per player).
- A player who finishes a game, or just arrived, goes to the back of the line.
- The player at the front of the line becomes the Picker.
- The Picker looks at the next 8-12 players in line and hand-picks 3 of them to build a balanced doubles match.
- Those four players go play, then all four return to the back of the line once the game ends.

*[Insert diagram: Peg Board / Racket Staking rotation]*

**An admin can adjust:**
- How many players the Picker gets to choose from (default 8-12).
- Whether the app suggests balanced groupings by skill level, which the Picker can accept or change.
- Manually reorder the line, for example if a player steps out and comes back.

### Four Off, Four On

- Every match is one standard game, played to 21 points.
- When the game ends, all four players leave the court, no matter who won.
- This guarantees a full swap of players roughly every 15 minutes, so no one holds a court all day.

*[Insert diagram: Four Off, Four On rotation]*

**An admin can adjust:**
- The point target (default 21, can be changed).
- Whether to strictly enforce the full swap, or relax it for a casual game.
- Singles or doubles.

### Challenge Court

- One court is set aside as the Challenge Court, where the winning pair keeps playing.
- The winning pair keeps facing new challengers pulled from the line.
- There's a cap of 2 or 3 wins in a row (the admin decides which).
- Once a pair hits that cap, they step off and rejoin the line, even if they're still winning.

*[Insert diagram: Challenge Court rotation]*

**An admin can adjust:**
- The win cap: 2 or 3 in a row.
- Which physical court is the Challenge Court.
- Combining this with another format on the other courts is possible later, but not part of this version.

### Half-Court Kingminton

- One doubles court is split down the middle into two singles lanes, for when there's a big crowd.
- Games are short: first to 3 or 5 points (admin decides).
- The loser leaves the lane right away, and the next person in line steps in immediately.
- This keeps 8-10 players actively rotating through just one physical court.

*[Insert diagram: Half-Court Kingminton rotation]*

**An admin can adjust:**
- The point target: 3 or 5.
- Which physical courts get split into lanes.

## Tournament mode

Open-play rotation keeps a casual session moving. Tournament mode is different: it's a structured, bracket-based competition an admin runs inside a session, with a clear path to one winner (or one winner per bracket, for double elimination). An admin picks tournament mode instead of a rotation format when setting up a game.

| Format | How it ends | Best for |
|---|---|---|
| Single elimination | One loss and a player is out; the bracket narrows to one Champion. | A fast, straightforward tournament when court time is limited. |
| Double elimination | A player isn't out until their second loss; there's a winners bracket and a losers bracket. | A fairer result when one bad match shouldn't end someone's day. |

### Single elimination

- The admin sets the bracket size (commonly 4, 8, 16, or 32 players).
- Players are seeded into the bracket, by skill level (default) or randomly.
- The app generates the bracket automatically once seeding is confirmed.
- Each match's winner advances to the next round; the loser is out of the tournament.
- The bracket narrows round by round until one Champion remains.

*[Insert diagram: Single-elimination bracket]*

**An admin can adjust:**
- Bracket size and number of rounds.
- Seeding: by skill level, random, or manual drag-to-reorder.
- Which physical court each match is assigned to.
- Match format: single game to a point cap, or best-of-three.

### Double elimination

- Works like single elimination, except a player's first loss drops them into a losers bracket instead of eliminating them.
- A player is only out of the tournament after a second loss.
- The winners-bracket champion and the losers-bracket champion meet in a final match.
- Takes longer to complete than single elimination, since every player gets a second chance.

**An admin can adjust:**
- The same controls as single elimination, plus whether the losers-bracket final is a single match or a full reset (loser's-bracket winner must beat the winners-bracket champion twice).

### Live scoreboard

Whether a session is running open-play rotation or a tournament, every court's score is visible in one place, live. This is one of the two things our validated challenge response calls out by name, alongside real-time queue visibility, so it applies everywhere in the app, not just tournaments.

- Every active court and its current score are shown together, updating in real time as scores are entered.
- In tournament mode, the scoreboard is paired with the live Bracket View, so spectators can see both the current score and where it slots into the bracket.
- Players and spectators without the app can see the live scoreboard as a web guest, the same way they'd see open-play queue status.

## What an admin can do

### Setting up a game

- Create a game: give it a name and location, pick the date and time, set the number of courts, choose singles or doubles, and pick a rotation format with its specific settings (round length, point cap, win cap, and so on).
- Get a QR code, a shareable link, and a short join code so players can join.
- Name each court (Court 1, Center Court, and so on).
- Set the skill level labels used for this game (defaults: Beginner, Intermediate, Advanced; the admin can rename them).
- Optionally cap how many players can join, and choose whether joining needs admin approval.
- Optionally show a short rules or waiver message when someone joins.
- Save a game's setup as a template to reuse next time.

### Managing players

- See the full roster: names, skill levels, and current status (queued, on court, or resting).
- Approve or reject join requests, if that setting is turned on.
- Add a walk-in player by hand, for someone without a phone.
- Change a player's skill level at any time.
- Pause a player (injury, break) without removing them, then bring them back when they're ready.
- Remove a player from the game.
- Fix or merge duplicate entries.

### Running the game live

- See a live dashboard: every court, who's playing, the score or timer, and the full queue.
- Start, pause, resume, or end the game. Pausing freezes every timer (useful for a rain delay).
- Manually override anything at any time, by dragging a player between a court and the queue.
- Enter a match score, or confirm a score a player self-reported.
- Fix a score after it's entered, with a visible record of the change.
- Start, reset, or add time to any court's timer.
- Send a message to everyone, or nudge one player directly ("Court 3, you're up").
- Stop a match and cancel its score, in case of an injury or a dispute.

### After the game

- See a summary: total matches played, how many games each player got (a fairness check), and standout performers.
- Export the summary.
- Keep the game and player stats saved for later reference or reuse as a template.

### Running more than one game at once

- Switch between active games from a "My games" list; each game keeps its own roster, courts, queue, and live dashboard, fully separate from the others.
- Every game gets its own QR code, link, and join code, even if the same admin is running several games at the same time.
- Notifications and announcements are scoped to one game at a time, so a player only hears about the game they joined.
- A clear indicator of which game is currently "active" on screen, to avoid an admin accidentally recording a score or moving a player in the wrong game.
- Add a co-admin to help manage any one game.
- Set notification and sound preferences, default timer length, and whether rotation is automatic or manual by default, per game or as an account-wide default.

## What a player can do (iPhone app)

### Getting started

- Sign in with Apple, then choose Admin or Play for this game.
- Join a game by scanning its QR code (which opens the app straight into that game), or by typing its short join code.
- Set a skill level the first time they join; the admin can adjust it later.

### Live status

- Their spot in the queue and an estimated wait, shown the right way for whichever rotation format is active.
- The court they're assigned to, the moment it's their turn.
- Who their teammate and opponents are, and their skill levels.
- The live score of their current match.
- Time left on the court timer, for timed formats.
- A short reminder of how the current rotation format works.
- A push notification the moment they're assigned a court, plus a warning before a timer runs out.

### Self-service

- Self-report the score at the end of a match (the admin may need to confirm it, depending on the game's settings).
- Step out of the queue for a break, then step back in.
- See the full roster and skill levels of everyone playing.

### History and profile

- This game's history: matches played, wins and losses, scores.
- Overall history tied to their Apple sign-in: win rate, games played, and skill level over time, across every game they've joined.
- A profile screen: name, default skill level, and Apple Watch pairing status.

## Joining without the app

- Scan the game's QR code, or open the shared link, in a phone's web browser.
- Type in a name (and optionally a skill level) to join the queue. No account or app install needed.
- See the same live queue, court assignment, teammates and opponents, and score as an app player.
- Get browser push notifications for the same events an app player gets (assigned to a court, timer warnings, score confirmations), no watch support, since there's no app to pair a Watch to. On iOS Safari, this only works once the guest has added the page to their Home Screen; on desktop or Android, it works from the open tab with no install needed.
- Their spot in the game is tied to that browser for the length of the game; there's no syncing across devices for guests, so a notification subscription is per browser, not per person.
- They can be offered a prompt to install the app and sign in, which can carry this game's result into a saved profile going forward.

## Apple Watch

### For players

- A notification with a tap on the wrist when it's their turn: court number, teammate, opponent.
- A quick glance at their status: queue position, or their current court and timer countdown.
- A quick tap to confirm a self-reported score.

### For admins

- A notification when a court's timer ends, or when a match needs a score entered.
- Quick actions: start the next round, or approve a player waiting to join.

## Notifications

| What triggers it | Who gets it | Where it shows up |
|---|---|---|
| Assigned to a court | Player | Push, in-app, and Watch |
| Timer is about to end (e.g., 1 minute left) | Player, admin | Push and Watch |
| A score needs confirming | Player | Push and in-app |
| Game paused or resumed | All players | Push and in-app |
| Admin sends an announcement | All players, or one player | Push and in-app |
| Someone requests to join | Admin | Push and Watch |

"Push" means Apple Push (APNs) for the iPhone app, and Web Push for web guests, the two run on separate delivery systems but fire on the same triggers. Watch support only ever applies to the iPhone app; web guests have no Watch to pair. Web Push to a guest's browser only works once they've added the page to their Home Screen on iOS Safari; on desktop or Android it works straight from the open tab.

## Suggested app screens

This is a starting list of the screens each surface needs, based on the features above. Think of it as a checklist for design and engineering, not a final wireframe; the exact flow can change once someone sketches it out.

### Admin: iPhone app

| Screen | Type | What it's for |
|---|---|---|
| Sign in | Onboarding | Sign In With Apple. The only way to log in. |
| Choose Admin or Play | Onboarding | Shown right after signing in, or when starting something new. |
| My games | List | Every game this admin runs: active games at the top (tap to switch and open its dashboard), then past and saved games, with a button to create a new one. |
| Create a game | Form | Name, location, date and time, number of courts, singles or doubles, and rotation format. |
| Rotation format settings | Form | Format-specific options (round length, point cap, win cap) shown after picking a format. |
| Invite players | Share sheet | QR code, shareable link, and join code, with a share button. |
| Roster | List + actions | Every player who has joined: name, skill level, status. Approve or reject, add a walk-in, adjust skill level. |
| Live dashboard | Dashboard | The main screen while a game is running: every court, the queue, timers, and scores at a glance. |
| Court detail | Detail view | Tap a court to see the current match, enter or confirm a score, and control its timer. |
| Send announcement | Modal / form | Message everyone, or nudge one player directly. |
| Game summary | Report | Shown after ending a game: matches played, games per player, standout performers, export option. |
| Templates | List | Save a game's setup, or start a new game from a saved template. |
| Admin settings | Settings | Notification preferences, default timer length, auto vs. manual rotation, co-admin management. |

*[Insert wireframes: Live Dashboard and Create a Game]*

### Admin: Tournament screens

| Screen | Type | What it's for |
|---|---|---|
| Create Tournament | Form | Name, bracket size, single or double elimination, match format (point cap or best-of-three). |
| Seed players | List / form | Order players into the bracket by skill level, randomly, or by manually dragging. |
| Bracket View | Dashboard | The live bracket: every match, its court, its score, and who has advanced. |
| Live Scoreboard | Dashboard | Every active court's score in one place, updating in real time. |

### Player: iPhone app

| Screen | Type | What it's for |
|---|---|---|
| Sign in | Onboarding | Sign In With Apple. The only way to log in. |
| Choose Admin or Play | Onboarding | Shown right after signing in, or when starting something new. |
| Join a game | Scanner / form | Scan a QR code, or type a short join code. |
| Set skill level | Form | Shown the first time a player joins any game. |
| Live status (home) | Dashboard | Queue position, assigned court, teammate and opponents, live score, and timer, all in one place. |
| Match detail | Detail view | The current or most recent match: self-report a score, or see the admin's entry. |
| Roster | List | See everyone in the game and their skill level. |
| History and stats | List / report | This game's results, plus all-time stats tied to the player's profile. |
| Profile and settings | Settings | Name, default skill level, Apple Watch pairing, notification preferences. |

*[Insert wireframe: Live Status (home)]*

### Web guest: browser (no app)

| Screen | Type | What it's for |
|---|---|---|
| Join | Form | Opened from the QR code or link. Enter a name and optional skill level, then tap Join. |
| Live status | Dashboard | Same live queue, court, and score view as the app, plus Web Push notifications where the browser supports it. No Watch support. |
| Get the app (optional) | Modal / prompt | A one-tap prompt to install the app and sign in, carrying this game's result forward. |

*[Insert wireframe: Join screen]*

### Apple Watch screens

| Screen | Type | What it's for |
|---|---|---|
| Player: status glance | Glance | Queue position, or current court and timer countdown, at a glance. |
| Player: turn notification | Notification | "You're up" alert with the court number, teammate, and opponent. |
| Player: confirm score | Quick action | A quick tap to confirm a self-reported score. |
| Admin: court alert | Notification | Notification when a timer ends or a score needs entering. |
| Admin: quick actions | Quick action | Start the next round, or approve a player waiting to join, right from the wrist. |

### How the pieces connect: screen flows

A flow diagram for each feature area, plus the same flow written out as plain steps underneath it. A more detailed, editable version of these flows also lives in the Figma file (linked from the Design page in this space).

#### Admin: Create and Run a Game

*[Insert flow diagram]*

1. Sign in with Apple.
2. Choose Admin.
3. Open My Games and tap Create New.
4. Fill out the Create a Game form: name, location, number of courts, singles or doubles.
5. Set the rotation format and its specific settings (round length, point cap, or win cap).
6. Invite players using the QR code, link, or join code.
7. Land on the Live Dashboard, the main screen while the game is running.
   1. From the dashboard: tap a court to open Court Detail and enter a score or manage its timer, open Roster to approve or adjust players, or send an Announcement.
8. When the game ends, open Game Summary.
9. Save the setup as a template, or return to My Games to start or switch to another game.

#### Admin: Create and Run a Tournament

*[Insert flow diagram]*

1. Open My Games and tap Create New, then choose Tournament instead of open-play rotation.
2. Set up the tournament: bracket size, single or double elimination, match format.
3. Seed players by skill level, randomly, or by manually reordering.
4. Generate the bracket.
5. Assign each match to a physical court.
6. Land on Bracket View, the main screen while the tournament is running.
   1. From Bracket View: open Match Detail to enter a score; the winner automatically advances in the bracket.
7. Check Live Scoreboard any time to see every active court's score in one place.

#### Player (app): Join and Play

*[Insert flow diagram]*

1. Sign in with Apple.
2. Choose Play.
3. Join a Game by scanning a QR code or entering a join code.
4. Set a skill level; only asked the first time.
5. Land on Live Status (Home), the main screen while playing.
   1. From Home: open Match Detail to self-report a score, check the Roster, or view History and Stats.
6. Open Profile and Settings any time to update skill level or notification preferences.

#### Web Guest: Join Without the App

*[Insert flow diagram]*

1. Scan the game's QR code or open the shared link.
2. Land on the Join screen and enter a name (skill level optional).
3. See Live Status in the browser: the same live queue and court view as the app.
4. Optionally tap Get the App.
5. Sign in with Apple in the iPhone app; this game's result carries into a saved profile going forward.

#### Apple Watch: Notifications and Quick Actions

*[Insert flow diagram]*

1. Player: get a turn notification on the wrist.
   1. Player: glance at status: court number and time remaining.
   2. Player: confirm a self-reported score with one tap.
2. Admin: get a court alert when a timer ends.
   1. Admin: open Admin quick actions.
   2. Admin: start the next round, or approve a player waiting to join.

## Behind the scenes: things to keep in mind

- Updates to the queue, courts, and scores should reach every device in under 2 seconds.
- If the admin's phone loses internet mid-game, the game should not lose its state; it should save locally and catch up once reconnected.
- Court and queue status should never rely on color alone, so the app works for colorblind users; it should also work well with VoiceOver for players who are blind or low-vision.
- Only a player's name, skill level, and match history are collected. No location tracking beyond an optional, free-text venue name.
- The first version should comfortably handle games with roughly 60-80 players across 10 courts; this should be checked against real club sizes before locking in infrastructure choices.

## How we'll know this is working

- How many pilot admins run their game through the app instead of a whiteboard or pegboard.
- Whether players report spending less time confused about their queue position or court.
- Fairness: how evenly games are spread across players within one game (less variance is better).
- How many iPhone players pair an Apple Watch.
- How many admins come back to run a second game within 30 days.
- How many admins run a tournament through the app instead of a printed or hand-drawn bracket.

## Questions still open

- Should skill level automatically adjust based on match results (like a chess rating), or stay something the admin or player sets by hand?
- Do we need a spectator role for people watching but not playing, like a parent tracking one player's games?
- Should Challenge Court and King of the Court be combinable on different courts within the same game?
- Do we need to support more than one language in this first version?
- What's the right maximum game size before performance or the experience starts to suffer?
