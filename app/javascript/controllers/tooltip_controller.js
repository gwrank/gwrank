import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }

  connect() {
    this.tip = null
    this.storedTitle = this.element.getAttribute("title")
    if (this.storedTitle) this.element.removeAttribute("title")
    this.onShow = this.show.bind(this)
    this.onHide = this.hide.bind(this)
    this.showEvents = ["mouseenter", "focusin"]
    this.hideEvents = ["mouseleave", "focusout"]
    this.showEvents.forEach((event) => this.element.addEventListener(event, this.onShow))
    this.hideEvents.forEach((event) => this.element.addEventListener(event, this.onHide))
  }

  disconnect() {
    this.showEvents.forEach((event) => this.element.removeEventListener(event, this.onShow))
    this.hideEvents.forEach((event) => this.element.removeEventListener(event, this.onHide))
    this.hide()
  }

  show() {
    const content = this.contentValue || this.storedTitle
    if (!content || this.tip) return

    const rect = this.element.getBoundingClientRect()
    const tip = document.createElement("div")
    tip.className = "gw-tooltip"
    tip.textContent = content
    document.body.appendChild(tip)
    tip.style.left = `${rect.left + window.scrollX + rect.width / 2 - tip.offsetWidth / 2}px`
    tip.style.top = `${rect.top + window.scrollY - tip.offsetHeight - 6}px`
    this.tip = tip
  }

  hide() {
    if (this.tip) {
      this.tip.remove()
      this.tip = null
    }
  }
}
