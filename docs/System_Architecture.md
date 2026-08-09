# Qourt — System Architecture

Text version of the architecture diagram in the `Qourt - Flow` FigJam file (figma.com/board/Kve9wPtbWQkrpTlaV8DdqD), so this is usable even without Figma access.

## Clients

- **iPhone app** — SwiftUI, iOS 17+. Both the admin and player experience live in this one app (role is chosen after sign-in, not a separate build).
- **Apple Watch companion** — SwiftUI for watchOS, same Xcode project, separate target. Connects to the backend the same way the iPhone app does; not routed exclusively through the phone.
- **Web guest client** — small JS/TS app, hosted on Vercel, used by players without the app. Talks to Supabase directly from the browser.

All three clients connect to the same backend and see the same live data, there's no separate API for the web client versus the native app.

## Supabase (the backend)

Everything below is one Supabase project. Clients connect through Supabase's API gateway, which routes to four services:

- **Auth** — handles Sign In With Apple. This is the only login method; no email/password. Reads and writes the `profiles` table (and the underlying `auth.users` table Supabase manages).
- **Data API (PostgREST)** — auto-generated REST API over the Postgres tables, used for standard CRUD: creating a game, updating the roster, reading match history, etc. Row-level security (defined in `db/qourt_schema.sql`) enforces that an admin only ever sees their own games, and a player only sees games they've joined.
- **Realtime** — streams database changes over WebSocket to subscribed clients. This is what makes the queue, court assignments, and scores update live across every connected device in under 2 seconds, no polling.
- **Edge Functions** — serverless functions (Deno/TypeScript) for logic that doesn't belong in a client or a simple CRUD call: validating a web guest's join code and session token before letting them read/write anything (guests aren't Supabase-authenticated users, so RLS alone can't cover them), and sending push notifications when a database trigger fires (court assignment, timer ending, etc.).

All four services read and write the same **Postgres database** (schema in `db/qourt_schema.sql`): games, courts, game_players (roster/queue), matches, tournaments, tournament_matches (bracket), announcements, push_subscriptions.

## External integrations

- **Sign In with Apple** — Auth calls out to Apple for identity verification during login.
- **Apple Push (APNs)** — Edge Functions call this directly (no third-party push vendor, no Firebase) to deliver notifications to the iPhone app and Watch. Requires the paid Apple Developer Program membership to generate the push key.
- **Web Push Service** — for browser-based web guests. A service worker in the web client subscribes via the browser's PushManager, the subscription (endpoint + keys) is stored in the `push_subscriptions` table, and an Edge Function sends to it using VAPID keys on the same triggers as the APNs path. Important caveat: iOS Safari only allows this once the guest has added the page to their Home Screen, a plain browser tab can't subscribe. Desktop and Android browsers work from the open tab with no install needed.

## Data flow example: a player gets assigned a court

1. Admin drags a player onto a court in the Live Dashboard (iPhone app) → writes to the `matches`/`game_players` tables via the Data API.
2. Postgres commits the change → Realtime pushes it to every subscribed client (the player's Live Status screen, the web guest's Live Status page, the admin's own dashboard) within ~2 seconds.
3. A database trigger on that same write fires an Edge Function, which looks up the player's push subscriptions (APNs token if they're on the iPhone app, Web Push subscription if they're a browser guest) and sends the "you're up" notification through the matching external service.

## Why this stack, and what it costs

Supabase's free tier and Vercel's free Hobby tier cover this project at student-project scale ($0). The only real cost is the Apple Developer Program ($99/year), required for push notifications and for distributing test builds via TestFlight; without it the app still runs on your own device, just without push and with the build needing to be re-signed every 7 days.
