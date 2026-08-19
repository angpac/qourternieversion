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
