import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["type", "region"]

  connect() {
    this.sync()
  }

  regionTypeChanged() {
    this.sync()
  }

  sync() {
    const isAt = this.typeTarget.value === "at"
    this.regionTarget.disabled = !isAt
    if (!isAt) {
      this.regionTarget.value = ""
    }
  }
}
