import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "code", "trigger"]

  connect() {
    this.boundOutsideClick = this.outsideClick.bind(this)
    this.boundKeydown = this.keydown.bind(this)
    document.addEventListener("click", this.boundOutsideClick)
    document.addEventListener("keydown", this.boundKeydown)
    this.hide()
  }

  disconnect() {
    clearTimeout(this.resetTimer)
    document.removeEventListener("click", this.boundOutsideClick)
    document.removeEventListener("keydown", this.boundKeydown)
  }

  toggle(event) {
    event.stopPropagation()
    if (this.cardTarget.classList.contains("hidden")) {
      this.show()
      this.syncExpanded(true)
    } else {
      this.hide()
    }
  }

  show() {
    const card = this.cardTarget
    card.classList.remove("hidden")
    const rect = this.triggerTarget.getBoundingClientRect()
    const width = card.offsetWidth || 288
    const height = card.offsetHeight
    card.style.position = "fixed"
    card.style.top = `${rect.bottom + 8}px`
    if (window.innerHeight - rect.bottom < height + 16) {
      card.style.top = `${Math.max(8, rect.top - height - 8)}px`
    }
    card.style.left = `${Math.max(8, Math.min(rect.right - width, window.innerWidth - width - 8))}px`
    card.style.right = "auto"
  }

  async copy(event) {
    const button = event.currentTarget
    const code = this.codeTarget.textContent.trim()
    try {
      await navigator.clipboard.writeText(code)
      this.flashCopied(button)
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
    if (event.key !== "Escape") return
    const wasOpen = !this.cardTarget.classList.contains("hidden")
    this.hide()
    if (wasOpen) this.triggerTarget.focus()
  }

  hide() {
    this.cardTarget.classList.add("hidden")
    this.cardTarget.style.position = ""
    this.cardTarget.style.top = ""
    this.cardTarget.style.left = ""
    this.cardTarget.style.right = ""
    this.syncExpanded(false)
  }

  syncExpanded(open) {
    if (this.hasTriggerTarget) this.triggerTarget.setAttribute("aria-expanded", open ? "true" : "false")
  }
}
