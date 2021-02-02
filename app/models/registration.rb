class Registration < ApplicationRecord
  belongs_to :player

  scope :current_registrations, -> { where('registered_at > ?', DateTime.now - 4.hours).where(unregistered_at: nil) }
end
