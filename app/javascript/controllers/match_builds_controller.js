import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup", "toggle"]
  static values = { matchId: Number }

  connect() {
    this._documentClickListener = (event) => {
      if (this.isVisible && !this.element.contains(event.target)) {
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

  onKeydown(event) {
    if (event.key === "Escape") {
      this.hide()
      this.toggleTargets[0]?.focus()
    }
  }

  show() {
    this._visible = true
    this.popupTarget.style.display = "block"
    this.setExpanded(true)
  }

  hide() {
    this._visible = false
    this.popupTarget.style.display = "none"
    this.setExpanded(false)
  }

  get isVisible() {
    return Boolean(this._visible)
  }

  setExpanded(isExpanded) {
    this.toggleTargets.forEach((button) => {
      button.setAttribute("aria-expanded", String(isExpanded))
    })
  }
}
