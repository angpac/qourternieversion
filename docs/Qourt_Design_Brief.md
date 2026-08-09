# Qourt — Design Brief

Hand this whole document to a Claude session with Figma design tools (or a human designer) as the starting brief. It has everything needed to design the UI without re-deriving context: the product, the exact screens, where to put them, the visual direction, and the constraints that shape the layout.

## The one-liner

Qourt is an app that helps badminton community admins seamlessly manage social session court rotations and execute internal tournaments, featuring real-time player queue visibility and live, multi-court scoreboard tracking.

Badminton open-play sessions are usually run by hand: a whiteboard, a pegboard, a printed bracket. The admin spends the whole session managing the line instead of playing, and players never quite know when it's their turn. Qourt replaces the manual system: an admin sets up a session on their iPhone, and the app handles the queue, courts, timers, brackets, and scores. Players see everything live on their own phone.

## Who it's for

- **Admin** — runs the game, wants to spend time coaching and playing, not doing bookkeeping.
- **Player (app)** — signed in with Apple, wants to know where to be and when without asking.
- **Web guest** — no app installed, joins from a QR code in a browser, wants to join in seconds and still see everything live.

## Platforms and tech stack

This shapes what "correct" looks like on each surface:

- **iPhone app** — native SwiftUI. Design should read as a real iOS app: native navigation patterns (tab bars, nav bars, sheets, swipe actions), SF Symbols for iconography, support for Dynamic Type and both light and dark mode.
- **Apple Watch companion** — native watchOS (SwiftUI). Everything here is a glance, not a screen: minimal text, large touch targets, information hierarchy collapsed to the one or two facts that matter (court number, time left, whose turn).
- **Web guest client** — a lightweight web app (hosted on Vercel), used on a phone browser right after scanning a QR code. Design for mobile-width browser viewport first; this is not the same canvas size as the native iPhone frames even though the content overlaps a lot.
- **Backend** — Supabase (Postgres, Auth, Realtime, Edge Functions). Not a design concern directly, but it's *why* the UI should feel live: state changes should arrive in under 2 seconds, so live screens (dashboard, bracket, scoreboard) should visually communicate "this is updating in real time," not "this is a static snapshot you might need to refresh."

## Visual direction: bold, sporty brand

This is a distinct badminton-inspired identity, not a stock iOS look. A few concrete starting points:

- **Color:** lean into court and shuttlecock colors, a saturated court green or teal as the primary, paired with a high-energy accent (yellow-green or orange) for anything live, urgent, or action-triggering ("you're up," timer running low, win). Keep a neutral dark charcoal/black and white for text and structure so the bold color reads as *accent*, not noise.
- **Typography:** a heavier, confident weight for headlines and scores (this is a sports app, scores and court numbers should feel like a scoreboard, not a form label), with a clean, high-legibility body weight for everything else. Respect Dynamic Type, don't hardcode pixel sizes that break accessibility.
- **Status must never rely on color alone.** The PRD calls this out directly: courts and queue status need a shape or icon alongside the color (a filled vs. outlined dot, a checkmark vs. a clock icon) so the app works for colorblind users, and VoiceOver labels need to carry the same information the color does.
- **Support both light and dark mode.** This app gets used courtside under gym lighting, which varies a lot, and dark mode with a bright accent color tends to read especially well for "glance and go" scoreboard-style screens.
- **Live state should look alive.** Subtle motion or a pulsing indicator on anything actively updating (current match score, active timer) reinforces the real-time promise instead of a static-looking number that might be stale.

If a real logo or exact hex palette doesn't exist yet, propose one as part of the design pass rather than blocking on it, this brief is intentionally not prescribing exact hex codes so the design step has room to make it feel intentional rather than assembled from a spec.

## Where to design this

Everything already lives in Figma, don't start a new file.

- **Screens file:** `Qourt Screens` — figma.com/design/Rq7kYFWULakImoFhoVbHSR. Six sections (Onboarding, Admin — iPhone app, Admin — Tournament, Player — iPhone app, Web guest — browser, Apple Watch), 32 named blank frames total, one per screen, each with a text note underneath explaining what it should contain and why it exists. Design in place: replace each blank frame's contents, keep the frame name and the section structure intact, leave the purpose note where it is (or move it to a Dev Mode annotation if that's cleaner) so the "why" doesn't get lost once the visuals go in.
- **Frame sizing note:** the placeholder frames are arbitrary sizes (300×560 for phone screens, 180×220 for Watch), not real device dimensions. First step of the design pass should be resizing each frame to its actual target, iPhone 15/16 (390×844), Apple Watch Series (approx. 198×242 for a 45mm face), and a mobile browser viewport (390×844 is a reasonable proxy) for the web guest screens.
- **Flow reference file:** `Qourt - Flow` (FigJam) — figma.com/board/Kve9wPtbWQkrpTlaV8DdqD. Has five screen-flow diagrams (Admin: create and run a game, Admin: create and run a tournament, Player: join and play, Web guest: join without the app, Apple Watch: notifications and quick actions) plus two system architecture diagrams. Use these to get the screen-to-screen navigation right, they define what triggers a transition and where it goes.

## Full screen inventory

Design every screen below. Type indicates the general pattern (list, form, dashboard, and so on); the description is the scope for that screen, not a full spec, use judgment on details not covered here.

### Onboarding (shared by Admin and Player)
| Screen | Type | Scope |
|---|---|---|
| Sign in | Onboarding | Sign In With Apple. The only way to log in. |
| Choose Admin or Play | Onboarding | Shown right after signing in, or when starting something new. |

### Admin — iPhone app
| Screen | Type | Scope |
|---|---|---|
| My games | List | Every game this admin runs: active games at top (tap to switch), then past/saved games, plus a create button. |
| Create a game | Form | Name, location, date/time, number of courts, singles/doubles, rotation format. |
| Rotation format settings | Form | Format-specific options (round length, point cap, win cap), shown after picking a format. |
| Invite players | Share sheet | QR code, shareable link, join code, share button. |
| Roster | List + actions | Every player: name, skill level, status. Approve/reject, add walk-in, adjust skill level. |
| Live dashboard | Dashboard | Every court, the queue, timers, scores, all at a glance. The main screen while a game runs. |
| Court detail | Detail view | Tap a court: current match, enter/confirm score, control its timer. |
| Send announcement | Modal / form | Message everyone, or nudge one player. |
| Game summary | Report | Matches played, games per player, standout performers, export option. |
| Templates | List | Save a setup, or start from a saved template. |
| Admin settings | Settings | Notification preferences, default timer length, auto/manual rotation, co-admin management. |

### Admin — Tournament
| Screen | Type | Scope |
|---|---|---|
| Create Tournament | Form | Name, bracket size, single/double elimination, match format. |
| Seed players | List / form | Order players by skill level, randomly, or by manually dragging. |
| Bracket View | Dashboard | The live bracket: every match, its court, its score, who's advanced. |
| Live Scoreboard | Dashboard | Every active court's score in one place, updating live. |

### Player — iPhone app
| Screen | Type | Scope |
|---|---|---|
| Join a game | Scanner / form | Scan a QR code, or type a join code. |
| Set skill level | Form | Shown the first time a player joins any game. |
| Live status (home) | Dashboard | Queue position, assigned court, teammate/opponents, live score, timer, all in one place. |
| Match detail | Detail view | Current/most recent match: self-report a score, or see the admin's entry. |
| Roster | List | Everyone in the game and their skill level. |
| History and stats | List / report | This game's results, plus all-time stats. |
| Profile and settings | Settings | Name, default skill level, Watch pairing, notification preferences. |

### Web guest — browser
| Screen | Type | Scope |
|---|---|---|
| Join | Form | From the QR code/link. Name, optional skill level, tap Join. |
| Live status | Dashboard | Same live queue/court/score view as the app, plus Web Push notifications where supported. No Watch support. |
| Get the app (optional) | Modal / prompt | One-tap install + sign-in prompt, carries the game result forward. |

### Apple Watch
| Screen | Type | Scope |
|---|---|---|
| Player: status glance | Glance | Queue position, or current court + timer countdown. |
| Player: turn notification | Notification | "You're up" alert: court number, teammate, opponent. |
| Player: confirm score | Quick action | One tap to confirm a self-reported score. |
| Admin: court alert | Notification | Timer ended, or a score needs entering. |
| Admin: quick actions | Quick action | Start next round, or approve a player waiting to join. |

## Rotation format mechanics (needed for accurate dashboards/settings screens)

Screens like Live Dashboard, Court Detail, and Rotation format settings need to visually represent whichever format is active. The five formats:

- **King of the Court** — courts ranked bottom to top, timed rounds (7–10 min default), winner moves up, loser moves down. Live dashboard should show court *rank*, not just court number.
- **Peg Board / Racket Staking** — a single line; a rotating "Picker" hand-picks 3 players from the next 8–12 in line to build a match. Needs a visible line/queue with a "Picker" role called out.
- **Four Off, Four On** — games to 21, all four players leave when it ends regardless of outcome. Simplest to show, standard queue + court view.
- **Challenge Court** — one court where winners keep playing up to a 2–3 win cap, then step off. Needs a visible win-streak counter on that court.
- **Half-Court Kingminton** — one doubles court split into two singles lanes for a big crowd. Needs a split-court visual, two independent mini-matches on one physical court.

Tournament mode is separate from rotation formats (single/double elimination), and needs an actual bracket-tree visualization for Bracket View, plus a losers-bracket lane for double elimination.

## Non-functional constraints that affect the design

- Real-time updates should read as real-time, under 2 seconds is the target, live screens should visually communicate freshness.
- Never encode status with color alone, pair it with an icon, shape, or label.
- VoiceOver support matters: every icon-only control needs a real accessible label, not just a tooltip.
- Design an offline/reconnecting state for the admin's live dashboard, the PRD requires the app to keep working locally and catch up once reconnected, so there should be a visible (not alarming) indicator for that state.

## Scope: design all 32 screens

Every screen in the inventory above needs a full design, not just the high-traffic ones (Live Dashboard, Live Status, Court Detail, Bracket View). That includes the settings, report, and one-off screens, Admin settings, Game summary, Templates, Profile and settings, History and stats, and every Apple Watch screen. Nothing in this list is optional or a placeholder to skip; all 32 frames in the Figma file should come out of this pass with real content, not blank or partially done.
