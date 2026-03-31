import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!
const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent"

serve(async (req) => {
  const { imageBase64 } = await req.json()

  const prompt = `Analyze this receipt image and extract:
1. Each line item with name and price
2. Subtotal
3. Tax amount
4. Tip amount (if any)
5. Total

Return ONLY valid JSON in this exact format:
{
  "items": [{"name": "string", "price": number}],
  "subtotal": number,
  "tax": number,
  "tip": number,
  "total": number
}`

  const response = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{
        parts: [
          { text: prompt },
          { inline_data: { mime_type: "image/jpeg", data: imageBase64 } }
        ]
      }]
    })
  })

  const data = await response.json()
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}"
  const jsonMatch = text.match(/\{[\s\S]*\}/)
  const parsed = jsonMatch ? JSON.parse(jsonMatch[0]) : {}

  return new Response(JSON.stringify(parsed), {
    headers: { "Content-Type": "application/json" }
  })
})
