import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Privacy Policy | Qourt",
};

export default function PrivacyPage() {
  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col px-6 py-12">
      <header className="border-b border-black/10 pb-6 dark:border-white/15">
        <Link className="text-sm font-medium text-emerald-700 hover:underline dark:text-emerald-400" href="/">
          ← Qourt
        </Link>
        <h1 className="mt-4 text-3xl font-bold tracking-tight">Privacy Policy</h1>
        <p className="mt-2 text-sm opacity-70">Last updated 21 August 2026</p>
      </header>

      <div className="legal-body flex flex-col gap-6 py-8 text-[15px] leading-relaxed">
        <p>
          Qourt helps badminton organisers run court rotations and tournaments, and lets players see the
          queue, their court, and live scores. This policy explains exactly what the app collects, why,
          and how to get rid of it. We do not sell your data, we do not show ads, and we do not track you
          across other apps or websites.
        </p>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">What we collect</h2>
          <p className="font-medium">If you sign in to the iPhone or Watch app</p>
          <ul className="list-disc pl-5">
            <li>
              <strong>Your Apple account identifier.</strong> You sign in with Sign in with Apple. Apple
              gives us a unique identifier for you and, the first time you sign in, your name. We ask Apple
              only for your name, not your email address. If Apple chooses to pass along a private relay
              email address, our authentication provider stores it and we do not use it.
            </li>
            <li>
              <strong>Your profile.</strong> A display name (seeded from your Apple name, editable at any
              time), your skill level, and whether you have paired an Apple Watch.
            </li>
            <li>
              <strong>Device tokens for notifications.</strong> If you allow notifications, we store an
              Apple Push Notification token for each of your devices, covering iPhone, Apple Watch, and App
              Clip, plus a token for any Live Activity showing your match on the Lock Screen. These exist
              only to send you notifications about your game.
            </li>
          </ul>
          <p className="font-medium">If you join as a guest in a browser</p>
          <ul className="list-disc pl-5">
            <li>
              <strong>A display name and skill level</strong> that you type in. No account is created and
              we never ask for an email or a password.
            </li>
            <li>
              <strong>A session token</strong> stored in your browser so the page remembers which player
              you are when you come back.
            </li>
            <li>
              <strong>A web push subscription</strong> if you allow browser notifications. This is the
              subscription URL, its keys, and your browser user agent, which we keep so we can clear out
              dead subscriptions.
            </li>
          </ul>
          <p className="font-medium">Whichever way you join</p>
          <ul className="list-disc pl-5">
            <li>
              <strong>Gameplay information:</strong> the games you join, your position in the queue, which
              court you are on, who you played with and against, and match scores.
            </li>
            <li>
              <strong>Announcements</strong> that an organiser sends to the game you are in.
            </li>
          </ul>
          <p>
            The app can open your camera to scan a game&apos;s QR code. That happens entirely on your
            device. We never receive, store, or transmit camera images.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">What we don&apos;t collect</h2>
          <p>
            No advertising identifiers, no analytics or tracking SDKs, no location data, no contacts, no
            health data, and no payment details. Qourt has no payment features at all.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Why we collect it</h2>
          <p>
            Every item above exists to make the app work: to show you your place in line, to put you on a
            court, to keep the scoreboard live for everyone in your game, and to notify you when you are
            up. We do not use any of it for advertising or profiling.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Who else processes it</h2>
          <ul className="list-disc pl-5">
            <li>
              <strong>Supabase</strong> hosts our database, authentication, and realtime sync. All the
              information above is stored there.
            </li>
            <li>
              <strong>Apple</strong> provides Sign in with Apple and delivers push notifications to Apple
              devices.
            </li>
            <li>
              <strong>Vercel</strong> hosts this website and the browser guest experience.
            </li>
            <li>
              <strong>Your browser vendor&apos;s push service</strong> delivers web push notifications if
              you turned them on.
            </li>
          </ul>
          <p>
            These are service providers acting on our behalf. We do not sell or rent your information to
            anyone, and we do not share it for advertising.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Who can see your information</h2>
          <p>
            Your display name, skill level, queue position, court, and match scores are visible to other
            people in the same game. That is the point of a shared queue and a live scoreboard. Organisers
            of a game can additionally manage your place in it. People outside your game cannot see you,
            and a short join code or QR code is required to enter a game at all.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">How long we keep it</h2>
          <p>
            Profile information is kept until you delete your account. Game and match records are kept so
            organisers and players keep their history. Push tokens are removed when they stop working or
            when you turn notifications off. Guest session tokens expire with the browser session they
            belong to.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Deleting your data</h2>
          <p>
            To delete your account and everything attached to it, meaning your profile, your device
            tokens, and your membership in any game, write to{" "}
            <a className="text-emerald-700 underline dark:text-emerald-400" href="mailto:ernesto@criers.net">
              ernesto@criers.net
            </a>{" "}
            and we will action it. This also applies if you joined as a browser guest and want your guest
            record removed.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Your rights</h2>
          <p>
            Depending on where you live, you may have the right to access, correct, export, or delete the
            information we hold about you, and to object to how we use it. Contact us at the address above
            and we will respond.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Children</h2>
          <p>
            Qourt is not directed at children under 13, and we do not knowingly collect information from
            them. If you believe a child has given us information, contact us and we will delete it.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Changes to this policy</h2>
          <p>
            If we change this policy we will update the date at the top of this page. Material changes will
            be surfaced in the app before they take effect.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Contact</h2>
          <p>
            Questions about this policy or your data can go to{" "}
            <a className="text-emerald-700 underline dark:text-emerald-400" href="mailto:ernesto@criers.net">
              ernesto@criers.net
            </a>
            .
          </p>
        </section>
      </div>

      <footer className="mt-auto border-t border-black/10 pt-6 text-sm dark:border-white/15">
        <nav className="flex gap-4">
          <Link className="text-emerald-700 hover:underline dark:text-emerald-400" href="/privacy">
            Privacy Policy
          </Link>
          <Link className="text-emerald-700 hover:underline dark:text-emerald-400" href="/terms">
            Terms of Service
          </Link>
        </nav>
      </footer>
    </main>
  );
}
