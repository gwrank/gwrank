import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navButtons", "professionSection"]

  connect() {
    this.currentSection = null
    this.sections = Array.from(this.professionSectionTargets)

    // Listen for hash changes
    this.hashChangeHandler = () => this.showSectionByHash()
    window.addEventListener('hashchange', this.hashChangeHandler)

    // Show first section or all sections by default if no hash
    if (!window.location.hash) {
      this.showSection(this.sections[0])
    } else {
      this.showSectionByHash()
    }
  }

  disconnect() {
    window.removeEventListener('hashchange', this.hashChangeHandler)
  }

  selectProfession(event) {
    event.preventDefault()
    const profession = event.target.dataset.profession
    if (profession === 'all') {
      this.showAll()
    } else {
      const section = this.getSectionByProfession(profession)
      if (section) {
        this.showSection(section)
      }
    }
  }

  showSection(section) {
    if (!section) return

    // Hide all sections
    this.sections.forEach(sec => {
      sec.classList.add('d-none')
      sec.setAttribute('aria-hidden', 'true')
    })

    // Show selected section
    section.classList.remove('d-none')
    section.setAttribute('aria-hidden', 'false')

    // Update button states
    this.updateButtons(section.dataset.profession)

    // Update URL hash
    const profession = section.dataset.profession
    history.pushState(null, null, `#${profession.toLowerCase()}`)
    this.currentSection = section
  }

  showAll() {
    // Show all sections
    this.sections.forEach(sec => {
      sec.classList.remove('d-none')
      sec.setAttribute('aria-hidden', 'false')
    })

    // Reset button states
    this.updateButtons(null)

    // Clear URL hash
    history.pushState(null, null, ' ')
    this.currentSection = null
  }

  updateButtons(activeProfession) {
    const buttons = Array.from(this.navButtonsTarget.querySelectorAll('button'))
    buttons.forEach(btn => {
      const btnProfession = btn.dataset.profession
      btn.classList.remove('btn-primary', 'text-white')
      btn.classList.add('btn-outline-primary')

      if (activeProfession && btnProfession === activeProfession.toLowerCase()) {
        btn.classList.remove('btn-outline-primary')
        btn.classList.add('btn-primary', 'text-white')
      }
    })
  }

  showSectionByHash() {
    const hash = window.location.hash.slice(1) // Remove #
    if (!hash || hash === 'all') {
      this.showAll()
      return
    }
    const section = this.getSectionByProfession(hash)
    if (section) {
      this.showSection(section)
    }
  }

  getSectionByProfession(profession) {
    const professionLower = profession.toLowerCase()
    return this.sections.find(
      sec => sec.dataset.profession.toLowerCase() === professionLower
    )
  }

  scrollToSection(event) {
    event.preventDefault()
    const section = this.getSectionByProfession(event.target.hash.slice(1))
    if (section) {
      this.showSection(section)
      section.scrollIntoView({ behavior: 'smooth', block: 'start' })
    }
  }
}
