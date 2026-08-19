# App Clip setup

The code side of the App Clip is done and builds. What remains is
configuration in the Apple Developer portal and App Store Connect, which
can't be scripted from here. Until those steps are finished the clip runs
fine from Xcode but **will not appear when anyone scans a QR code**.

## How routing is meant to work

One URL, `https://qourt-web.vercel.app/join/<CODE>`, encoded in every
game's QR code. What happens on scan depends on the device:

| Device | Outcome | What drives it |
|---|---|---|
| iPhone **with** Qourt installed | Opens the app at the join flow | `applinks` in the AASA + `applinks:` entitlement on the app |
| iPhone **without** Qourt | App Clip card, then the clip | `appclips` in the AASA + `appclips:` entitlement on the clip + an App Clip Experience in App Store Connect |
| Android / desktop | Web guest client | No iOS association applies; the URL is just a web page |

iOS prefers the installed app when both claims match, so the "has the app"
and "doesn't have the app" cases can't both fire.

## Steps to finish

### 1. Register the App Clip's bundle ID

Developer portal → Certificates, IDs & Profiles → Identifiers → **+**

- Bundle ID: `net.criers.Qourt.Clip`
- Enable **Associated Domains**
- It must be created as an *App Clip* identifier nested under
  `net.criers.Qourt`, not as a standalone app ID

### 2. Verify the AASA is live — DONE (2026-08-19)

Deployed to production and verified: HTTP 200, `application/json`, no
redirect, and both keys present.

```
curl -s https://qourt-web.vercel.app/.well-known/apple-app-site-association
```

Re-check with that after any web deploy. If `appclips` is missing, the web
app has been deployed from a commit that predates it.

**Deploying from the CLI:** run `vercel --prod` from the **repo root**, not
from `web/`. The Vercel project's Root Directory is already set to `web`,
so deploying from inside `web/` resolves to `web/web` and fails with "The
provided path does not exist". The repo root is linked for this reason.

**Preview builds:** `NEXT_PUBLIC_SUPABASE_URL` and
`NEXT_PUBLIC_SUPABASE_ANON_KEY` were originally scoped to the `dhkst`
preview branch only, so every other branch's preview build failed at
prerender with "supabaseUrl is required". They're now set for all preview
branches.

### 3. Register an Advanced App Clip Experience

App Store Connect → the Qourt app → the version → **App Clip** →
Advanced App Clip Experiences → **+**

- URL: `https://qourt-web.vercel.app/join`
- Fill in the card title, subtitle, action ("Open"), and the 3:2 header
  image — this is what a guest sees on the card before the clip loads

This is the step that makes a scanned QR produce an App Clip card. The
`appclips` AASA entry alone is not enough. It requires at least one build
uploaded to TestFlight or the App Store.

A **default** App Clip experience (no URL registration) only covers
launches from the App Store product page, which isn't the flow here.

### 4. Numeric App Store ID for the Safari banner

A QR scanned in the Camera app gets the App Clip card directly. A link
*tapped into Safari* gets a Smart App Banner instead, and that banner needs
the app's numeric App Store ID.

As of 2026-08-19 the app isn't on the App Store yet (an iTunes lookup for
`net.criers.Qourt` returns no results), so this ID doesn't exist to be set.
Once the app has one, set it in Vercel:

```
NEXT_PUBLIC_APP_STORE_ID=<numeric id>
```

The banner is deliberately omitted while that variable is unset — a
placeholder ID would point people at somebody else's app listing.

## Three ways to test, and which to use when

These are genuinely different mechanisms, and the confusing part is that
only the last one needs App Store Connect at all.

| Goal | Use |
|---|---|
| Iterate while building | Xcode `_XCAppClipURL` |
| Scan real QR codes, any game | **Local Experience on the device** |
| Hand it to non-developer testers | TestFlight App Clip Invocation |
| Public scans it from the Camera app | Advanced App Clip Experience (step 3) |

### Local Experience - the realistic test, no Apple setup

This is the one that lets you scan a QR for a game you just created. On the
device: **Settings -> Developer -> App Clips Testing -> Local Experience**

- URL prefix: `https://qourt-web.vercel.app/join`
- Bundle ID: `net.criers.Qourt.Clip`
- Plus a title, subtitle and action for the card

It matches on a URL *prefix*, so every join code works - make a new game,
show its QR, scan it with the Camera app, and the clip launches with that
code. No per-game setup.

Needs Developer Mode enabled on the device, and the clip installed by
running the QourtClip scheme onto it from Xcode first.

### TestFlight App Clip Invocation

TestFlight -> the app -> App Clip Invocations -> **+**. Title and URL only;
no header image, subtitle or action, and no Advanced Experience required.
Testers pick the invocation from a list inside TestFlight rather than
scanning.

The URL is fixed per invocation, so point it at a game that will stay
alive - e.g. `https://qourt-web.vercel.app/join/DPGMJM` (the "Appclip"
game). Two things to know:

- Invocations can be added or edited **without uploading a new build**, so
  pointing at a different game is a one-minute change, and several can
  exist at once for testers to choose between.
- Every tester who opens it joins that game's roster for real, under
  whatever name they type. Keep it on a throwaway game, not a live session.

If the game is ever ended, the invocation starts failing with "This game
has ended" - `guest_join_game` rejects `ended`, though `draft` is fine.

## Testing before any of that is done

The clip can be run locally without any App Store Connect setup. The
`QourtClip` scheme sets `_XCAppClipURL`, which simulates being invoked by
a scanned QR:

```
Scheme QourtClip → Run → Arguments → Environment Variables
_XCAppClipURL = https://qourt-web.vercel.app/join/ABC123
```

Change `ABC123` to a real join code from a game you've created, or clear
the variable to test the blank join form (someone who opened the clip
without a code).

On a real device, App Clip experiences can also be tested through
TestFlight → the app → App Clip → Local Experiences, which lets you map a
URL without submitting anything for review.

## Production hardening already in place

- **Upgrade path.** The status screen presents Apple's `SKOverlay`
  App Clip configuration once, three seconds after the guest can actually
  see their place in line, and again on demand from the "Get the full app"
  card. Deliberately not on arrival - that would ask for a commitment
  before delivering anything.
- **Polling follows the scene.** The 2-second poll stops on background and
  resumes on foreground, rather than running behind the lock screen.
- **Requests time out in 15 seconds**, not the default 60, so one stalled
  request on gym wifi can't freeze the queue position for half a minute.
- **Stale data is labelled.** A failed poll keeps the last known state on
  screen under a "Reconnecting…" banner instead of blanking or silently
  lying.
- **A dead session recovers.** If the token stops resolving, the clip
  returns to the join form rather than polling a doomed request forever.
- **Scanning a second game works.** The clip remembers which code its
  session belongs to; a different code drops the old session, the same code
  returns the guest to their existing spot instead of joining them twice.
- **VoiceOver.** Decorative emoji are hidden from the accessibility tree,
  the score reads as "Score 21 to 19", and the live/reported dot is hidden
  because the wording beside it already carries that meaning.

## Notes on what the clip deliberately does not do

- **No Supabase SDK.** The clip calls the `guest_*` RPCs directly over
  URLSession (`ClipAPI.swift`). App Clips have a 15 MB uncompressed budget;
  the guest flow needs no auth and the web client already polls rather than
  using Realtime, so the SDK bought nothing. The clip binary is ~73 KB.
- **No push notifications.** An App Clip can only request an ephemeral
  notification permission lasting a few hours. Rather than half-deliver
  "you're up next", the status screen points at the full app.
- **No sign-in.** The clip is guest-only, exactly like the web client, and
  stores its session token in UserDefaults the way the web stores it in
  localStorage.
