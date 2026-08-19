import type { Metadata } from "next";
import JoinForm from "@/components/JoinForm";

// Bare /join, with no code. This is the URL registered as the App Clip
// invocation in App Store Connect, and Apple holds it as the canonical
// entry point, so it has to resolve - it used to 404 because the only
// route here was /join/[code].
//
// It's also what someone lands on if a QR scan drops the code, or if the
// URL gets shared with the code trimmed off. Same form as the home page,
// with the code field open for typing.
export async function generateMetadata(): Promise<Metadata> {
  const appStoreId = process.env.NEXT_PUBLIC_APP_STORE_ID;
  if (!appStoreId) return {};
  return {
    other: {
      "apple-itunes-app": `app-id=${appStoreId}, app-clip-bundle-id=net.criers.Qourt.Clip, app-clip-display=card`,
    },
  };
}

export default function JoinPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 bg-gradient-to-b from-emerald-900 to-emerald-700 px-6 py-16">
      <div className="flex flex-col items-center gap-2 text-center text-white">
        <h1 className="text-4xl font-bold">Qourt</h1>
        <p className="text-emerald-100">Run the game. Not the whiteboard.</p>
      </div>
      <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
        <JoinForm />
      </div>
    </main>
  );
}
