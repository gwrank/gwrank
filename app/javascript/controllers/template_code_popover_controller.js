import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "code"]

  connect() {
    this.boundOutsideClick = this.outsideClick.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundOutsideClick)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  toggle(event) {
    event.stopPropagation()
    this.cardTarget.classList.toggle("hidden")
  }

  async copy(event) {
    const code = this.codeTarget.textContent.trim()
    try {
      await navigator.clipboard.writeText(code)
      this.flashCopied(event.currentTarget)
    } catch {
      this.selectCode()
    }
  }

  flashCopied(button) {
    if (!button.dataset.originalLabel) button.dataset.originalLabel = button.textContent
    button.textContent = "Copied ✓"
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      button.textContent = button.dataset.originalLabel
    }, 1500)
  }

  selectCode() {
    const range = document.createRange()
    range.selectNodeContents(this.codeTarget)
    const selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)
  }

  outsideClick(event) {
    if (!this.element.contains(event.target)) this.hide()
  }

  keydown(event) {
    if (event.key === "Escape") this.hide()
  }

  hide() {
    this.cardTarget.classList.add("hidden")
  }
}
