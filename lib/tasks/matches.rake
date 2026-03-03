namespace :matches do
  task prepare_stats: :environment do
    Match.all.find_each(&:prepare_stats!)
  end
end
