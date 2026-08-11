"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

type Player = { id: string; display_name: string };

type PoolPlayer = { id: string; display_name: string; skill_level: string };

type AnnouncementItem = { id: string; message: string; sent_at: string };

type GuestStatus = {
  game_name: string;
  game_format: string;
  is_doubles: boolean;
  join_code: string;
  player_status: "pending" | "queued" | "on_court" | "resting" | "removed";
  queue_position: number | null;
  court_name: string | null;
  match_status: "in_progress" | "awaiting_confirmation" | null;
  score_a: number | null;
  score_b: number | null;
  team_a: Player[] | null;
  team_b: Player[] | null;
  last_match_score_a: number | null;
  last_match_score_b: number | null;
  last_match_my_team: "a" | "b" | null;
  is_picker: boolean;
  picker_pool: PoolPlayer[] | null;
  my_display_name: string;
  my_skill_level: string;
};

const POLL_INTERVAL_MS = 2000;

// A rough "how many matches until mine" hint on top of the raw individual
// queue position — useful for doubles, where "#7 in line" alone doesn't
// say much. Skipped for Peg Board: the Picker chooses from a pool further
// down the line rather than the next N players in order, so "the next 4
// are a match" doesn't hold there.
function groupsAheadText(status: GuestStatus): string | null {
  if (status.game_format === "peg_board" || status.queue_position === null) return null;
  const matchSize = status.is_doubles ? 4 : 2;
  const groupsAhead = Math.floor((status.queue_position - 1) / matchSize);
  if (groupsAhead < 1) return null;
  return `About ${groupsAhead} more match${groupsAhead === 1 ? "" : "es"} before yours`;
}

export default function StatusPage() {
  const router = useRouter();
  const [status, setStatus] = useState<GuestStatus | null>(null);
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isConfirmingLeave, setIsConfirmingLeave] = useState(false);
  const [isReportingScore, setIsReportingScore] = useState(false);
  const [reportScoreA, setReportScoreA] = useState(0);
  const [reportScoreB, setReportScoreB] = useState(0);
  const [isPicking, setIsPicking] = useState(false);
  const [pickedIds, setPickedIds] = useState<string[]>([]);
  const [pickerError, setPickerError] = useState<string | null>(null);
  const [notifStatus, setNotifStatus] = useState<"unsupported" | "default" | "granted" | "denied">(
    "default"
  );

  const sessionToken =
    typeof window !== "undefined" ? localStorage.getItem("qourt_session_token") : null;

  const poll = useCallback(async () => {
    if (!sessionToken) return;
    const { data, error: rpcError } = await supabase.rpc("guest_status", {
      p_session_token: sessionToken,
    });
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    setStatus(data as GuestStatus);
  }, [sessionToken]);

  const pollAnnouncements = useCallback(async () => {
    if (!sessionToken) return;
    const { data } = await supabase.rpc("guest_announcements", {
      p_session_token: sessionToken,
    });
    if (data) setAnnouncements(data as AnnouncementItem[]);
  }, [sessionToken]);

  useEffect(() => {
    if (!sessionToken) {
      router.replace("/");
      return;
    }
    poll();
    pollAnnouncements();
    const interval = setInterval(() => {
      poll();
      pollAnnouncements();
    }, POLL_INTERVAL_MS);
    return () => clearInterval(interval);
  }, [router, sessionToken, poll, pollAnnouncements]);

  useEffect(() => {
    if (!("Notification" in window) || !("serviceWorker" in navigator) || !("PushManager" in window)) {
      setNotifStatus("unsupported");
      return;
    }
    setNotifStatus(Notification.permission as "default" | "granted" | "denied");
  }, []);

  function urlBase64ToUint8Array(base64String: string) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
    const rawData = atob(base64);
    return Uint8Array.from([...rawData].map((char) => char.charCodeAt(0)));
  }

  async function handleEnableNotifications() {
    if (!sessionToken) return;
    const permission = await Notification.requestPermission();
    setNotifStatus(permission);
    if (permission !== "granted") return;

    const vapidKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    if (!vapidKey) return;

    const registration = await navigator.serviceWorker.register("/sw.js");
    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidKey),
    });

    const json = subscription.toJSON();
    await supabase.rpc("guest_subscribe_push", {
      p_session_token: sessionToken,
      p_endpoint: json.endpoint,
      p_p256dh_key: json.keys?.p256dh,
      p_auth_key: json.keys?.auth,
      p_user_agent: navigator.userAgent,
    });
  }

  async function handleStepOut() {
    if (!sessionToken) return;
    await supabase.rpc("guest_step_out", { p_session_token: sessionToken });
    poll();
  }

  async function handleStepIn() {
    if (!sessionToken) return;
    await supabase.rpc("guest_step_in", { p_session_token: sessionToken });
    poll();
  }

  async function handleLeave() {
    if (!sessionToken) return;
    await supabase.rpc("guest_leave_game", { p_session_token: sessionToken });
    setIsConfirmingLeave(false);
    poll();
  }

  async function handleSubmitScore() {
    if (!sessionToken) return;
    await supabase.rpc("guest_report_score", {
      p_session_token: sessionToken,
      p_score_a: reportScoreA,
      p_score_b: reportScoreB,
    });
    setIsReportingScore(false);
    poll();
  }

  function togglePick(id: string) {
    setPickedIds((prev) => {
      if (prev.includes(id)) return prev.filter((p) => p !== id);
      if (prev.length >= 3) return prev;
      return [...prev, id];
    });
  }

  async function handleStartPickerMatch() {
    if (!sessionToken || pickedIds.length !== 3) return;
    setPickerError(null);
    const { error: rpcError } = await supabase.rpc("guest_pick_board_start_match", {
      p_session_token: sessionToken,
      p_teammate_ids: pickedIds,
    });
    if (rpcError) {
      setPickerError(rpcError.message);
      return;
    }
    setIsPicking(false);
    setPickedIds([]);
    poll();
  }

  if (error) {
    return (
      <main className="flex min-h-screen flex-col items-center justify-center gap-4 bg-gradient-to-b from-emerald-900 to-emerald-700 px-6 text-center text-white">
        <p>{error}</p>
        <button
          onClick={() => {
            localStorage.removeItem("qourt_session_token");
            router.replace("/");
          }}
          className="rounded-lg bg-white px-4 py-2 font-semibold text-emerald-800"
        >
          Join a different game
        </button>
      </main>
    );
  }

  if (!status) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-gradient-to-b from-emerald-900 to-emerald-700">
        <p className="text-white">Loading…</p>
      </main>
    );
  }

  const wonLastMatch =
    status.last_match_my_team && status.last_match_score_a !== null && status.last_match_score_b !== null
      ? status.last_match_my_team === "a"
        ? status.last_match_score_a > status.last_match_score_b
        : status.last_match_score_b > status.last_match_score_a
      : null;

  return (
    <main className="flex min-h-screen flex-col items-center gap-6 bg-gradient-to-b from-emerald-900 to-emerald-700 px-6 py-16">
      <div className="text-center text-white">
        <p className="text-sm text-emerald-100">{status.game_name}</p>
        <h1 className="text-3xl font-bold">{status.my_display_name}</h1>
        <p className="text-sm text-emerald-100">{status.my_skill_level}</p>
      </div>

      {announcements.length > 0 && (
        <div className="flex w-full max-w-sm items-start gap-2 rounded-xl bg-white px-4 py-3 shadow">
          <span>📣</span>
          <span className="text-sm font-medium text-zinc-800">{announcements[0].message}</span>
        </div>
      )}

      {wonLastMatch !== null && (
        <div
          className={`flex w-full max-w-sm items-center justify-between rounded-xl px-4 py-3 shadow ${
            wonLastMatch ? "bg-amber-100" : "bg-white"
          }`}
        >
          <span className="font-semibold text-zinc-800">
            {wonLastMatch ? "🏆 You won your last match" : "You lost your last match"}
          </span>
          <span className="font-mono text-zinc-600">
            {status.last_match_score_a} – {status.last_match_score_b}
          </span>
        </div>
      )}

      <div className="w-full max-w-sm rounded-2xl bg-white p-8 shadow-xl">
        {status.player_status === "pending" && (
          <div className="flex flex-col items-center gap-2 text-center">
            <div className="text-5xl">⌛</div>
            <p className="text-xl font-bold text-zinc-900">Waiting for approval</p>
            <p className="text-sm text-zinc-500">
              The host needs to approve you before you can join the line.
            </p>
          </div>
        )}

        {status.player_status === "queued" && (
          <div className="flex flex-col items-center gap-2 text-center">
            <div className="text-5xl">⏳</div>
            <p className="text-2xl font-bold text-zinc-900">
              You&apos;re #{status.queue_position} in line
            </p>
            {groupsAheadText(status) && (
              <p className="text-sm text-zinc-600">{groupsAheadText(status)}</p>
            )}
            <p className="text-sm text-zinc-500">{status.game_format}</p>
          </div>
        )}

        {status.player_status === "queued" && status.is_picker && (
          <div className="mt-6 flex flex-col items-center gap-2 rounded-xl bg-amber-50 px-4 py-4 text-center">
            <div className="text-3xl">⭐</div>
            <p className="font-bold text-zinc-900">You&apos;re the Picker!</p>
            <p className="text-sm text-zinc-600">Choose 3 players from the line to build your match.</p>
            <button
              onClick={() => {
                setPickedIds([]);
                setPickerError(null);
                setIsPicking(true);
              }}
              className="mt-1 rounded-lg bg-emerald-700 px-4 py-2 text-sm font-semibold text-white"
            >
              Build your match
            </button>
          </div>
        )}

        {status.player_status === "on_court" && (
          <div className="flex flex-col items-center gap-3 text-center">
            <div className="flex items-center gap-2">
              <span
                className={`h-2.5 w-2.5 rounded-full ${
                  status.match_status === "awaiting_confirmation" ? "bg-amber-500" : "bg-green-500"
                }`}
              />
              <p className="text-2xl font-bold text-zinc-900">{status.court_name}</p>
            </div>

            {status.team_a && status.team_b && (
              <div className="flex flex-col gap-1">
                <p className="font-semibold text-zinc-800">
                  {status.team_a.map((p) => p.display_name).join(" & ")}
                </p>
                <p className="text-xs text-zinc-400">vs</p>
                <p className="font-semibold text-zinc-800">
                  {status.team_b.map((p) => p.display_name).join(" & ")}
                </p>
              </div>
            )}

            {status.score_a !== null && status.score_b !== null && (
              <p className="text-4xl font-bold text-zinc-900">
                {status.score_a} – {status.score_b}
              </p>
            )}

            {status.match_status === "awaiting_confirmation" ? (
              <p className="text-sm font-medium text-amber-600">Waiting for admin to confirm</p>
            ) : (
              <button
                onClick={() => {
                  setReportScoreA(0);
                  setReportScoreB(0);
                  setIsReportingScore(true);
                }}
                className="mt-1 rounded-lg border border-emerald-700 px-4 py-2 text-sm font-semibold text-emerald-700"
              >
                Report score
              </button>
            )}
          </div>
        )}

        {status.player_status === "resting" && (
          <div className="flex flex-col items-center gap-3 text-center">
            <p className="text-zinc-600">You&apos;re resting. Step back in whenever you&apos;re ready.</p>
            <button
              onClick={handleStepIn}
              className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white"
            >
              I&apos;m ready to play
            </button>
          </div>
        )}

        {status.player_status === "removed" && (
          <p className="text-center text-zinc-600">You&apos;ve left this game.</p>
        )}

        {(status.player_status === "queued" ||
          status.player_status === "resting" ||
          status.player_status === "pending") && (
          <div className="mt-6 flex flex-col items-center gap-3 border-t border-zinc-100 pt-4">
            {status.player_status === "queued" && (
              <button onClick={handleStepOut} className="text-sm font-medium text-zinc-600 underline">
                Skip my turn
              </button>
            )}
            <button
              onClick={() => setIsConfirmingLeave(true)}
              className="text-sm font-medium text-red-600"
            >
              {status.player_status === "pending" ? "Cancel request" : "Leave game"}
            </button>
          </div>
        )}
      </div>

      {notifStatus === "default" && (
        <button
          onClick={handleEnableNotifications}
          className="rounded-lg bg-white/10 px-4 py-2 text-sm font-medium text-white underline"
        >
          Enable notifications
        </button>
      )}
      {notifStatus === "denied" && (
        <p className="text-xs text-emerald-100/70">
          Notifications are blocked. Enable them in your browser settings to get alerts.
        </p>
      )}

      <p className="font-mono text-sm text-emerald-100">Join code: {status.join_code}</p>

      {isConfirmingLeave && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/50 px-6">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="text-lg font-bold text-zinc-900">Leave this game?</h2>
            <p className="mt-1 text-sm text-zinc-600">You&apos;ll be removed from the roster.</p>
            <div className="mt-5 flex justify-end gap-3">
              <button onClick={() => setIsConfirmingLeave(false)} className="px-4 py-2 text-zinc-600">
                Cancel
              </button>
              <button onClick={handleLeave} className="rounded-lg bg-red-600 px-4 py-2 font-semibold text-white">
                Leave game
              </button>
            </div>
          </div>
        </div>
      )}

      {isReportingScore && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/50 px-6">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="text-lg font-bold text-zinc-900">Report score</h2>
            <div className="mt-4 flex items-center justify-between">
              <span className="text-sm font-medium text-zinc-700">
                {status.team_a?.map((p) => p.display_name).join(" & ")}
              </span>
              <input
                type="number"
                min={0}
                value={reportScoreA}
                onChange={(e) => setReportScoreA(Number(e.target.value))}
                className="w-16 rounded-lg border border-zinc-300 px-2 py-1 text-center"
              />
            </div>
            <div className="mt-3 flex items-center justify-between">
              <span className="text-sm font-medium text-zinc-700">
                {status.team_b?.map((p) => p.display_name).join(" & ")}
              </span>
              <input
                type="number"
                min={0}
                value={reportScoreB}
                onChange={(e) => setReportScoreB(Number(e.target.value))}
                className="w-16 rounded-lg border border-zinc-300 px-2 py-1 text-center"
              />
            </div>
            <div className="mt-5 flex justify-end gap-3">
              <button onClick={() => setIsReportingScore(false)} className="px-4 py-2 text-zinc-600">
                Cancel
              </button>
              <button
                onClick={handleSubmitScore}
                className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white"
              >
                Submit
              </button>
            </div>
          </div>
        </div>
      )}
      {isPicking && (
        <div className="fixed inset-0 flex items-center justify-center bg-black/50 px-6">
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl">
            <h2 className="text-lg font-bold text-zinc-900">You&apos;re the Picker</h2>
            <p className="mt-1 text-sm text-zinc-600">Pick 3 players to join your match.</p>
            <div className="mt-4 max-h-72 space-y-1 overflow-y-auto">
              {status.picker_pool?.map((player) => {
                const picked = pickedIds.includes(player.id);
                return (
                  <button
                    key={player.id}
                    onClick={() => togglePick(player.id)}
                    disabled={!picked && pickedIds.length >= 3}
                    className={`flex w-full items-center justify-between rounded-lg px-3 py-2 text-left text-sm ${
                      picked ? "bg-emerald-100 font-semibold text-emerald-800" : "text-zinc-700 hover:bg-zinc-50"
                    } disabled:opacity-40`}
                  >
                    <span>{player.display_name}</span>
                    <span className="flex items-center gap-2">
                      <span className="text-xs text-zinc-400">{player.skill_level}</span>
                      {picked && <span>✓</span>}
                    </span>
                  </button>
                );
              })}
              {(!status.picker_pool || status.picker_pool.length === 0) && (
                <p className="px-3 py-2 text-sm text-zinc-500">No one else is in line yet.</p>
              )}
            </div>
            {pickerError && <p className="mt-3 text-sm text-red-600">{pickerError}</p>}
            <div className="mt-5 flex justify-end gap-3">
              <button onClick={() => setIsPicking(false)} className="px-4 py-2 text-zinc-600">
                Cancel
              </button>
              <button
                onClick={handleStartPickerMatch}
                disabled={pickedIds.length !== 3}
                className="rounded-lg bg-emerald-700 px-4 py-2 font-semibold text-white disabled:opacity-40"
              >
                Start match ({pickedIds.length}/3)
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}
