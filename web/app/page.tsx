import JoinForm from "@/components/JoinForm";

export default function Home() {
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
