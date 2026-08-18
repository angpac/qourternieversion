// Sends push notifications on the events the DB triggers fire:
//   match_assigned  - a player is put on court ("you're up!")
//   announcement    - an admin messages the game
//   queue_advanced  - the queue moved; players near the front get a heads-up
//   player_left     - someone quit or stepped out; the host gets a nudge Delivers over two separate paths per
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
// The Watch app and the App Clip are separate bundle ids, so APNs treats
// them as separate topics — a token from either is rejected under the
// iOS topic. The App Clip id is env-overridable because the clip target
// isn't built yet and its final id may differ.
const APNS_WATCH_BUNDLE_ID = Deno.env.get("APNS_WATCH_BUNDLE_ID") ?? `${APNS_BUNDLE_ID}.watchkitapp`;
const APNS_APPCLIP_BUNDLE_ID = Deno.env.get("APNS_APPCLIP_BUNDLE_ID") ?? `${APNS_BUNDLE_ID}.Clip`;

type Platform = "ios" | "watchos" | "appclip";

function apnsTopic(platform: Platform): string {
  switch (platform) {
    case "watchos":
      return APNS_WATCH_BUNDLE_ID;
    case "appclip":
      return APNS_APPCLIP_BUNDLE_ID;
    default:
      return APNS_BUNDLE_ID;
  }
}

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

async function sendApns(deviceToken: string, title: string, body: string, platform: Platform = "ios") {
  const jwt = await apnsJwt();
  if (!jwt) return; // APNs not configured yet — no-op, don't fail the batch
  try {
    await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": apnsTopic(platform),
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
      .select("device_token, platform")
      .eq("profile_id", player.profile_id);
    for (const row of tokens ?? []) {
      sends.push(sendApns(row.device_token, title, body, row.platform as Platform));
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

/// Sends to every device a signed-in profile owns — phone, Watch, App Clip.
/// Used for hosts, who are not necessarily rows in game_players.
async function notifyProfile(profileId: string, title: string, body: string) {
  const { data: tokens } = await supabase
    .from("apns_device_tokens")
    .select("device_token, platform")
    .eq("profile_id", profileId);

  await Promise.all(
    (tokens ?? []).map((row) => sendApns(row.device_token, title, body, row.platform as Platform))
  );
}

/// Everyone who administers a game: its owner, its explicit co-admins, and
/// — if the game is linked to a club — that club's owner and admins. Mirrors
/// the is_game_admin() inheritance in the schema.
async function gameAdminProfileIds(gameId: string): Promise<string[]> {
  const ids = new Set<string>();

  const { data: game } = await supabase
    .from("games")
    .select("owner_id, club_id")
    .eq("id", gameId)
    .single();
  if (!game) return [];
  if (game.owner_id) ids.add(game.owner_id);

  const { data: coAdmins } = await supabase
    .from("game_admins")
    .select("profile_id")
    .eq("game_id", gameId);
  for (const row of coAdmins ?? []) ids.add(row.profile_id);

  if (game.club_id) {
    const { data: club } = await supabase
      .from("clubs")
      .select("owner_id")
      .eq("id", game.club_id)
      .single();
    if (club?.owner_id) ids.add(club.owner_id);

    const { data: clubAdmins } = await supabase
      .from("club_admins")
      .select("profile_id")
      .eq("club_id", game.club_id);
    for (const row of clubAdmins ?? []) ids.add(row.profile_id);
  }

  return [...ids];
}

/// "Your turn is coming up" for whoever is now within one match of playing.
///
/// Fired whenever someone leaves the queue, which is the only moment
/// positions shift. Each player is told once per stint in the queue —
/// turn_soon_notified_at is the guard, and a BEFORE UPDATE trigger clears it
/// when they re-queue, so a queue that churns can't spam the same person.
async function handleQueueAdvanced(gameId: string) {
  const { data: game } = await supabase
    .from("games")
    .select("name, is_doubles, status")
    .eq("id", gameId)
    .single();
  if (!game) return;
  // A draft or finished game has no meaningful "next up".
  if (game.status !== "live") return;

  // The queue really did just shift, independent of whether anyone still
  // needs a fresh "you're up next" ping below — so every queued player's
  // Live Activity gets its position refreshed unconditionally.
  await pushQueuePositionsToLiveActivities(gameId);

  const matchSize = game.is_doubles ? 4 : 2;

  const { data: queued } = await supabase
    .from("game_players")
    .select("id, turn_soon_notified_at")
    .eq("game_id", gameId)
    .eq("status", "queued")
    .order("queue_position", { ascending: true, nullsFirst: false })
    .order("joined_at", { ascending: true })
    .limit(matchSize);

  const candidates = (queued ?? []).filter((p) => p.turn_soon_notified_at === null);
  if (candidates.length === 0) return;

  // Claim before sending, not after.
  //
  // Putting four players on court flips four rows out of the queue, so this
  // trigger fires four times and four invocations run concurrently. If each
  // read "not yet notified", sent, and only then stamped, every up-next
  // player would get four identical pushes. The `is null` predicate makes
  // the claim atomic per row: exactly one invocation wins each row, and
  // `select()` returns only the rows this one actually claimed.
  const { data: claimed } = await supabase
    .from("game_players")
    .update({ turn_soon_notified_at: new Date().toISOString() })
    .in("id", candidates.map((p) => p.id))
    .is("turn_soon_notified_at", null)
    .select("id");

  if (!claimed || claimed.length === 0) return;

  await Promise.all(
    claimed.map((player) =>
      notifyGamePlayer(
        player.id,
        "You're up next",
        `Get ready — you're in the next match at ${game.name}.`
      )
    )
  );
}

/// Keeps every queued player's Lock Screen / Dynamic Island Live Activity
/// showing their real position, even while the app is backgrounded — without
/// this, the "#N in line" badge only refreshes the next time they foreground
/// the app. Distinct from the "you're up next" notification above: this
/// covers the WHOLE queue, not just the next matchSize players, and fires
/// on every queue shift rather than once per stint in the queue.
async function pushQueuePositionsToLiveActivities(gameId: string) {
  const { data: queued } = await supabase
    .from("game_players")
    .select("id")
    .eq("game_id", gameId)
    .eq("status", "queued")
    .order("queue_position", { ascending: true, nullsFirst: false })
    .order("joined_at", { ascending: true });

  if (!queued || queued.length === 0) return;

  await Promise.all(
    queued.map((player, index) =>
      sendLiveActivityUpdate(player.id, {
        status: "queued",
        queuePosition: index + 1,
        courtName: null,
        teammateNames: null,
        opponentNames: null,
        scoreA: null,
        scoreB: null,
      })
    )
  );
}

/// Nudges the host when a player quits ('removed') or steps out ('resting'),
/// since either leaves a gap the host has to fill.
async function handlePlayerLeft(gamePlayerId: string, newStatus: string) {
  const { data: player } = await supabase
    .from("game_players")
    .select("display_name, game_id")
    .eq("id", gamePlayerId)
    .single();
  if (!player) return;

  const { data: game } = await supabase
    .from("games")
    .select("name, status")
    .eq("id", player.game_id)
    .single();
  // Includes 'paused': an admin who paused the session still needs to know
  // someone dropped out, since that's often exactly why they'd resume with a
  // different lineup. Only draft and ended games are silent.
  if (!game || (game.status !== "live" && game.status !== "paused")) return;

  const quit = newStatus === "removed";
  const title = quit ? "Player left" : "Player stepped out";
  const body = quit
    ? `${player.display_name} left ${game.name}. The queue may need a rebalance.`
    : `${player.display_name} is sitting out at ${game.name}.`;

  const adminIds = await gameAdminProfileIds(player.game_id);
  await Promise.all(adminIds.map((id) => notifyProfile(id, title, body)));
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
    } else if (payload.type === "queue_advanced") {
      await handleQueueAdvanced(payload.game_id);
    } else if (payload.type === "player_left") {
      await handlePlayerLeft(payload.game_player_id, payload.new_status);
    }
  } catch (error) {
    console.error("send-push failed", error);
    return new Response("error", { status: 500 });
  }

  return new Response("ok", { status: 200 });
});
