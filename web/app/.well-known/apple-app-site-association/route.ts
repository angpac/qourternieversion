import { NextResponse } from "next/server";

// Lets iOS treat qourt-web.vercel.app/join/* links (and their QR codes) as
// Universal Links: if the native app is installed, tapping/scanning opens
// it directly to that game's join flow instead of the web guest client.
// Must be served with an application/json content type and no redirects.
//
// The "appclips" key is the same idea for the App Clip target
// (net.criers.Qourt.Clip): if the full app ISN'T installed but the App
// Clip is registered, iOS shows the App Clip card instead of falling
// through to this same domain's plain web guest page. No separate App
// Clip Code needed — the per-game QR/link InvitePlayersView already
// generates is enough. Anyone without an eligible iOS device (Android
// included) still just lands on the web guest page below, unchanged.
export async function GET() {
  return NextResponse.json({
    applinks: {
      apps: [],
      details: [
        {
          appID: "67YBGP3A84.net.criers.Qourt",
          paths: ["/join/*"],
        },
      ],
    },
    appclips: {
      apps: ["67YBGP3A84.net.criers.Qourt.Clip"],
    },
  });
}
