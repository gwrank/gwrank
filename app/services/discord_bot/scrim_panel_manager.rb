# app/services/discord_bot/scrim_panel_manager.rb
module DiscordBot
  class ScrimPanelManager
    include Singleton
    
    def initialize
      @active_panels = {} # {server_id => {channel_id => Set[message_id]}}
      @mutex = Mutex.new
    end

    def add_panel(server_id, channel_id, message_id)
      @mutex.synchronize do
        Rails.logger.debug("Adding panel: server=#{server_id}, channel=#{channel_id}, message=#{message_id}")
        @active_panels[server_id.to_s] ||= {}
        @active_panels[server_id.to_s][channel_id.to_s] ||= Set.new
        @active_panels[server_id.to_s][channel_id.to_s] << message_id.to_s
        Rails.logger.debug("Total panels: #{@active_panels.size}")
      end
    end

    def remove_panel(server_id, channel_id, message_id)
      @mutex.synchronize do
        return unless @active_panels[server_id.to_s] && @active_panels[server_id.to_s][channel_id.to_s]
        @active_panels[server_id.to_s][channel_id.to_s].delete(message_id.to_s)
        
        # Clean up empty channels
        if @active_panels[server_id.to_s][channel_id.to_s].empty?
          @active_panels[server_id.to_s].delete(channel_id.to_s)
          @active_panels.delete(server_id.to_s) if @active_panels[server_id.to_s].empty?
        end
      end
    end

    def update_all_panels(bot)
      @mutex.synchronize do
        Rails.logger.debug("Updating #{@active_panels.size} servers with panels")
        @active_panels.each do |server_id, channels|
          server = bot.server(server_id)
          next unless server

          channels.each do |channel_id, message_ids|
            channel = server.channel(channel_id)
            next unless channel

            message_ids.each do |message_id|
              Rails.logger.debug("Updating panel: server=#{server_id}, channel=#{channel_id}, message=#{message_id}")
              update_panel_message(bot, server, channel, message_id)
            end
          end
        end
      end
    end

    def panel_content
      registrations = Registration.current_registrations.order(registered_at: :asc)
      
      if registrations.empty?
        "### Scrim Registration Panel\nNo players currently registered."
      else
        players = registrations.each_with_index.map do |registration, index|
          entry = "\n##{index + 1} <@#{registration.player.uid}>"
          entry << " (**#{registration.player.igname}**)" if registration.player.igname.present?
          entry << " [#{registration.player.professions_text}]" if registration.player.professions_text.present?
          entry
        end
        "### Scrim Registration Panel\nCurrent registered users:\n#{players.join}"
      end
    end

    def panel_components
      Discordrb::Webhooks::View.new.tap do |view|
        view.container do |container|
          container.text_display(content: panel_content)
          
          # Row 1: Register/Unregister
          container.row do |row|
            row.button(label: 'Register', style: :success, custom_id: 'scrim_register')
            row.button(label: 'Unregister', style: :danger, custom_id: 'scrim_unregister')
          end
          
          # Row 2: AFK/Back
          container.row do |row|
            row.button(label: 'AFK', style: :secondary, custom_id: 'scrim_afk')
            row.button(label: 'Back (from AFK)', style: :secondary, custom_id: 'scrim_back')
          end
          
          # Row 3: Reset (moderators only)
          container.row do |row|
            row.button(label: 'Reset Queue', style: :danger, custom_id: 'scrim_reset')
          end
        end
      end.to_a
    end

    private

    def update_panel_message(bot, server, channel, message_id)
      return unless channel
      
      message = channel.message(message_id)
      return unless message
      
       begin
        # For messages with components, we need to use edit with components
        # The content is included in the components via text_display
        message.edit("", components: panel_components.to_a)
      rescue => e
        Rails.logger.error("Failed to update scrim panel #{server.id}/#{channel.id}/#{message_id}: #{e.class}: #{e.message}")
      end
    end
  end
end
