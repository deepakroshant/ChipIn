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

async function sendPush(token: string, title: string, body: string, jwt: string) {
  const payload = JSON.stringify({
    aps: { alert: { title, body }, sound: "default", badge: 1 }
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
      const { data: splits } = await supabase
        .from("expense_splits")
        .select("user_id")
        .eq("expense_id", record.id)
        .neq("user_id", record.paid_by);

      if (splits && splits.length > 0) {
        const { data: payer } = await supabase
          .from("users")
          .select("name")
          .eq("id", record.paid_by)
          .single();

        const ids = splits.map((s: any) => s.user_id);
        const { data: recipients } = await supabase
          .from("users")
          .select("apns_token")
          .in("id", ids)
          .not("apns_token", "is", null);

        const title = `${payer?.name ?? "Someone"} added an expense`;
        const pushBody = `${record.title} — ${record.currency} ${parseFloat(record.total_amount).toFixed(2)}`;
        await Promise.all(
          (recipients ?? []).map((r: any) => sendPush(r.apns_token, title, pushBody, jwt))
        );
      }
    } else if (type === "settlements") {
      const { data: recipient } = await supabase
        .from("users")
        .select("name, apns_token")
        .eq("id", record.to_user_id)
        .single();

      const { data: sender } = await supabase
        .from("users")
        .select("name")
        .eq("id", record.from_user_id)
        .single();

      if (recipient?.apns_token) {
        await sendPush(
          recipient.apns_token,
          "Payment received!",
          `${sender?.name ?? "Someone"} marked $${parseFloat(record.amount).toFixed(2)} as settled`,
          jwt
        );
      }
    }

    return new Response("ok", { status: 200 });
  } catch (err) {
    return new Response(String(err), { status: 500 });
  }
});
