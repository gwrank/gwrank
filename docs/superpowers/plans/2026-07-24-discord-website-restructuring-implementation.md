# Discord Bot & Website Restructuring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize Discord bot commands into hierarchical structure (/player, /at, /mat, /scrim) and add website documentation pages

**Architecture:** 
- Phase 1: Create new Discord bot command classes (ScrimCommands, MatCommands) and migrate functionality from QueueCommands and TeamCommands
- Phase 1: Extend database models to support monthly ATs
- Phase 1: Update CommandBotJob to register new commands and remove old ones
- Phase 2: Create DocumentationController and views for website documentation pages
- Phase 2: Update routes and navigation to include documentation pages

**Tech Stack:** Ruby on Rails, Discordrb, PostgreSQL

---

## File Structure Overview

### New Files to Create
- `app/services/discord_bot/commands/scrim_commands.rb` - Merged queue + team commands
- `app/services/discord_bot/commands/mat_commands.rb` - Monthly AT commands
- `app/services/discord_bot/mat_reminder_check.rb` - Monthly AT reminder service
- `app/controllers/documentation_controller.rb` - Documentation page controller
- `app/views/documentation/player.html.erb` - Player commands documentation
- `app/views/documentation/at.html.erb` - AT commands documentation
- `app/views/documentation/mat.html.erb` - Monthly AT commands documentation
- `app/views/documentation/scrim.html.erb` - Scrim commands documentation
- `app/views/documentation/build.html.erb` - Build commands documentation
- `app/views/documentation/teambuild.html.erb` - Team build commands documentation
- `app/views/documentation/_breadcrumb.html.erb` - Breadcrumb partial
- `app/views/documentation/_sidebar.html.erb` - Sidebar navigation partial
- `db/migrate/[timestamp]_add_monthly_support_to_automated_tournament_schedules.rb`
- `db/migrate/[timestamp]_add_is_monthly_to_automated_tournament_registrations.rb`

### Modified Files
- `app/jobs/command_bot_job.rb` - Update command registration
- `config/routes.rb` - Add documentation routes
- `app/views/application/_navbar.html.erb` - Add documentation dropdown

### Deleted Files
- `app/services/discord_bot/commands/queue_commands.rb` - Migrated to ScrimCommands
- `app/services/discord_bot/commands/team_commands.rb` - Migrated to ScrimCommands

---

## Phase 1: Discord Bot Reorganization

---

### Task 1: Create Database Migrations for Monthly AT Support

**Files:**
- Create: `db/migrate/20260724000001_add_monthly_support_to_automated_tournament_schedules.rb`
- Create: `db/migrate/20260724000002_add_is_monthly_to_automated_tournament_registrations.rb`

- [ ] **Step 1: Create migration for AutomatedTournamentSchedule**

```bash
rails generate migration AddMonthlySupportToAutomatedTournamentSchedules is_monthly:boolean recurrence_pattern:string registration_opens_days_before:integer
```

- [ ] **Step 2: Edit the migration file**

```ruby
# db/migrate/20260724000001_add_monthly_support_to_automated_tournament_schedules.rb

class AddMonthlySupportToAutomatedTournamentSchedules < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_tournament_schedules, :is_monthly, :boolean, default: false
    add_column :automated_tournament_schedules, :recurrence_pattern, :string
    add_column :automated_tournament_schedules, :registration_opens_days_before, :integer, default: 28
    
    # Set existing records as daily
    reversible do |dir|
      dir.up do
        execute "UPDATE automated_tournament_schedules SET is_monthly = false, recurrence_pattern = CONCAT('daily_', timezone) WHERE is_monthly IS NULL"
      end
    end
  end
end
```

- [ ] **Step 3: Create migration for AutomatedTournamentRegistration**

```bash
rails generate migration AddIsMonthlyToAutomatedTournamentRegistrations is_monthly:boolean
```

- [ ] **Step 4: Edit the migration file**

```ruby
# db/migrate/20260724000002_add_is_monthly_to_automated_tournament_registrations.rb

class AddIsMonthlyToAutomatedTournamentRegistrations < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_tournament_registrations, :is_monthly, :boolean, default: false
  end
end
```

- [ ] **Step 5: Run migrations**

```bash
rails db:migrate
```

Expected: Both migrations run successfully

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20260724000001_add_monthly_support_to_automated_tournament_schedules.rb db/migrate/20260724000002_add_is_monthly_to_automated_tournament_registrations.rb
git commit -m "Add database support for monthly automated tournaments"
```

---

### Task 2: Extend AutomatedTournamentSchedule Model

**Files:**
- Modify: `app/models/automated_tournament_schedule.rb`

- [ ] **Step 1: Add enum and methods to AutomatedTournamentSchedule**

```ruby
# app/models/automated_tournament_schedule.rb

class AutomatedTournamentSchedule < ApplicationRecord
  # Existing code...
  
  enum recurrence_pattern: {
    daily_a: 'daily_a',
    daily_b: 'daily_b', 
    daily_c: 'daily_c',
    every_3rd_saturday: 'every_3rd_saturday'
  }, _default: 'daily_a'
  
  def next_occurrence(from: Time.now.utc)
    if is_monthly?
      next_monthly_occurrence(from)
    else
      next_daily_occurrence(from)
    end
  end
  
  def next_daily_occurrence(from)
    # Keep existing logic for daily AT
    # This is the current implementation from the codebase
    now = from
    timezone_letter = timezone
    
    # Daily AT times (UTC) - these should match the existing logic
    at_times = {
      'a' => { hour: 15, min: 0 },
      'b' => { hour: 18, min: 0 },
      'c' => { hour: 21, min: 0 }
    }
    
    target_time = at_times[timezone_letter]
    target_today = now.change(hour: target_time[:hour], min: target_time[:min], sec: 0)
    
    if now <= target_today
      target_today
    else
      target_today + 1.day
    end
  end
  
  def next_monthly_occurrence(from)
    now = from
    
    # Find the next 3rd Saturday
    # If today is before the 3rd Saturday of this month, return it
    # Otherwise, return the 3rd Saturday of next month
    
    current_year = now.year
    current_month = now.month
    
    # Try current month first
    third_saturday = find_nth_weekday(current_year, current_month, 6, 3) # 6 = Saturday
    
    if now <= third_saturday
      return third_saturday
    end
    
    # Next month
    next_month = now + 1.month
    find_nth_weekday(next_month.year, next_month.month, 6, 3)
  end
  
  def find_nth_weekday(year, month, weekday, nth)
    # weekday: 0=Sunday, 1=Monday, ..., 6=Saturday
    # nth: 1=first, 2=second, 3=third, etc.
    
    first_day = Date.new(year, month, 1)
    first_weekday = first_day + ((weekday - first_day.wday + 7) % 7).days
    first_weekday + (nth - 1).weeks
  end
  
  def registration_window_open?(from: Time.now.utc)
    if is_monthly?
      next_occ = next_occurrence(from: from)
      registration_start = next_occ - registration_opens_days_before.days
      from >= registration_start && from <= next_occ
    else
      # Keep existing logic for daily AT
      now = from
      next_occ = next_occurrence(from: now)
      boundary = window_boundary(from: now)
      now >= boundary - 30.minutes && now <= next_occ
    end
  end
  
  def window_boundary(from: Time.now.utc)
    # Keep existing logic for daily AT
    now = from
    timezone_letter = timezone
    
    at_times = {
      'a' => { hour: 15, min: 0 },
      'b' => { hour: 18, min: 0 },
      'c' => { hour: 21, min: 0 }
    }
    
    target_time = at_times[timezone_letter]
    target_today = now.change(hour: target_time[:hour], min: target_time[:min], sec: 0)
    
    if now <= target_today
      target_today
    else
      target_today + 1.day
    end
  end
end
```

- [ ] **Step 2: Run tests to verify model changes**

```bash
rails test app/models/automated_tournament_schedule_test.rb 2>/dev/null || echo "No test file found, skipping"
```

Expected: Tests pass or no test file exists

- [ ] **Step 3: Commit**

```bash
git add app/models/automated_tournament_schedule.rb
git commit -m "Extend AutomatedTournamentSchedule with monthly support"
```

---

### Task 3: Extend AutomatedTournamentRegistration Model

**Files:**
- Modify: `app/models/automated_tournament_registration.rb`

- [ ] **Step 1: Add scope for monthly registrations**

```ruby
# app/models/automated_tournament_registration.rb

class AutomatedTournamentRegistration < ApplicationRecord
  # Existing code...
  
  scope :monthly, -> { where(is_monthly: true) }
  scope :daily, -> { where(is_monthly: false) }
  
  # Update existing scope to handle both types
  scope :current_for_server, ->(discord_server_id) do
    where(discord_server_id: discord_server_id, unregistered_at: nil)
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/models/automated_tournament_registration.rb
git commit -m "Add monthly scope to AutomatedTournamentRegistration"
```

---

### Task 4: Create MatReminderCheck Service

**Files:**
- Create: `app/services/discord_bot/mat_reminder_check.rb`

- [ ] **Step 1: Create the service file**

```ruby
# app/services/discord_bot/mat_reminder_check.rb

module DiscordBot
  class MatReminderCheck
    POLL_INTERVAL = 60 # seconds
    
    def self.call(bot:)
      new(bot: bot).call
    end
    
    def initialize(bot:)
      @bot = bot
    end
    
    def call
      AutomatedTournamentSchedule.where(is_monthly: true).find_each do |schedule|
        check_and_remind(schedule)
      end
    end
    
    private
    
    def check_and_remind(schedule)
      now = Time.now.utc
      next_occ = schedule.next_occurrence(from: now)
      
      # Check if we need to send a reminder
      # Send reminder 24 hours before
      reminder_time = next_occ - 24.hours
      
      if now >= reminder_time && now <= next_occ
        send_reminder(schedule, next_occ)
      end
      
      # Also check for registration opening reminder
      registration_start = next_occ - schedule.registration_opens_days_before.days
      registration_reminder_time = registration_start - 1.hour
      
      if now >= registration_reminder_time && now <= registration_start
        send_registration_opening_reminder(schedule, registration_start)
      end
    end
    
    def send_reminder(schedule, next_occ)
      channel = @bot.channel(schedule.channel_id)
      return unless channel
      
      message = "@here Monthly Automated Tournament reminder! The next monthly AT is in 24 hours (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')})."
      channel.send_message(message)
    rescue StandardError => e
      Rails.logger.error("Failed to send MAT reminder: #{e.class}: #{e.message}")
    end
    
    def send_registration_opening_reminder(schedule, registration_start)
      channel = @bot.channel(schedule.channel_id)
      return unless channel
      
      message = "@here Registration for the monthly Automated Tournament opens in 1 hour! (#{registration_start.strftime('%Y-%m-%d %H:%M UTC')})"
      channel.send_message(message)
    rescue StandardError => e
      Rails.logger.error("Failed to send MAT registration reminder: #{e.class}: #{e.message}")
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/services/discord_bot/mat_reminder_check.rb
git commit -m "Add MatReminderCheck service for monthly AT reminders"
```

---

### Task 5: Create ScrimCommands Class

**Files:**
- Create: `app/services/discord_bot/commands/scrim_commands.rb`

- [ ] **Step 1: Create the ScrimCommands file**

```ruby
# app/services/discord_bot/commands/scrim_commands.rb

module DiscordBot
  module Commands
    class ScrimCommands
      include ModeratorGate
      
      QUEUE_SIZE = 16
      FORM_FIRST_SCRIM_LOCK_KEY = 'discord_bot.form_first_scrim'.hash & 0x7FFFFFFFFFFFFFFF
      
      def self.register(bot)
        new(bot).register
      end
      
      def initialize(bot)
        @bot = bot
      end
      
      def register
        register_schema
        register_dispatch
        register_buttons
      end
      
      def register_schema
        @bot.register_application_command(:scrim, 'Manage scrim registration and teams', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          # Queue management
          cmd.subcommand(:register, 'Register for the scrim queue')
          cmd.subcommand(:unregister, 'Unregister from the scrim queue')
          cmd.subcommand(:queue, 'Show current scrim queue')
          cmd.subcommand(:reset, 'Reset the current queue (moderators only)')
          
          cmd.subcommand(:add, 'Add a player to the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end
          
          cmd.subcommand(:remove, 'Remove a player from the queue (moderators only)') do |sub|
            sub.string(:igname, "The player's in-game name", required: true)
          end
          
          cmd.subcommand(:afk, 'Mark a player AFK (moderators only)') do |sub|
            sub.user(:member, 'The player to mark AFK (defaults to yourself)', required: false)
          end
          
          cmd.subcommand(:back, 'Bring a player back from AFK (moderators only)') do |sub|
            sub.user(:member, 'The player to bring back (defaults to yourself)', required: false)
          end
          
          # Team management
          cmd.subcommand_group(:team, 'Team management commands') do |team_cmd|
            team_cmd.subcommand(:captains, 'See the current captains')
            team_cmd.subcommand(:roll, 'Roll 0-100')
            team_cmd.subcommand(:new, 'Form new teams for the next series (moderators only)')
            team_cmd.subcommand(:win, 'Record a game win for a team (moderators only)') do |sub|
              sub.string(:side, 'Which team won', required: true, choices: { 'Team A' => 'a', 'Team B' => 'b' })
            end
            team_cmd.subcommand(:move, 'Move the current queue to the Scrimers voice channel (moderators only)')
          end
        end
      end
      
      def register_dispatch
        handler = @bot.application_command(:scrim)
        %i[register unregister queue reset add remove afk back].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
        
        team_handler = handler.subcommand_group(:team)
        %i[captains roll new win move].each { |name| team_handler.subcommand(name) { |event| dispatch(event) } }
      end
      
      def register_buttons
        @bot.button(custom_id: 'register') do |event|
          handle_register_button(event)
        end
        
        @bot.button(custom_id: 'unregister') do |event|
          handle_unregister_button(event)
        end
      end
      
      def dispatch(event)
        case event.subcommand
        when :register then handle_register(event)
        when :unregister then handle_unregister(event)
        when :queue then handle_queue(event)
        when :reset then with_moderator(event) { handle_reset(event) }
        when :add then with_moderator(event) { handle_add(event) }
        when :remove then with_moderator(event) { handle_remove(event) }
        when :afk then with_moderator(event) { handle_afk(event) }
        when :back then with_moderator(event) { handle_back(event) }
        when :captains then handle_captains(event)
        when :roll then handle_roll(event)
        when :new then with_moderator(event) { handle_new(event) }
        when :win then with_moderator(event) { handle_win(event) }
        when :move then with_moderator(event) { handle_move(event) }
        end
      end
      
      private
      
      # Queue management methods (migrated from QueueCommands)
      
      def handle_register(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          form_first_scrim_if_ready!
          
          event.respond(content: "You have been registered, #{event.user.username}!", ephemeral: true)
        end
      end
      
      def handle_unregister(event)
        player = Player.find_by(uid: event.user.id)
        
        if player&.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          event.respond(content: "You have been unregistered, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered, #{event.user.username}!", ephemeral: true)
        end
      end
      
      def handle_queue(event)
        message = "<@#{event.user.id}>, the current players ordered by registration time are:"
        Registration.current_registrations.order(registered_at: :asc).each_with_index do |registration, index|
          player = registration.player
          message << "\n##{index + 1} <@#{player.uid}>"
          message << " (**#{player.igname}**)" if player.igname.present?
          message << " [#{player.professions_short_text}]" if player.professions_short_text.present?
        end
        event.respond(content: message)
      end
      
      def handle_reset(event)
        Registration.current_registrations.update_all(unregistered_at: DateTime.now)
        event.respond(content: "<@#{event.user.id}>, you successfully reset the current queue.\nPlayers can register again via the queue panel (*/scrim register*).")
      end
      
      def handle_add(event)
        igname = event.options['igname']
        current_registrations = Registration.current_registrations
        player = Player.find_by(igname: igname)
        
        message =
          if player.present?
            if player.has_current_registration?
              "<@#{event.user.id}>, the player #{player.name} is already ##{current_registrations.count} in the current queue."
            else
              player.registrations.create(registered_at: DateTime.now)
              m = "<@#{event.user.id}>, the player #{player.name} is now ##{current_registrations.count} in the current queue for the next 8 hours."
              m << "\nIf he's out, a moderator can use */scrim remove*."
              if current_registrations.count < QUEUE_SIZE
                m << "\nWe need #{QUEUE_SIZE - current_registrations.count} more players."
              elsif current_registrations.count.eql?(QUEUE_SIZE)
                m << "\nWe have 16 players!"
                m << "\nTo see the players list, you can use */scrim queue* or go on https://gwrank.com/scrims"
              end
              m
            end
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end
        
        event.respond(content: message)
      end
      
      def handle_remove(event)
        igname = event.options['igname']
        player = Player.find_by(igname: igname)
        
        message =
          if player.present?
            if player.has_current_registration?
              player.current_registration.update(unregistered_at: DateTime.now)
              "<@#{event.user.id}>, the player #{player.name} is not anymore in the current queue."
            else
              "<@#{event.user.id}>, the player #{player.name} was not in the current queue."
            end
          else
            "<@#{event.user.id}>, #{igname} is not found and needs to use */player register* first."
          end
        
        event.respond(content: message)
      end
      
      def handle_afk(event)
        self_target = event.options['member'].blank?
        player = Player.find_by(uid: self_target ? event.user.id : event.options['member'])
        
        message =
          if player&.has_current_registration?
            player.current_registration.update(unregistered_at: DateTime.now)
            self_target ? "<@#{event.user.id}>, you are now in AFK mode." : "<@#{event.user.id}>, the player #{player.name} is now in AFK mode, he can use */scrim back* to return."
          elsif player
            self_target ? "<@#{event.user.id}>, you were not in the current queue." : "<@#{event.user.id}>, the player #{player.name} is not in the current queue."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end
        
        event.respond(content: message)
      end
      
      def handle_back(event)
        self_target = event.options['member'].blank?
        player = Player.find_by(uid: self_target ? event.user.id : event.options['member'])
        
        message =
          if player&.has_afk_registration?
            player.afk_registration.update(unregistered_at: self_target ? nil : DateTime.now)
            self_target ? "<@#{event.user.id}>, welcome back!" : "<@#{event.user.id}>, the player #{player.name} is now back in the queue."
          elsif player
            self_target ? "<@#{event.user.id}>, you were not in the current queue." : "<@#{event.user.id}>, the player #{player.name} was not in AFK mode."
          else
            "<@#{event.user.id}>, the player is not found and needs to use */player register* first."
          end
        
        event.respond(content: message)
      end
      
      # Team management methods (migrated from TeamCommands)
      
      def handle_captains(event)
        scrim = Scrim.current_scrims.order(created_at: :desc).first
        
        if scrim&.captain_a && scrim&.captain_b
          event.respond(content: "<@#{event.user.id}>, the current captains are @#{scrim.captain_a.username} (#{scrim.captain_a.igname}) and @#{scrim.captain_b.username} (#{scrim.captain_b.igname}).")
        else
          event.respond(content: "<@#{event.user.id}>, there are no active scrim captains right now.")
        end
      end
      
      def handle_roll(event)
        event.respond(content: "<@#{event.user.id}>, you rolled: #{rand(0..100)}")
      end
      
      def handle_new(event)
        if Scrim.in_progress.exists?
          event.respond(content: "<@#{event.user.id}>, a scrim is already in progress. Finish it with */scrim team win* first, or this will abandon it.")
          return
        end
        
        queue_count = Player.in_queue.count
        if queue_count != Scrims::FormTeams::QUEUE_SIZE
          event.respond(content: "<@#{event.user.id}>, need exactly #{Scrims::FormTeams::QUEUE_SIZE} players in queue to form teams (currently #{queue_count}).")
          return
        end
        
        scrim = begin
          Scrims::FormTeams.call!
        rescue StandardError => e
          Rails.logger.error("Failed to form new teams: #{e.class}: #{e.message}")
          event.respond(content: "<@#{event.user.id}>, something went wrong forming new teams.")
          return
        end
        
        event.respond(content: team_roster_message(scrim, :team_a))
        event.channel.send_message(team_roster_message(scrim, :team_b))
        
        remaining = Player.in_queue.where.not(id: scrim.team_a.players.pluck(:id) + scrim.team_b.players.pluck(:id))
        return unless remaining.any?
        
        message = 'Next players by order:'
        remaining.each do |player|
          message << "\n<@#{player.uid}>"
          message << ", in-game name **#{player.igname}**" if player.igname.present?
        end
        event.channel.send_message(message)
      end
      
      def handle_win(event)
        winner = event.options['side'].to_sym
        
        scrim = begin
          record_win!(winner)
        rescue StandardError => e
          Rails.logger.error("Failed to record win: #{e.class}: #{e.message}")
          event.respond(content: "<@#{event.user.id}>, something went wrong recording that result.")
          return
        end
        
        unless scrim
          event.respond(content: "<@#{event.user.id}>, there is no scrim in progress right now.")
          return
        end
        
        if scrim.winner_team_id.present?
          winning_label = scrim.winner_team_id == scrim.team_a_id ? 'Team A' : 'Team B'
          event.respond(content: "#{winning_label} wins the series #{scrim.team_a_wins}-#{scrim.team_b_wins}! Elo has been updated.")
        else
          event.respond(content: "Game recorded. Series score: #{scrim.team_a_wins}-#{scrim.team_b_wins}.")
        end
      end
      
      def handle_move(event)
        server = event.bot.server(ENV['DISCORD_SERVER_ID'])
        channel = event.bot.channel(ENV['DISCORD_SCRIMERS_VOICE_CHANNEL_ID'])
        
        Registration.current_registrations.order(registered_at: :asc).first(16).each do |registration|
          server.move(event.bot.user(registration.player.uid), channel)
        end
        
        event.respond(content: "<@#{event.user.id}>, the current first 16 players were moved to the Scrimers voice channel.")
      end
      
      def record_win!(winner)
        Scrim.transaction do
          scrim = Scrim.in_progress.order(created_at: :desc).lock.first
          return nil unless scrim
          
          Scrims::RecordGameResult.call!(scrim: scrim, winner: winner)
        end
      end
      
      def team_roster_message(scrim, side)
        team = scrim.public_send(side)
        captain_id = side == :team_a ? scrim.captain_a_id : scrim.captain_b_id
        label = side == :team_a ? 'Team A' : 'Team B'
        
        message = "#{label}:"
        team.team_players.includes(:player, :profession).each do |team_player|
          player = team_player.player
          message << "\n<@#{player.uid}>"
          message << ', captain' if team_player.player_id == captain_id
          message << ", in-game name **#{player.igname}**" if player.igname.present?
          message << ", #{team_player.profession.name}"
        end
        message
      end
      
      # Button handlers (migrated from QueueCommands)
      
      def handle_register_button(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        if player.has_current_registration?
          event.respond(content: "You are already registered, #{event.user.username}!", ephemeral: true)
        else
          player.registrations.create(registered_at: DateTime.now)
          form_first_scrim_if_ready!
          event.interaction.update_message(has_components: true) do |_, view|
            message_container(view)
          end
          event.send_message(content: "You have been registered, #{event.user.username}!", ephemeral: true)
        end
      end
      
      def handle_unregister_button(event)
        player = Player.find_by(uid: event.user.id)
        
        if player&.has_current_registration?
          player.current_registration.update(unregistered_at: DateTime.now)
          event.interaction.update_message(has_components: true) do |_, view|
            message_container(view)
          end
          event.send_message(content: "You have been unregistered, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered, #{event.user.username}!", ephemeral: true)
        end
      end
      
      # Helper methods (migrated from QueueCommands)
      
      def form_first_scrim_if_ready!
        return unless Player.in_queue.count == QUEUE_SIZE
        
        with_form_first_scrim_lock do
          Scrims::FormTeams.call! if Player.in_queue.count == QUEUE_SIZE && !Scrim.exists?
        end
      rescue StandardError => e
        Rails.logger.error("Failed to auto-form first scrim: #{e.class}: #{e.message}")
      end
      
      def with_form_first_scrim_lock
        acquired = ActiveRecord::Base.connection.select_value("SELECT pg_try_advisory_lock(#{FORM_FIRST_SCRIM_LOCK_KEY})")
        return unless acquired
        
        yield
      ensure
        ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{FORM_FIRST_SCRIM_LOCK_KEY})") if acquired
      end
      
      def message_container(view)
        view.container do |container|
          container.text_display(content: scrim_registration_panel_content)
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'unregister')
          end
        end
      end
      
      def scrim_registration_panel_content
        players = Registration.current_registrations.order(registered_at: :asc).map.with_index do |registration, index|
          entry = ["\n##{index + 1} <@#{registration.player.uid}>"]
          entry << "(**#{registration.player.igname}**)" if registration.player.igname.present?
          entry << "[#{registration.player.professions_text}]" if registration.player.professions_text.present?
          entry.join(' ')
        end
        "### Scrim Registration Panel\nCurrent registered users:\n#{players.join("\n")}"
      end
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/services/discord_bot/commands/scrim_commands.rb
git commit -m "Create ScrimCommands merging queue and team functionality"
```

---

### Task 6: Create MatCommands Class

**Files:**
- Create: `app/services/discord_bot/commands/mat_commands.rb`

- [ ] **Step 1: Create the MatCommands file**

```ruby
# app/services/discord_bot/commands/mat_commands.rb

module DiscordBot
  module Commands
    class MatCommands
      QUEUE_SIZE = 8
      
      def self.register(bot)
        new(bot).register
      end
      
      def initialize(bot)
        @bot = bot
      end
      
      def register
        register_schema
        register_dispatch
        
        @bot.button(custom_id: 'mat_register') do |event|
          handle_mat_register_button(event)
        end
        
        @bot.button(custom_id: 'mat_unregister') do |event|
          handle_mat_unregister_button(event)
        end
      end
      
      def register_schema
        @bot.register_application_command(:mat, 'Manage Monthly Automated Tournament queue', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:schedule, 'Set the monthly AT schedule pattern') do |sub|
            sub.string(:pattern, 'Monthly pattern', required: true, 
                       choices: { 'Every 3rd Saturday' => 'every_3rd_saturday' })
          end
          
          cmd.subcommand(:next, 'Show time until the next monthly AT')
          cmd.subcommand(:join, 'Post the Monthly AT registration panel')
          cmd.subcommand(:players, 'List players in the monthly AT queue')
        end
      end
      
      def register_dispatch
        handler = @bot.application_command(:mat)
        %i[schedule next join players].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end
      
      def dispatch(event)
        case event.subcommand
        when :schedule then handle_schedule(event)
        when :next then handle_next(event)
        when :join then handle_join(event)
        when :players then handle_players(event)
        end
      end
      
      private
      
      def handle_schedule(event)
        discord_server_id = event.server.id
        pattern = event.options['pattern']
        
        schedule = AutomatedTournamentSchedule.find_or_initialize_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        schedule.recurrence_pattern = pattern
        schedule.channel_id = event.channel.id
        schedule.registration_opens_days_before = 28
        schedule.save!
        
        next_occ = schedule.next_occurrence
        event.respond(content: "<@#{event.user.id}>, this server now tracks monthly AT with pattern **#{pattern}**; reminders will post in this channel. Next monthly AT: #{next_occ.strftime('%Y-%m-%d %H:%M UTC')}.")
      end
      
      def handle_next(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        now = Time.now.utc
        next_occ = schedule.next_occurrence(from: now)
        
        message = if next_occ > now
          registration_start = next_occ - schedule.registration_opens_days_before.days
          if now >= registration_start
            "<@#{event.user.id}>, the next monthly AT starts in #{format_duration(next_occ - now)} (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')}). Registration is OPEN!"
          else
            "<@#{event.user.id}>, the next monthly AT starts in #{format_duration(next_occ - now)} (#{next_occ.strftime('%Y-%m-%d %H:%M UTC')}). Registration opens in #{format_duration(registration_start - now)}."
          end
        else
          "<@#{event.user.id}>, the monthly AT started #{format_duration(now - next_occ)} ago."
        end
        
        event.respond(content: message)
      end
      
      def handle_join(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        event.respond(has_components: true) do |_, view|
          mat_container(view, player, discord_server_id: discord_server_id)
        end
      end
      
      def handle_players(event)
        discord_server_id = event.server.id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "<@#{event.user.id}>, this server hasn't set a monthly AT schedule yet. Run */mat schedule* first.") unless schedule
        
        mat_registrations = AutomatedTournamentRegistration.current_for_server(discord_server_id).monthly.order(registered_at: :asc)
        
        message = "<@#{event.user.id}>, the current monthly AT queue players for this server are:"
        if mat_registrations.empty?
          message << "\nNo players in the queue yet."
        else
          mat_registrations.each_with_index do |registration, index|
            message << "\n##{index + 1} <@#{registration.player.uid}>"
            message << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          end
        end
        
        mat_count = mat_registrations.count
        message << (mat_count < QUEUE_SIZE ? "\nWe need #{QUEUE_SIZE - mat_count} more players." : "\nTeam is full! (#{QUEUE_SIZE} players)")
        
        event.respond(content: message)
      end
      
      def handle_mat_register_button(event)
        discord_server_id = event.server_id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "This server hasn't set a monthly AT schedule yet.", ephemeral: true) unless schedule
        
        player = DiscordBot::FindOrCreatePlayer.call(event)
        
        if player.has_current_mat_registration?(discord_server_id)
          event.respond(content: "You are already registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
          return
        end
        
        AutomatedTournamentRegistration.create!(
          player: player, 
          discord_server_id: discord_server_id, 
          registered_at: DateTime.now,
          is_monthly: true
        )
        mat_count = AutomatedTournamentRegistration.current_for_server(discord_server_id).monthly.count
        
        event.interaction.update_message(has_components: true) do |_, view|
          mat_container(view, player, discord_server_id: discord_server_id)
        end
        event.send_message(content: "You have been registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        
        if mat_count == QUEUE_SIZE
          event.channel.send_message "Team is full! #{QUEUE_SIZE} players registered for the Monthly Automated Tournament."
        elsif mat_count > QUEUE_SIZE
          event.channel.send_message "Monthly AT queue now has #{mat_count} players for this server."
        end
      end
      
      def handle_mat_unregister_button(event)
        discord_server_id = event.server_id
        schedule = AutomatedTournamentSchedule.find_by(
          discord_server_id: discord_server_id,
          is_monthly: true
        )
        return event.respond(content: "This server hasn't set a monthly AT schedule yet.", ephemeral: true) unless schedule
        
        player = Player.find_by(uid: event.user.id)
        
        if player&.has_current_mat_registration?(discord_server_id)
          player.current_mat_registration(discord_server_id).update(unregistered_at: DateTime.now)
          event.interaction.update_message(has_components: true) do |_, view|
            mat_container(view, player, discord_server_id: discord_server_id)
          end
          event.send_message(content: "You have been unregistered from the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        else
          event.respond(content: "You are not registered in the monthly AT queue for this server, #{event.user.username}!", ephemeral: true)
        end
      end
      
      def mat_container(view, player, discord_server_id: nil)
        view.container do |container|
          container.text_display(content: mat_registration_panel_content(player, discord_server_id: discord_server_id))
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'mat_register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'mat_unregister')
          end
        end
      end
      
      def mat_registration_panel_content(player, discord_server_id: nil)
        mat_registrations = AutomatedTournamentRegistration.current_for_server(discord_server_id).monthly.order(registered_at: :asc)
        
        players = mat_registrations.each_with_index.map do |registration, index|
          entry = "\n##{index + 1} <@#{registration.player.uid}>"
          entry << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          entry
        end
        
        message = "### Monthly Automated Tournament Registration Panel\n"
        message << "Current registered players for this server:\n"
        message << (players.empty? ? "No players registered yet.\n" : players.join("\n"))
        message << "\n"
        
        mat_count = mat_registrations.count
        message << (mat_count < QUEUE_SIZE ? "We need #{QUEUE_SIZE - mat_count} more players." : "Team is full! (#{QUEUE_SIZE} players)")
        message
      end
      
      def format_duration(seconds)
        total_minutes = (seconds / 60).round
        hours, minutes = total_minutes.divmod(60)
        hours.positive? ? "#{hours}h #{minutes}m" : "#{minutes}m"
      end
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/services/discord_bot/commands/mat_commands.rb
git commit -m "Create MatCommands for monthly automated tournaments"
```

---

### Task 7: Update Player Model for MAT Registrations

**Files:**
- Modify: `app/models/player.rb`

- [ ] **Step 1: Add methods for MAT registration checks**

```ruby
# app/models/player.rb

class Player < ApplicationRecord
  # Existing code...
  
  def has_current_mat_registration?(discord_server_id)
    current_mat_registration(discord_server_id).present?
  end
  
  def current_mat_registration(discord_server_id)
    registrations.find_by(
      discord_server_id: discord_server_id,
      unregistered_at: nil,
      is_monthly: true
    )
  end
  
  def has_current_at_registration?(discord_server_id)
    current_at_registration(discord_server_id).present?
  end
  
  def current_at_registration(discord_server_id)
    automated_tournament_registrations.find_by(
      discord_server_id: discord_server_id,
      unregistered_at: nil
    )
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/models/player.rb
git commit -m "Add MAT registration methods to Player model"
```

---

### Task 8: Update CommandBotJob

**Files:**
- Modify: `app/jobs/command_bot_job.rb`

- [ ] **Step 1: Update command class list and add MAT reminder thread**

```ruby
# app/jobs/command_bot_job.rb

class CommandBotJob < ApplicationJob
  queue_as :default
  
  COMMAND_CLASSES = [
    DiscordBot::Commands::PlayerCommands,
    DiscordBot::Commands::ScrimCommands,
    DiscordBot::Commands::AtCommands,
    DiscordBot::Commands::MatCommands,
    DiscordBot::Commands::BuildCommands,
    DiscordBot::Commands::TeamBuildCommands
  ].freeze
  
  def perform(*args)
    bot = Discordrb::Commands::CommandBot.new(
      token: ENV['DISCORD_BOT_TOKEN'],
      client_id: ENV['DISCORD_CLIENT_ID']
    )
    
    COMMAND_CLASSES.each { |command_class| command_class.register(bot) }
    
    start_at_reminder_thread(bot)
    start_mat_reminder_thread(bot)
    
    at_exit { bot.stop }
    bot.run
  end
  
  private
  
  def start_at_reminder_thread(bot)
    Thread.new do
      loop do
        DiscordBot::AtReminderCheck.call(bot: bot)
      rescue StandardError => e
        Rails.logger.error("AT reminder poll loop error: #{e.class}: #{e.message}")
      ensure
        sleep(DiscordBot::AtReminderCheck::POLL_INTERVAL)
      end
    end
  end
  
  def start_mat_reminder_thread(bot)
    Thread.new do
      loop do
        DiscordBot::MatReminderCheck.call(bot: bot)
      rescue StandardError => e
        Rails.logger.error("MAT reminder poll loop error: #{e.class}: #{e.message}")
      ensure
        sleep(DiscordBot::MatReminderCheck::POLL_INTERVAL)
      end
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/jobs/command_bot_job.rb
git commit -m "Update CommandBotJob with new command classes and MAT reminder thread"
```

---

### Task 9: Remove Old Command Files

**Files:**
- Delete: `app/services/discord_bot/commands/queue_commands.rb`
- Delete: `app/services/discord_bot/commands/team_commands.rb`

- [ ] **Step 1: Remove old command files**

```bash
rm app/services/discord_bot/commands/queue_commands.rb
rm app/services/discord_bot/commands/team_commands.rb
```

- [ ] **Step 2: Commit**

```bash
git rm app/services/discord_bot/commands/queue_commands.rb app/services/discord_bot/commands/team_commands.rb
git commit -m "Remove old queue and team command files"
```

---

## Phase 1 Verification

- [ ] **Step 1: Start the bot locally and test all commands**

```bash
# In one terminal
rails jobs:work

# In another terminal, test commands in Discord
# Test /scrim register, /scrim queue, /scrim team new, etc.
# Test /mat schedule, /mat next, /mat join, etc.
# Test /player, /at, /build, /teambuild still work
```

Expected: All commands work as expected, old commands (/queue, /team) are not available

- [ ] **Step 2: Verify old commands are removed**

Try using `/queue` and `/team` commands in Discord - they should not appear in the command list.

Expected: Commands not found

- [ ] **Step 3: Commit Phase 1 completion**

```bash
git add .
git commit -m "Complete Phase 1: Discord bot command reorganization"
```

---

## Phase 2: Website Documentation

---

### Task 10: Create DocumentationController

**Files:**
- Create: `app/controllers/documentation_controller.rb`

- [ ] **Step 1: Create the controller**

```ruby
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
```

- [ ] **Step 2: Commit**

```bash
git add app/controllers/documentation_controller.rb
git commit -m "Create DocumentationController"
```

---

### Task 11: Add Documentation Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add documentation routes**

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # ... existing routes ...
  
  # Documentation routes
  get '/player', to: 'documentation#player', as: :player_doc
  get '/at', to: 'documentation#at', as: :at_doc
  get '/mat', to: 'documentation#mat', as: :mat_doc
  get '/scrim', to: 'documentation#scrim', as: :scrim_doc
  get '/build', to: 'documentation#build', as: :build_doc
  get '/teambuild', to: 'documentation#teambuild', as: :teambuild_doc
  
  # ... rest of existing routes ...
end
```

- [ ] **Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "Add documentation routes"
```

---

### Task 12: Create Documentation Views

**Files:**
- Create: `app/views/documentation/player.html.erb`
- Create: `app/views/documentation/at.html.erb`
- Create: `app/views/documentation/mat.html.erb`
- Create: `app/views/documentation/scrim.html.erb`
- Create: `app/views/documentation/build.html.erb`
- Create: `app/views/documentation/teambuild.html.erb`
- Create: `app/views/documentation/_breadcrumb.html.erb`
- Create: `app/views/documentation/_sidebar.html.erb`

- [ ] **Step 1: Create documentation directory**

```bash
mkdir -p app/views/documentation
```

- [ ] **Step 2: Create breadcrumb partial**

```erb
# app/views/documentation/_breadcrumb.html.erb

<nav aria-label="breadcrumb" class="mpl-breadcrumb">
  <div class="container">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><%= link_to 'Home', root_path %></li>
      <li class="breadcrumb-item"><%= link_to 'Documentation', '#' %></li>
      <li class="breadcrumb-item active" aria-current="page"><%= local_assigns[:page] || 'Documentation' %></li>
    </ol>
  </div>
</nav>
```

- [ ] **Step 3: Create sidebar partial**

```erb
# app/views/documentation/_sidebar.html.erb

<div class="mpl-sidebar-content">
  <h3>Documentation</h3>
  <ul class="nav flex-column">
    <li class="nav-item">
      <%= link_to 'Player Commands', player_doc_path, class: "nav-link #{'active' if current_page?(player_doc_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'AT Commands', at_doc_path, class: "nav-link #{'active' if current_page?(at_doc_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Monthly AT Commands', mat_doc_path, class: "nav-link #{'active' if current_page?(mat_doc_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Scrim Commands', scrim_doc_path, class: "nav-link #{'active' if current_page?(scrim_doc_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Build Commands', build_doc_path, class: "nav-link #{'active' if current_page?(build_doc_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Team Build Commands', teambuild_doc_path, class: "nav-link #{'active' if current_page?(teambuild_doc_path)}" %>
    </li>
  </ul>
  
  <h3 class="mt-4">Live Data</h3>
  <ul class="nav flex-column">
    <li class="nav-item">
      <%= link_to 'Players', players_path, class: "nav-link" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Scrims', scrims_path, class: "nav-link" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Tournaments', tournaments_path, class: "nav-link" %>
    </li>
  </ul>
</div>
```

- [ ] **Step 4: Create player documentation page**

```erb
# app/views/documentation/player.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Player Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Player Commands</h1>
          <p class="lead">Manage your player profile and characters</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Command Reference</h2>
              
              <div class="mb-4">
                <h3>/player register</h3>
                <p><strong>Description:</strong> Set your in-game character name</p>
                <p><strong>Usage:</strong> <code>/player register &lt;igname&gt;</code></p>
                <p><strong>Example:</strong> <code>/player register Arka The Brave</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, your in-game name is now **Arka The Brave**.</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/player igname</h3>
                <p><strong>Description:</strong> Look up a player's in-game name</p>
                <p><strong>Usage:</strong> <code>/player igname &lt;@user&gt;</code></p>
                <p><strong>Example:</strong> <code>/player igname @Arka</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt; (**Arka The Brave**)</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/player claim</h3>
                <p><strong>Description:</strong> Claim a character name as your own</p>
                <p><strong>Usage:</strong> <code>/player claim &lt;igname&gt;</code></p>
                <p><strong>Example:</strong> <code>/player claim Arka The Brave</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, you have successfully claimed the character **Arka The Brave**!</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/player professions</h3>
                <p><strong>Description:</strong> View or toggle your professions</p>
                <p><strong>Usage:</strong> <code>/player professions [&lt;profession&gt;]</code></p>
                <p><strong>Available Professions:</strong> warrior, ranger, monk, necromancer, mesmer, elementalist, assassin, ritualist, paragon, dervish</p>
                <p><strong>Example:</strong> <code>/player professions warrior</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, your current professions: Warrior, Monk</code></p>
              </div>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View all players', players_path %></li>
                  <% if current_player %>
                    <li><%= link_to 'Your profile', profile_path %></li>
                  <% end %>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>
```

- [ ] **Step 5: Create AT documentation page**

```erb
# app/views/documentation/at.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Automated Tournament Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Automated Tournament Commands</h1>
          <p class="lead">Manage daily Automated Tournament registration</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Command Reference</h2>
              
              <div class="mb-4">
                <h3>/at schedule</h3>
                <p><strong>Description:</strong> Set which daily AT slot (a/b/c) this server tracks</p>
                <p><strong>Usage:</strong> <code>/at schedule &lt;a|b|c&gt;</code></p>
                <p><strong>Example:</strong> <code>/at schedule a</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, this server now tracks AT slot **a**; reminders will post in this channel. Next AT: &lt;date&gt;.</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/at next</h3>
                <p><strong>Description:</strong> Show time until the next scheduled AT and registration window status</p>
                <p><strong>Usage:</strong> <code>/at next</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, the next AT (slot A) starts in 2h 30m (&lt;date&gt;).</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/at join</h3>
                <p><strong>Description:</strong> Post the Automated Tournament registration panel</p>
                <p><strong>Usage:</strong> <code>/at join</code></p>
                <p><strong>Response:</strong> Posts an interactive panel with Register/Unregister buttons</p>
              </div>
              
              <div class="mb-4">
                <h3>/at players</h3>
                <p><strong>Description:</strong> List players in the current AT queue</p>
                <p><strong>Usage:</strong> <code>/at players</code></p>
                <p><strong>Response:</strong></p>
                <pre>&lt;@user&gt;, the current AT queue players for this server are:
#1 &lt;@player1&gt; (**IGN1**)
#2 &lt;@player2&gt; (**IGN2**)
...
Team is full! (8 players)</pre>
              </div>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View all tournaments', tournaments_path %></li>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>
```

- [ ] **Step 6: Create MAT documentation page**

```erb
# app/views/documentation/mat.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Monthly AT Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Monthly Automated Tournament Commands</h1>
          <p class="lead">Manage monthly AT registration (every 3rd Saturday)</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Command Reference</h2>
              
              <div class="alert alert-info">
                <strong>Note:</strong> Monthly ATs occur on the 3rd Saturday of every month. 
                Registration opens 4 weeks (28 days) before the event.
              </div>
              
              <div class="mb-4">
                <h3>/mat schedule</h3>
                <p><strong>Description:</strong> Set the monthly AT schedule pattern</p>
                <p><strong>Usage:</strong> <code>/mat schedule every_3rd_saturday</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, this server now tracks monthly AT with pattern **every_3rd_saturday**; reminders will post in this channel. Next monthly AT: &lt;date&gt;.</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/mat next</h3>
                <p><strong>Description:</strong> Show time until the next monthly AT</p>
                <p><strong>Usage:</strong> <code>/mat next</code></p>
                <p><strong>Response (before registration opens):</strong> <code>&lt;@user&gt;, the next monthly AT starts in 25d 12h (&lt;date&gt;). Registration opens in 3d 6h.</code></p>
                <p><strong>Response (during registration):</strong> <code>&lt;@user&gt;, the next monthly AT starts in 25d 12h (&lt;date&gt;). Registration is OPEN!</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/mat join</h3>
                <p><strong>Description:</strong> Post the Monthly AT registration panel</p>
                <p><strong>Usage:</strong> <code>/mat join</code></p>
                <p><strong>Response:</strong> Posts an interactive panel with Register/Unregister buttons</p>
              </div>
              
              <div class="mb-4">
                <h3>/mat players</h3>
                <p><strong>Description:</strong> List players registered for the monthly AT</p>
                <p><strong>Usage:</strong> <code>/mat players</code></p>
                <p><strong>Response:</strong></p>
                <pre>&lt;@user&gt;, the current monthly AT queue players for this server are:
#1 &lt;@player1&gt; (**IGN1**)
#2 &lt;@player2&gt; (**IGN2**)
...
We need X more players.</pre>
              </div>
              
              <% if @next_monthly_at %>
                <div class="mt-5">
                  <h2>Schedule Information</h2>
                  <div class="card">
                    <div class="card-body">
                      <h5 class="card-title">Next Monthly AT</h5>
                      <p class="card-text">
                        <strong><%= @next_monthly_at.strftime('%B %d, %Y') %></strong> (3rd Saturday)<br>
                        Registration opens: <strong><%= (@next_monthly_at - 28.days).strftime('%B %d, %Y') %></strong>
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View all tournaments', tournaments_path %></li>
                  <li><%= link_to 'Daily AT commands', at_doc_path %></li>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>
```

- [ ] **Step 7: Create scrim documentation page**

```erb
# app/views/documentation/scrim.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Scrim Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Scrim Commands</h1>
          <p class="lead">Manage scrim registration and teams</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Queue Management</h2>
              
              <div class="mb-4">
                <h3>/scrim register</h3>
                <p><strong>Description:</strong> Register for the scrim queue</p>
                <p><strong>Usage:</strong> Click the "Register" button in the scrim panel or use the command</p>
                <p><strong>Response:</strong> <code>You have been registered, &lt;username&gt;!</code></p>
                <button class="btn btn-sm btn-success" onclick="toggleExample('register')">Show Example</button>
                <div id="example-register" class="example-output mt-2" style="display: none;">
                  <div class="card">
                    <div class="card-body">
                      <p><strong>Example Output:</strong></p>
                      <p>You have been registered, Arka!</p>
                    </div>
                  </div>
                </div>
              </div>
              
              <div class="mb-4">
                <h3>/scrim unregister</h3>
                <p><strong>Description:</strong> Unregister from the scrim queue</p>
                <p><strong>Usage:</strong> Click the "Unregister" button or use the command</p>
                <p><strong>Response:</strong> <code>You have been unregistered, &lt;username&gt;!</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim queue</h3>
                <p><strong>Description:</strong> Show the current scrim queue</p>
                <p><strong>Usage:</strong> <code>/scrim queue</code></p>
                <p><strong>Response:</strong></p>
                <pre>&lt;@user&gt;, the current players ordered by registration time are:
#1 &lt;@player1&gt; (**IGN1**)
#2 &lt;@player2&gt; (**IGN2**)
...
We need X more players.</pre>
              </div>
              
              <h2 class="mt-5">Team Management</h2>
              
              <div class="mb-4">
                <h3>/scrim team new</h3>
                <p><strong>Description:</strong> Form new teams for the next series (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim team new</code></p>
                <p><strong>Requires:</strong> Exactly 16 players in queue</p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim team win</h3>
                <p><strong>Description:</strong> Record a game win for a team (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim team win &lt;a|b&gt;</code></p>
                <p><strong>Example:</strong> <code>/scrim team win a</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim team captains</h3>
                <p><strong>Description:</strong> See the current captains</p>
                <p><strong>Usage:</strong> <code>/scrim team captains</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim team roll</h3>
                <p><strong>Description:</strong> Roll a random number between 0-100</p>
                <p><strong>Usage:</strong> <code>/scrim team roll</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, you rolled: &lt;number&gt;</code></p>
                <button class="btn btn-sm btn-primary" onclick="rollExample()">Roll Example</button>
                <div id="example-roll" class="example-output mt-2" style="display: none;">
                </div>
              </div>
              
              <div class="mb-4">
                <h3>/scrim team move</h3>
                <p><strong>Description:</strong> Move the current queue to the Scrimers voice channel (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim team move</code></p>
              </div>
              
              <h2 class="mt-5">Moderator Commands</h2>
              
              <div class="mb-4">
                <h3>/scrim reset</h3>
                <p><strong>Description:</strong> Reset the current scrim queue (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim reset</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim add</h3>
                <p><strong>Description:</strong> Add a player to the queue by in-game name (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim add &lt;igname&gt;</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim remove</h3>
                <p><strong>Description:</strong> Remove a player from the queue by in-game name (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim remove &lt;igname&gt;</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim afk</h3>
                <p><strong>Description:</strong> Mark a player as AFK (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim afk [@user]</code></p>
              </div>
              
              <div class="mb-4">
                <h3>/scrim back</h3>
                <p><strong>Description:</strong> Bring a player back from AFK (moderators only)</p>
                <p><strong>Usage:</strong> <code>/scrim back [@user]</code></p>
              </div>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View current scrim queue', scrims_path %></li>
                  <li><%= link_to 'See all scrims', scrims_path %></li>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>

<script>
function toggleExample(type) {
  const element = document.getElementById(`example-${type}`);
  if (element.style.display === 'none') {
    element.style.display = 'block';
  } else {
    element.style.display = 'none';
  }
}

function rollExample() {
  const element = document.getElementById('example-roll');
  const roll = Math.floor(Math.random() * 101);
  element.innerHTML = `
    <div class="card">
      <div class="card-body">
        <p><strong>Example Output:</strong></p>
        <p>&lt;@user&gt;, you rolled: ${roll}</p>
      </div>
    </div>
  `;
  element.style.display = 'block';
}
</script>
```

- [ ] **Step 8: Create build documentation page**

```erb
# app/views/documentation/build.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Build Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Build Commands</h1>
          <p class="lead">Show Guild Wars builds from template codes</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Command Reference</h2>
              
              <div class="mb-4">
                <h3>/build</h3>
                <p><strong>Description:</strong> Show a build from a GW1 template code</p>
                <p><strong>Usage:</strong> <code>/build &lt;code&gt; [--verbose]</code></p>
                <p><strong>Parameters:</strong></p>
                <ul>
                  <li><code>code</code> (required): The template code from the in-game Templates panel</li>
                  <li><code>verbose</code> (optional): Show skill names and descriptions</li>
                </ul>
                <p><strong>Example:</strong> <code>/build OAQhYgB3Kg7H0b2H3I4H5</code></p>
                <p><strong>Response:</strong> Embed with build image showing skills, attributes, and profession</p>
                <p><strong>Verbose Example:</strong> <code>/build OAQhYgB3Kg7H0b2H3I4H5 --verbose true</code></p>
                <p><strong>Verbose Response:</strong> Embed with additional skill descriptions and attribute details</p>
              </div>
              
              <div class="mt-5">
                <h2>How to Get a Template Code</h2>
                <ol>
                  <li>Open Guild Wars 1</li>
                  <li>Press <kbd>Ctrl + T</kbd> to open the Templates panel</li>
                  <li>Select your build template</li>
                  <li>Click "Copy Code"</li>
                  <li>Paste the code in Discord with <code>/build &lt;code&gt;</code></li>
                </ol>
              </div>
              
              <div class="mt-5">
                <h2>Related Commands</h2>
                <ul>
                  <li><%= link_to '/teambuild', teambuild_doc_path %> - For team builds (pawned2 format)</li>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>
```

- [ ] **Step 9: Create teambuild documentation page**

```erb
# app/views/documentation/teambuild.html.erb

<div class="content-wrap">
  <div class="mpl-navbar-mobile-overlay"></div>
  <div>
    <%= render 'documentation/breadcrumb', page: 'Team Build Commands' %>
    
    <section class="mpl-banner mpl-banner-top mpl-banner-small">
      <div class="mpl-image" data-speed="0.8">
        <%= image_tag 'background.jpg', class: 'jarallax-img' %>
      </div>
      <div class="mpl-banner-content mpl-box-sm">
        <div class="container">
          <h1 class="display-1 mb-0">Team Build Commands</h1>
          <p class="lead">Show Guild Wars team builds from pawned2 exports</p>
        </div>
      </div>
    </section>
    
    <div class="mpl-box-md">
      <div class="container">
        <div class="row hgap-lg vgap-lg">
          <div class="col-lg mpl-content">
            <article class="mpl-post">
              <h2>Command Reference</h2>
              
              <div class="mb-4">
                <h3>/teambuild</h3>
                <p><strong>Description:</strong> Show a team build from a pawned2 export</p>
                <p><strong>Usage:</strong> <code>/teambuild &lt;code&gt; [--verbose]</code></p>
                <p><strong>Parameters:</strong></p>
                <ul>
                  <li><code>code</code> (required): The pawned2 team build text</li>
                  <li><code>verbose</code> (optional): Show skill names for each player</li>
                </ul>
                <p><strong>Example:</strong> <code>/teambuild &lt;paste pawned2 export here&gt;</code></p>
                <p><strong>Response (compact):</strong> Single embed with grid image showing all 8 players' builds</p>
                <p><strong>Response (verbose):</strong> Multiple embeds, one per player with skill details</p>
              </div>
              
              <div class="mt-5">
                <h2>How to Get a Pawned2 Export</h2>
                <ol>
                  <li>Go to <a href="https://paw.ned2.com" target="_blank">paw.ned2.com</a></li>
                  <li>Create or load your team build</li>
                  <li>Click "Export" or "Copy Text"</li>
                  <li>Paste the text in Discord with <code>/teambuild &lt;text&gt;</code></li>
                </ol>
              </div>
              
              <div class="mt-5">
                <h2>Limitations</h2>
                <ul>
                  <li>Maximum 8 players per team</li>
                  <li>Maximum 10 embeds per Discord message (verbose mode with 8 players = 8 embeds)</li>
                  <li>Invalid codes will show an error message</li>
                </ul>
              </div>
              
              <div class="mt-5">
                <h2>Related Commands</h2>
                <ul>
                  <li><%= link_to '/build', build_doc_path %> - For individual builds</li>
                </ul>
              </div>
            </article>
          </div>
          
          <div class="col-auto-lg mpl-sidebar">
            <%= render 'documentation/sidebar' %>
          </div>
        </div>
      </div>
    </div>
    
    <%= render 'footer' %>
  </div>
</div>
```

- [ ] **Step 10: Commit all views**

```bash
git add app/views/documentation/
git commit -m "Create all documentation view templates"
```

---

### Task 13: Update Navigation Bar

**Files:**
- Modify: `app/views/application/_navbar.html.erb`

- [ ] **Step 1: Add documentation dropdown to navbar**

Find the closing `</ul>` for the main navbar nav and add the documentation dropdown before it:

```erb
<!-- Add this before the closing </ul> of mpl-navbar-nav -->
<li class="mpl-dropdown">
  <a href="#" class="mpl-nav-link" role="button">
    <span class="mpl-nav-link-name"> Documentation </span>
  </a>
  <div class="mpl-dropdown-menu">
    <ul class="mpl-navbar-nav">
      <li>
        <%= link_to player_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> Player Commands </span>
        <% end %>
      </li>
      <li>
        <%= link_to at_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> AT Commands </span>
        <% end %>
      </li>
      <li>
        <%= link_to mat_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> Monthly AT Commands </span>
        <% end %>
      </li>
      <li>
        <%= link_to scrim_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> Scrim Commands </span>
        <% end %>
      </li>
      <li>
        <%= link_to build_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> Build Commands </span>
        <% end %>
      </li>
      <li>
        <%= link_to teambuild_doc_path, class: 'mpl-nav-link' do %>
          <span class="mpl-nav-link-name"> Team Build Commands </span>
        <% end %>
      </li>
    </ul>
  </div>
</li>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/application/_navbar.html.erb
git commit -m "Add documentation dropdown to navigation bar"
```

---

## Phase 2 Verification

- [ ] **Step 1: Test all documentation pages**

```bash
rails server
```

Then visit each page in browser:
- http://localhost:3000/player
- http://localhost:3000/at
- http://localhost:3000/mat
- http://localhost:3000/scrim
- http://localhost:3000/build
- http://localhost:3000/teambuild

Expected: All pages render correctly with proper styling

- [ ] **Step 2: Test navigation**

Click through the documentation dropdown and sidebar links.

Expected: All links work, active states are correct

- [ ] **Step 3: Test interactive elements**

Click the "Show Example" and "Roll Example" buttons on the scrim page.

Expected: Examples appear/disappear correctly, roll generates random numbers

- [ ] **Step 4: Commit Phase 2 completion**

```bash
git add .
git commit -m "Complete Phase 2: Website documentation pages"
```

---

## Final Verification

- [ ] **Step 1: Full system test**

1. Start the Rails server and bot:
```bash
rails server
# In another terminal
rails jobs:work
```

2. Test all Discord commands in a development server
3. Visit all documentation pages in browser
4. Verify navigation works correctly

- [ ] **Step 2: Run existing tests**

```bash
rails test
```

Expected: All existing tests pass

- [ ] **Step 3: Final commit**

```bash
git add .
git commit -m "Complete Discord bot and website restructuring"
```

---

## Rollback Instructions

If issues arise, to rollback:

```bash
# For Discord bot issues
git checkout HEAD~1 -- app/jobs/command_bot_job.rb
# Restart bot

# For database issues
git checkout HEAD~1 -- db/migrate/
rails db:rollback

# For website issues
git checkout HEAD~1 -- app/controllers/documentation_controller.rb app/views/documentation/ app/views/application/_navbar.html.erb config/routes.rb
```

---

## Success Criteria Checklist

- [ ] All Discord bot commands are organized under the new hierarchy
- [ ] `/queue` and `/team` commands are removed and replaced by `/scrim`
- [ ] `/mat` commands work for monthly AT management
- [ ] `/build` and `/teambuild` remain as standalone commands
- [ ] All documentation pages are accessible and contain accurate command references
- [ ] Documentation pages include interactive example elements
- [ ] Navigation includes links to all documentation pages
- [ ] All existing functionality continues to work
- [ ] Database migrations are applied correctly
- [ ] No breaking changes to existing features
