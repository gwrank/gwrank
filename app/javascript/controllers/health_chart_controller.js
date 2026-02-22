import { Controller } from "@hotwired/stimulus"
import { Chart, LineController, LineElement, PointElement, LinearScale, Title, Tooltip, Legend, TimeScale, Filler, ScatterController } from "chart.js"
import zoomPlugin from "chartjs-plugin-zoom"

// Register Chart.js components
Chart.register(LineController, LineElement, PointElement, LinearScale, Title, Tooltip, Legend, TimeScale, Filler, ScatterController, zoomPlugin)

export default class extends Controller {
  static values = {
    data: Object
  }
  
  static targets = ["resetButton", "toggleButton"]

  connect() {
    this.currentMode = 'health' // 'health' or 'morale'
    this.createChart()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
  
  resetZoom(event) {
    event.preventDefault()
    if (this.chart) {
      this.chart.resetZoom()
    }
  }
  
  toggleMode(event) {
    event.preventDefault()
    this.currentMode = this.currentMode === 'health' ? 'morale' : 'health'
    
    // Update button text
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.textContent = this.currentMode === 'health' ? 'Show Morale' : 'Show Health'
    }
    
    // Recreate chart with new mode
    if (this.chart) {
      this.chart.destroy()
    }
    this.createChart()
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
        tension: 0.4,
        order: 1
      })
      
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
        tension: 0.4,
        order: 1
      })
    } else {
      // Morale datasets
      if (healthData.morale_data) {
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
          tension: 0.4,
          order: 1
        })
        
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
          tension: 0.4,
          order: 1
        })
      }
    }
    
    // Add death events (always shown)
    if (healthData.death_events && healthData.death_events.length > 0) {
      const team1Deaths = healthData.death_events.filter(e => e.party_id === 1)
      const team2Deaths = healthData.death_events.filter(e => e.party_id === 2)
      
      if (team1Deaths.length > 0) {
        datasets.push({
          label: `Deaths (${healthData.team1.tag || 'Team 1'})`,
          data: team1Deaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: this.currentMode === 'health' ? 5 : -20, 
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
          pointStyle: 'rectRot',
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2Deaths.length > 0) {
        datasets.push({
          label: `Deaths (${healthData.team2.tag || 'Team 2'})`,
          data: team2Deaths.map(e => ({ 
            x: e.timestamp_ms, 
            y: this.currentMode === 'health' ? 5 : -20, 
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
          pointStyle: 'rectRot',
          order: 0,
          hitRadius: 15
        })
      }
    }
    
    // Add resurrection events
    if (healthData.resurrection_events && healthData.resurrection_events.length > 0) {
      const team1Res = healthData.resurrection_events.filter(e => e.party_id === 1)
      const team2Res = healthData.resurrection_events.filter(e => e.party_id === 2)
      
      if (team1Res.length > 0) {
        datasets.push({
          label: `Resurrections (${healthData.team1.tag || 'Team 1'})`,
          data: team1Res.map(e => ({ 
            x: e.timestamp_ms, 
            y: this.currentMode === 'health' ? 10 : -15,
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
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'triangle',
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2Res.length > 0) {
        datasets.push({
          label: `Resurrections (${healthData.team2.tag || 'Team 2'})`,
          data: team2Res.map(e => ({ 
            x: e.timestamp_ms, 
            y: this.currentMode === 'health' ? 10 : -15,
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
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'triangle',
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
            y: this.currentMode === 'health' ? 15 : -10,
            eventType: 'morale_boost'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(234, 179, 8, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'star',
          order: 0,
          hitRadius: 15
        })
      }
      
      if (team2Boosts.length > 0) {
        datasets.push({
          label: `Morale Boosts (${healthData.team2.tag || 'Team 2'})`,
          data: team2Boosts.map(e => ({ 
            x: e.timestamp_ms, 
            y: this.currentMode === 'health' ? 15 : -10,
            eventType: 'morale_boost'
          })),
          type: 'scatter',
          backgroundColor: 'rgba(234, 179, 8, 1)',
          borderColor: '#fff',
          borderWidth: 2,
          pointRadius: 8,
          pointHoverRadius: 12,
          pointStyle: 'star',
          order: 0,
          hitRadius: 15
        })
      }
    }

    const yAxisConfig = this.currentMode === 'health' 
      ? {
          min: 0,
          max: 100,
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
      : {
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
            text: this.currentMode === 'health' ? 'Team Health Over Time' : 'Team Morale (Death Penalty) Over Time',
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
                
                if (dataPoint.eventType === 'resurrection') {
                  if (dataPoint.isBaseRes) {
                    return `🏠 Base Res: ${dataPoint.name}`
                  } else {
                    const skillInfo = dataPoint.skillName ? dataPoint.skillName : (dataPoint.skillId ? `Skill ${dataPoint.skillId}` : '')
                    return `✨ ${dataPoint.resurrector || 'Unknown'} resurrected ${dataPoint.name}${skillInfo ? ' - ' + skillInfo : ''}`
                  }
                }
                
                if (dataPoint.eventType === 'morale_boost') {
                  return `🏁 Morale Boost`
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
              y: this.currentMode === 'health' ? {min: 0, max: 100} : {min: 'original', max: 'original'}
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