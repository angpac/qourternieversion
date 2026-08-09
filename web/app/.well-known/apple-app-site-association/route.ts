import { NextResponse } from "next/server";

// Lets iOS treat qourt-web.vercel.app/join/* links (and their QR codes) as
// Universal Links: if the native app is installed, tapping/scanning opens
// it directly to that game's join flow instead of the web guest client.
// Must be served with an application/json content type and no redirects.
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
  });
}
