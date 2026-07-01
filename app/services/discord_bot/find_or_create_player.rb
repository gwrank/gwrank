module DiscordBot
  class FindOrCreatePlayer
    def self.call(event)
      Player.where(provider: 'discord', uid: event.user.id).first_or_create do |player|
        player.email = "#{event.user.id}@gwrank.com"
        player.password = Devise.friendly_token[0, 20]
        player.username = event.user.name
      end
    end
  end
end
