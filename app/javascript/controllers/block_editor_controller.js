import { Controller } from "@hotwired/stimulus"

// Block JSON format:
//   { type: "paragraph", content: "text with **bold**, *italic*, [links](url)" }
//   { type: "heading",   level: 2|3, content: "text" }
//   { type: "ul",        items: ["a", "b with **bold**"] }
//   { type: "ol",        items: ["a", "b"] }
//   { type: "image",     signed_id: "...", url: "...", alt: "" }
// Inline content uses markdown syntax: **bold**, *italic*, [text](url)

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"]
const MAX_SIZE      = 10 * 1024 * 1024

export default class extends Controller {
  static targets = ["canvas", "input", "status"]
  static values  = { url: String, uploadUrl: String, blocks: Array }

  connect() {
    this.saveTimer   = null
    this.savedLink   = null
    this.linkToolbar = null
    this._onMouseUp      = () => this.updateLinkToolbar()
    this._onKeyUp        = () => this.updateLinkToolbar()
    this._onDocMouseDown = e => {
      if (this.linkToolbar && !this.linkToolbar.hidden &&
          !this.linkToolbar.contains(e.target) &&
          !this.canvasTarget.contains(e.target)) {
        this.hideLinkToolbar()
      }
    }

    this.render(this.blocksValue.length ? this.blocksValue : [{ type: "paragraph", content: "" }])
    this.canvasTarget.addEventListener("dragover",  e => { e.preventDefault(); e.dataTransfer.dropEffect = "copy" })
    this.canvasTarget.addEventListener("drop",      e => this.onDrop(e))
    this.canvasTarget.addEventListener("paste",     e => this.onPaste(e))
    this.canvasTarget.addEventListener("focusin",   e => this.setActiveBlock(e.target.closest(".block")))
    this.canvasTarget.addEventListener("focusout",  e => {
      if (!e.relatedTarget?.closest(".link-toolbar")) this.setActiveBlock(null)
    })
    this.canvasTarget.addEventListener("mouseup",   this._onMouseUp)
    this.canvasTarget.addEventListener("keyup",     this._onKeyUp)
    this.canvasTarget.addEventListener("click",     e => { if (e.target.closest("a")) e.preventDefault() })
    document.addEventListener("mousedown", this._onDocMouseDown)
  }

  disconnect() {
    clearTimeout(this.saveTimer)
    this.canvasTarget.removeEventListener("mouseup", this._onMouseUp)
    this.canvasTarget.removeEventListener("keyup",   this._onKeyUp)
    document.removeEventListener("mousedown", this._onDocMouseDown)
    this.linkToolbar?.remove()
  }

  // ── Rendering ────────────────────────────────────────────────────────────

  render(blocks) {
    this.canvasTarget.innerHTML = ""
    blocks.forEach(block => {
      this.canvasTarget.appendChild(this.createBlock(block))
    })
    this.updateInput()
  }

  createBlock(data) {
    const wrapper = document.createElement("div")
    wrapper.className = "block"
    wrapper.dataset.blockType = data.type

    const addBtn = document.createElement("button")
    addBtn.type      = "button"
    addBtn.className = "block__add-btn"
    addBtn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="14" viewBox="0 0 10 14" fill="currentColor" aria-hidden="true"><circle cx="2.5" cy="2"  r="1.5"/><circle cx="7.5" cy="2"  r="1.5"/><circle cx="2.5" cy="7"  r="1.5"/><circle cx="7.5" cy="7"  r="1.5"/><circle cx="2.5" cy="12" r="1.5"/><circle cx="7.5" cy="12" r="1.5"/></svg>'
    addBtn.setAttribute("aria-label", "Add block")
    addBtn.addEventListener("click", () => this.openMenu(wrapper))
    wrapper.appendChild(addBtn)

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
      this.markdownLinksToHtml(data.content || "", el)
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
    this.markdownLinksToHtml(text, li)
    return li
  }

  // ── Type switcher menu ────────────────────────────────────────────────────

  openMenu(wrapper) {
    this.closeMenu()
    const insertIndex = this.blockIndex(wrapper) + 1
    const addBtn = wrapper.querySelector(".block__add-btn")
    const menu = document.createElement("div")
    menu.className = "block-menu"
    menu.setAttribute("role", "menu")

    const types = [
      { label: "Paragraph",     data: { type: "paragraph", content: "" } },
      { label: "Heading 2",     data: { type: "heading", level: 2, content: "" } },
      { label: "Heading 3",     data: { type: "heading", level: 3, content: "" } },
      { label: "Bullet list",   data: { type: "ul", items: [""] } },
      { label: "Numbered list", data: { type: "ol", items: [""] } },
    ]

    types.forEach(({ label, data }) => {
      const btn = document.createElement("button")
      btn.type        = "button"
      btn.textContent = label
      btn.setAttribute("role", "menuitem")
      btn.addEventListener("click", () => {
        this.closeMenu()
        if (data) {
          this.insertBlockAt(insertIndex, data)
        } else {
          this.pickImageAt(insertIndex)
        }
      })
      menu.appendChild(btn)
    })

    addBtn.appendChild(menu)
    wrapper.classList.add("block--menu-open")

    this._menuCloseHandler = e => {
      if (!menu.contains(e.target)) this.closeMenu()
    }
    document.addEventListener("click", this._menuCloseHandler, { once: true, capture: true })
  }

  closeMenu() {
    const existing = this.canvasTarget.querySelector(".block-menu")
    if (existing) {
      existing.closest(".block")?.classList.remove("block--menu-open")
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
    const index   = this.blockIndex(wrapper)
    const blocks  = this.canvasTarget.querySelectorAll(".block")

    if (e.key === "Enter") {
      e.preventDefault()
      this.insertBlockAt(index + 1, { type: "paragraph", content: "" })
      return
    }

    if (e.key === "Backspace" && this.caretAtStart(el) && el.textContent === "") {
      e.preventDefault()
      this.removeBlock(wrapper)
      return
    }

    if (e.key === "ArrowDown" && this.caretAtLastLine(el)) {
      if (index + 1 < blocks.length) {
        e.preventDefault()
        this.focusBlockAt(index + 1, "start")
      }
      return
    }

    if (e.key === "ArrowUp" && this.caretAtFirstLine(el)) {
      if (index > 0) {
        e.preventDefault()
        this.focusBlockAt(index - 1, "end")
      }
      return
    }

    if (e.key === "/" && el.textContent === "") {
      e.preventDefault()
      this.openMenu(wrapper)
    }

    if ((e.metaKey || e.ctrlKey) && e.key === "b") {
      e.preventDefault()
      if (this.savedLink) this.applyInlineFormat("**", "**")
    }

    if ((e.metaKey || e.ctrlKey) && e.key === "i") {
      e.preventDefault()
      if (this.savedLink) this.applyInlineFormat("*", "*")
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

    if (e.key === "ArrowDown" && li === list.lastElementChild && this.caretAtLastLine(li)) {
      const index = this.blockIndex(wrapper)
      const blocks = this.canvasTarget.querySelectorAll(".block")
      if (index + 1 < blocks.length) {
        e.preventDefault()
        this.focusBlockAt(index + 1, "start")
      }
    }

    if (e.key === "ArrowUp" && li === list.firstElementChild && this.caretAtFirstLine(li)) {
      const index = this.blockIndex(wrapper)
      if (index > 0) {
        e.preventDefault()
        this.focusBlockAt(index - 1, "end")
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

  setActiveBlock(block) {
    this.canvasTarget.querySelectorAll(".block--active").forEach(b => b.classList.remove("block--active"))
    block?.classList.add("block--active")
  }

  blockIndex(wrapper) {
    return Array.from(this.canvasTarget.querySelectorAll(".block")).indexOf(wrapper)
  }

  focusBlockAt(index, position = "end") {
    const blocks   = this.canvasTarget.querySelectorAll(".block")
    const target   = blocks[index]
    if (!target) return
    const focusable = target.querySelector("[contenteditable]")
    if (focusable) {
      focusable.focus()
      this.placeCaret(focusable, position)
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
        return { type, items: Array.from(wrapper.querySelectorAll("li")).map(li => this.htmlToMarkdownText(li)) }
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
        return { type, level: parseInt(el.dataset.blockLevel, 10), content: this.htmlToMarkdownText(el) }
      }
      return { type: "paragraph", content: this.htmlToMarkdownText(el) }
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

  // ── Inline formatting ─────────────────────────────────────────────────────

  markdownLinksToHtml(text, el) {
    el.innerHTML = ""
    // Bold must come before italic so ** is matched before *
    const re = /\*\*([^*]+)\*\*|\*([^*]+)\*|\[([^\]]*)\]\(([^)]*)\)/g
    let last = 0, m
    while ((m = re.exec(text)) !== null) {
      if (m.index > last) el.appendChild(document.createTextNode(text.slice(last, m.index)))
      if (m[1] !== undefined) {
        const strong = document.createElement("strong")
        strong.textContent = m[1]
        el.appendChild(strong)
      } else if (m[2] !== undefined) {
        const em = document.createElement("em")
        em.textContent = m[2]
        el.appendChild(em)
      } else {
        const a = document.createElement("a")
        a.href = m[4]
        a.textContent = m[3]
        el.appendChild(a)
      }
      last = m.index + m[0].length
    }
    if (last < text.length) el.appendChild(document.createTextNode(text.slice(last)))
  }

  htmlToMarkdownText(el) {
    let result = ""
    for (const node of el.childNodes) {
      if (node.nodeType === Node.TEXT_NODE) {
        result += node.textContent
      } else if (node.nodeName === "A") {
        result += `[${this.htmlToMarkdownText(node)}](${node.getAttribute("href") || ""})`
      } else if (node.nodeName === "STRONG" || node.nodeName === "B") {
        result += `**${this.htmlToMarkdownText(node)}**`
      } else if (node.nodeName === "EM" || node.nodeName === "I") {
        result += `*${this.htmlToMarkdownText(node)}*`
      } else {
        result += this.htmlToMarkdownText(node)
      }
    }
    return result
  }

  // ── Link toolbar ───────────────────────────────────────────────────────────

  updateLinkToolbar() {
    const sel = window.getSelection()
    if (!sel || sel.rangeCount === 0) { this.hideLinkToolbar(); return }

    const range = sel.getRangeAt(0)
    let node = range.commonAncestorContainer
    if (node.nodeType === Node.TEXT_NODE) node = node.parentNode

    const inCanvas = node.closest?.("[data-block-editor-target='canvas']") === this.canvasTarget
    const inText   = node.closest?.(".block__text, li[contenteditable]")
    if (!inCanvas || !inText) { this.hideLinkToolbar(); return }

    const existingLink = node.closest("a") ||
      (range.commonAncestorContainer.nodeType === Node.TEXT_NODE &&
       range.commonAncestorContainer.parentElement?.closest("a"))

    if (!sel.isCollapsed || existingLink) {
      // Save while selection is live (mouseup), not when the button is clicked
      if (!sel.isCollapsed) {
        this.savedLink = { el: inText, text: range.toString() }
      }
      this.showLinkToolbar(range.getBoundingClientRect(), existingLink)
    } else {
      this.hideLinkToolbar()
    }
  }

  showLinkToolbar(rect, existingLink) {
    if (!this.linkToolbar) this.buildLinkToolbar()

    const toolbar   = this.linkToolbar
    const linkBtn   = toolbar.querySelector(".link-toolbar__btn")
    const inputWrap = toolbar.querySelector(".link-toolbar__input-wrap")
    const removeBtn = toolbar.querySelector(".link-toolbar__remove")

    linkBtn.hidden   = !!existingLink
    removeBtn.hidden = !existingLink
    inputWrap.hidden = true
    toolbar.hidden   = false

    requestAnimationFrame(() => {
      const top  = rect.top - toolbar.offsetHeight - 6
      const left = Math.min(rect.left, window.innerWidth - toolbar.offsetWidth - 8)
      toolbar.style.top  = `${top}px`
      toolbar.style.left = `${left}px`
    })
  }

  buildLinkToolbar() {
    const toolbar = document.createElement("div")
    toolbar.className = "link-toolbar"
    toolbar.hidden    = true
    toolbar.innerHTML = `
      <button class="link-toolbar__bold"   type="button" title="Bold (⌘B)"><strong>B</strong></button>
      <button class="link-toolbar__italic" type="button" title="Italic (⌘I)"><em>I</em></button>
      <div class="link-toolbar__sep"></div>
      <button class="link-toolbar__btn" type="button">Link</button>
      <div class="link-toolbar__input-wrap" hidden>
        <input class="link-toolbar__url" type="url" placeholder="https://…" autocomplete="off">
        <button class="link-toolbar__apply" type="button">Apply</button>
      </div>
      <button class="link-toolbar__remove" type="button" hidden>Remove link</button>
    `
    document.body.appendChild(toolbar)
    this.linkToolbar = toolbar

    toolbar.querySelector(".link-toolbar__bold").addEventListener("mousedown", e => {
      e.preventDefault()
      this.applyInlineFormat("**", "**")
    })

    toolbar.querySelector(".link-toolbar__italic").addEventListener("mousedown", e => {
      e.preventDefault()
      this.applyInlineFormat("*", "*")
    })

    toolbar.querySelector(".link-toolbar__btn").addEventListener("mousedown", e => {
      e.preventDefault()
      toolbar.querySelector(".link-toolbar__btn").hidden = true
      toolbar.querySelector(".link-toolbar__input-wrap").hidden = false
      toolbar.querySelector(".link-toolbar__url").value = ""
      toolbar.querySelector(".link-toolbar__url").focus()
    })

    toolbar.querySelector(".link-toolbar__apply").addEventListener("click", () => {
      this.applyLink(toolbar.querySelector(".link-toolbar__url").value.trim())
    })

    toolbar.querySelector(".link-toolbar__url").addEventListener("keydown", e => {
      if (e.key === "Enter")  { e.preventDefault(); this.applyLink(toolbar.querySelector(".link-toolbar__url").value.trim()) }
      if (e.key === "Escape") this.hideLinkToolbar()
    })

    toolbar.querySelector(".link-toolbar__remove").addEventListener("mousedown", e => {
      e.preventDefault()
      const sel  = window.getSelection()
      const node = sel?.rangeCount ? sel.getRangeAt(0).commonAncestorContainer : null
      const a    = node ? (node.nodeType === Node.TEXT_NODE ? node.parentElement : node).closest("a") : null
      if (a) {
        const parent = a.parentNode
        while (a.firstChild) parent.insertBefore(a.firstChild, a)
        parent.removeChild(a)
      }
      this.onChange()
      this.hideLinkToolbar()
    })
  }

  applyLink(url) {
    if (!url || !this.savedLink) { this.hideLinkToolbar(); return }

    const { el, text } = this.savedLink
    const updated = this.wrapInMarkdown(this.htmlToMarkdownText(el), text, `[${text}](${url})`)
    if (updated !== null) { this.markdownLinksToHtml(updated, el); this.onChange() }

    this.savedLink = null
    this.hideLinkToolbar()
  }

  applyInlineFormat(open, close) {
    if (!this.savedLink) return
    const { el, text } = this.savedLink
    const updated = this.wrapInMarkdown(this.htmlToMarkdownText(el), text, `${open}${text}${close}`)
    if (updated !== null) { this.markdownLinksToHtml(updated, el); this.onChange() }
    this.hideLinkToolbar()
  }

  wrapInMarkdown(markdown, text, replacement) {
    // Find all existing inline spans so we skip text already inside them
    const spans = []
    const spanRe = /\*\*[^*]+\*\*|\*[^*]+\*|\[[^\]]*\]\([^)]*\)/g
    let m
    while ((m = spanRe.exec(markdown)) !== null) {
      spans.push([m.index, m.index + m[0].length])
    }

    const escaped = text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    const re = new RegExp(escaped, "g")
    while ((m = re.exec(markdown)) !== null) {
      const inside = spans.some(([s, e]) => m.index >= s && m.index + text.length <= e)
      if (!inside) {
        return markdown.slice(0, m.index) + replacement + markdown.slice(m.index + text.length)
      }
    }
    return null
  }

  hideLinkToolbar() {
    if (this.linkToolbar) this.linkToolbar.hidden = true
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  caretAtStart(el) {
    const sel = window.getSelection()
    if (!sel?.rangeCount) return false
    const range = sel.getRangeAt(0)
    return range.startOffset === 0 &&
      (range.startContainer === el || el.contains(range.startContainer))
  }

  caretAtFirstLine(el) {
    if (!el.textContent) return true
    const sel = window.getSelection()
    if (!sel?.rangeCount) return false
    const range     = sel.getRangeAt(0).cloneRange()
    range.collapse(true)
    const caretRect = range.getBoundingClientRect()
    if (!caretRect.height) return false
    const elRect = el.getBoundingClientRect()
    const lineH  = parseFloat(getComputedStyle(el).lineHeight) || caretRect.height * 1.5
    return caretRect.top < elRect.top + lineH
  }

  caretAtLastLine(el) {
    if (!el.textContent) return true
    const sel = window.getSelection()
    if (!sel?.rangeCount) return false
    const range     = sel.getRangeAt(0).cloneRange()
    range.collapse(true)
    const caretRect = range.getBoundingClientRect()
    if (!caretRect.height) return false
    const elRect = el.getBoundingClientRect()
    const lineH  = parseFloat(getComputedStyle(el).lineHeight) || caretRect.height * 1.5
    return caretRect.bottom > elRect.bottom - lineH
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
