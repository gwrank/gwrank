# frozen_string_literal: true

require 'digest'

# == Schema Information
#
# Table name: characters
#
#  id            :bigint           not null, primary key
#  igname        :string
#  igname_hash   :string
#  is_archived   :boolean          default(FALSE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  player_id     :bigint
#  profession_id :bigint
#
# Indexes
#
#  index_characters_on_igname         (igname) UNIQUE
#  index_characters_on_igname_hash    (igname_hash) UNIQUE
#  index_characters_on_player_id      (player_id)
#  index_characters_on_profession_id  (profession_id)
#
# Foreign Keys
#
#  fk_rails_...  (player_id => players.id)
#  fk_rails_...  (profession_id => professions.id)
#

class Character < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :profession, optional: true
  has_many :team_players

  scope :active, -> { where(is_archived: false) }
  scope :archived, -> { where(is_archived: true) }

  # igname is deprecated but kept for backwards compatibility
  # igname_hash is the primary identifier for lookups
  validates :igname, presence: true

  include PgSearch::Model
  multisearchable against: [:igname]
  pg_search_scope :whose_igname_starts_with,
                  against: :igname,
                  using: {
                    tsearch: { prefix: true }
                  }

  # Callbacks for hashing character names
  before_validation :ensure_igname_hashed
  before_save :hash_igname_if_changed

  # Find character by original in-game name (used by claim flow, admin)
  # @param original_name [String] The original in-game name
  # @return [Character, nil]
  def self.find_by_igname(original_name)
    return nil if original_name.blank?
    hash = hash_name_static(original_name)
    find_by(igname_hash: hash)
  end

  # Check if given name matches this character
  # @param original_name [String] The original in-game name to check
  # @return [Boolean]
  def matches_igname?(original_name)
    return false if original_name.blank?
    igname_hash == hash_name_static(original_name)
  end

  # Get anonymized display name for a specific user
  # @param user [Player, nil] The user viewing the character
  # @return [String] The anonymized name or original for admins
  def anonymized_name_for(user)
    return igname if user&.is_admin?
    return anonymized_name_for_user(user) if user.present?
    public_anonymous_label
  end

  # Get the anonymized name based on user's seed
  # @param user [Player] The user viewing the character
  # @return [String]
  def anonymized_name_for_user(user)
    return igname if igname.blank?
    AnonymizedNameService.anonymize_character(self, user)
  end

  # Placeholder for unauthenticated users
  # @return [String]
  def public_anonymous_label
    "Character ##{id}"
  end

  def igname_with_profession
    if profession.present?
      "#{igname} (#{profession.name})"
    else
      igname
    end
  end

  def unlink!
    new_player ||= Player.where(email: igname.split.join("-").downcase + "@gwrank.com").first_or_create! do |p|
      p.password = Devise.friendly_token[0, 20]
    end
    team_players.update_all(player_id: new_player.id) if team_players.any?
    update(player_id: new_player.id)
  end

  # Check if character can be claimed by a specific player
  # @param player [Player, nil] The player attempting to claim
  # @return [Boolean] true if character is unowned or owned by the same player
  def claimable_by?(player)
    player_id.nil? || player_id == player.id
  end

  def anonymized_igname_with_profession(user = nil)
    anonymized_name = anonymized_name_for(user)
    if profession.present?
      "#{anonymized_name} (#{profession.name})"
    else
      anonymized_name
    end
  end


  private

  # Generate a deterministic hash for a name using SHA256
  # This allows consistent lookups while still obscuring the original name
  # @param name [String] The name to hash
  # @return [String] The SHA256 hash
  def self.hash_name_static(name)
    return nil if name.blank?
    Digest::SHA256.hexdigest(name.downcase.strip)
  end

  # Instance method for hashing (delegates to class method)
  def hash_name(name)
    self.class.hash_name_static(name)
  end

  # Ensure igname is hashed before validation
  def ensure_igname_hashed
    if igname.present? && igname_hash.blank?
      self.igname_hash = hash_name(igname)
    elsif igname_changed? && igname.present?
      # Re-hash if name changes
      self.igname_hash = hash_name(igname)
    end
  end

  # Re-hash igname if it changes
  def hash_igname_if_changed
    return unless igname_changed? && igname.present?
    self.igname_hash = hash_name(igname)
  end
end
