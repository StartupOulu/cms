import { Controller } from "@hotwired/stimulus"

const ALLOWED_TYPES = ["image/jpeg", "image/png", "image/webp"]
const MAX_SIZE      = 10 * 1024 * 1024

export default class extends Controller {
  static targets = ["preview", "placeholder", "removeBtn"]
  static values  = { uploadUrl: String, deleteUrl: String }

  connect() {
    this.element.addEventListener("dragover", e => { e.preventDefault(); e.dataTransfer.dropEffect = "copy" })
    this.element.addEventListener("drop",     e => this.onDrop(e))
  }

  pick() {
    const input  = document.createElement("input")
    input.type   = "file"
    input.accept = ALLOWED_TYPES.join(",")
    input.addEventListener("change", () => {
      const file = input.files[0]
      if (file) this.upload(file)
    })
    input.click()
  }

  onDrop(e) {
    e.preventDefault()
    const file = Array.from(e.dataTransfer.files).find(f => ALLOWED_TYPES.includes(f.type))
    if (file) this.upload(file)
  }

  async upload(file) {
    if (!ALLOWED_TYPES.includes(file.type) || file.size > MAX_SIZE) return

    this.setLoading(true)

    const formData = new FormData()
    formData.append("file", file)

    try {
      const resp = await fetch(this.uploadUrlValue, {
        method:  "PATCH",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "" },
        body:    formData
      })
      if (!resp.ok) throw new Error("Upload failed")
      const { url } = await resp.json()
      this.showPreview(url)
    } catch {
      this.setLoading(false)
    }
  }

  async remove() {
    await fetch(this.deleteUrlValue, {
      method:  "DELETE",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content ?? "" }
    })
    this.clearPreview()
  }

  showPreview(url) {
    if (this.hasPreviewTarget) {
      this.previewTarget.src          = url
      this.previewTarget.style.display = "block"
    }
    if (this.hasPlaceholderTarget) this.placeholderTarget.style.display = "none"
    if (this.hasRemoveBtnTarget)   this.removeBtnTarget.style.display   = "inline"
    this.setLoading(false)
  }

  clearPreview() {
    if (this.hasPreviewTarget)     this.previewTarget.style.display     = "none"
    if (this.hasPlaceholderTarget) this.placeholderTarget.style.display = "flex"
    if (this.hasRemoveBtnTarget)   this.removeBtnTarget.style.display   = "none"
  }

  setLoading(state) {
    this.element.dataset.loading = state ? "true" : "false"
  }
}
