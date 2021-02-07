class Player < ApplicationRecord
  belongs_to :guild, optional: true
  has_many :registrations
  has_many :team_players
  has_many :teams, through: :team_players

  extend FriendlyId
  friendly_id :username, use: :slugged

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable,
         :omniauthable

  validates_presence_of :password, on: :create
  validates_confirmation_of :password, on: :create
  validates_length_of :password, within: Devise.password_length, allow_blank: true
  validates_uniqueness_of :igname, on: :update

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

  def name
    igname.present? ? igname : username
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

  def professions_text
    professions.join(', ')
  end

  def current_registrations
    registrations.current_registrations
  end

  def current_registration
    current_registrations.first
  end

  def has_current_registration?
    current_registrations.any?
  end
end
