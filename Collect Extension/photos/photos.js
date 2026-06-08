// ─────────────────────────────────────────────────────────────────────────────
// Collect Chrome Extension — Photo Drag Window
// ─────────────────────────────────────────────────────────────────────────────

const grid  = document.getElementById("grid")
const hint  = document.getElementById("hint")

chrome.storage.session.get("collect_pending_photos", data => {
  const photos = data?.collect_pending_photos

  if (!photos?.length) {
    const empty = document.createElement("div")
    empty.id = "empty"
    empty.textContent = "No photos found."
    grid.replaceWith(empty)
    hint.hidden = true
    return
  }

  photos.forEach((b64, i) => {
    const wrap = document.createElement("div")
    wrap.className = "photo-wrap"
    wrap.draggable = true

    const img = document.createElement("img")
    img.src = `data:image/jpeg;base64,${b64}`
    img.alt = `Photo ${i + 1}`
    img.draggable = false

    const badge = document.createElement("div")
    badge.className = "photo-badge"
    badge.textContent = i + 1

    wrap.appendChild(img)
    wrap.appendChild(badge)

    wrap.addEventListener("dragstart", e => {
      try {
        const bin = atob(b64)
        const buf = new Uint8Array(bin.length)
        for (let j = 0; j < bin.length; j++) buf[j] = bin.charCodeAt(j)
        const file = new File([buf], `photo${i + 1}.jpg`, { type: "image/jpeg" })
        e.dataTransfer.clearData()
        e.dataTransfer.items.add(file)
        e.dataTransfer.effectAllowed = "copy"
      } catch (err) {
        console.error("[Collect] dragstart error:", err)
      }
      wrap.classList.add("dragging")
    })

    wrap.addEventListener("dragend", () => {
      wrap.classList.remove("dragging")
    })

    grid.appendChild(wrap)
  })
})
