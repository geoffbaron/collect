// ─────────────────────────────────────────────────────────────────────────────
// Collect Chrome Extension — Content Script (Form Filler)
// ─────────────────────────────────────────────────────────────────────────────

const sleep = ms => new Promise(r => setTimeout(r, ms))

// ── React-safe input setter ───────────────────────────────────────────────────
// React tracks input state via its own internal fiber. Setting .value directly
// doesn't trigger onChange. We bypass React's shadow copy using the native
// prototype setter, then dispatch the events React actually listens to.

function fillInput(el, value) {
  el.focus()
  const proto  = el.tagName === "TEXTAREA" ? HTMLTextAreaElement : HTMLInputElement
  const setter = Object.getOwnPropertyDescriptor(proto.prototype, "value")?.set
  if (setter) setter.call(el, value)
  else el.value = value
  el.dispatchEvent(new InputEvent("input",  { bubbles: true, cancelable: true }))
  el.dispatchEvent(new Event("change",      { bubbles: true, cancelable: true }))
  el.blur()
}

// ── ContentEditable filler ────────────────────────────────────────────────────
// Facebook's newer inputs are contenteditable divs. execCommand('insertText')
// works in content scripts and properly triggers React's synthetic events.

function fillContentEditable(el, value) {
  el.focus()
  const sel   = window.getSelection()
  const range = document.createRange()
  range.selectNodeContents(el)
  sel.removeAllRanges()
  sel.addRange(range)
  document.execCommand("insertText", false, value)
  el.dispatchEvent(new InputEvent("input", { bubbles: true, cancelable: true }))
}

// Fill whichever element type we got
function fillElement(el, value) {
  if (!el || value == null) return
  if (el.isContentEditable || el.getAttribute("role") === "textbox") {
    fillContentEditable(el, value)
  } else {
    fillInput(el, value)
  }
}

// ── Smart element finder ──────────────────────────────────────────────────────
// Waits up to `timeout` ms for an element matching any selector to appear.
// Facebook lazy-renders form fields as the page scrolls / React mounts.

async function waitFor(selectors, timeout = 5000) {
  const deadline = Date.now() + timeout
  while (Date.now() < deadline) {
    for (const sel of selectors) {
      try {
        const el = document.querySelector(sel)
        if (el) return el
      } catch (_) {}
    }
    await sleep(300)
  }
  return null
}

// Find any focusable element whose aria-label / placeholder contains the text
function findByText(...texts) {
  const candidates = document.querySelectorAll(
    'input, textarea, [contenteditable="true"], [role="textbox"]'
  )
  for (const el of candidates) {
    const label = (
      el.getAttribute("aria-label")       ||
      el.getAttribute("placeholder")      ||
      el.getAttribute("aria-placeholder") ||
      el.closest("[aria-label]")?.getAttribute("aria-label") ||
      ""
    ).toLowerCase()
    if (texts.some(t => label.includes(t.toLowerCase()))) return el
  }
  return null
}

// ── Facebook Marketplace filler ───────────────────────────────────────────────

async function fillFacebook({ title, description, price, photos }) {
  const warnings = []

  // Title — plain <input> on the create/item page
  const titleEl = await waitFor([
    'input[aria-label="Title"]',
    'input[placeholder="Title"]',
  ], 4000) || findByText("title")

  if (titleEl) { fillElement(titleEl, title); await sleep(400) }
  else warnings.push("title field not found")

  // Price
  const priceEl = await waitFor([
    'input[aria-label="Price"]',
    'input[placeholder="Price"]',
    'input[aria-label="$ Price"]',
    'input[placeholder="$ Price"]',
  ], 3000) || findByText("price")

  if (priceEl && price != null) { fillElement(priceEl, String(Math.round(price))); await sleep(400) }
  else if (!priceEl) warnings.push("price field not found")

  // Description — often a contenteditable div
  const descEl = await waitFor([
    'textarea[aria-label="Description"]',
    '[aria-label="Description"][contenteditable]',
    '[aria-label="Description"][role="textbox"]',
    'textarea[placeholder="Description"]',
  ], 3000) || findByText("description", "describe")

  if (descEl) { fillElement(descEl, description); await sleep(400) }
  else warnings.push("description field not found")

  // Photos — attempt file input injection (best-effort)
  if (photos?.length) {
    const fileInput = document.querySelector('input[type="file"][accept*="image"]')
      || document.querySelector('input[type="file"]')
    injectPhotos(photos, fileInput)
  }

  return warnings
}

// ── Craigslist filler ─────────────────────────────────────────────────────────

async function fillCraigslist({ title, description, price, photos }) {
  const warnings = []

  const titleEl = await waitFor(['#PostingTitle', 'input[name="PostingTitle"]'], 4000)
    || findByText("posting title", "title")
  if (titleEl) { fillElement(titleEl, title); await sleep(200) }
  else warnings.push("title field not found")

  const priceEl = await waitFor(['#price', 'input[name="price"]'], 2000)
    || findByText("price")
  if (priceEl && price != null) { fillElement(priceEl, String(Math.round(price))); await sleep(200) }

  const descEl = await waitFor(['#PostingBody', 'textarea[name="PostingBody"]'], 2000)
    || findByText("posting body", "description")
  if (descEl) { fillElement(descEl, description); await sleep(200) }
  else warnings.push("description field not found")

  if (photos?.length) injectPhotos(photos, document.querySelector('input[type="file"]'))

  return warnings
}

// ── Photo injection ───────────────────────────────────────────────────────────

function base64ToFile(b64, filename) {
  const binary = atob(b64)
  const bytes  = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return new File([bytes], filename, { type: "image/jpeg" })
}

function injectPhotos(photos, fileInput) {
  if (!photos?.length || !fileInput) return
  try {
    const dt = new DataTransfer()
    photos.forEach((b64, i) => dt.items.add(base64ToFile(b64, `photo${i + 1}.jpg`)))
    fileInput.files = dt.files
    fileInput.dispatchEvent(new Event("change", { bubbles: true }))
  } catch (e) {
    console.warn("[Collect] Photo injection failed:", e)
  }
}

// ── Message listener ──────────────────────────────────────────────────────────
// Guard against double-registration when dynamically re-injected.

if (!window.__collectFillerRegistered) {
  window.__collectFillerRegistered = true

  chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
    if (msg.type !== "COLLECT_FILL") return false

    ;(async () => {
      const { platform, title, description, price, photos } = msg
      let warnings = []
      try {
        if      (platform === "facebook")   warnings = await fillFacebook({ title, description, price, photos })
        else if (platform === "craigslist") warnings = await fillCraigslist({ title, description, price, photos })
        else { sendResponse({ ok: false, error: "Unknown platform" }); return }
      } catch (e) {
        sendResponse({ ok: false, error: e.message }); return
      }
      if (warnings.length) console.warn("[Collect] Fill warnings:", warnings)
      sendResponse({ ok: true, warnings })
    })()

    return true
  })

  console.log("[Collect] Filler ready on", location.hostname)
}
