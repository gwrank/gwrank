namespace :tournaments do
  task add_archives: :environment do
    (2008..2010).each do |year|
      (1..12).each do |month|
        next if year == 2010 && month > 7
        Tournament.create(year: year, month: month)
      end
    end
  end
end
