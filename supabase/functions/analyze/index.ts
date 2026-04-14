import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface AnalyzeRequest {
  frames: string[]  // base64-encoded JPEG images
  template: {
    systemPrompt: string
    userPromptPrefix: string
    type: string
  }
}

interface AssetResult {
  name: string
  category: string
  description: string
  condition?: string
  quantity: number
  confidence: number
  estimated_value?: number
  frame_indices: number[]
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const GEMINI_MODEL   = "gemini-2.0-flash"
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? ""

const CORS_HEADERS = {
  "Access-Control-Allow-Origin":  "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS })
  }

  // ── 1. Auth ──────────────────────────────────────────────────────────────
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return json({ error: "Unauthorized" }, 401)
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  )

  const { data: { user }, error: authError } = await supabase.auth.getUser()
  if (authError || !user) {
    return json({ error: "Unauthorized" }, 401)
  }

  // ── 2. Parse request ─────────────────────────────────────────────────────
  let body: AnalyzeRequest
  try {
    body = await req.json()
  } catch {
    return json({ error: "Invalid JSON body" }, 400)
  }

  const { frames, template } = body
  if (!Array.isArray(frames) || frames.length === 0 || !template) {
    return json({ error: "Missing frames or template" }, 400)
  }

  if (!GEMINI_API_KEY) {
    return json({ error: "Server configuration error: missing GEMINI_API_KEY" }, 500)
  }

  // ── 3. Build Gemini request ───────────────────────────────────────────────
  const frameCount = frames.length
  const frameSchema = `
Also include:
- "estimated_value": a number representing the estimated current market or replacement value \
in USD for one unit of this item (omit the field if truly unknown, do not guess wildly).
- "frame_indices": an array of exactly 1 or 2 integers (0-based, from 0 to ${frameCount - 1}) \
identifying the frames where this specific asset is most clearly visible.
`
  const systemPrompt = template.systemPrompt + "\n" + frameSchema

  // Build parts: system prompt → numbered frames → user instruction
  const parts: object[] = [{ text: systemPrompt }]
  for (let i = 0; i < frames.length; i++) {
    parts.push({ text: `Frame ${i}:` })
    parts.push({ inline_data: { mime_type: "image/jpeg", data: frames[i] } })
  }
  const userText = template.type === "custom"
    ? template.userPromptPrefix
    : `${template.userPromptPrefix} Return ONLY a JSON array, no markdown.`
  parts.push({ text: userText })

  // ── 4. Call Gemini ────────────────────────────────────────────────────────
  const geminiURL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`

  let geminiResp: Response
  try {
    geminiResp = await fetch(geminiURL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts }],
        generationConfig: {
          response_mime_type: "application/json",
          temperature: 0.1,
          max_output_tokens: 8192,
        },
      }),
    })
  } catch (err) {
    return json({ error: `Failed to reach Gemini: ${err}` }, 502)
  }

  if (!geminiResp.ok) {
    const errText = await geminiResp.text()
    return json({ error: `Gemini error ${geminiResp.status}: ${errText}` }, 502)
  }

  const geminiJson = await geminiResp.json()

  // ── 5. Parse and return ───────────────────────────────────────────────────
  const rawText    = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text ?? ""
  const finishReason = geminiJson?.candidates?.[0]?.finishReason ?? ""
  const allAssets = parseAssets(rawText, finishReason, frameCount)

  // ── 5a. Enforce max_assets_per_scan from plan_limits ─────────────────────
  let maxAssets = -1
  try {
    const { data } = await supabase.rpc("get_my_limits")
    if (data && data.length > 0) maxAssets = data[0].max_assets_per_scan
  } catch { /* ignore — no limits means full results */ }

  const assets  = maxAssets !== -1 ? allAssets.slice(0, maxAssets) : allAssets
  const success = assets.length > 0

  // Log scan for analytics (fire-and-forget — don't block the response)
  supabase.from("scans").insert({
    user_id:     user.id,
    prompt_type: body.template.type,
    asset_count: assets.length,
    success,
  }).then(() => {})

  // Increment scan counter on profile
  supabase.rpc("increment_scans_used", { user_id: user.id }).then(() => {})

  return json({ assets })
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  })
}

function parseAssets(text: string, finishReason: string, frameCount: number): AssetResult[] {
  const tryParse = (t: string): AssetResult[] | null => {
    try {
      const parsed = JSON.parse(t)
      // Accept a bare array or any common wrapper key
      const arr: unknown[] = Array.isArray(parsed)
        ? parsed
        : (parsed?.assets ?? parsed?.items ?? parsed?.results ?? parsed?.data ?? parsed?.inventory)
      if (!Array.isArray(arr) || arr.length === 0) return null
      const results = arr
        .map(item => mapAsset(item as Record<string, unknown>, frameCount))
        .filter((a): a is AssetResult => a !== null)
      return results.length > 0 ? results : null
    } catch {
      return null
    }
  }

  // 1. Direct parse
  let result = tryParse(text)
  if (result) return result

  // 2. Strip markdown code fences
  const stripped = text.replace(/```json\s*/g, "").replace(/```\s*/g, "").trim()
  result = tryParse(stripped)
  if (result) return result

  // 3. Extract outermost [...] block
  const match = text.match(/\[[\s\S]*\]/)
  if (match) {
    result = tryParse(match[0])
    if (result) return result
  }

  // 4. Truncation recovery (MAX_TOKENS hit mid-array)
  if (finishReason === "MAX_TOKENS" || text.includes("[")) {
    const start     = text.indexOf("[")
    const lastBrace = text.lastIndexOf("}")
    if (start !== -1 && lastBrace !== -1 && lastBrace > start) {
      result = tryParse(text.slice(start, lastBrace + 1) + "]")
      if (result) return result
    }
  }

  return []
}

function mapAsset(item: Record<string, unknown>, frameCount: number): AssetResult | null {
  const name = item.name as string | undefined
  if (!name) return null

  const rawIndices = (item.frame_indices as number[] | undefined) ?? []
  const validIndices = rawIndices.filter(i => Number.isInteger(i) && i >= 0 && i < frameCount).slice(0, 2)
  const frameIndices = validIndices.length > 0
    ? validIndices
    : [0, Math.min(1, frameCount - 1)]

  const estimatedValue = typeof item.estimated_value === "number" ? item.estimated_value : undefined

  return {
    name,
    category:        (item.category    as string | undefined) ?? "Other",
    description:     (item.description as string | undefined) ?? "",
    condition:        item.condition   as string | undefined,
    quantity:        (item.quantity    as number | undefined) ?? 1,
    confidence:      (item.confidence  as number | undefined) ?? 1.0,
    estimated_value: estimatedValue,
    frame_indices:   frameIndices,
  }
}
