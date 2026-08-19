import type { Metadata } from "next";
import JoinForm from "@/components/JoinForm";

// Smart App Banner. It covers the case the App Clip card can't: a link
// opened inside Safari, where iOS shows this banner rather than the card.
// A scanned QR goes through the Camera app instead and gets the card
// directly, driven by the AASA `appclips` claim.
//
// `app-clip-display=card` asks Safari for the full App Clip card. The
// numeric App Store id is required even for a clip-only banner, so the
// banner is omitted entirely until NEXT_PUBLIC_APP_STORE_ID is set -
// a banner with a placeholder id would send people to the wrong listing.
export async function generateMetadata(): Promise<Metadata> {
  const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID;
  if (!appStoreId) return {};
  return {
    other: {
      "apple-itunes-app": `app-id=${appStoreId}, app-clip-bundle-id=net.criers.Qourt.Clip, app-clip-display=card`,
    },
  };
}

export default async function JoinWithCodePage({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-b from-emerald-900 to-emerald-700 px-6 py-16">
      <div className="flex flex-col items-center gap-2 text-center text-white">
        <h1 className="text-4xl font-bold">Qourt</h1>
        <p className="text-emerald-100">Run the game. Not the whiteboard.</p>
      </div>
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
        <JoinForm initialCode={decodeURIComponent(code).toUpperCase()} />
      </div>
    </main>
  );
}
