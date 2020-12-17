class Player < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable,
         :omniauthable

  validates_presence_of :password, on: :create
  validates_confirmation_of :password, on: :create
  validates_length_of :password, within: Devise.password_length, allow_blank: true
  validates_uniqueness_of :igname, on: :update

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
end
