import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APNS_KEY_ID = Deno.env.get("APNS_KEY_ID")!;
const APNS_TEAM_ID = Deno.env.get("APNS_TEAM_ID")!;
const APNS_BUNDLE_ID = "com.deepak.ChipIn";
const APNS_HOST = Deno.env.get("APNS_ENV") === "production"
  ? "https://api.push.apple.com"
  : "https://api.sandbox.push.apple.com";

async function getApnsJwt(privateKeyPem: string): Promise<string> {
  const pemBody = privateKeyPem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8", keyData.buffer,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"]
  );
  return create(
    { alg: "ES256", kid: APNS_KEY_ID },
    { iss: APNS_TEAM_ID, iat: getNumericDate(0) },
    key
  );
}

async function sendPush(
  token: string,
  title: string,
  body: string,
  jwt: string,
  sound: string = "default",
) {
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound, badge: 1 },
  });
  const url = `${APNS_HOST}/3/device/${token}`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": APNS_BUNDLE_ID,
      "apns-push-type": "alert",
      "content-type": "application/json",
    },
    body: payload,
  });
  if (!res.ok) {
    const errBody = await res.text();
    console.error(`APNs ${res.status} for device …${token.slice(-8)} sound=${sound}: ${errBody}`);
  }
  return res;
}

Deno.serve(async (req) => {
  try {
    const body = await req.json();
    const privateKey = Deno.env.get("APNS_PRIVATE_KEY")!;
    const jwt = await getApnsJwt(privateKey);

    // Handle nudge payloads from iOS app
    if (body.nudge) {
      const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
      const { data: recipient } = await supabase
        .from("users").select("apns_token").eq("id", body.to_user_id).single();
      if (recipient?.apns_token) {
        await sendPush(recipient.apns_token, "💸 Payment Reminder", body.message, jwt);
      }
      return new Response("ok", { status: 200 });
    }

    const record = body.record;
    const type = body.table; // "expenses" or "settlements"
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    if (type === "expenses") {
      const creatorId = record.created_by as string | null | undefined;
      const paidBy = record.paid_by as string;

      const { data: payerRow } = await supabase
        .from("users")
        .select("name")
        .eq("id", paidBy)
        .single();

      const title = `${payerRow?.name ?? "Someone"} added an expense`;
      const pushBody = `${record.title} — ${record.currency} ${parseFloat(record.total_amount).toFixed(2)}`;

      // People who owe their share (not the payer). Never notify the person who recorded the expense.
      const { data: oweSplits } = await supabase
        .from("expense_splits")
        .select("user_id")
        .eq("expense_id", record.id)
        .neq("user_id", paidBy);

      const oweIds = (oweSplits ?? [])
        .map((s: { user_id: string }) => s.user_id)
        .filter((uid: string) => !creatorId || uid !== creatorId);

      if (oweIds.length > 0) {
        const { data: oweRecipients } = await supabase
          .from("users")
          .select("id, apns_token, push_custom_sound_enabled")
          .in("id", oweIds)
          .not("apns_token", "is", null);

        await Promise.all(
          (oweRecipients ?? []).map((r: { apns_token: string; push_custom_sound_enabled?: boolean }) => {
            const sound = r.push_custom_sound_enabled === false ? "default" : "money_out.caf";
            return sendPush(r.apns_token, title, pushBody, jwt, sound);
          }),
        );
      }

      // Payer is "owed" by others when someone else recorded the expense — notify with gained tone.
      if (creatorId && paidBy !== creatorId) {
        const { data: payerDevice } = await supabase
          .from("users")
          .select("apns_token, push_custom_sound_enabled")
          .eq("id", paidBy)
          .single();

        if (payerDevice?.apns_token) {
          const sound = payerDevice.push_custom_sound_enabled === false ? "default" : "money_in.caf";
          await sendPush(payerDevice.apns_token, title, pushBody, jwt, sound);
        }
      }
    } else if (type === "settlements") {
      const { data: recipient } = await supabase
        .from("users")
        .select("name, apns_token, push_custom_sound_enabled")
        .eq("id", record.to_user_id)
        .single();

      const { data: sender } = await supabase
        .from("users")
        .select("name")
        .eq("id", record.from_user_id)
        .single();

      if (recipient?.apns_token) {
        const sound = recipient.push_custom_sound_enabled === false ? "default" : "money_in.caf";
        await sendPush(
          recipient.apns_token,
          "Payment received!",
          `${sender?.name ?? "Someone"} marked $${parseFloat(record.amount).toFixed(2)} as settled`,
          jwt,
          sound,
        );
      }
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
