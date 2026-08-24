import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }

  connect() {
    this.tip = null
    this.storedTitle = this.element.getAttribute("title")
    if (this.storedTitle) this.element.removeAttribute("title")
    this.onShow = this.show.bind(this)
    this.onHide = this.hide.bind(this)
    this.element.addEventListener("mouseenter", this.onShow)
    this.element.addEventListener("mouseleave", this.onHide)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.onShow)
    this.element.removeEventListener("mouseleave", this.onHide)
    this.hide()
  }

  show() {
    const content = this.contentValue || this.storedTitle
    if (!content || this.tip) return

    const rect = this.element.getBoundingClientRect()
    const tip = document.createElement("div")
    tip.textContent = content
    Object.assign(tip.style, {
      position: "absolute",
      zIndex: "1070",
      maxWidth: "240px",
      padding: "4px 8px",
      fontSize: "12px",
      fontFamily: "var(--font-display), serif",
      lineHeight: "1.4",
      color: "#171006",
      background: "linear-gradient(#f4dfa0, #c9a959)",
      border: "1px solid #9c7c3c",
      borderRadius: "4px",
      boxShadow: "0 1px 4px rgba(0,0,0,.5)",
      pointerEvents: "none"
    })
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
