import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Terms of Service | Qourt",
};

export default function TermsPage() {
  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col px-6 py-12">
      <header className="border-b border-black/10 pb-6 dark:border-white/15">
        <Link className="text-sm font-medium text-emerald-700 hover:underline dark:text-emerald-400" href="/">
          ← Qourt
        </Link>
        <h1 className="mt-4 text-3xl font-bold tracking-tight">Terms of Service</h1>
        <p className="mt-2 text-sm opacity-70">Last updated 21 August 2026</p>
      </header>

      <div className="legal-body flex flex-col gap-6 py-8 text-[15px] leading-relaxed">
        <p>
          These terms cover your use of Qourt, including the iPhone app, the Apple Watch app, the App
          Clip, and this website. By signing in or joining a game you agree to them. If you do not agree,
          please do not use Qourt.
        </p>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">What Qourt is</h2>
          <p>
            Qourt is a tool for organising badminton sessions. Organisers set up a game, add courts, and
            let the app manage the queue, the rotation, the brackets, and the scores. Players see their
            place in line, their court, and live scores on their own device. Qourt does not book courts,
            take payments, or organise anything on your behalf. It keeps track of a session that you and
            your community are running.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Your account</h2>
          <p>
            The iPhone and Watch apps use Sign in with Apple. You are responsible for keeping access to
            your Apple account secure, and for what happens under your Qourt account. You can join a game
            in a browser as a guest without an account at all.
          </p>
          <p>You must be old enough to use Qourt where you live, and at least 13.</p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Acceptable use</h2>
          <p>You agree not to:</p>
          <ul className="list-disc pl-5">
            <li>
              Use a display name, or send an announcement, that is abusive, harassing, hateful, or
              impersonates someone else.
            </li>
            <li>
              Join a game you have not been invited to, or share a join code to let someone disrupt a
              session.
            </li>
            <li>
              Try to break, overload, reverse engineer, or gain unauthorised access to Qourt or the
              accounts of other people.
            </li>
            <li>Use Qourt for anything illegal.</li>
          </ul>
          <p>We may remove content or suspend access to Qourt if these rules are broken.</p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">If you organise a game</h2>
          <p>
            Organisers control the roster, the queue, and the courts in their games, and can send
            announcements to the players in them. If you organise a game, you are responsible for how you
            run it and for treating the people in it fairly. Adding somebody to a roster means their
            display name and skill level become visible to everyone else in that game.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Content you provide</h2>
          <p>
            You keep ownership of what you put into Qourt, such as your display name, your game names, and
            your announcements. You give us permission to store it and to show it to the other people in
            your game, which is what makes the app work. You are responsible for having the right to share
            whatever you enter.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Playing badminton is up to you</h2>
          <p>
            Qourt tracks a queue and a score. It does not supervise play, assess whether a court is safe,
            or verify anybody&apos;s skill level, and it is not responsible for injuries, disputes, damage,
            or anything else that happens at your session. Play safely and use your judgement.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Availability</h2>
          <p>
            We work to keep Qourt running and its live sync fast, but we do not promise it will always be
            available, uninterrupted, or error free. Sessions depend on your network, on Apple&apos;s
            notification services, and on our hosting providers. Features may change or be withdrawn.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Disclaimers and liability</h2>
          <p>
            Qourt is provided &quot;as is&quot;, without warranties of any kind to the fullest extent the
            law allows. To the extent permitted by law, we are not liable for indirect, incidental, or
            consequential losses, or for lost data, arising from your use of Qourt. Nothing in these terms
            limits liability that cannot be limited by law.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Ending your use</h2>
          <p>
            You can stop using Qourt whenever you like, and you can ask us to delete your account by
            writing to the address below. We may suspend or end access if these terms are broken or if we
            need to protect other people using the app.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Changes to these terms</h2>
          <p>
            If we change these terms we will update the date at the top of this page, and surface material
            changes in the app before they take effect. Continuing to use Qourt after that means you accept
            the new terms.
          </p>
        </section>

        <section className="flex flex-col gap-3">
          <h2 className="text-lg font-semibold tracking-tight">Contact</h2>
          <p>
            Questions about these terms can go to{" "}
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
