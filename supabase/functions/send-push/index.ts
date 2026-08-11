// Sends push notifications on two events (see the DB triggers that call
// this): a player getting assigned to a fresh match ("you're up!"), and an
// admin sending an announcement. Delivers over two separate paths per
// CLAUDE.md — APNs for the iPhone app + Watch, Web Push (VAPID) for browser
// guests — no third-party push vendor for either.
import { createClient } from "npm:@supabase/supabase-js@2";
import { SignJWT, importPKCS8 } from "npm:jose@5";
import webpush from "npm:web-push@3";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID");
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID");
const APNS_AUTH_KEY = Deno.env.get("APNS_AUTH_KEY"); // .p8 file contents, PEM format
const APNS_BUNDLE_ID = Deno.env.get("APNS_BUNDLE_ID") ?? "net.criers.Qourt";

const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY");
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY");
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") ?? "mailto:support@example.com";

if (VAPID_PUBLIC_KEY && VAPID_PRIVATE_KEY) {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
}

let cachedApnsJwt: { token: string; issuedAt: number } | null = null;

async function apnsJwt(): Promise<string | null> {
  if (!APNS_TEAM_ID || !APNS_KEY_ID || !APNS_AUTH_KEY) return null;
  // APNs auth tokens are valid up to an hour; reuse for 50 minutes.
  if (cachedApnsJwt && Date.now() - cachedApnsJwt.issuedAt < 50 * 60 * 1000) {
    return cachedApnsJwt.token;
  }
  // Stored as a Supabase secret with literal "\n" sequences (safer to pass
  // through the CLI than raw newlines) — restore real newlines for PEM parsing.
  const key = await importPKCS8(APNS_AUTH_KEY.replace(/\\n/g, "\n"), "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: APNS_KEY_ID })
    .setIssuedAt()
    .setIssuer(APNS_TEAM_ID)
    .sign(key);
  cachedApnsJwt = { token, issuedAt: Date.now() };
  return token;
}

async function sendApns(deviceToken: string, title: string, body: string) {
  const jwt = await apnsJwt();
  if (!jwt) return; // APNs not configured yet — no-op, don't fail the batch
  try {
    await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify({ aps: { alert: { title, body }, sound: "default" } }),
    });
  } catch (error) {
    console.error("APNs send failed", error);
  }
}

async function sendWebPush(
  subscription: { endpoint: string; p256dh_key: string; auth_key: string },
  title: string,
  body: string
) {
  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) return;
  try {
    await webpush.sendNotification(
      {
        endpoint: subscription.endpoint,
        keys: { p256dh: subscription.p256dh_key, auth: subscription.auth_key },
      },
      JSON.stringify({ title, body })
    );
  } catch (error) {
    console.error("Web push send failed", error);
  }
}

// Live Activity pushes use a different APNs push type/topic and payload
// shape than a regular alert — no title/body, just a content-state blob
// matching PlayerActivityAttributes.ContentState field-for-field (Swift's
// Codable synthesis expects these exact camelCase keys).
async function sendLiveActivityUpdate(gamePlayerId: string, contentState: Record<string, unknown>) {
  const { data: tokenRow } = await supabase
    .from("live_activity_tokens")
    .select("push_token")
    .eq("game_player_id", gamePlayerId)
    .single();
  if (!tokenRow) return;

  const jwt = await apnsJwt();
  if (!jwt) return;
  try {
    await fetch(`https://api.push.apple.com/3/device/${tokenRow.push_token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": `${APNS_BUNDLE_ID}.push-type.liveactivity`,
        "apns-push-type": "liveactivity",
        "apns-priority": "10",
      },
      body: JSON.stringify({
        aps: {
          timestamp: Math.floor(Date.now() / 1000),
          event: "update",
          "content-state": contentState,
        },
      }),
    });
  } catch (error) {
    console.error("Live Activity push failed", error);
  }
}

async function notifyGamePlayer(gamePlayerId: string, title: string, body: string) {
  const { data: player } = await supabase
    .from("game_players")
    .select("profile_id")
    .eq("id", gamePlayerId)
    .single();

  const sends: Promise<void>[] = [];

  if (player?.profile_id) {
    const { data: tokens } = await supabase
      .from("apns_device_tokens")
      .select("device_token")
      .eq("profile_id", player.profile_id);
    for (const row of tokens ?? []) {
      sends.push(sendApns(row.device_token, title, body));
    }
  }

  const { data: subs } = await supabase
    .from("push_subscriptions")
    .select("endpoint, p256dh_key, auth_key")
    .eq("game_player_id", gamePlayerId);
  for (const sub of subs ?? []) {
    sends.push(sendWebPush(sub, title, body));
  }

  await Promise.all(sends);
}

async function handleMatchAssigned(matchId: string, gamePlayerId: string) {
  const { data: matchPlayer } = await supabase
    .from("match_players")
    .select("game_player_id, match_id, team")
    .eq("match_id", matchId)
    .eq("game_player_id", gamePlayerId)
    .single();
  if (!matchPlayer) return;

  const { data: match } = await supabase
    .from("matches")
    .select("court_id, game_id")
    .eq("id", matchPlayer.match_id)
    .single();
  if (!match) return;

  const { data: game } = await supabase.from("games").select("name").eq("id", match.game_id).single();
  const { data: court } = match.court_id
    ? await supabase.from("courts").select("name").eq("id", match.court_id).single()
    : { data: null };

  await notifyGamePlayer(
    matchPlayer.game_player_id,
    "You're up!",
    court?.name ? `${court.name} — ${game?.name ?? "your game"}` : `Head to your court — ${game?.name ?? ""}`
  );

  const { data: allRows } = await supabase
    .from("match_players")
    .select("team, game_player_id, game_players(display_name)")
    .eq("match_id", matchPlayer.match_id);

  if (allRows) {
    const onTeamA = matchPlayer.team === "a";
    const myTeam = allRows.filter((r) => r.team === (onTeamA ? "a" : "b"));
    const oppTeam = allRows.filter((r) => r.team === (onTeamA ? "b" : "a"));
    const teammateOthers = myTeam
      .filter((r) => r.game_player_id !== matchPlayer.game_player_id)
      .map((r) => (r.game_players as { display_name: string } | null)?.display_name)
      .filter(Boolean);
    const opponentNames = oppTeam
      .map((r) => (r.game_players as { display_name: string } | null)?.display_name)
      .filter(Boolean)
      .join(" & ");

    await sendLiveActivityUpdate(matchPlayer.game_player_id, {
      status: "onCourt",
      queuePosition: null,
      courtName: court?.name ?? null,
      teammateNames: teammateOthers.length > 0 ? `You & ${teammateOthers.join(" & ")}` : "You",
      opponentNames,
      scoreA: 0,
      scoreB: 0,
    });
  }
}

async function handleAnnouncement(announcementId: string) {
  const { data: announcement } = await supabase
    .from("announcements")
    .select("game_id, message, target_player_id")
    .eq("id", announcementId)
    .single();
  if (!announcement) return;

  const { data: game } = await supabase.from("games").select("name").eq("id", announcement.game_id).single();
  const title = game?.name ? `📣 ${game.name}` : "📣 Announcement";

  if (announcement.target_player_id) {
    await notifyGamePlayer(announcement.target_player_id, title, announcement.message);
    return;
  }

  const { data: players } = await supabase
    .from("game_players")
    .select("id")
    .eq("game_id", announcement.game_id)
    .neq("status", "removed");

  await Promise.all((players ?? []).map((p) => notifyGamePlayer(p.id, title, announcement.message)));
}

Deno.serve(async (req) => {
  const secret = req.headers.get("x-webhook-secret");
  if (!secret || secret !== Deno.env.get("PUSH_WEBHOOK_SECRET")) {
    return new Response("Unauthorized", { status: 401 });
  }

  const payload = await req.json();

  try {
    if (payload.type === "match_assigned") {
      await handleMatchAssigned(payload.match_id, payload.game_player_id);
    } else if (payload.type === "announcement") {
      await handleAnnouncement(payload.announcement_id);
    }
  } catch (error) {
    console.error("send-push failed", error);
    return new Response("error", { status: 500 });
  }

  return new Response("ok", { status: 200 });
});
