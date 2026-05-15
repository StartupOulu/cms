import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["publish"]

  connect() {
    this.clickedSubmit = null
    this.element.querySelectorAll("input[type=submit]").forEach(btn => {
      btn.addEventListener("click", e => { this.clickedSubmit = e.target })
    })
  }

  submit() {
    const submits = this.element.querySelectorAll("input[type=submit]")
    submits.forEach(btn => { btn.disabled = true })

    if (this.clickedSubmit === this.publishTarget) {
      this.publishTarget.value = "Publishing…"
    }
  }
}
