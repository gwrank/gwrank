# == Schema Information
#
# Table name: players
#
#  id                      :bigint           not null, primary key
#  anonymization_seed      :string
#  api_token               :string
#  average_deaths_per_game :float
#  average_dmg_per_game    :float
#  average_dpm             :float            default(0.0)
#  average_opponent_elo    :integer
#  average_team_elo        :integer
#  average_warrior_cpm     :float
#  confirmation_sent_at    :datetime
#  confirmation_token      :string
#  confirmed_at            :datetime
#  current_sign_in_at      :datetime
#  current_sign_in_ip      :string
#  elo_matches             :integer
#  elo_rating              :integer
#  email                   :string           default("")
#  encrypted_password      :string           default(""), not null
#  failed_attempts         :integer          default(0), not null
#  igname                  :string
#  image_url               :string
#  is_admin                :boolean          default(FALSE)
#  is_assassin             :boolean          default(FALSE)
#  is_dervish              :boolean          default(FALSE)
#  is_elementalist         :boolean          default(FALSE)
#  is_mesmer               :boolean          default(FALSE)
#  is_moderator            :boolean          default(FALSE)
#  is_monk                 :boolean          default(FALSE)
#  is_necromancer          :boolean          default(FALSE)
#  is_paragon              :boolean          default(FALSE)
#  is_ranger               :boolean          default(FALSE)
#  is_ritualist            :boolean          default(FALSE)
#  is_verified             :boolean          default(FALSE)
#  is_warrior              :boolean          default(FALSE)
#  kd_ratio                :float
#  last_sign_in_at         :datetime
#  last_sign_in_ip         :string
#  locked_at               :datetime
#  provider                :string
#  remember_created_at     :datetime
#  reset_password_sent_at  :datetime
#  reset_password_token    :string
#  sign_in_count           :integer          default(0), not null
#  slug                    :string
#  twitch_username         :string
#  uid                     :string
#  unconfirmed_email       :string
#  unlock_token            :string
#  username                :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  guild_id                :bigint
#
# Indexes
#
#  index_players_on_confirmation_token    (confirmation_token) UNIQUE
#  index_players_on_email                 (email) UNIQUE
#  index_players_on_guild_id              (guild_id)
#  index_players_on_reset_password_token  (reset_password_token) UNIQUE
#  index_players_on_slug                  (slug) UNIQUE
#  index_players_on_unlock_token          (unlock_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (guild_id => guilds.id)
#
class Player < ApplicationRecord
  belongs_to :guild, optional: true
  has_secure_token :api_token
  has_many :characters, dependent: :nullify
  has_many :registrations, dependent: :destroy
  has_many :team_players, dependent: :nullify
  has_many :team_player_stats, through: :team_players
  has_many :teams, through: :team_players
  has_many :matches, through: :teams

  # Callbacks for anonymization seed
  before_validation :ensure_anonymization_seed
  before_save :generate_anonymization_seed

  extend FriendlyId
  friendly_id :id, use: :slugged
  def should_generate_new_friendly_id?
    slug.blank? || username_changed?
  end

  devise :database_authenticatable, :omniauthable, :rememberable, :lockable

  validates_presence_of :password, on: :create
  validates_confirmation_of :password, on: :create
  validates_length_of :password, within: Devise.password_length, allow_blank: true
  validates_uniqueness_of :igname, on: :update, allow_blank: true

  scope :with_igname, -> { where.not(igname: nil).where.not(igname: '') }

  scope :in_queue, -> { joins(:registrations)
                          .where('registrations.registered_at > ?', DateTime.now - 8.hours)
                          .where('registrations.unregistered_at IS NULL')
                          .order('registrations.registered_at ASC')
                      }

  scope :streamers, -> { where.not(twitch_username: '') }

  scope :warriors, -> { where(is_warrior: true) }
  scope :rangers, -> { where(is_ranger: true) }
  scope :monks, -> { where(is_monk: true) }
  scope :necromancers, -> { where(is_necromancer: true) }
  scope :mesmers, -> { where(is_mesmer: true) }
  scope :elementalists, -> { where(is_elementalist: true) }
  scope :assassins, -> { where(is_assassin: true) }
  scope :ritualists, -> { where(is_ritualist: true) }
  scope :paragons, -> { where(is_paragon: true) }
  scope :dervishs, -> { where(is_dervish: true) }

  scope :frontliners, -> { warriors.or(dervishs).or(assassins) }
  scope :midliners, -> { rangers.or(necromancers).or(mesmers).or(elementalists).or(ritualists).or(paragons) }
  scope :backliners, -> { monks.or(ritualists) }

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |player|
      player.email = auth.uid + '@gwrank.com'
      player.password = Devise.friendly_token[0, 20]
      player.username = auth.info.name
      player.image_url = auth.info.image
      # If you are using confirmable and the provider(s) you use validate emails, 
      # uncomment the line below to skip the confirmation emails.
      # player.skip_confirmation!
    end
  end

  def afk_registration
    afk_registrations.order(unregistered_at: :desc).first
  end

  def afk_registrations
    registrations.afk_registrations
  end

  def current_registration
    current_registrations.order(registered_at: :desc).first
  end

  def current_registrations
    registrations.current_registrations
  end

  def has_afk_registration?
    afk_registrations.any?
  end

  def has_current_registration?
    current_registrations.any?
  end

  def historic_guilds
    historic_guilds_distinct.to_a
  end

  def historic_guilds_distinct
    # Guilds the player has played with based on their team_players
    # Player -> team_players -> team -> guild
    # Get guild IDs from teams that have team_players for this player
    Guild.where(id: Team.joins(:team_players)
                      .where(team_players: { player_id: id })
                      .distinct(:guild_id)
                      .pluck(:guild_id))
       .order(name: :asc)
  end

  def matches_with_stats_count
    matches.with_stats.count
  end

  def name
    igname.present? ? igname : username
  end

  def notifications_count
    counter = 0
    counter += 1 unless characters.any?
    counter += 1 unless guild_id.present?
    counter += 1 if professions.empty?
    counter
  end

  def professions
    professions = []
    professions << :warrior if is_warrior?
    professions << :ranger if is_ranger?
    professions << :monk if is_monk?
    professions << :necromancer if is_necromancer?
    professions << :mesmer if is_mesmer?
    professions << :elementalist if is_elementalist?
    professions << :assassin if is_assassin?
    professions << :ritualist if is_ritualist?
    professions << :paragon if is_paragon?
    professions << :dervish if is_dervish?
    professions
  end

  def professions_short_text
    p = []
    professions.each do |profession_sym|
      p << Profession.find_by(name: profession_sym.to_s.capitalize)&.name
    end
    p.join(', ')
  end

  def professions_text
    p = []
    professions.each do |profession_sym|
      p << Profession.find_by(name: profession_sym.to_s.capitalize)&.short_name
    end
    p.join(', ')
  end

  def verification_status
    is_verified? ? 'Verified' : 'Unverified'
  end

  def prepare_stats!
    set_professions_from_team_players
    set_average_warrior_cpm_from_team_player_stats
    set_average_dpm_from_team_player_stats
    set_average_dmg_per_game
    set_average_deaths_per_game
    set_kd_ratio
    set_average_team_elo
    set_average_opponent_elo
    save!
  end

  def set_average_warrior_cpm_from_team_player_stats
    average_warrior_cpms = team_player_stats.where(stat_key: 'average_warrior_cpm')
    return unless average_warrior_cpms
    return if average_warrior_cpms.count < 2

    self.average_warrior_cpm = average_warrior_cpms.sum(:stat_value).to_f / average_warrior_cpms.count.to_f
    self
  end

  def set_average_dpm_from_team_player_stats
    average_dpms = team_player_stats.where(stat_key: 'average_dpm')
    return unless average_dpms && average_dpms.any?

    self.average_dpm = average_dpms.sum(:stat_value).to_f / average_dpms.count.to_f
    self
  end

  def set_average_dmg_per_game
    return if matches_with_stats_count == 0

    total_damage = 0
    team_players.each do |tp|
      total_damage += tp.team_player_stats.where(stat_key: 'total_damage_dealt').sum(:stat_value).to_i
    end

    self.average_dmg_per_game = total_damage.to_f / matches_with_stats_count.to_f
    self
  end

  def set_average_deaths_per_game
    return if matches_with_stats_count == 0

    total_deaths = 0
    team_players.each do |tp|
      total_deaths += tp.team_player_stats.where(stat_key: 'total_deaths').sum(:stat_value).to_i
    end

    self.average_deaths_per_game = total_deaths.to_f / matches_with_stats_count.to_f
    self
  end

  def set_kd_ratio
    total_kills = 0
    total_deaths = 0

    team_players.each do |tp|
      total_kills += tp.team_player_stats.where(stat_key: 'total_kills').sum(:stat_value).to_f
      total_deaths += tp.team_player_stats.where(stat_key: 'total_deaths').sum(:stat_value).to_f
    end

    # Avoid divide by zero
    self.kd_ratio = total_deaths > 0 ? (total_kills / total_deaths) : total_kills.to_f
    self
  end

  def set_average_team_elo
    team_elos = team_player_stats.where(stat_key: 'team_elo_at_match')
    return unless team_elos && team_elos.any?

    self.average_team_elo = (team_elos.sum(:stat_value) / team_elos.count).round
    self
  end

  def set_average_opponent_elo
    opponent_elos = team_player_stats.where(stat_key: 'opponent_elo_at_match')
    return unless opponent_elos && opponent_elos.any?

    self.average_opponent_elo = (opponent_elos.sum(:stat_value) / opponent_elos.count).round
    self
  end

  def set_professions_from_team_players
    return if team_players.empty?

    team_players.each do |team_player|
      # Update the player's profession boolean fields based on the profession name
      profession_name = team_player.profession.name&.downcase
      case profession_name
      when 'warrior'
        self.is_warrior = true
      when 'ranger'
        self.is_ranger = true
      when 'monk'
        self.is_monk = true
      when 'necromancer'
        self.is_necromancer = true
      when 'mesmer'
        self.is_mesmer = true
      when 'elementalist'
        self.is_elementalist = true
      when 'assassin'
        self.is_assassin = true
      when 'ritualist'
        self.is_ritualist = true
      when 'paragon'
        self.is_paragon = true
      when 'dervish'
        self.is_dervish = true
      end
    end

    self
  end

  private

  # Ensure anonymization_seed exists for consistent name swapping
  def ensure_anonymization_seed
    self.anonymization_seed = SecureRandom.hex(16) if anonymization_seed.blank?
  end

  # Generate anonymization_seed if not present
  def generate_anonymization_seed
    self.anonymization_seed = SecureRandom.hex(16) if anonymization_seed.blank?
  end
end
