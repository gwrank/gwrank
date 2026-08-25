import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "input"]

  open() {
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  submit() {
    this.dialogTarget.close()
  }
}
