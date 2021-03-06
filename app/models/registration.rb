class Registration < ApplicationRecord
  belongs_to :player

  scope :current_registrations, -> { where('registered_at > ?', DateTime.now - 8.hours).where(unregistered_at: nil) }
  scope :afk_registrations, -> { where('registered_at > ?', DateTime.now - 8.hours).where.not(unregistered_at: nil) }
end
