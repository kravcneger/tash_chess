import { Controller } from "@hotwired/stimulus"

// Time left before the next round, in minutes and seconds. The page gives the seconds left when it was rendered,
// so the count doesn't depend on the device's clock; a live refresh brings a fresh value, or a new countdown.
export default class extends Controller {
  static targets = [ "time", "running", "over" ]
  static values = { seconds: Number }

  connect() {
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  secondsValueChanged() {
    this.endsAt = Date.now() + this.secondsValue * 1000
    this.tick()
  }

  tick() {
    const left = Math.max(0, Math.ceil((this.endsAt - Date.now()) / 1000))
    this.timeTarget.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`

    if (this.hasRunningTarget) this.runningTarget.hidden = left === 0
    if (this.hasOverTarget) this.overTarget.hidden = left > 0
  }
}
