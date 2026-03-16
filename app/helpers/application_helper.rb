module ApplicationHelper
  def today_scrim_registration_time
    now = DateTime.now
    now.change(hour: scrim_hour_for(now.wday))
  end

  def today_scrim_end_registration_time
    today_scrim_registration_time + 1.hour
  end

  def tomorrow_scrim_registration_time
    DateTime.now.tomorrow.change(hour: scrim_hour_for(Date.tomorrow.wday))
  end

  # Display character name with anonymization based on user permissions
  # @param character [Character] The character to display
  # @param user [Player, nil] The current user viewing (optional)
  # @return [String] The display name
  def display_character_name(character, user = nil)
    # Registered users see their igname
    if character&.player&.uid&.present?
      character.igname.presence || character.player.username
    # Users see their own igname
    elsif user.present? && player.id == user.id
      player.igname.presence || player.username
    # Other users see anonymized names
    elsif user.present?
      AnonymizedNameService.anonymize_player_name(character.igname, user)
    else
      "Character #{character&.id || '??'}"
    end
  end

  # Display player name with anonymization based on user permissions
  # @param player [Player] The player to display
  # @param user [Player, nil] The current user viewing (optional)
  # @return [String] The display name
  def display_player_name(player, user = nil)
    # Registered users see their own igname
    if player&.uid&.present?
      player.igname.presence || player.username
    # Users see their own igname
    elsif user.present? && player.id == user.id
      player.igname.presence || player.username
    # Other users see anonymized names
    elsif user.present?
      AnonymizedNameService.anonymize_player_name(player.igname, user)
    else
      "Player #{player&.id || '??'}"
    end
  end

  def display_team_player_name(team_player, user = nil)
    # Registered users see their own igname
    if team_player&.player&.uid&.present?
      player.igname.presence || player.username
    # Users see their own igname
    elsif user.present? && team_player&.character&.player&.id == user.id
      team_player.igname || team_player.character.player.username
    # Other users see anonymized names
    elsif user.present?
      AnonymizedNameService.anonymize_player_name(team_player.igname, user)
    else
      "Team Player #{team_player&.id || '??'}"
    end
  end

  private

  def scrim_hour_for(wday)
    case wday
    when 1, 5 # monday, friday
      23
    when 2, 4, 6 # tuesday, thirsday, saturday
      20
    when 3, 7 # wednesday, sunday
      21
    end
  end
end
