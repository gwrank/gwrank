# frozen_string_literal: true

namespace :gwrank do
  task setup: :environment do
    Rake::Task["professions:setup"].invoke
    Rake::Task["skills:setup"].invoke
    Rake::Task["tournaments:setup"].invoke
  end
end
