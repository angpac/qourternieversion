import { NextResponse } from "next/server";

// Tells iOS what to do with qourt-web.vercel.app/join/* links and the QR
// codes that encode them. Must be served as application/json, from the
// bare domain, with no redirects.
//
// Two claims, and iOS picks between them by what's installed:
//   applinks  - Qourt is installed, so open it straight to the join flow.
//   appclips  - Qourt isn't installed: offer the App Clip instead of
//               sending the guest to the web client.
// Anything that isn't iOS ignores this file entirely and just loads the
// page, which is how Android guests keep getting the web client.
//
// The appclips claim alone isn't enough to make the App Clip card appear.
// The same URL also has to be registered as an Advanced App Clip
// Experience in App Store Connect - see docs/AppClip_Setup.md.
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
