// ─────────────────────────────────────────────────────────────────────────────
// Collect Chrome Extension — Popup
// ─────────────────────────────────────────────────────────────────────────────

const msg = (type, extra = {}) =>
  chrome.runtime.sendMessage({ type, ...extra })

// ── DOM refs ─────────────────────────────────────────────────────────────────

const $ = id => document.getElementById(id)

const viewLoading  = $("view-loading")
const viewSignin   = $("view-signin")
const viewListings = $("view-listings")
const btnSignout   = $("btn-signout")
const btnRefresh   = $("btn-refresh")
const formSignin   = $("form-signin")
const inpEmail     = $("inp-email")
const inpPassword  = $("inp-password")
const signinError  = $("signin-error")
const btnSignin    = $("btn-signin")
const listingsEl   = $("listings-list")
const noListings   = $("no-listings")
const platformBanner = $("platform-banner")
const platformName   = $("platform-name")

// ── State ─────────────────────────────────────────────────────────────────────

let currentPlatform = null   // "facebook" | "craigslist" | null

// ── Utilities ────────────────────────────────────────────────────────────────

function show(el) { el.hidden = false }
function hide(el) { el.hidden = true  }

function setView(name) {
  hide(viewLoading); hide(viewSignin); hide(viewListings)
  if (name === "loading")  show(viewLoading)
  if (name === "signin")   show(viewSignin)
  if (name === "listings") show(viewListings)
}

function formatPrice(n) {
  if (n == null) return null
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 }).format(n)
}

// ── Platform detection ────────────────────────────────────────────────────────

async function detectPlatform() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
  if (!tab?.url) return null
  if (tab.url.includes("facebook.com/marketplace")) return "facebook"
  if (tab.url.includes("craigslist.org/post"))      return "craigslist"
  return null
}

// ── Render listings ───────────────────────────────────────────────────────────

function renderListings(listings) {
  listingsEl.innerHTML = ""
  if (listings.length === 0) { show(noListings); return }
  hide(noListings)
  for (const listing of listings) listingsEl.appendChild(buildCard(listing))
}

function buildCard(listing) {
  const li = document.createElement("li")
  li.className = "listing-card"

  // ── Top row: thumbnail · info · fill button ───────────────────────────────
  const top = document.createElement("div")
  top.className = "card-top"

  // Thumbnail
  const thumb = document.createElement("div")
  thumb.className = "listing-thumb-placeholder"
  thumb.textContent = "📦"
  top.appendChild(thumb)

  if (listing.photo1_path) {
    msg("DOWNLOAD_PHOTO", { path: listing.photo1_path }).then(b64 => {
      if (!b64) return
      const img = document.createElement("img")
      img.className = "listing-thumb"
      img.src = `data:image/jpeg;base64,${b64}`
      top.replaceChild(img, thumb)
    })
  }

  // Info
  const info = document.createElement("div")
  info.className = "listing-info"

  const titleEl = document.createElement("div")
  titleEl.className = "listing-title"
  titleEl.textContent = listing.listing_title || listing.name
  info.appendChild(titleEl)

  const meta = document.createElement("div")
  meta.className = "listing-meta"
  if (listing.asking_price != null) {
    const p = document.createElement("span")
    p.className = "listing-price"
    p.textContent = formatPrice(listing.asking_price)
    meta.appendChild(p)
  }
  if (listing.listed_facebook)   { const b = document.createElement("span"); b.className = "badge badge-fb"; b.textContent = "FB"; meta.appendChild(b) }
  if (listing.listed_craigslist) { const b = document.createElement("span"); b.className = "badge badge-cl"; b.textContent = "CL"; meta.appendChild(b) }

  // Status chip — reflects current listing_status (Ready / Listed / Pending)
  const statusChip = document.createElement("span")
  statusChip.className = "badge badge-status"
  const renderStatusChip = () => {
    const s = listing.listing_status
    statusChip.textContent = s === "listed" ? "Listed"
      : s === "pending" ? "Pending"
      : s === "ready" ? "Ready"
      : s
    statusChip.dataset.status = s
  }
  renderStatusChip()
  meta.appendChild(statusChip)

  info.appendChild(meta)
  top.appendChild(info)

  // Fill button
  const fillBtn = document.createElement("button")
  fillBtn.className = "btn-fill"
  fillBtn.textContent = "Fill"
  const canFill = currentPlatform === "facebook" ? listing.listed_facebook
    : currentPlatform === "craigslist" ? listing.listed_craigslist : false
  fillBtn.disabled = !canFill
  fillBtn.title = canFill ? "Auto-fill this listing" : "Navigate to Facebook Marketplace or Craigslist first"
  fillBtn.addEventListener("click", () => fillListing(listing, fillBtn, renderStatusChip))
  top.appendChild(fillBtn)

  li.appendChild(top)

  // ── Bottom actions row ────────────────────────────────────────────────────
  const actions = document.createElement("div")
  actions.className = "card-actions"

  // Inline form (hidden; swaps in place of actions)
  const inlineForm = document.createElement("div")
  inlineForm.className = "card-form"
  inlineForm.hidden = true

  const showActions = () => { inlineForm.hidden = true; actions.hidden = false }
  const hideActions = () => { actions.hidden = true; inlineForm.hidden = false }

  // ── Left: link chip ───────────────────────────────────────────────────────
  const linkArea = document.createElement("div")
  linkArea.className = "action-link"

  const renderLink = () => {
    linkArea.innerHTML = ""
    if (listing.listing_url) {
      const a = document.createElement("a")
      a.href = listing.listing_url; a.target = "_blank"; a.className = "act-url-chip"
      try { a.textContent = "↗ " + new URL(listing.listing_url).hostname.replace(/^www\./, "") }
      catch (_) { a.textContent = "↗ View listing" }
      a.title = listing.listing_url
      linkArea.appendChild(a)
    } else {
      const b = document.createElement("button")
      b.className = "act-link-btn"; b.textContent = "🔗 Link"
      b.addEventListener("click", () => showUrlForm())
      linkArea.appendChild(b)
    }
  }
  renderLink()

  // ── Right: status buttons ─────────────────────────────────────────────────
  const statusArea = document.createElement("div")
  statusArea.className = "action-status"

  const renderStatus = () => {
    statusArea.innerHTML = ""
    const s = listing.listing_status

    if (s === "pending") {
      // Active pending pill — click to revert to listed
      const pill = document.createElement("button")
      pill.className = "act-btn act-pending-active"
      pill.textContent = "⏳ Pending"
      pill.title = "Tap to mark as listed again"
      pill.addEventListener("click", () => patchStatus("listed", pill))
      statusArea.appendChild(pill)
    } else {
      // Pending button (ghost)
      const pendBtn = document.createElement("button")
      pendBtn.className = "act-btn act-pending"
      pendBtn.textContent = "Pending"
      pendBtn.title = "Mark as pending sale"
      pendBtn.addEventListener("click", () => patchStatus("pending", pendBtn))
      statusArea.appendChild(pendBtn)
    }

    // Sold button — always shown (opens price form)
    const soldBtn = document.createElement("button")
    soldBtn.className = "act-btn act-sold"
    soldBtn.textContent = "Sold"
    soldBtn.addEventListener("click", () => showSoldForm())
    statusArea.appendChild(soldBtn)

    // Unlist button — cancel/remove from listings (reverts to Not Listed)
    const unlistBtn = document.createElement("button")
    unlistBtn.className = "act-btn act-unlist"
    unlistBtn.textContent = "Unlist"
    unlistBtn.title = "Cancel — remove from listings"
    unlistBtn.addEventListener("click", () => unlistCard(unlistBtn))
    statusArea.appendChild(unlistBtn)
  }
  renderStatus()

  actions.appendChild(linkArea)
  actions.appendChild(statusArea)

  // ── Patch helpers ─────────────────────────────────────────────────────────
  async function patchStatus(newStatus, triggerBtn) {
    if (triggerBtn) triggerBtn.disabled = true
    const res = await msg("UPDATE_ASSET", { id: listing.id, updates: { listing_status: newStatus } })
    if (res?.ok) { listing.listing_status = newStatus; renderStatus(); renderStatusChip() }
    else if (triggerBtn) triggerBtn.disabled = false
  }

  // Unlist / cancel — revert to Not Listed and clear platform flags so it leaves
  // the extension (and the app's active views), then fade the card out.
  async function unlistCard(triggerBtn) {
    if (triggerBtn) triggerBtn.disabled = true
    const res = await msg("UPDATE_ASSET", { id: listing.id, updates: {
      listing_status:    "not_listed",
      listed_facebook:   false,
      listed_craigslist: false,
      listed_at:         null,
    }})
    if (res?.ok) {
      li.style.transition = "opacity 0.4s"
      li.style.opacity = "0"
      setTimeout(() => li.remove(), 400)
      await updateBadgeCount()
    } else if (triggerBtn) {
      triggerBtn.disabled = false
    }
  }

  // ── URL form ──────────────────────────────────────────────────────────────
  function showUrlForm() {
    inlineForm.innerHTML = ""
    hideActions()

    const urlInput = document.createElement("input")
    urlInput.type = "url"; urlInput.placeholder = "Paste Facebook listing URL…"; urlInput.className = "form-input"

    const row = document.createElement("div"); row.className = "form-row"
    const saveBtn = document.createElement("button"); saveBtn.textContent = "Save"; saveBtn.className = "btn-form-save"
    const cancelBtn = document.createElement("button"); cancelBtn.textContent = "✕"; cancelBtn.className = "btn-form-cancel"
    cancelBtn.addEventListener("click", showActions)
    row.appendChild(saveBtn); row.appendChild(cancelBtn)
    inlineForm.appendChild(urlInput); inlineForm.appendChild(row)
    urlInput.focus()

    saveBtn.addEventListener("click", async () => {
      const url = urlInput.value.trim(); if (!url) { urlInput.focus(); return }
      saveBtn.disabled = true; saveBtn.textContent = "Saving…"
      const res = await msg("UPDATE_ASSET", { id: listing.id, updates: { listing_url: url } })
      if (res?.ok) { listing.listing_url = url; showActions(); renderLink() }
      else { saveBtn.disabled = false; saveBtn.textContent = "Save" }
    })
  }

  // ── Sold form ─────────────────────────────────────────────────────────────
  function showSoldForm() {
    inlineForm.innerHTML = ""
    hideActions()

    const priceInput = document.createElement("input")
    priceInput.type = "number"; priceInput.placeholder = "Sold price (optional)"; priceInput.className = "form-input"
    if (listing.asking_price != null) priceInput.value = listing.asking_price

    const row = document.createElement("div"); row.className = "form-row"
    const confirmBtn = document.createElement("button"); confirmBtn.textContent = "✓ Mark Sold"; confirmBtn.className = "btn-form-sold"
    const cancelBtn  = document.createElement("button"); cancelBtn.textContent  = "✕"; cancelBtn.className = "btn-form-cancel"
    cancelBtn.addEventListener("click", showActions)
    row.appendChild(confirmBtn); row.appendChild(cancelBtn)
    inlineForm.appendChild(priceInput); inlineForm.appendChild(row)
    priceInput.focus(); priceInput.select()

    confirmBtn.addEventListener("click", async () => {
      const price = priceInput.value !== "" ? parseFloat(priceInput.value) : null
      confirmBtn.disabled = true; confirmBtn.textContent = "Saving…"
      const updates = { listing_status: "sold" }
      if (price != null && !isNaN(price)) updates.sold_price = price
      const res = await msg("UPDATE_ASSET", { id: listing.id, updates })
      if (res?.ok) {
        // Item is now sold — remove card from list with a fade
        li.style.transition = "opacity 0.4s"
        li.style.opacity = "0"
        setTimeout(() => li.remove(), 400)
        await updateBadgeCount()
      } else {
        confirmBtn.disabled = false; confirmBtn.textContent = "✓ Mark Sold"
      }
    })
  }

  li.appendChild(actions)
  li.appendChild(inlineForm)
  return li
}

async function updateBadgeCount() {
  // Ask background to refresh the badge after a status change
  await msg("BADGE_REFRESH")
}

// ── Fill a listing ────────────────────────────────────────────────────────────
// We skip chrome.tabs.sendMessage entirely (unreliable in MV3 popup context)
// and use executeScript with func+args to run the fill logic directly in the
// page — no message channel needed.

async function fillListing(listing, btn, onStatusChange) {
  btn.disabled = true
  btn.classList.add("loading")
  btn.textContent = "Filling…"

  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true })
  if (!tab?.id) {
    btn.disabled = false; btn.classList.remove("loading"); btn.textContent = "Fill"
    return
  }

  // Download photos from Supabase Storage — 8 s timeout per photo so we never stall
  btn.textContent = "Loading photos…"
  const withTimeout = (promise, ms) =>
    Promise.race([promise, new Promise(resolve => setTimeout(() => resolve(null), ms))])
  const photos = []
  for (const path of [listing.photo1_path, listing.photo2_path]) {
    if (!path) continue
    const b64 = await withTimeout(msg("DOWNLOAD_PHOTO", { path }), 8000)
    if (b64) photos.push(b64)
  }

  btn.textContent = "Filling…"

  const fillArgs = {
    platform:    currentPlatform,
    title:       listing.listing_title || listing.name,
    description: listing.listing_description || "",
    price:       listing.asking_price,
    condition:   listing.condition  || null,
    category:    listing.category   || null,
    photos,
  }

  try {
    // allFrames: true — FB Marketplace renders the create form inside an iframe.
    // We inject into every frame; the one that has the form will fill it.
    const results = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      func:   fillPageDirectly,
      args:   [fillArgs],
    })

    // Log ALL frame results unconditionally
    console.log(`[Collect] executeScript returned ${results?.length ?? 0} frame(s)`)
    results?.forEach((r, i) => {
      console.log(`[Collect] Frame ${i} (${r.result?.debug?.frameUrl ?? "?"})`,
        { titleFound:  r.result?.debug?.titleFound,
          priceFound:  r.result?.debug?.priceFound,
          descFound:   r.result?.debug?.descFound,
          photoResult: r.result?.debug?.photoResult,
          elements:    r.result?.debug?.domSnapshot?.length ?? 0,
          snapshot:    r.result?.debug?.domSnapshot })
    })

    // Only call it a win if at least one field was actually found & filled
    const winner = results?.find(r =>
      r.result?.debug?.titleFound || r.result?.debug?.priceFound || r.result?.debug?.descFound
    )

    if (winner) {
      btn.classList.remove("loading")
      btn.classList.add("success")
      btn.textContent = "Filled ✓"

      // Photos are injected directly into the page's file input by fillPageDirectly.

      // The item is now actually posted → mark it "listed" (was "ready"). The user
      // can still change this later via Pending/Sold/Unlist if they cancel.
      if (listing.listing_status !== "listed") {
        const res = await msg("UPDATE_ASSET", { id: listing.id, updates: { listing_status: "listed" } })
        if (res?.ok) {
          listing.listing_status = "listed"
          if (typeof onStatusChange === "function") onStatusChange()
          await updateBadgeCount()
        }
      }
    } else {
      // Nothing found — build a diagnostic string from every frame
      const snap = results?.map((r, i) => {
        const d = r.result?.debug
        const url  = d?.frameUrl ?? "unknown"
        const els  = d?.domSnapshot?.length ?? 0
        const labels = d?.domSnapshot?.map(e => e.ariaLabel || e.placeholder || e.name || e.id || e.tag).filter(Boolean).join(", ") || "—"
        return `Frame ${i} [${url}]\n  ${els} element(s): ${labels}`
      }).join("\n\n")
      throw new Error("No form fields found in any frame.\n\n" + (snap || "(no results)"))
    }
  } catch (e) {
    btn.classList.remove("loading")
    btn.disabled = false
    btn.textContent = "Fill"
    alert("Could not fill the form.\n\n" + e.message)
  }
}

// ── Page-side fill function (runs inside the FB/CL tab, not the popup) ────────
// IMPORTANT: This function is serialised and sent to the page by executeScript.
// It must be entirely self-contained — no closures, no imports, no references
// to anything defined outside this function body.

function fillPageDirectly({ platform, title, description, price, condition, category, photos }) {
  const sleep = ms => new Promise(r => setTimeout(r, ms))

  function fillInput(el, value) {
    el.focus()
    const proto  = el.tagName === "TEXTAREA" ? HTMLTextAreaElement : HTMLInputElement
    const setter = Object.getOwnPropertyDescriptor(proto.prototype, "value")?.set
    if (setter) setter.call(el, value); else el.value = value
    el.dispatchEvent(new InputEvent("input",  { bubbles: true, cancelable: true }))
    el.dispatchEvent(new Event("change",      { bubbles: true, cancelable: true }))
    el.blur()
  }

  function fillContentEditable(el, value) {
    el.focus()
    const sel = window.getSelection()
    const range = document.createRange()
    range.selectNodeContents(el)
    sel.removeAllRanges()
    sel.addRange(range)
    document.execCommand("insertText", false, value)
    el.dispatchEvent(new InputEvent("input", { bubbles: true, cancelable: true }))
  }

  function fillEl(el, value) {
    if (!el || value == null) return
    if (el.isContentEditable || el.getAttribute("role") === "textbox")
      fillContentEditable(el, String(value))
    else
      fillInput(el, String(value))
  }

  async function waitFor(selectors, ms = 5000) {
    const end = Date.now() + ms
    while (Date.now() < end) {
      for (const sel of selectors) {
        try { const el = document.querySelector(sel); if (el) return el } catch (_) {}
      }
      await sleep(250)
    }
    return null
  }

  // Resolve the visible text label for an element using every possible mechanism
  function elLabel(el) {
    // 1. Direct aria-label / placeholder
    const direct = el.getAttribute("aria-label") || el.getAttribute("placeholder") || el.getAttribute("aria-placeholder")
    if (direct) return direct.toLowerCase()

    // 2. aria-labelledby → look up the referenced element's text
    const labelledBy = el.getAttribute("aria-labelledby")
    if (labelledBy) {
      const text = labelledBy.split(" ")
        .map(id => document.getElementById(id)?.textContent?.trim())
        .filter(Boolean).join(" ")
      if (text) return text.toLowerCase()
    }

    // 3. <label for="id">
    if (el.id) {
      const lbl = document.querySelector(`label[for="${el.id}"]`)
      if (lbl) return lbl.textContent.toLowerCase()
    }

    // 4. Closest wrapping <label>
    const wrap = el.closest("label")
    if (wrap) return wrap.textContent.toLowerCase()

    return ""
  }

  function byLabel(...texts) {
    const sel = 'input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]),textarea,[contenteditable="true"],[role="textbox"]'
    for (const el of document.querySelectorAll(sel)) {
      const lbl = elLabel(el)
      if (texts.some(t => lbl.includes(t))) return el
    }
    return null
  }

  // All visible, fillable text inputs in DOM order (exclude hidden/radio/checkbox/search)
  function visibleTextInputs() {
    return [...document.querySelectorAll(
      'input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]):not([type="submit"]):not([type="button"]),' +
      'textarea,[contenteditable="true"],[role="textbox"]'
    )].filter(el => {
      const r = el.getBoundingClientRect()
      return r.width > 0 && r.height > 0
    })
  }



  function snapshot() {
    return [...document.querySelectorAll(
      'input:not([type="hidden"]):not([type="radio"]):not([type="checkbox"]), textarea, [contenteditable="true"], [role="textbox"]'
    )].map(el => {
      const r = el.getBoundingClientRect()
      return {
        tag:          el.tagName,
        type:         el.getAttribute("type"),
        role:         el.getAttribute("role"),
        ariaLabel:    el.getAttribute("aria-label"),
        placeholder:  el.getAttribute("placeholder"),
        ariaLabelledBy: el.getAttribute("aria-labelledby"),
        resolvedLabel: elLabel(el) || undefined,
        name:         el.getAttribute("name"),
        id:           el.id || undefined,
        visible:      r.width > 0 && r.height > 0,
      }
    })
  }

  // Click a custom FB dropdown and choose the best-matching option.
  // Only matches elements by aria-label — never by textContent (too broad/risky).
  async function selectDropdown(ariaLabel, value) {
    if (!value) return false

    // Find the trigger by exact aria-label (case-insensitive)
    const trigger = [...document.querySelectorAll('[role="combobox"],[role="listbox"],[role="button"],[role="option"]')]
      .find(el => {
        const lbl = (el.getAttribute("aria-label") || el.getAttribute("aria-labelledby") || "").toLowerCase()
        return lbl === ariaLabel.toLowerCase()
      })
    if (!trigger) return false

    trigger.click()
    await sleep(600)

    // Options appear in a listbox or popover
    const opts = [...document.querySelectorAll('[role="option"],[role="menuitem"]')]
    const target = opts.find(o => o.textContent.trim().toLowerCase().includes(value.toLowerCase()))
    if (target) { target.click(); await sleep(300); return true }

    // No match found — click somewhere neutral to close the dropdown without navigating
    try { document.activeElement?.blur() } catch (_) {}
    return false
  }

  // Inject photos directly into the page's file input.
  // Strategy: intercept the next file-input .click() call so we can slip our
  // files in right when Facebook opens the picker — more reliable than setting
  // files on a hidden input that FB may not be listening to yet.
  async function injectPhotos(photoList) {
    if (!photoList?.length) return "no-photos"

    // Build DataTransfer from base64 strings
    const dt = new DataTransfer()
    photoList.forEach((b64, i) => {
      try {
        const bin = atob(b64)
        const buf = new Uint8Array(bin.length)
        for (let j = 0; j < bin.length; j++) buf[j] = bin.charCodeAt(j)
        dt.items.add(new File([buf], `photo${i + 1}.jpg`, { type: "image/jpeg" }))
      } catch (_) {}
    })
    if (!dt.files.length) return "decode-failed"

    function setAndFire(input) {
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "files")?.set
      if (setter) setter.call(input, dt.files)
      else input.files = dt.files
      input.dispatchEvent(new Event("change", { bubbles: true }))
      input.dispatchEvent(new InputEvent("input", { bubbles: true }))
    }

    // ── Strategy A: intercept the next file-input click ──────────────────────
    // Facebook calls fileInput.click() when the user clicks the upload area.
    // We monkey-patch .click() so we can slip our DataTransfer in before the
    // native file-picker dialog would open.
    let intercepted = false
    const origClick = HTMLInputElement.prototype.click
    HTMLInputElement.prototype.click = function () {
      if (this.type === "file") {
        HTMLInputElement.prototype.click = origClick   // restore immediately
        intercepted = true
        setAndFire(this)
        return  // skip the real click → no OS file picker
      }
      return origClick.call(this)
    }

    // Click whichever visible element FB uses to open the photo picker
    const uploadBtn = [...document.querySelectorAll('[role="button"],[role="presentation"],div,label')]
      .find(el => {
        const lbl = (el.getAttribute("aria-label") || el.textContent || "").toLowerCase()
        return (lbl.includes("photo") || lbl.includes("add image") || lbl.includes("upload")) &&
               el.getBoundingClientRect().width > 0
      })
    if (uploadBtn) {
      uploadBtn.click()
      await sleep(400)
    }

    // Always restore — don't leave the monkey-patch dangling
    HTMLInputElement.prototype.click = origClick

    if (intercepted) return "intercepted-ok"

    // ── Strategy B: set files directly on any file input already in DOM ──────
    const fileInput = document.querySelector('input[type="file"]')
    if (fileInput) {
      setAndFire(fileInput)
      await sleep(400)
      return "direct-set"
    }

    // ── Strategy C: drop-event simulation on the upload zone ─────────────────
    const zone = [...document.querySelectorAll("[aria-label]")].find(el => {
      const lbl = (el.getAttribute("aria-label") || "").toLowerCase()
      return lbl.includes("photo") || lbl.includes("add image") || lbl.includes("upload")
    })
    if (zone) {
      const makeDE = type => {
        const e = new DragEvent(type, { bubbles: true, cancelable: true })
        Object.defineProperty(e, "dataTransfer", { value: dt })
        return e
      }
      zone.dispatchEvent(makeDE("dragenter"))
      await sleep(60)
      zone.dispatchEvent(makeDE("dragover"))
      await sleep(60)
      zone.dispatchEvent(makeDE("drop"))
      await sleep(400)
      return "drop-simulated"
    }

    return "no-input-found"
  }

  async function run() {
    const frameUrl = window.location.href

    if (platform === "facebook") {
      // Wait up to 3 s for the form to be ready; proceed regardless
      await waitFor([
        'input[aria-label="Title"]','input[placeholder="Title"]','input[name="title"]',
        'form input[type="text"]','form input:not([type])',
      ], 3000)

      // ── Title ─────────────────────────────────────────────────────────────────
      let titleEl = byLabel("title", "what are you selling", "listing title")
      if (!titleEl) {
        // Positional fallback: first visible text input that isn't the search bar
        const inputs = visibleTextInputs().filter(el =>
          !elLabel(el).includes("search") && el.tagName === "INPUT"
        )
        titleEl = inputs[0] || null
      }
      fillEl(titleEl, title); await sleep(400)

      // ── Price ─────────────────────────────────────────────────────────────────
      let priceEl = await waitFor([
        'input[aria-label="Price"]','input[placeholder="Price"]',
        'input[aria-label="$ Price"]','input[placeholder="$ Price"]',
        'input[type="number"]',
      ], 2000) || byLabel("price", "amount")
      if (!priceEl) {
        // Positional fallback: second visible text/number input that isn't search
        const inputs = visibleTextInputs().filter(el =>
          !elLabel(el).includes("search") && el.tagName === "INPUT"
        )
        priceEl = inputs[1] || null
      }
      fillEl(priceEl, price != null ? String(Math.round(price)) : null); await sleep(400)

      // ── Description ───────────────────────────────────────────────────────────
      const descEl = await waitFor([
        'textarea[aria-label="Description"]',
        '[aria-label="Description"][contenteditable]',
        '[role="textbox"][aria-label="Description"]',
        'textarea','[role="textbox"]',
      ], 3000) || byLabel("description", "describe", "detail", "more info")
      fillEl(descEl, description); await sleep(400)

      // ── Condition ─────────────────────────────────────────────────────────────
      if (condition) {
        await selectDropdown("Condition", condition)
      }

      // ── Category ──────────────────────────────────────────────────────────────
      if (category) {
        await selectDropdown("Category", category)
      }

      // ── Photos ────────────────────────────────────────────────────────────────
      const photoResult = await injectPhotos(photos)

      return {
        ok:    true,
        debug: {
          frameUrl,
          titleFound:  !!titleEl,
          priceFound:  !!priceEl,
          descFound:   !!descEl,
          photoResult,
          domSnapshot: snapshot(),
        }
      }

    } else if (platform === "craigslist") {
      const titleEl = await waitFor(['#PostingTitle','input[name="PostingTitle"]'], 4000)
        || byLabel("posting title", "title")
      fillEl(titleEl, title); await sleep(200)

      const priceEl = await waitFor(['#price','input[name="price"]'], 2000) || byLabel("price")
      fillEl(priceEl, price != null ? String(Math.round(price)) : null); await sleep(200)

      const descEl = await waitFor(['#PostingBody','textarea[name="PostingBody"]'], 2000)
        || byLabel("description")
      fillEl(descEl, description)

      return {
        ok:    true,
        debug: {
          frameUrl,
          titleFound: !!titleEl,
          priceFound: !!priceEl,
          descFound:  !!descEl,
          domSnapshot: snapshot(),
        }
      }
    }

    // Not our platform — just report what this frame contains
    return { ok: false, debug: { frameUrl, domSnapshot: snapshot() } }
  }

  return run()
}

// ── Sign-in ───────────────────────────────────────────────────────────────────

formSignin.addEventListener("submit", async e => {
  e.preventDefault()
  hide(signinError)
  btnSignin.disabled = true
  btnSignin.textContent = "Signing in…"

  const result = await msg("SIGN_IN", {
    email:    inpEmail.value.trim(),
    password: inpPassword.value,
  })

  if (result?.ok) {
    await initListingsView()
  } else {
    show(signinError)
    signinError.textContent = result?.error || "Sign-in failed."
    btnSignin.disabled = false
    btnSignin.textContent = "Sign In"
  }
})

// ── Sign-out ──────────────────────────────────────────────────────────────────

btnSignout.addEventListener("click", async () => {
  await msg("SIGN_OUT")
  hide(btnSignout)
  hide(btnRefresh)
  setView("signin")
})

// ── Refresh ───────────────────────────────────────────────────────────────────

btnRefresh.addEventListener("click", async () => {
  btnRefresh.classList.add("spinning")
  btnRefresh.disabled = true

  const [listings] = await Promise.all([msg("GET_LISTINGS")])
  renderListings(Array.isArray(listings) ? listings : [])

  btnRefresh.classList.remove("spinning")
  btnRefresh.disabled = false
})

// ── Init ──────────────────────────────────────────────────────────────────────

async function initListingsView() {
  setView("loading")
  show(btnSignout)
  show(btnRefresh)

  // Fetch everything before revealing the view so sub-elements don't bleed
  // through while their parent section is still hidden.
  const [platform, listings] = await Promise.all([
    detectPlatform(),
    msg("GET_LISTINGS"),
  ])
  currentPlatform = platform

  if (currentPlatform) {
    show(platformBanner)
    platformName.textContent =
      currentPlatform === "facebook" ? "Facebook Marketplace" : "Craigslist"
  } else {
    hide(platformBanner)
  }

  renderListings(Array.isArray(listings) ? listings : [])
  setView("listings")   // reveal everything at once
}

async function init() {
  setView("loading")
  const session = await msg("GET_SESSION")
  if (session?.access_token) {
    await initListingsView()
  } else {
    hide(btnSignout)
    setView("signin")
  }
}

init()
