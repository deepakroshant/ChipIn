import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")
const PRIMARY_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash-lite"
const FALLBACK_MODEL = "gemini-2.0-flash"

const jsonHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
}

const PROMPT = `You are a receipt OCR assistant. Extract all purchasable line items and totals from this receipt image.

IMPORTANT RULES:
- Include EVERY item that has a price. If price is unclear, estimate from context.
- Use short item names: "Burger", "Latte", "Tax", NOT "Thank you" or store addresses.
- Quantity × unit price = combine into one total (e.g. "2x Coffee $3.50" → price: 7.00).
- Skip non-items: store name, address, phone, date, time, receipt #, loyalty points, dividers.
- Tax, HST, GST, PST: put the TOTAL tax amount in the "tax" field, NOT as an item.
- Tip/gratuity: put in "tip" field if present, NOT as an item.
- All numbers must be plain numbers with 2 decimal places, NO $ symbols or commas.
- If the image is partially cut off, extract whatever is visible.

Return ONLY this JSON (no markdown, no code blocks, no extra text):
{"merchant":"string or empty","items":[{"name":"string","price":0.00}],"subtotal":0.00,"tax":0.00,"tip":0.00,"total":0.00}

- "merchant": store or restaurant name from the top of the receipt (short). Use "" if not visible.

Example for a café receipt:
{"merchant":"North Cafe","items":[{"name":"Latte","price":5.50},{"name":"Sandwich","price":9.25}],"subtotal":14.75,"tax":1.92,"tip":0.00,"total":16.67}`

async function callGemini(model: string, imageBase64: string): Promise<Response> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`
  return fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [
        {
          parts: [
            { text: PROMPT },
            { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
          ],
        },
      ],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 4096,
        topP: 0.95,
        responseMimeType: "application/json",
      },
    }),
  })
}

function normalizePrice(val: unknown): number | null {
  if (typeof val === "number" && isFinite(val)) return Math.min(val, 500)
  if (typeof val === "string") {
    const cleaned = val.replace(/[$,]/g, "")
    const n = parseFloat(cleaned)
    return isFinite(n) ? Math.min(n, 500) : null
  }
  return null
}

function cleanItems(rawItems: unknown[]): { name: string; price: number }[] {
  const seen = new Set<string>()
  const result: { name: string; price: number }[] = []
  for (const row of rawItems) {
    if (typeof row !== "object" || !row) continue
    const r = row as Record<string, unknown>
    const name = typeof r.name === "string" ? r.name.trim() : ""
    if (!name) continue
    const price = normalizePrice(r.price)
    if (price === null || price < 0) continue
    const key = `${name.toLowerCase()}|${price}`
    if (seen.has(key)) continue
    seen.add(key)
    result.push({ name, price })
  }
  // Remove zero-price items only when there are other valid items
  const nonZero = result.filter((i) => i.price > 0)
  return nonZero.length > 0 ? nonZero : result
}

const stripCodeFences = (s: string): string => {
  let t = s.trim()
  const fenced = t.match(/^```(?:json)?\s*([\s\S]*?)```$/im)
  if (fenced) return fenced[1].trim()
  if (t.startsWith("```")) {
    t = t.replace(/^```(?:json)?\s*/i, "").replace(/```[\s\S]*$/i, "")
  }
  return t.trim()
}

function extractParsed(raw: string): { items?: unknown; subtotal?: unknown; tax?: unknown; tip?: unknown; total?: unknown } | null {
  let data: unknown
  try {
    data = JSON.parse(raw)
  } catch {
    return null
  }
  const parts = (data as { candidates?: { content?: { parts?: { text?: string }[] } }[] })?.candidates?.[0]?.content?.parts ?? []
  for (const p of parts) {
    if (typeof p?.text !== "string" || !p.text.trim()) continue
    for (const chunk of [p.text.trim(), stripCodeFences(p.text)]) {
      try {
        const x = JSON.parse(chunk) as { items?: unknown }
        if (Array.isArray(x?.items)) return x
      } catch {
        /* try next */
      }
    }
  }
  return null
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
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser()
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

    // Call primary model; fall back to FALLBACK_MODEL on 400/404 (model not found)
    let response = await callGemini(PRIMARY_MODEL, imageBase64)
    if (response.status === 400 || response.status === 404) {
      const errSnippet = (await response.text()).slice(0, 300)
      // Only retry if it looks like a model-not-found error
      if (/not found|invalid model|does not exist/i.test(errSnippet)) {
        response = await callGemini(FALLBACK_MODEL, imageBase64)
      } else {
        return new Response(
          JSON.stringify({ error: "gemini_http", detail: errSnippet }),
          { status: 502, headers: jsonHeaders },
        )
      }
    }

    const raw = await response.text()
    if (!response.ok) {
      return new Response(
        JSON.stringify({ error: "gemini_http", detail: raw.slice(0, 800) }),
        { status: 502, headers: jsonHeaders },
      )
    }

    const parsed = extractParsed(raw)
    if (!parsed) {
      return new Response(
        JSON.stringify({ error: "no_model_output", detail: raw.slice(0, 500) }),
        { status: 502, headers: jsonHeaders },
      )
    }
    if (!Array.isArray(parsed.items)) {
      return new Response(
        JSON.stringify({ error: "invalid_json_shape", detail: JSON.stringify(parsed).slice(0, 400) }),
        { status: 502, headers: jsonHeaders },
      )
    }

    const items = cleanItems(parsed.items as unknown[])
    const subtotal = normalizePrice(parsed.subtotal) ?? 0
    const tax = normalizePrice(parsed.tax) ?? 0
    const tip = normalizePrice(parsed.tip) ?? 0
    const total = normalizePrice(parsed.total) ?? 0
    const merchantRaw =
      typeof (parsed as { merchant?: unknown }).merchant === "string"
        ? ((parsed as { merchant: string }).merchant || "").trim()
        : ""

    return new Response(
      JSON.stringify({ items, subtotal, tax, tip, total, merchant: merchantRaw }),
      { headers: jsonHeaders },
    )
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: jsonHeaders,
    })
  }
})
