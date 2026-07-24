# Design Specification: Gwrank Discord Bot & Website Restructuring

**Date:** 2026-07-24  
**Status:** Approved  
**Author:** opencode  
**Stakeholder:** arka

---

## Overview

This specification details the comprehensive restructuring of Gwrank's Discord bot commands and the addition of website documentation pages to mirror the command structure. The goal is to organize all player commands under `/player`, automated tournament commands under `/at`, monthly automated tournament commands under `/mat`, and scrim commands under `/scrim`, while adding corresponding documentation pages to the website.

---

## Background

### Current State

**Discord Bot Commands:**
- `/player` - Player profile management (register, igname, claim, professions)
- `/at` - Automated Tournament queue management (schedule, next, join, players)
- `/queue` - Scrim registration queue management (open, players, reset, add, remove, afk, back)
- `/team` - Scrim team management (captains, roll, new, win, move)
- `/build` - Show individual builds from template codes
- `/teambuild` - Show team builds from pawned2 exports

**Website Structure:**
- Home page with queue count and Discord link
- `/players` - Player listings
- `/scrims` - Scrim listings and current queue
- `/tournaments` - Tournament listings
- Navigation bar with Home, Players, Scrims links

### Problems

1. **Command Organization:** Scrim-related commands are split across `/queue` and `/team`, making discovery difficult
2. **No Documentation:** No centralized documentation for Discord bot commands on the website
3. **Missing Monthly ATs:** No support for monthly automated tournaments
4. **Inconsistent Structure:** Website URLs don't mirror Discord command structure

---

## Goals

1. Reorganize Discord bot commands into logical hierarchies
2. Add website documentation pages that mirror the command structure
3. Add support for monthly automated tournaments
4. Maintain backward compatibility where possible (full migration approach chosen)
5. Keep `/build` and `/teambuild` as standalone commands

---

## Design

### 1. Discord Bot Command Restructuring

#### New Command Structure

```
Player Commands (/player)
├── register - Set your in-game name
├── igname - Look up a player's in-game name
├── claim - Claim a character name
└── professions - View or toggle your professions

Automated Tournament Commands (/at)
├── schedule - Set which daily AT slot (a/b/c) this server tracks
├── next - Show time until the next scheduled AT
├── join - Post the AT registration panel
└── players - List players in the current AT queue

Monthly Automated Tournament Commands (/mat)
├── schedule - Set monthly schedule (every 3rd Saturday)
├── next - Show next monthly AT time
├── join - Post the monthly AT registration panel
└── players - List players registered for monthly AT

Scrim Commands (/scrim)
├── register - Register for scrim queue
├── unregister - Unregister from queue
├── queue - Show current queue
├── reset - Reset the current queue (moderators only)
├── add - Add a player to the queue (moderators only)
├── remove - Remove a player from the queue (moderators only)
├── afk - Mark a player AFK (moderators only)
├── back - Bring a player back from AFK (moderators only)
└── team
    ├── new - Form new teams for the next series (moderators only)
    ├── win - Record a game win for a team (moderators only)
    ├── captains - See the current captains
    ├── roll - Roll 0-100
    └── move - Move the current queue to the Scrimers voice channel (moderators only)

Standalone Commands (unchanged)
├── /build - Show a build from a GW1 template code
└── /teambuild - Show a team build from a pawned2 export
```

#### Command Migration Mapping

| Old Command | New Command | Action |
|-------------|--------------|--------|
| `/queue open` | `/scrim register` (via button) | Migrate |
| `/queue players` | `/scrim queue` | Migrate |
| `/queue reset` | `/scrim reset` | Migrate |
| `/queue add` | `/scrim add` | Migrate |
| `/queue remove` | `/scrim remove` | Migrate |
| `/queue afk` | `/scrim afk` | Migrate |
| `/queue back` | `/scrim back` | Migrate |
| `/team captains` | `/scrim team captains` | Migrate |
| `/team roll` | `/scrim team roll` | Migrate |
| `/team new` | `/scrim team new` | Migrate |
| `/team win` | `/scrim team win` | Migrate |
| `/team move` | `/scrim team move` | Migrate |
| `/player *` | `/player *` | Keep as-is |
| `/at *` | `/at *` | Keep as-is |
| `/build` | `/build` | Keep as-is |
| `/teambuild` | `/teambuild` | Keep as-is |

#### New `/mat` Commands Specification

**`/mat schedule`**
- Sets the monthly AT schedule pattern
- Default: every 3rd Saturday of the month
- Registration opens 4 weeks (28 days) before the event
- Stores in `AutomatedTournamentSchedule` with `is_monthly: true`

**`/mat next`**
- Shows the next monthly AT date/time
- Calculates based on "every 3rd Saturday" pattern
- Shows time until next occurrence
- Shows registration window status

**`/mat join`**
- Posts the monthly AT registration panel
- Uses same button-based registration as daily AT
- Separate registration tracking from daily AT

**`/mat players`**
- Lists players registered for the next monthly AT
- Shows queue position and player info

### 2. Database Changes

#### Model Extensions

**`AutomatedTournamentSchedule`** (extend existing model)

```ruby
# app/models/automated_tournament_schedule.rb

class AutomatedTournamentSchedule < ApplicationRecord
  # Existing fields:
  # - discord_server_id: string
  # - channel_id: string
  # - timezone: string (for daily AT: 'a', 'b', 'c')
  # - last_reminded_on: datetime
  
  # New fields:
  # - is_monthly: boolean, default: false
  # - recurrence_pattern: string, e.g., "every_3rd_saturday"
  # - registration_opens_days_before: integer, default: 28
  
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
  
  def next_monthly_occurrence(from)
    # Find next 3rd Saturday from the given date
    # Returns DateTime of next occurrence
  end
  
  def next_daily_occurrence(from)
    # Existing logic for daily AT
  end
  
  def registration_window_open?(from: Time.now.utc)
    if is_monthly?
      next_occ = next_occurrence(from: from)
      registration_start = next_occ - registration_opens_days_before.days
      from >= registration_start && from <= next_occ
    else
      # Existing logic for daily AT registration window
    end
  end
end
```

**Migration:**
```ruby
# db/migrate/[timestamp]_add_monthly_support_to_automated_tournament_schedules.rb

class AddMonthlySupportToAutomatedTournamentSchedules < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_tournament_schedules, :is_monthly, :boolean, default: false
    add_column :automated_tournament_schedules, :recurrence_pattern, :string
    add_column :automated_tournament_schedules, :registration_opens_days_before, :integer, default: 28
    
    # Set existing records as daily
    execute "UPDATE automated_tournament_schedules SET is_monthly = false, recurrence_pattern = CONCAT('daily_', timezone) WHERE is_monthly IS NULL"
  end
end
```

**`AutomatedTournamentRegistration`** (extend existing model)

Add `is_monthly: boolean, default: false` to distinguish between daily and monthly AT registrations.

```ruby
# Migration
add_column :automated_tournament_registrations, :is_monthly, :boolean, default: false
```

### 3. Discord Bot Implementation

#### New Command Classes

**`app/services/discord_bot/commands/scrim_commands.rb`**

Merges functionality from `QueueCommands` and `TeamCommands`:

```ruby
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
      
      # ... (implementation methods migrated from QueueCommands and TeamCommands)
    end
  end
end
```

**`app/services/discord_bot/commands/mat_commands.rb`**

New class for monthly automated tournaments:

```ruby
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
      
      # ... (button handlers and helper methods)
    end
  end
end
```

#### Updated CommandBotJob

**`app/jobs/command_bot_job.rb`**

```ruby
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

**New service for MAT reminders:**

**`app/services/discord_bot/mat_reminder_check.rb`**

```ruby
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
      # Logic similar to AtReminderCheck but for monthly schedule
    end
  end
end
```

### 4. Website Documentation Implementation

#### New Controller

**`app/controllers/documentation_controller.rb`**

```ruby
class DocumentationController < ApplicationController
  before_action :set_documentation_data
  
  def player
    render :player
  end
  
  def at
    render :at
  end
  
  def mat
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
      player: { name: 'Player Commands', path: '/player' },
      at: { name: 'Automated Tournament Commands', path: '/at' },
      mat: { name: 'Monthly AT Commands', path: '/mat' },
      scrim: { name: 'Scrim Commands', path: '/scrim' },
      build: { name: 'Build Commands', path: '/build' },
      teambuild: { name: 'Team Build Commands', path: '/teambuild' }
    }
  end
end
```

#### New Views

**`app/views/documentation/player.html.erb`**

```erb
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
                <p><strong>Example:</strong> <code>/player professions warrior</code></p>
                <p><strong>Response:</strong> <code>&lt;@user&gt;, your current professions: Warrior, Monk</code></p>
              </div>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View all players', players_path %></li>
                  <li><%= link_to 'Your profile', current_player ? profile_path : '#' %></li>
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

**`app/views/documentation/scrim.html.erb`**

```erb
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
                <button class="btn btn-sm btn-success" onclick="showExample('register')">Show Example</button>
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
                <button class="btn btn-sm btn-primary" onclick="showRollExample()">Roll Example</button>
                <div id="example-roll" class="example-output mt-2" style="display: none;">
                  <div class="card">
                    <div class="card-body">
                      <p><strong>Example Output:</strong></p>
                      <p>&lt;@user&gt;, you rolled: <%= rand(0..100) %></p>
                    </div>
                  </div>
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
function showExample(type) {
  const element = document.getElementById(`example-${type}`);
  if (element.style.display === 'none') {
    element.style.display = 'block';
  } else {
    element.style.display = 'none';
  }
}

function showRollExample() {
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

**`app/views/documentation/at.html.erb`**

```erb
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

**`app/views/documentation/mat.html.erb`**

```erb
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
              
              <div class="mt-5">
                <h2>Schedule Information</h2>
                <div class="card">
                  <div class="card-body">
                    <h5 class="card-title">Next Monthly AT</h5>
                    <p class="card-text">
                      <% next_mat = @next_monthly_at %>
                      <% if next_mat %>
                        <strong><%= next_mat.strftime('%B %d, %Y') %></strong> (3rd Saturday)<br>
                        Registration opens: <strong><%= (next_mat - 28.days).strftime('%B %d, %Y') %></strong>
                      <% else %>
                        No monthly AT scheduled yet.
                      <% end %>
                    </p>
                  </div>
                </div>
              </div>
              
              <div class="mt-5">
                <h2>Related Pages</h2>
                <ul>
                  <li><%= link_to 'View all tournaments', tournaments_path %></li>
                  <li><%= link_to 'Daily AT commands', at_path %></li>
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

**`app/views/documentation/build.html.erb`**

```erb
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
                  <li><%= link_to '/teambuild', teambuild_path %> - For team builds (pawned2 format)</li>
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

**`app/views/documentation/teambuild.html.erb`**

```erb
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
                  <li><%= link_to '/build', build_path %> - For individual builds</li>
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

#### Partials

**`app/views/documentation/_breadcrumb.html.erb`**

```erb
<nav aria-label="breadcrumb" class="mpl-breadcrumb">
  <div class="container">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><%= link_to 'Home', root_path %></li>
      <li class="breadcrumb-item"><%= link_to 'Documentation', '#' %></li>
      <li class="breadcrumb-item active" aria-current="page"><%= page %></li>
    </ol>
  </div>
</nav>
```

**`app/views/documentation/_sidebar.html.erb`**

```erb
<div class="mpl-sidebar-content">
  <h3>Documentation</h3>
  <ul class="nav flex-column">
    <li class="nav-item">
      <%= link_to 'Player Commands', player_path, class: "nav-link #{'active' if current_page?(player_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'AT Commands', at_path, class: "nav-link #{'active' if current_page?(at_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Monthly AT Commands', mat_path, class: "nav-link #{'active' if current_page?(mat_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Scrim Commands', scrim_path, class: "nav-link #{'active' if current_page?(scrim_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Build Commands', build_path, class: "nav-link #{'active' if current_page?(build_path)}" %>
    </li>
    <li class="nav-item">
      <%= link_to 'Team Build Commands', teambuild_path, class: "nav-link #{'active' if current_page?(teambuild_path)}" %>
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

#### Updated Routes

**`config/routes.rb`**

```ruby
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

#### Updated Navigation

**`app/views/application/_navbar.html.erb`** (add documentation dropdown)

```erb
<!-- Add to the navbar, before the right-side icons -->
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

---

## Implementation Plan

### Phase 1: Discord Bot Reorganization (Priority)

1. **Create new command classes**
   - [ ] Create `ScrimCommands` class
   - [ ] Create `MatCommands` class
   - [ ] Review and finalize command method implementations

2. **Database migrations**
   - [ ] Add columns to `AutomatedTournamentSchedule`
   - [ ] Add `is_monthly` to `AutomatedTournamentRegistration`
   - [ ] Run migrations

3. **Update existing classes**
   - [ ] Update `AtCommands` if needed for compatibility
   - [ ] Keep `PlayerCommands` as-is
   - [ ] Keep `BuildCommands` as-is
   - [ ] Keep `TeamBuildCommands` as-is

4. **Update CommandBotJob**
   - [ ] Replace `QueueCommands` and `TeamCommands` with `ScrimCommands`
   - [ ] Add `MatCommands`
   - [ ] Add MAT reminder thread

5. **Create new service**
   - [ ] Create `MatReminderCheck` service

6. **Test all commands**
   - [ ] Test `/scrim` commands
   - [ ] Test `/mat` commands
   - [ ] Test existing commands still work
   - [ ] Verify old commands (`/queue`, `/team`) are removed

### Phase 2: Website Documentation

1. **Create controller**
   - [ ] Create `DocumentationController`
   - [ ] Implement all 6 actions

2. **Create views**
   - [ ] Create all 6 documentation page templates
   - [ ] Create partials (`_breadcrumb`, `_sidebar`)

3. **Update routes**
   - [ ] Add documentation routes

4. **Update navigation**
   - [ ] Add documentation dropdown to navbar

5. **Add styling**
   - [ ] Ensure pages match existing design
   - [ ] Add JavaScript for interactive examples

6. **Test all pages**
   - [ ] Verify all documentation pages render correctly
   - [ ] Test navigation between pages
   - [ ] Test interactive elements

---

## Testing Strategy

### Discord Bot Testing

1. **Unit Tests**
   - Test command registration
   - Test command dispatching
   - Test each command handler method
   - Test monthly schedule calculation logic

2. **Integration Tests**
   - Test command flow from Discord event to response
   - Test button interactions
   - Test moderator gate functionality

3. **Manual Testing**
   - Test in development Discord server
   - Verify all commands work as expected
   - Verify error handling

### Website Testing

1. **View Tests**
   - Test all documentation pages render without errors
   - Test partials render correctly

2. **Route Tests**
   - Test all documentation routes work
   - Test route helpers

3. **Manual Testing**
   - Verify pages display correctly
   - Test navigation
   - Test interactive elements

---

## Rollback Plan

If issues arise during deployment:

1. **Discord Bot**
   - Revert to old `CommandBotJob` with original command classes
   - Old commands (`/queue`, `/team`) will need to be re-added

2. **Database**
   - Rollback migrations if needed
   - Data migration scripts may be needed for existing records

3. **Website**
   - Remove documentation routes
   - Remove documentation pages
   - Revert navbar changes

---

## Success Criteria

1. All Discord bot commands are organized under the new hierarchy
2. `/queue` and `/team` commands are removed and replaced by `/scrim`
3. `/mat` commands work for monthly AT management
4. `/build` and `/teambuild` remain as standalone commands
5. All documentation pages are accessible and contain accurate command references
6. Documentation pages include interactive example elements
7. Navigation includes links to all documentation pages
8. All existing functionality continues to work

---

## Open Questions

None - all requirements have been clarified and addressed in the design.

---

## Appendix

### File Changes Summary

**New Files:**
- `app/services/discord_bot/commands/scrim_commands.rb`
- `app/services/discord_bot/commands/mat_commands.rb`
- `app/services/discord_bot/mat_reminder_check.rb`
- `app/controllers/documentation_controller.rb`
- `app/views/documentation/player.html.erb`
- `app/views/documentation/at.html.erb`
- `app/views/documentation/mat.html.erb`
- `app/views/documentation/scrim.html.erb`
- `app/views/documentation/build.html.erb`
- `app/views/documentation/teambuild.html.erb`
- `app/views/documentation/_breadcrumb.html.erb`
- `app/views/documentation/_sidebar.html.erb`
- `db/migrate/[timestamp]_add_monthly_support_to_automated_tournament_schedules.rb`
- `db/migrate/[timestamp]_add_is_monthly_to_automated_tournament_registrations.rb`

**Modified Files:**
- `app/jobs/command_bot_job.rb`
- `config/routes.rb`
- `app/views/application/_navbar.html.erb`

**Deleted Files:**
- `app/services/discord_bot/commands/queue_commands.rb`
- `app/services/discord_bot/commands/team_commands.rb`

### Command Reference Quick Guide

| Category | Commands |
|----------|----------|
| Player | register, igname, claim, professions |
| AT | schedule, next, join, players |
| MAT | schedule, next, join, players |
| Scrim | register, unregister, queue, reset, add, remove, afk, back, team (captains, roll, new, win, move) |
| Standalone | build, teambuild |
