import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup", "toggle"]
  static values = { matchId: Number }

  connect() {
    this._documentClickListener = (event) => {
      if (!this.element.contains(event.target)) {
        this.hide()
      }
    }

    document.addEventListener("click", this._documentClickListener)
  }

  disconnect() {
    document.removeEventListener("click", this._documentClickListener)
  }

  toggle() {
    this.isVisible ? this.hide() : this.show()
  }

  show() {
    this.popupTarget.style.display = "block"
    this.setExpanded(true)
  }

  hide() {
    this.popupTarget.style.display = "none"
    this.setExpanded(false)
  }

  onKeydown(event) {
    if (event.key === "Escape") {
      this.hide()
      this.toggleTarget.focus()
    }
  }

  get isVisible() {
    return this.popupTarget.style.display !== "none"
  }

  setExpanded(isExpanded) {
    this.toggleTargets.forEach((button) => {
      button.setAttribute("aria-expanded", String(isExpanded))
    })
  }
}
