import { Controller } from "@hotwired/stimulus"
import { Chart, LineController, LineElement, PointElement, LinearScale, Title, Tooltip, Legend, TimeScale, Filler, ScatterController } from "chart.js"
import zoomPlugin from "chartjs-plugin-zoom"

// Register Chart.js components
Chart.register(LineController, LineElement, PointElement, LinearScale, Title, Tooltip, Legend, TimeScale, Filler, ScatterController, zoomPlugin)

export default class extends Controller {
  static values = {
    data: Object,
    initialMode: String,
    shrineIcon: String,
    ressigIcon: String,
    moraleIcon: String
  }
  
  static targets = ["resetButton", "healthButton", "moraleButton", "timelineButton"]

  connect() {
    this.currentMode = this.hasInitialModeValue ? this.initialModeValue : 'health'
    // Create icon images for use in charts
    this.flagIcon = this.createEmojiIcon('🚩', 20)
    this.towerIcon = this.createEmojiIcon('🗼', 20)
    this.skullIcon = this.createEmojiIcon('💀', 20)
    
    // Load external images asynchronously
    this.loadAllIcons().then(() => {
      this.createChart()
    })
  }
  
  async loadAllIcons() {
    this.resurrectionShrineIcon = await this.loadImageIconAsync(this.shrineIconValue, 20)
    this.resurrectionSignetIcon = await this.loadImageIconAsync(this.ressigIconValue, 20)
    this.moraleBoostIcon = await this.loadImageIconAsync(this.moraleIconValue, 20)
  }
  
  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
  
  // Helper to load an external image as an icon (async)
  loadImageIconAsync(url, size) {
    return new Promise((resolve) => {
      const img = new Image(size, size)
      img.onload = () => resolve(img)
      img.onerror = () => {
        console.error(`Failed to load icon: ${url}`)
        // Return a fallback empty image
        const fallback = new Image(size, size)
        resolve(fallback)
      }
      img.src = url
    })
  }
  
  // Helper to create an image from an emoji
  createEmojiIcon(emoji, size) {
    const canvas = document.createElement('canvas')
    canvas.width = size
    canvas.height = size
    const ctx = canvas.getContext('2d')
    
    // Clear canvas
    ctx.clearRect(0, 0, size, size)
    
    // Use a font stack that supports emoji and slightly smaller to ensure it fits
    ctx.font = `${Math.floor(size * 0.9)}px "Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji", sans-serif`
    ctx.textAlign = 'center'
    ctx.textBaseline = 'middle'
    ctx.fillText(emoji, size / 2, size / 2)
    
    const img = new Image()
    img.src = canvas.toDataURL()
    return img
  }
  
  resetZoom(event) {
    event.preventDefault()
    if (this.chart) {
      this.chart.resetZoom()
    }
  }
  
  setModeHealth(event) {
    event.preventDefault()
    this.setMode('health')
  }
  
  setModeMorale(event) {
    event.preventDefault()
    this.setMode('morale')
  }
  
  setModeTimeline(event) {
    event.preventDefault()
    this.setMode('timeline')
  }
  
  setMode(mode) {
    if (this.currentMode === mode) return
    
    this.currentMode = mode
    
    // Update button styles
    this.updateButtonStyles()
    
    // Recreate chart with new mode
    if (this.chart) {
      this.chart.destroy()
    }
    this.createChart()
  }
  
  updateButtonStyles() {
    // Remove active class from all buttons
    if (this.hasHealthButtonTarget) {
      this.healthButtonTarget.classList.remove('btn-primary')
      this.healthButtonTarget.classList.add('btn-outline-primary')
    }
    if (this.hasMoraleButtonTarget) {
      this.moraleButtonTarget.classList.remove('btn-primary')
      this.moraleButtonTarget.classList.add('btn-outline-primary')
    }
    if (this.hasTimelineButtonTarget) {
      this.timelineButtonTarget.classList.remove('btn-primary')
      this.timelineButtonTarget.classList.add('btn-outline-primary')
    }
    
    // Add active class to current mode button
    const activeButton = {
      'health': this.healthButtonTarget,
      'morale': this.moraleButtonTarget,
      'timeline': this.timelineButtonTarget
    }[this.currentMode]
    
    if (activeButton) {
      activeButton.classList.remove('btn-outline-primary')
      activeButton.classList.add('btn-primary')
    }
  }

  createChart() {
    const canvas = this.element.querySelector('canvas')
    if (!canvas) {
      console.error("Canvas element not found")
      return
    }
    
    const ctx = canvas.getContext('2d')
    const healthData = this.dataValue

    if (!healthData || !healthData.team1 || !healthData.team2) {
      console.error("Health data not available")
      return
    }
    
    const team1Color = 'rgba(54, 162, 235, 1)'
    const team2Color = 'rgba(255, 99, 132, 1)'
    
    // Prepare datasets based on current mode
    const datasets = []
    
    if (this.currentMode === 'health') {
      // Health percentage datasets
      if (healthData.team1 && healthData.team1.data && healthData.team1.data.length > 0) {
        datasets.push({
          label: healthData.team1.name,
          data: healthData.team1.data,
          borderColor: team1Color,
          borderWidth: 2,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: team1Color,
          pointHoverBorderColor: '#fff',
          pointHoverBorderWidth: 2,
          fill: false,
          tension: 0,
          order: 1
        })
      }
      
      if (healthData.team2 && healthData.team2.data && healthData.team2.data.length > 0) {
        datasets.push({
          label: healthData.team2.name,
          data: healthData.team2.data,
          borderColor: team2Color,
          borderWidth: 2,
          pointRadius: 0,
          pointHoverRadius: 5,
          pointHoverBackgroundColor: team2Color,
          pointHoverBorderColor: '#fff',
          pointHoverBorderWidth: 2,
          fill: false,
          tension: 0,
          order: 1
        })
      }
    } else if (this.currentMode === 'morale') {
      // Morale datasets
      if (healthData.morale_data) {
        if (healthData.morale_data.team1 && healthData.morale_data.team1.data && healthData.morale_data.team1.data.length > 0) {
          datasets.push({
            label: healthData.morale_data.team1.name,
            data: healthData.morale_data.team1.data,
            borderColor: team1Color,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: team1Color,
            pointHoverBorderColor: '#fff',
            pointHoverBorderWidth: 2,
            fill: false,
            stepped: true,
            order: 1
          })
        }
        
        if (healthData.morale_data.team2 && healthData.morale_data.team2.data && healthData.morale_data.team2.data.length > 0) {
          datasets.push({
            label: healthData.morale_data.team2.name,
            data: healthData.morale_data.team2.data,
            borderColor: team2Color,
            borderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: team2Color,
            pointHoverBorderColor: '#fff',
            pointHoverBorderWidth: 2,
            fill: false,
            stepped: true,
            order: 1
          })
        }
      }
    }
    // For timeline mode, we don't add health or morale lines
    
    // Helper function to get Y position based on mode
    const getYPosition = (eventType) => {
      if (this.currentMode === 'timeline') {
        // Timeline mode - stack events at different levels
        const positions = {
          'death': 10,
          'resurrection': 20,
          'morale_boost': 30,
          'npc_death': 40,
          'tower_capture': 50,
          'shrine_capture': 60
        }
        return positions[eventType] || 0
      } else if (this.currentMode === 'health') {
        // Health mode - position near bottom/top
        const positions = {
          'death': 5,
          'resurrection': 10,
          'morale_boost': 15,
          'npc_death': 20,
          'tower_capture': 25,
          'shrine_capture': 30
        }
        return positions[eventType] || 5
      } else {
        // Morale mode - position in negative range
        const positions = {
          'death': -20,
          'resurrection': -15,
          'morale_boost': -10,
          'npc_death': -5,
          'tower_capture': -25,
          'shrine_capture': -30
        }
        return positions[eventType] || -20
      }
    }
    
    // Add death events (player deaths)
    if (healthData.death_events && healthData.death_events.length > 0) {
      const team1Deaths = healthData.death_events.filter(e => e.party_id === 1 && !e.is_npc)
      const team2Deaths = healthData.death_events.filter(e => e.party_id === 2 && !e.is_npc)
      
      if (team1Deaths.length > 0) {
        datasets.push({
          label: `Deaths (${healthData.team1.tag || 'Team 1'})`,
          data: team1Deaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('death'), 
            name: e.agent_name, 
            isNpc: e.is_npc,
            isDeathPact: e.is_death_pact,
            eventType: 'death'
          })),
          type: 'scatter',
          backgroundColor: team1Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.skullIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2Deaths.length > 0) {
        datasets.push({
          label: `Deaths (${healthData.team2.tag || 'Team 2'})`,
          data: team2Deaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('death'), 
            name: e.agent_name, 
            isNpc: e.is_npc,
            isDeathPact: e.is_death_pact,
            eventType: 'death'
          })),
          type: 'scatter',
          backgroundColor: team2Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.skullIcon,
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add NPC death events (only in timeline mode)
    if (this.currentMode === 'timeline' && healthData.npc_death_events && healthData.npc_death_events.length > 0) {
      // Split NPC deaths by team
      const team1NpcDeaths = healthData.npc_death_events.filter(e => e.party_id === 1)
      const team2NpcDeaths = healthData.npc_death_events.filter(e => e.party_id === 2)
      
      if (team1NpcDeaths.length > 0) {
        datasets.push({
          label: `NPC Deaths (${healthData.team1.tag || 'Team 1'})`,
          data: team1NpcDeaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('npc_death'),
            name: e.agent_name,
            npcType: e.npc_type,
            partyId: e.party_id,
            guildTag: e.guild_tag,
            eventType: 'npc_death'
          })),
          type: 'scatter',
          backgroundColor: team1Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'crossRot',
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2NpcDeaths.length > 0) {
        datasets.push({
          label: `NPC Deaths (${healthData.team2.tag || 'Team 2'})`,
          data: team2NpcDeaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('npc_death'),
            name: e.agent_name,
            npcType: e.npc_type,
            partyId: e.party_id,
            guildTag: e.guild_tag,
            eventType: 'npc_death'
          })),
          type: 'scatter',
          backgroundColor: team2Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'crossRot',
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add tower capture events (flags)
    if (healthData.tower_captures && healthData.tower_captures.length > 0) {
      const team1TowerCaptures = healthData.tower_captures.filter(e => e.party_id === 1)
      const team2TowerCaptures = healthData.tower_captures.filter(e => e.party_id === 2)
      
      if (team1TowerCaptures.length > 0) {
        datasets.push({
          label: `Flag Captures (${healthData.team1.tag || 'Team 1'})`,
          data: team1TowerCaptures.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('tower_capture'),
            partyId: e.party_id,
            partyName: e.party_name,
            guildTag: e.guild_tag,
            eventType: 'tower_capture'
          })),
          type: 'scatter',
          backgroundColor: team1Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.flagIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2TowerCaptures.length > 0) {
        datasets.push({
          label: `Flag Captures (${healthData.team2.tag || 'Team 2'})`,
          data: team2TowerCaptures.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('tower_capture'),
            partyId: e.party_id,
            partyName: e.party_name,
            guildTag: e.guild_tag,
            eventType: 'tower_capture'
          })),
          type: 'scatter',
          backgroundColor: team2Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.flagIcon,
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add shrine capture events
    if (healthData.shrine_captures && healthData.shrine_captures.length > 0) {
      const team1ShrineCaptures = healthData.shrine_captures.filter(e => e.party_id === 1)
      const team2ShrineCaptures = healthData.shrine_captures.filter(e => e.party_id === 2)
      
      if (team1ShrineCaptures.length > 0) {
        datasets.push({
          label: `Shrine Captures (${healthData.team1.tag || 'Team 1'})`,
          data: team1ShrineCaptures.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('shrine_capture'),
            partyId: e.party_id,
            partyName: e.party_name,
            guildTag: e.guild_tag,
            eventType: 'shrine_capture'
          })),
          type: 'scatter',
          backgroundColor: team1Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.towerIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2ShrineCaptures.length > 0) {
        datasets.push({
          label: `Shrine Captures (${healthData.team2.tag || 'Team 2'})`,
          data: team2ShrineCaptures.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('shrine_capture'),
            partyId: e.party_id,
            partyName: e.party_name,
            guildTag: e.guild_tag,
            eventType: 'shrine_capture'
          })),
          type: 'scatter',
          backgroundColor: team2Color,
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.towerIcon,
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add resurrection events
    if (healthData.resurrection_events && healthData.resurrection_events.length > 0) {
      const team1BaseRes = healthData.resurrection_events.filter(e => e.party_id === 1 && e.is_base_res)
      const team2BaseRes = healthData.resurrection_events.filter(e => e.party_id === 2 && e.is_base_res)
      const team1SkillRes = healthData.resurrection_events.filter(e => e.party_id === 1 && !e.is_base_res)
      const team2SkillRes = healthData.resurrection_events.filter(e => e.party_id === 2 && !e.is_base_res)
      
      // Base resurrections (from shrine)
      if (team1BaseRes.length > 0) {
        datasets.push({
          label: `Base Res (${healthData.team1.tag || 'Team 1'})`,
          data: team1BaseRes.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('resurrection'),
            name: e.agent_name,
            resurrector: e.resurrector_name,
            skillId: e.resurrection_skill_id,
            skillName: e.resurrection_skill_name,
            isBaseRes: e.is_base_res,
            eventType: 'resurrection'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(34, 197, 94, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.resurrectionShrineIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2BaseRes.length > 0) {
        datasets.push({
          label: `Base Res (${healthData.team2.tag || 'Team 2'})`,
          data: team2BaseRes.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('resurrection'),
            name: e.agent_name,
            resurrector: e.resurrector_name,
            skillId: e.resurrection_skill_id,
            skillName: e.resurrection_skill_name,
            isBaseRes: e.is_base_res,
            eventType: 'resurrection'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(34, 197, 94, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.resurrectionShrineIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      // Skill resurrections
      if (team1SkillRes.length > 0) {
        datasets.push({
          label: `Skill Res (${healthData.team1.tag || 'Team 1'})`,
          data: team1SkillRes.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('resurrection'),
            name: e.agent_name,
            resurrector: e.resurrector_name,
            skillId: e.resurrection_skill_id,
            skillName: e.resurrection_skill_name,
            isBaseRes: e.is_base_res,
            eventType: 'resurrection'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(34, 197, 94, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.resurrectionSignetIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2SkillRes.length > 0) {
        datasets.push({
          label: `Skill Res (${healthData.team2.tag || 'Team 2'})`,
          data: team2SkillRes.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('resurrection'),
            name: e.agent_name,
            resurrector: e.resurrector_name,
            skillId: e.resurrection_skill_id,
            skillName: e.resurrection_skill_name,
            isBaseRes: e.is_base_res,
            eventType: 'resurrection'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(34, 197, 94, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.resurrectionSignetIcon,
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add morale boost events
    if (healthData.morale_boosts && healthData.morale_boosts.length > 0) {
      const team1Boosts = healthData.morale_boosts.filter(e => e.party_id === 1)
      const team2Boosts = healthData.morale_boosts.filter(e => e.party_id === 2)
      
      if (team1Boosts.length > 0) {
        datasets.push({
          label: `Morale Boosts (${healthData.team1.tag || 'Team 1'})`,
          data: team1Boosts.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('morale_boost'),
            guildTag: e.guild_tag,
            eventType: 'morale_boost'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(234, 179, 8, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.moraleBoostIcon,
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2Boosts.length > 0) {
        datasets.push({
          label: `Morale Boosts (${healthData.team2.tag || 'Team 2'})`,
          data: team2Boosts.map(e => ({ 
            x: e.timestamp_ms, 
            y: getYPosition('morale_boost'),
            guildTag: e.guild_tag,
            eventType: 'morale_boost'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(234, 179, 8, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 10,
          pointHoverRadius: 14,
          pointStyle: this.moraleBoostIcon,
          order: 0,
          hitRadius: 15
        })
      }
    }

    // If no datasets were created, show a message
    if (datasets.length === 0) {
      ctx.font = '16px Arial'
      ctx.fillStyle = '#ccc'
      ctx.textAlign = 'center'
      ctx.fillText('No data available for this view', canvas.width / 2, canvas.height / 2)
      return
    }

    const yAxisConfig = this.currentMode === 'health' 
      ? {
          min: 0,
          max: 120,
          title: {
            display: true,
            text: 'Health %',
            color: '#fff',
            font: { size: 14 }
          },
          ticks: {
            color: '#ccc',
            callback: function(value) {
              return value + '%'
            }
          },
          grid: {
            color: 'rgba(255, 255, 255, 0.1)'
          }
        }
      : this.currentMode === 'morale'
      ? {
          min: -70,
          max: 20,
          title: {
            display: true,
            text: 'Death Penalty %',
            color: '#fff',
            font: { size: 14 }
          },
          ticks: {
            color: '#ccc',
            callback: function(value) {
              return value + '%'
            }
          },
          grid: {
            color: 'rgba(255, 255, 255, 0.1)'
          }
        }
      : {
          min: 0,
          max: 70,
          title: {
            display: true,
            text: 'Event Type',
            color: '#fff',
            font: { size: 14 }
          },
          ticks: {
            color: '#ccc',
            callback: function(value) {
              const labels = {
                10: 'Deaths',
                20: 'Resurrections',
                30: 'Morale Boosts',
                40: 'NPC Deaths',
                50: 'Flag Captures',
                60: 'Shrine Captures'
              }
              return labels[value] || ''
            }
          },
          grid: {
            color: 'rgba(255, 255, 255, 0.1)'
          }
        }

    this.chart = new Chart(ctx, {
      type: 'line',
      data: { datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'nearest',
          intersect: false,
          axis: 'xy'
        },
        plugins: {
          title: {
            display: true,
            text: this.currentMode === 'health' 
              ? 'Team Health Over Time' 
              : this.currentMode === 'morale'
              ? 'Team Morale (Death Penalty) Over Time'
              : 'Match Event Timeline',
            color: '#fff',
            font: {
              size: 18,
              weight: 'bold'
            }
          },
          legend: {
            display: true,
            position: 'top',
            labels: {
              color: '#fff',
              font: {
                size: 14
              },
              usePointStyle: true,
              padding: 15
            }
          },
          tooltip: {
            enabled: true,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            titleColor: '#fff',
            bodyColor: '#fff',
            borderColor: 'rgba(255, 255, 255, 0.3)',
            borderWidth: 1,
            padding: 12,
            displayColors: true,
            callbacks: {
              title: function(context) {
                const ms = context[0].parsed.x
                const totalSeconds = ms / 1000
                const minutes = Math.floor(totalSeconds / 60)
                const seconds = Math.floor(totalSeconds % 60)
                return `Time: ${minutes}:${seconds.toString().padStart(2, '0')}`
              },
              label: function(context) {
                const label = context.dataset.label || ''
                const dataPoint = context.raw
                
                // Check event type
                if (dataPoint.eventType === 'death') {
                  const deathType = dataPoint.isNpc ? 'NPC' : 'Player'
                  let deathMessage = `💀 ${deathType}: ${dataPoint.name}`
                  
                  if (dataPoint.isDeathPact) {
                    deathMessage += ' (Death Pact)'
                  }
                  
                  return deathMessage
                }
                
                if (dataPoint.eventType === 'npc_death') {
                  const npcName = dataPoint.name
                  const guildTag = dataPoint.guildTag ? ` ${dataPoint.guildTag}` : ''
                  return `⚔️ NPC Killed: ${npcName}${guildTag} (${dataPoint.npcType})`
                }
                
                if (dataPoint.eventType === 'resurrection') {
                  if (dataPoint.isBaseRes) {
                    return `🏠 Base Res: ${dataPoint.name}`
                  } else {
                    const skillInfo = dataPoint.skillName ? dataPoint.skillName : (dataPoint.skillId ? `Skill ${dataPoint.skillId}` : '')
                    return `✨ ${dataPoint.resurrector || 'Unknown'} resurrected ${dataPoint.name}${skillInfo ? ' - ' + skillInfo : ''}`
                  }
                }
                
                if (dataPoint.eventType === 'morale_boost') {
                  const guildTag = dataPoint.guildTag ? `${dataPoint.guildTag} ` : ''
                  return `🏁 ${guildTag}Morale Boost`
                }
                
                if (dataPoint.eventType === 'tower_capture') {
                  const guildTag = dataPoint.guildTag ? `${dataPoint.guildTag} ` : ''
                  return `🚩 ${guildTag}Flag Captured`
                }
                
                if (dataPoint.eventType === 'shrine_capture') {
                  const guildTag = dataPoint.guildTag ? `${dataPoint.guildTag} ` : ''
                  return `🗼 ${guildTag}Shrine Captured`
                }
                
                // Regular health/morale percentage
                const value = context.parsed.y.toFixed(2)
                return `${label}: ${value}%`
              }
            }
          },
          zoom: {
            limits: {
              x: {min: 'original', max: 'original'},
              y: this.currentMode === 'health' 
                ? {min: 0, max: 100} 
                : this.currentMode === 'timeline'
                ? {min: 0, max: 50}
                : {min: 'original', max: 'original'}
            },
            zoom: {
              wheel: {
                enabled: true,
                speed: 0.1
              },
              pinch: {
                enabled: true
              },
              mode: 'x'
            },
            pan: {
              enabled: true,
              mode: 'x',
              modifierKey: null
            }
          }
        },
        scales: {
          x: {
            type: 'linear',
            title: {
              display: true,
              text: 'Time (minutes)',
              color: '#fff',
              font: {
                size: 14
              }
            },
            ticks: {
              color: '#ccc',
              callback: function(value) {
                const minutes = (value / 60000).toFixed(1)
                return minutes
              }
            },
            grid: {
              color: 'rgba(255, 255, 255, 0.1)'
            }
          },
          y: yAxisConfig
        }
      }
    })
  }
}