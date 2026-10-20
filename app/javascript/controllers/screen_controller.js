import { Controller } from "@hotwired/stimulus"

// The hall TV screen: runs the clock, switches to the other view every few seconds when asked to,
// shows the controls while the mouse moves, and toggles full screen.
export default class extends Controller {
  static targets = [ "clock" ]
  static values = { rotate: Number, nextUrl: String }

  connect() {
    this.tick()
    this.clock = setInterval(() => this.tick(), 1000)
    if (this.rotateValue > 0) {
      this.rotation = setTimeout(() => window.Turbo.visit(this.nextUrlValue, { action: "replace" }), this.rotateValue * 1000)
    }
  }

  disconnect() {
    clearInterval(this.clock)
    clearTimeout(this.rotation)
    clearTimeout(this.idle)
  }

  wake() {
    this.element.classList.add("tv--awake")
    clearTimeout(this.idle)
    this.idle = setTimeout(() => this.element.classList.remove("tv--awake"), 2500)
  }

  fullscreen() {
    if (document.fullscreenElement) {
      document.exitFullscreen()
    } else {
      document.documentElement.requestFullscreen()
    }
  }

  tick() {
    if (!this.hasClockTarget) return

    this.clockTarget.textContent = new Date().toLocaleTimeString(document.documentElement.lang, { hour: "2-digit", minute: "2-digit" })
  }
}
