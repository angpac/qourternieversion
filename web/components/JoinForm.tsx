"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { supabase } from "@/lib/supabase";

const SKILL_LEVELS = ["Beginner", "Intermediate", "Advanced"];

type GamePreview = { name: string; status: string };

export default function JoinForm({ initialCode = "" }: { initialCode?: string }) {
  const router = useRouter();
  const [joinCode, setJoinCode] = useState(initialCode);
  const [name, setName] = useState("");
  const [skillLevel, setSkillLevel] = useState("Beginner");
  const [isJoining, setIsJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // A code that arrived via a scanned QR / tapped link is already correct —
  // show it as a settled confirmation, not another blank-looking field to
  // fill in, so people don't miss that it's already handled for them.
  const [isEditingCode, setIsEditingCode] = useState(!initialCode);
  const [gamePreview, setGamePreview] = useState<GamePreview | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [isLoadingPreview, setIsLoadingPreview] = useState(false);

  useEffect(() => {
    if (isEditingCode || !joinCode) {
      setGamePreview(null);
      setPreviewError(null);
      return;
    }
    let cancelled = false;
    setIsLoadingPreview(true);
    setPreviewError(null);
    supabase
      .rpc("game_preview_by_code", { p_join_code: joinCode })
      .then(({ data, error: rpcError }) => {
        if (cancelled) return;
        setIsLoadingPreview(false);
        if (rpcError) {
          setPreviewError(rpcError.message);
          return;
        }
        const preview = data as GamePreview;
        if (preview.status === "ended") {
          setPreviewError("This game has ended. The code no longer works.");
          return;
        }
        setGamePreview(preview);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isEditingCode, joinCode]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    const code = joinCode.trim();
    const trimmedName = name.trim();
    if (!code || !trimmedName) {
      setError("Enter a join code and your name.");
      return;
    }

    setIsJoining(true);
    const { data, error: rpcError } = await supabase.rpc("guest_join_game", {
      p_join_code: code,
      p_display_name: trimmedName,
      p_skill_level: skillLevel,
    });
    setIsJoining(false);

    if (rpcError) {
      setError(rpcError.message);
      return;
    }

    localStorage.setItem("qourt_session_token", data.session_token);
    router.push("/status");
  }

  return (
    <form onSubmit={handleSubmit} className="flex w-full max-w-sm flex-col gap-4">
      {!isEditingCode && (
        <p className="text-center text-sm text-zinc-600">
          You scanned the code, just add your name below to join.
        </p>
      )}

      <div className="flex flex-col gap-1">
        {isEditingCode ? (
          <>
            <label htmlFor="joinCode" className="text-sm font-medium text-zinc-700">
              Join code
            </label>
            <input
              id="joinCode"
              value={joinCode}
              onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
              placeholder="6-character code"
              autoCapitalize="characters"
              autoCorrect="off"
              className="rounded-lg border border-zinc-300 px-4 py-3 text-lg tracking-widest font-mono uppercase text-zinc-900 focus:border-emerald-600 focus:outline-none"
            />
          </>
        ) : previewError ? (
          <div className="flex items-center justify-between gap-3 rounded-lg border-2 border-red-300 bg-red-50 px-4 py-3">
            <div className="flex flex-col">
              <span className="text-sm font-medium text-red-700">{previewError}</span>
              <span className="font-mono text-xs tracking-widest text-red-500">{joinCode}</span>
            </div>
            <button
              type="button"
              onClick={() => setIsEditingCode(true)}
              className="text-xs font-medium text-red-700 underline"
            >
              Try another code
            </button>
          </div>
        ) : (
          <div className="flex items-center justify-between gap-3 rounded-lg border-2 border-emerald-600 bg-emerald-50 px-4 py-3">
            <div className="flex items-center gap-3">
              <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-emerald-600 text-white">
                ✓
              </span>
              <div className="flex flex-col">
                <span className="text-xs font-medium text-emerald-700">Joining</span>
                <span className="text-lg font-bold text-emerald-900">
                  {isLoadingPreview ? "…" : (gamePreview?.name ?? "game")}
                </span>
                <span className="font-mono text-xs tracking-widest text-emerald-700">{joinCode}</span>
              </div>
            </div>
            <button
              type="button"
              onClick={() => setIsEditingCode(true)}
              className="text-xs font-medium text-emerald-700 underline"
            >
              Not this game?
            </button>
          </div>
        )}
      </div>

      <div className="flex flex-col gap-1">
        <label htmlFor="name" className="text-sm font-medium text-zinc-700">
          Your name
        </label>
        <input
          id="name"
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="Name"
          className="rounded-lg border border-zinc-300 px-4 py-3 focus:border-emerald-600 focus:outline-none"
        />
      </div>

      <div className="flex flex-col gap-1">
        <label htmlFor="skillLevel" className="text-sm font-medium text-zinc-700">
          Skill level
        </label>
        <select
          id="skillLevel"
          value={skillLevel}
          onChange={(e) => setSkillLevel(e.target.value)}
          className="rounded-lg border border-zinc-300 px-4 py-3 focus:border-emerald-600 focus:outline-none"
        >
          {SKILL_LEVELS.map((level) => (
            <option key={level} value={level}>
              {level}
            </option>
          ))}
        </select>
      </div>

      {error && <p className="text-sm text-red-600">{error}</p>}

      <button
        type="submit"
        disabled={isJoining || (!isEditingCode && previewError !== null)}
        className="mt-2 rounded-lg bg-emerald-700 px-4 py-3 font-semibold text-white transition-colors hover:bg-emerald-800 disabled:opacity-50"
      >
        {isJoining ? "Joining…" : "Join"}
      </button>
    </form>
  );
}
