# app/controllers/documentation_controller.rb

class DocumentationController < ApplicationController
  before_action :set_documentation_data
  
  def player
    render :player
  end
  
  def at
    render :at
  end
  
  def mat
    @next_monthly_at = calculate_next_monthly_at
    render :mat
  end
  
  def scrim
    render :scrim
  end
  
  def build
    render :build
  end
  
  def teambuild
    render :teambuild
  end
  
  private
  
  def set_documentation_data
    @documentation_pages = {
      player: { name: 'Player Commands', path: player_doc_path },
      at: { name: 'Automated Tournament Commands', path: at_doc_path },
      mat: { name: 'Monthly AT Commands', path: mat_doc_path },
      scrim: { name: 'Scrim Commands', path: scrim_doc_path },
      build: { name: 'Build Commands', path: build_doc_path },
      teambuild: { name: 'Team Build Commands', path: teambuild_doc_path }
    }
  end
  
  def calculate_next_monthly_at
    # Find the next 3rd Saturday
    now = Time.now.utc
    current_year = now.year
    current_month = now.month
    
    # Try current month first
    third_saturday = find_nth_weekday(current_year, current_month, 6, 3)
    
    if now <= third_saturday
      return third_saturday
    end
    
    # Next month
    next_month = now + 1.month
    find_nth_weekday(next_month.year, next_month.month, 6, 3)
  end
  
  def find_nth_weekday(year, month, weekday, nth)
    first_day = Date.new(year, month, 1)
    first_weekday = first_day + ((weekday - first_day.wday + 7) % 7).days
    first_weekday + (nth - 1).weeks
  end
end
