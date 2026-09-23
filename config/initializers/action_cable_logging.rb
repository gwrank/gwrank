require Rails.root.join("app/channels/application_cable/logging_boundary").to_s

Rails.application.config.after_initialize do
  ApplicationCable::LoggingBoundary.install!
end
