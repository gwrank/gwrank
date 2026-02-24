import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup"]
  static values = { matchId: Number }

  show(event) {
    this.popupTarget.style.display = "block"
  }

  hide(event) {
    this.popupTarget.style.display = "none"
  }
}
