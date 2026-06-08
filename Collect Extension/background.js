// ─────────────────────────────────────────────────────────────────────────────
// Collect Chrome Extension — Background Service Worker
// ─────────────────────────────────────────────────────────────────────────────

const SUPABASE_URL     = "https://nrvlkoakvjlqvkqvncel.supabase.co"
const SUPABASE_ANON    = "sb_publishable_ehxGkAGni7zVzhesCt4LDw_MVBGkpZD"
const STORAGE_KEY      = "collect_session"
const BADGE_COLOR      = "#007AFF"

// ── Auth helpers ──────────────────────────────────────────────────────────────

async function getSession() {
  const data = await chrome.storage.local.get(STORAGE_KEY)
  return data[STORAGE_KEY] ?? null
}

async function saveSession(session) {
  // Compute expires_at from expires_in if the server didn't include it
  // (Supabase's new publishable-key responses sometimes omit it).
  if (!session.expires_at && session.expires_in) {
    session = {
      ...session,
      expires_at: Math.floor(Date.now() / 1000) + session.expires_in,
    }
  }
  await chrome.storage.local.set({ [STORAGE_KEY]: session })
}

async function clearSession() {
  await chrome.storage.local.remove(STORAGE_KEY)
}

// Refresh using the stored refresh_token.
// Only clears the session if the token is actually expired AND refresh fails.
async function refreshSession() {
  const session = await getSession()
  if (!session?.refresh_token) return null

  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "apikey": SUPABASE_ANON,
    },
    body: JSON.stringify({ refresh_token: session.refresh_token }),
  })

  if (!res.ok) {
    // Only wipe the session if the token is genuinely expired (401/400).
    // Network errors (5xx, no response) keep the old session so the user
    // doesn't get logged out just because they're briefly offline.
    const status = res.status
    if (status === 400 || status === 401) await clearSession()
    return null
  }

  const fresh = await res.json()
  await saveSession(fresh)
  return fresh
}

// Return a live access_token, refreshing proactively if within 5 min of expiry.
async function getLiveToken() {
  let session = await getSession()
  if (!session?.access_token) return null

  const expiresAt = session.expires_at ?? Infinity   // if missing, assume still valid
  const nowSecs   = Math.floor(Date.now() / 1000)

  if (nowSecs >= expiresAt - 300) {
    // Proactively refresh; fall back to existing token if refresh fails
    const refreshed = await refreshSession()
    session = refreshed ?? session
  }

  return session.access_token
}

// ── Supabase REST helpers ─────────────────────────────────────────────────────

async function supabaseFetch(path, options = {}) {
  const token = await getLiveToken()
  const headers = {
    "apikey":        SUPABASE_ANON,
    "Content-Type":  "application/json",
    ...(token ? { "Authorization": `Bearer ${token}` } : {}),
    ...(options.headers ?? {}),
  }
  return fetch(`${SUPABASE_URL}${path}`, { ...options, headers })
}

// ── Listing fetch ─────────────────────────────────────────────────────────────

async function fetchListings() {
  const cols = [
    "id", "name", "listing_title", "listing_description",
    "asking_price", "listed_facebook", "listed_craigslist",
    "photo1_path", "photo2_path", "listing_status",
    "condition", "category", "listing_url",
  ].join(",")

  const res = await supabaseFetch(
    `/rest/v1/assets?select=${cols}&listing_status=in.(ready,listed,pending)&order=listed_at.desc`,
    { headers: { "Prefer": "return=representation" } }
  )
  if (!res.ok) return []
  return res.json()
}

// ── Badge management ──────────────────────────────────────────────────────────

async function updateBadge() {
  const token = await getLiveToken()
  if (!token) {
    chrome.action.setBadgeText({ text: "" })
    return
  }

  const listings = await fetchListings()
  const count = listings.length
  chrome.action.setBadgeBackgroundColor({ color: BADGE_COLOR })
  chrome.action.setBadgeText({ text: count > 0 ? String(count) : "" })
}

// ── Message handler (from popup / content scripts) ────────────────────────────

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  ;(async () => {
    switch (msg.type) {

      case "GET_SESSION":
        sendResponse(await getSession())
        break

      case "SIGN_IN": {
        const { email, password } = msg
        const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
          method: "POST",
          headers: { "Content-Type": "application/json", "apikey": SUPABASE_ANON },
          body: JSON.stringify({ email, password }),
        })
        const data = await res.json()
        if (res.ok) {
          await saveSession(data)
          await updateBadge()
          sendResponse({ ok: true, session: data })
        } else {
          sendResponse({ ok: false, error: data.error_description ?? data.message ?? "Sign-in failed" })
        }
        break
      }

      case "SIGN_OUT":
        await clearSession()
        chrome.action.setBadgeText({ text: "" })
        sendResponse({ ok: true })
        break

      case "GET_LISTINGS":
        sendResponse(await fetchListings())
        break

      case "DOWNLOAD_PHOTO": {
        // Download a private storage photo and return it as base64
        const { path } = msg
        const token    = await getLiveToken()
        if (!path || !token) { sendResponse(null); break }
        try {
          const res = await fetch(
            `${SUPABASE_URL}/storage/v1/object/asset-photos/${path}`,
            { headers: { "Authorization": `Bearer ${token}` } }
          )
          if (!res.ok) { sendResponse(null); break }
          const buf    = await res.arrayBuffer()
          const bytes  = new Uint8Array(buf)
          let binary   = ""
          bytes.forEach(b => { binary += String.fromCharCode(b) })
          sendResponse(btoa(binary))
        } catch { sendResponse(null) }
        break
      }

      case "UPDATE_ASSET": {
        // Patch arbitrary columns on an asset row (used by "Mark Listed" UI)
        const { id, updates } = msg
        const res = await supabaseFetch(
          `/rest/v1/assets?id=eq.${id}`,
          {
            method:  "PATCH",
            headers: { "Prefer": "return=minimal" },
            body:    JSON.stringify(updates),
          }
        )
        sendResponse({ ok: res.ok, status: res.status })
        break
      }

      case "BADGE_REFRESH":
        await updateBadge()
        sendResponse({ ok: true })
        break

      default:
        sendResponse(null)
    }
  })()
  return true  // keep message channel open for async response
})

// Refresh badge on install and whenever a tab becomes active on a matching URL
chrome.runtime.onInstalled.addListener(updateBadge)

chrome.tabs.onUpdated.addListener((tabId, info, tab) => {
  if (info.status === "complete" && tab.url && (
    tab.url.includes("facebook.com/marketplace") ||
    tab.url.includes("craigslist.org/post")
  )) {
    updateBadge()
  }
})
