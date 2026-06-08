import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface GenerateListingRequest {
  photos: string[]   // base64-encoded JPEGs (up to 2)
  asset: {
    id: string       // UUID
    name: string
    category: string
    description: string
    condition?: string
    estimatedValue?: number
  }
  platform: "facebook" | "craigslist"
}

interface ListingDraft {
  title: string
  description: string
  suggestedPrice?: number
  priceRationale: string
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GEMINI_MODEL   = "gemini-3-flash-preview"
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? ""

const CORS_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

// ---------------------------------------------------------------------------
// Platform profiles
// ---------------------------------------------------------------------------

function platformProfile(platform: string): { system: string; user: string } {
  switch (platform) {
    case "facebook":
      return {
        system: `You write irresistible Facebook Marketplace listings. Titles are short, casual, and punchy (under 80 chars). \
Descriptions are friendly and first-person — mention "DM me" or "message me for details," and note local pickup only. \
Suggest a price 10–15% below fair retail because FB buyers always negotiate. \
Return ONLY valid JSON — no markdown, no explanation.`,
        user: `Write a Facebook Marketplace listing for this item. Return ONLY valid JSON with exactly these fields:
- "title": string, under 80 chars, conversational tone
- "description": string, 3–5 sentences, friendly, mention DM / local pickup
- "suggested_price": number in USD (omit field if truly unknown), discounted ~10–15% from retail
- "price_rationale": string, 1 sentence explaining the price`,
      }
    case "craigslist":
      return {
        system: `You write effective Craigslist classified ads. Titles are keyword-dense, include the price, and have a [neighborhood] placeholder (under 70 chars). \
Descriptions are factual and information-dense — bullet key specs and dimensions, say "cash only" and "firm" or "OBO." \
Suggest a price 15–25% below retail since CL buyers expect steeper deals. \
Return ONLY valid JSON — no markdown, no explanation.`,
        user: `Write a Craigslist listing for this item. Return ONLY valid JSON with exactly these fields:
- "title": string, under 70 chars, keyword-heavy, include price, end with "- [neighborhood]"
- "description": string, factual spec list then a short callout line (cash only / firm / OBO)
- "suggested_price": number in USD (omit if unknown), 15–25% below retail
- "price_rationale": string, 1 sentence explaining the price`,
      }
    default:
      return {
        system: "You write clear marketplace listings for selling used items.",
        user: `Write a marketplace listing. Return ONLY valid JSON with fields: "title", "description", "suggested_price", "price_rationale".`,
      }
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return json(null, 204)
  }

  // Auth
  const authHeader  = req.headers.get("Authorization") ?? ""
  const bearerToken = authHeader.replace(/^Bearer\s+/i, "").trim()
  const isGuest     = !bearerToken || !bearerToken.startsWith("eyJ")

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    authHeader ? { global: { headers: { Authorization: authHeader } } } : {}
  )

  let userID: string | null = null
  if (!isGuest) {
    try {
      const { data, error } = await supabase.auth.getUser()
      if (error || !data?.user) return json({ error: "Unauthorized" }, 401)
      userID = data.user.id
    } catch {
      return json({ error: "Unauthorized" }, 401)
    }
  }

  // Parse body
  let body: GenerateListingRequest
  try {
    body = await req.json()
  } catch {
    return json({ error: "Invalid JSON body" }, 400)
  }

  const { photos, asset, platform } = body
  if (!asset?.name || !platform) return json({ error: "Missing asset or platform" }, 400)
  if (!GEMINI_API_KEY)            return json({ error: "Missing GEMINI_API_KEY"   }, 500)

  // Build Gemini request
  const { system, user } = platformProfile(platform)

  const assetContext = [
    `Item: ${asset.name}`,
    `Category: ${asset.category}`,
    asset.description ? `Description: ${asset.description}` : null,
    asset.condition   ? `Condition: ${asset.condition}`      : null,
    asset.estimatedValue != null ? `AI-estimated value: $${asset.estimatedValue}` : null,
  ].filter(Boolean).join("\n")

  const parts: object[] = [{ text: system }]
  for (let i = 0; i < Math.min((photos ?? []).length, 2); i++) {
    parts.push({ inline_data: { mime_type: "image/jpeg", data: photos[i] } })
  }
  parts.push({ text: `${assetContext}\n\n${user}` })

  const geminiURL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`

  let geminiResp: Response
  try {
    geminiResp = await fetch(geminiURL, {
      method:  "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature:        0.4,
          max_output_tokens:  1024,
        },
      }),
    })
  } catch (err) {
    return json({ error: `Gemini unreachable: ${err}` }, 502)
  }

  if (!geminiResp.ok) {
    const t = await geminiResp.text()
    return json({ error: `Gemini error ${geminiResp.status}: ${t.slice(0, 200)}` }, 502)
  }

  const geminiJson = await geminiResp.json()
  const rawText    = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? ""

  const tryParse = (t: string): ListingDraft | null => {
    try {
      const p = JSON.parse(t)
      if (!p?.title) return null
      return {
        title:          p.title           ?? asset.name,
        description:    p.description     ?? "",
        suggestedPrice: typeof p.suggested_price === "number" ? p.suggested_price : undefined,
        priceRationale: p.price_rationale ?? "",
      }
    } catch { return null }
  }

  const draft = tryParse(rawText)
    ?? tryParse(rawText.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim())
  if (!draft) return json({ error: "Could not parse Gemini response" }, 502)

  // Log usage (non-blocking)
  if (!isGuest && userID) {
    let assetUUID: string | null = null
    try { assetUUID = asset.id } catch { /* non-fatal */ }

    if (assetUUID) {
      supabase.from("monthly_listings").insert({
        user_id:  userID,
        asset_id: assetUUID,
        platform,
      }).then(() => {})
    }
  }

  return json(draft)
})

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      ...(body !== null ? { "Content-Type": "application/json" } : {}),
    },
  })
}
