import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    this.hashChangeHandler = () => this.show(window.location.hash.slice(1))
    window.addEventListener("hashchange", this.hashChangeHandler)
    this.show(window.location.hash.slice(1))
  }

  disconnect() {
    window.removeEventListener("hashchange", this.hashChangeHandler)
  }

  select(event) {
    event.preventDefault()
    this.show(event.currentTarget.dataset.compositionId)
  }

  show(id) {
    const target = this.panelTargets.find((panel) => panel.dataset.compositionId === id) || this.panelTargets[0]
    if (!target) return

    this.panelTargets.forEach((panel) => {
      const active = panel === target
      panel.classList.toggle("hidden", !active)
      panel.setAttribute("aria-hidden", active ? "false" : "true")
    })

    this.tabTargets.forEach((tab) => {
      const active = tab.dataset.compositionId === target.dataset.compositionId
      tab.classList.toggle("gw-tab--active", active)
      tab.setAttribute("aria-selected", active ? "true" : "false")
    })

    if (window.location.hash !== `#${target.dataset.compositionId}`) {
      history.pushState(null, null, `#${target.dataset.compositionId}`)
    }
  }
}
