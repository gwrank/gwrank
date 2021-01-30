class Registration < ApplicationRecord
  belongs_to :player

  scope :current_registrations, -> { where('registered_at > ?', DateTime.now - 1.hour).where(unregistered_at: nil) }
end
