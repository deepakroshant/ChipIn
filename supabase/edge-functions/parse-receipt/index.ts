import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")
const MODEL = "gemini-2.5-flash-lite"
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  }

  try {
    const authHeader = req.headers.get("Authorization")
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "missing_authorization" }), {
        status: 401,
        headers: jsonHeaders,
      })
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")
    if (!supabaseUrl || !supabaseAnonKey) {
      return new Response(JSON.stringify({ error: "server_misconfigured" }), {
        status: 500,
        headers: jsonHeaders,
      })
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({
          error: "unauthorized",
          detail: authError?.message ?? "invalid_session",
        }),
        { status: 401, headers: jsonHeaders },
      )
    }

    if (!GEMINI_API_KEY) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY not set in Supabase secrets" }), {
        status: 500,
        headers: jsonHeaders,
      })
    }

    const { imageBase64 } = await req.json()
    if (!imageBase64 || typeof imageBase64 !== "string") {
      return new Response(JSON.stringify({ error: "missing imageBase64" }), {
        status: 400,
        headers: jsonHeaders,
      })
    }

    const prompt = `You are a receipt OCR assistant. The image may be blurry, dark, skewed, or partially cropped — still extract the best possible data.

Rules:
- List every purchasable line item with a short name and a numeric price (no $ symbols).
- If you see quantity × unit price, combine into one line total for that item.
- Include subtotal, tax, tip (0 if absent), and grand total as numbers.
- Do NOT put store name, address, phone, dates, times, or receipt IDs into item names — use generic food/product names only.
- If totals are unreadable, sum line items for an approximate total and set subtotal/tax/tip sensibly.

Return ONLY valid JSON (no markdown) matching this shape:
{"items":[{"name":"string","price":number}],"subtotal":number,"tax":number,"tip":number,"total":number}`

    const response = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            // Text before image — more reliable for Gemini vision + JSON mode with some clients.
            parts: [
              { text: prompt },
              { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 4096,
          responseMimeType: "application/json",
        },
      }),
    })

    const raw = await response.text()
    if (!response.ok) {
      return new Response(JSON.stringify({ error: "gemini_http", detail: raw.slice(0, 800) }), {
        status: 502,
        headers: jsonHeaders,
      })
    }

    const data = JSON.parse(raw)
    const parts = data.candidates?.[0]?.content?.parts ?? []

    const stripCodeFences = (s: string): string => {
      let t = s.trim()
      const fenced = t.match(/^```(?:json)?\s*([\s\S]*?)```$/im)
      if (fenced) return fenced[1].trim()
      if (t.startsWith("```")) {
        t = t.replace(/^```(?:json)?\s*/i, "").replace(/```[\s\S]*$/i, "")
      }
      return t.trim()
    }

    let parsed: { items?: unknown } | null = null
    outer: for (const p of parts) {
      if (typeof p?.text !== "string" || !p.text.trim()) continue
      const chunks = [p.text.trim(), stripCodeFences(p.text)]
      for (const chunk of chunks) {
        try {
          const x = JSON.parse(chunk) as { items?: unknown }
          if (Array.isArray(x?.items)) {
            parsed = x
            break outer
          }
        } catch {
          /* try next chunk / part */
        }
      }
    }

    if (!parsed) {
      const sample = parts.map((p: { text?: string }) => p?.text?.slice(0, 200) ?? "").join(" | ")
      return new Response(JSON.stringify({ error: "no_model_output", detail: sample || raw.slice(0, 500) }), {
        status: 502,
        headers: jsonHeaders,
      })
    }
    if (!Array.isArray(parsed.items)) {
      return new Response(JSON.stringify({ error: "invalid_json_shape", detail: JSON.stringify(parsed).slice(0, 400) }), {
        status: 502,
        headers: jsonHeaders,
      })
    }

    return new Response(JSON.stringify(parsed), {
      headers: jsonHeaders,
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: jsonHeaders,
    })
  }
})
