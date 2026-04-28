import { Controller } from "@hotwired/stimulus"

// Block JSON format:
//   { type: "paragraph", content: "text" }
//   { type: "heading",   level: 2|3, content: "text" }
//   { type: "ul",        items: ["a", "b"] }
//   { type: "ol",        items: ["a", "b"] }
//   { type: "image",     signed_id: "...", url: "...", alt: "" }

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"]
const MAX_SIZE      = 10 * 1024 * 1024

export default class extends Controller {
  static targets = ["canvas", "input", "status"]
  static values  = { url: String, uploadUrl: String, blocks: Array }

  connect() {
    this.saveTimer = null
    this.render(this.blocksValue.length ? this.blocksValue : [{ type: "paragraph", content: "" }])
    this.canvasTarget.addEventListener("dragover",  e => { e.preventDefault(); e.dataTransfer.dropEffect = "copy" })
    this.canvasTarget.addEventListener("drop",      e => this.onDrop(e))
    this.canvasTarget.addEventListener("paste",     e => this.onPaste(e))
  }

  disconnect() {
    clearTimeout(this.saveTimer)
  }

  // ── Rendering ────────────────────────────────────────────────────────────

  render(blocks) {
    this.canvasTarget.innerHTML = ""
    this.insertPlusButton(0)
    blocks.forEach((block, i) => {
      this.canvasTarget.appendChild(this.createBlock(block))
      this.insertPlusButton(i + 1)
    })
    this.updateInput()
  }

  createBlock(data) {
    const wrapper = document.createElement("div")
    wrapper.className = "block"
    wrapper.dataset.blockType = data.type

    if (data.type === "ul" || data.type === "ol") {
      const list = document.createElement(data.type)
      list.className = "block__list"
      const items = data.items?.length ? data.items : [""]
      items.forEach(text => list.appendChild(this.createListItem(text)))
      list.addEventListener("keydown", e => this.onListKeydown(e))
      list.addEventListener("input",   () => this.onChange())
      wrapper.appendChild(list)
    } else if (data.type === "image") {
      wrapper.appendChild(this.createImageBlock(data))
    } else {
      const tag = data.type === "heading" ? `h${data.level}` : "p"
      const el  = document.createElement(tag)
      el.className          = "block__text"
      el.contentEditable    = "true"
      el.dataset.blockLevel = data.level || ""
      el.textContent        = data.content || ""
      el.addEventListener("keydown", e => this.onTextKeydown(e))
      el.addEventListener("input",   () => this.onChange())
      wrapper.appendChild(el)
    }

    return wrapper
  }

  createImageBlock(data) {
    const wrap = document.createElement("div")
    wrap.className = "block__image-wrap"

    if (data.uploading) {
      wrap.innerHTML = '<div class="block__image-placeholder">Uploading…</div>'
      return wrap
    }

    if (data.error) {
      const msg  = document.createElement("div")
      msg.className = "block__image-error"
      msg.textContent = "Couldn't upload — "
      const retry = document.createElement("button")
      retry.type = "button"
      retry.textContent = "try again"
      retry.addEventListener("click", () => {
        const wrapper = wrap.closest(".block")
        const index   = this.blockIndex(wrapper)
        this.removeBlock(wrapper)
        // Re-open file picker at that position
        this.pickImageAt(index)
      })
      msg.appendChild(retry)
      wrap.appendChild(msg)
      return wrap
    }

    const img = document.createElement("img")
    img.src       = data.url || ""
    img.alt       = data.alt || ""
    img.className = "block__image-preview"

    const altInput = document.createElement("input")
    altInput.type        = "text"
    altInput.placeholder = "Alt text"
    altInput.value       = data.alt || ""
    altInput.className   = "block__image-alt"
    altInput.addEventListener("input", () => {
      img.alt = altInput.value
      this.onChange()
    })

    wrap.appendChild(img)
    wrap.appendChild(altInput)
    return wrap
  }

  createListItem(text = "") {
    const li = document.createElement("li")
    li.contentEditable = "true"
    li.textContent     = text
    return li
  }

  insertPlusButton(index) {
    const wrap = document.createElement("div")
    wrap.className    = "block-insert"
    wrap.dataset.index = index
    const btn = document.createElement("button")
    btn.type        = "button"
    btn.className   = "block-insert__btn"
    btn.textContent = "+"
    btn.setAttribute("aria-label", "Add block")
    btn.addEventListener("click", e => this.openMenu(e.currentTarget.closest(".block-insert")))
    wrap.appendChild(btn)
    this.canvasTarget.appendChild(wrap)
  }

  // ── Type switcher menu ────────────────────────────────────────────────────

  openMenu(insertEl) {
    this.closeMenu()
    const menu = document.createElement("div")
    menu.className = "block-menu"
    menu.setAttribute("role", "menu")

    const types = [
      { label: "Paragraph",     data: { type: "paragraph", content: "" } },
      { label: "Heading 2",     data: { type: "heading", level: 2, content: "" } },
      { label: "Heading 3",     data: { type: "heading", level: 3, content: "" } },
      { label: "Bullet list",   data: { type: "ul", items: [""] } },
      { label: "Numbered list", data: { type: "ol", items: [""] } },
      { label: "Image",         data: null },
    ]

    types.forEach(({ label, data }) => {
      const btn = document.createElement("button")
      btn.type        = "button"
      btn.textContent = label
      btn.setAttribute("role", "menuitem")
      btn.addEventListener("click", () => {
        const index = parseInt(insertEl.dataset.index, 10)
        this.closeMenu()
        if (data) {
          this.insertBlockAt(index, data)
        } else {
          this.pickImageAt(index)
        }
      })
      menu.appendChild(btn)
    })

    insertEl.appendChild(menu)
    insertEl.classList.add("block-insert--open")

    this._menuCloseHandler = e => {
      if (!menu.contains(e.target)) this.closeMenu()
    }
    document.addEventListener("click", this._menuCloseHandler, { once: true, capture: true })
  }

  closeMenu() {
    const existing = this.canvasTarget.querySelector(".block-menu")
    if (existing) {
      existing.closest(".block-insert")?.classList.remove("block-insert--open")
      existing.remove()
    }
    if (this._menuCloseHandler) {
      document.removeEventListener("click", this._menuCloseHandler, { capture: true })
      this._menuCloseHandler = null
    }
  }

  // ── Keyboard handling — plain blocks ─────────────────────────────────────

  onTextKeydown(e) {
    const el      = e.currentTarget
    const wrapper = el.closest(".block")

    if (e.key === "Enter") {
      e.preventDefault()
      this.insertBlockAt(this.blockIndex(wrapper) + 1, { type: "paragraph", content: "" })
      return
    }

    if (e.key === "Backspace" && this.caretAtStart(el) && el.textContent === "") {
      e.preventDefault()
      this.removeBlock(wrapper)
      return
    }

    if (e.key === "/" && el.textContent === "") {
      e.preventDefault()
      const insertEl = wrapper.previousElementSibling
      if (insertEl?.classList.contains("block-insert")) this.openMenu(insertEl)
    }
  }

  // ── Keyboard handling — list blocks ──────────────────────────────────────

  onListKeydown(e) {
    const li      = e.target.closest("li")
    const list    = e.currentTarget
    const wrapper = list.closest(".block")

    if (e.key === "Enter") {
      e.preventDefault()
      if (li.textContent === "") {
        const index = this.blockIndex(wrapper)
        this.removeBlock(wrapper)
        this.insertBlockAt(index, { type: "paragraph", content: "" })
      } else {
        const newLi = this.createListItem()
        li.after(newLi)
        newLi.focus()
        this.onChange()
      }
      return
    }

    if (e.key === "Backspace" && this.caretAtStart(li)) {
      if (li.textContent === "" && list.children.length === 1) {
        e.preventDefault()
        const index = this.blockIndex(wrapper)
        this.removeBlock(wrapper)
        this.focusBlockAt(index - 1)
      } else if (li.textContent === "" && li !== list.firstElementChild) {
        e.preventDefault()
        const prev = li.previousElementSibling
        li.remove()
        this.placeCaret(prev, "end")
        this.onChange()
      }
    }
  }

  // ── Block manipulation ────────────────────────────────────────────────────

  insertBlockAt(index, data) {
    const blocks = this.serialize()
    blocks.splice(index, 0, data)
    this.render(blocks)
    this.focusBlockAt(index)
    this.onChange()
  }

  replaceBlockAt(index, data) {
    const blocks = this.serialize()
    blocks.splice(index, 1, data)
    this.render(blocks)
    this.onChange()
  }

  removeBlock(wrapper) {
    const index  = this.blockIndex(wrapper)
    const blocks = this.serialize()
    blocks.splice(index, 1)
    if (blocks.length === 0) blocks.push({ type: "paragraph", content: "" })
    this.render(blocks)
    this.focusBlockAt(Math.max(0, index - 1))
    this.onChange()
  }

  blockIndex(wrapper) {
    return Array.from(this.canvasTarget.querySelectorAll(".block")).indexOf(wrapper)
  }

  focusBlockAt(index) {
    const blocks   = this.canvasTarget.querySelectorAll(".block")
    const target   = blocks[index]
    if (!target) return
    const focusable = target.querySelector("[contenteditable]")
    if (focusable) {
      focusable.focus()
      this.placeCaret(focusable, "end")
    }
  }

  // ── Image upload ──────────────────────────────────────────────────────────

  onDrop(e) {
    e.preventDefault()
    const files = Array.from(e.dataTransfer.files).filter(f => ALLOWED_TYPES.includes(f.type))
    if (!files.length) return
    const index = this.dropTargetIndex(e)
    files.forEach((file, i) => this.uploadImage(file, index + i))
  }

  onPaste(e) {
    const items = Array.from(e.clipboardData?.items || [])
    const images = items.filter(i => ALLOWED_TYPES.includes(i.type))
    if (!images.length) return
    e.preventDefault()
    const index = this.currentFocusIndex()
    images.forEach((item, i) => {
      const file = item.getAsFile()
      if (file) this.uploadImage(file, index + i + 1)
    })
  }

  pickImageAt(index) {
    const input  = document.createElement("input")
    input.type   = "file"
    input.accept = ALLOWED_TYPES.join(",")
    input.addEventListener("change", () => {
      const file = input.files[0]
      if (file) this.uploadImage(file, index)
    })
    input.click()
  }

  async uploadImage(file, index) {
    if (!this.hasUploadUrlValue) return

    if (!ALLOWED_TYPES.includes(file.type)) {
      return this.setStatus("error")
    }
    if (file.size > MAX_SIZE) {
      return this.setStatus("error")
    }

    this.insertBlockAt(index, { type: "image", uploading: true, alt: "" })

    const formData = new FormData()
    formData.append("file", file)

    try {
      const resp = await fetch(this.uploadUrlValue, {
        method:  "POST",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "" },
        body:    formData
      })
      if (!resp.ok) throw new Error("Upload failed")
      const { signed_id, url } = await resp.json()
      this.replaceBlockAt(index, { type: "image", signed_id, url, alt: "" })
    } catch {
      this.replaceBlockAt(index, { type: "image", error: true, alt: "" })
    }
  }

  dropTargetIndex(e) {
    const blocks = Array.from(this.canvasTarget.querySelectorAll(".block"))
    for (let i = 0; i < blocks.length; i++) {
      const rect = blocks[i].getBoundingClientRect()
      if (e.clientY < rect.top + rect.height / 2) return i
    }
    return blocks.length
  }

  currentFocusIndex() {
    const active  = document.activeElement?.closest(".block")
    const blocks  = Array.from(this.canvasTarget.querySelectorAll(".block"))
    const index   = blocks.indexOf(active)
    return index >= 0 ? index : blocks.length - 1
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  serialize() {
    return Array.from(this.canvasTarget.querySelectorAll(".block")).map(wrapper => {
      const type = wrapper.dataset.blockType

      if (type === "ul" || type === "ol") {
        return { type, items: Array.from(wrapper.querySelectorAll("li")).map(li => li.textContent) }
      }

      if (type === "image") {
        const altInput = wrapper.querySelector(".block__image-alt")
        const img      = wrapper.querySelector("img")
        return {
          type,
          signed_id: wrapper.dataset.signedId || img?.dataset.signedId || "",
          url:       img?.src || "",
          alt:       altInput?.value || ""
        }
      }

      const el = wrapper.querySelector("[contenteditable]")
      if (type === "heading") {
        return { type, level: parseInt(el.dataset.blockLevel, 10), content: el.textContent }
      }
      return { type: "paragraph", content: el.textContent }
    })
  }

  updateInput() {
    if (this.hasInputTarget) {
      this.inputTarget.value = JSON.stringify(this.serialize())
    }
  }

  // ── Autosave ──────────────────────────────────────────────────────────────

  onChange() {
    this.updateInput()
    if (!this.hasUrlValue || !this.urlValue) return
    this.setStatus("saving")
    clearTimeout(this.saveTimer)
    this.saveTimer = setTimeout(() => this.autosave(), 1000)
  }

  async autosave() {
    try {
      const resp = await fetch(this.urlValue, {
        method:  "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? ""
        },
        body: JSON.stringify({ blocks: this.serialize() })
      })
      this.setStatus(resp.ok ? "saved" : "error")
    } catch {
      this.setStatus("error")
    }
  }

  setStatus(state) {
    if (!this.hasStatusTarget) return
    const labels = { saving: "Saving…", saved: "Saved", error: "Couldn't save" }
    this.statusTarget.textContent  = labels[state] ?? ""
    this.statusTarget.dataset.state = state
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  caretAtStart(el) {
    const sel = window.getSelection()
    if (!sel?.rangeCount) return false
    const range = sel.getRangeAt(0)
    return range.startOffset === 0 &&
      (range.startContainer === el || el.contains(range.startContainer))
  }

  placeCaret(el, position = "end") {
    if (!el) return
    el.focus()
    const range = document.createRange()
    const sel   = window.getSelection()
    if (position === "end") {
      range.selectNodeContents(el)
      range.collapse(false)
    } else {
      range.setStart(el, 0)
      range.collapse(true)
    }
    sel?.removeAllRanges()
    sel?.addRange(range)
  }
}
