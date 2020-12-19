module ApplicationHelper
  def today_scrim_registration_time
    now = DateTime.now
    now.change(hour: scrim_hour_for(now.wday))
  end

  def today_scrim_end_registration_time
    today_scrim_registration_time + 1.hour
  end

  def tomorrow_scrim_registration_time
    DateTime.now.tomorrow.change(hour: scrim_hour_for(Date.tomorrow.wday))
  end

  private

  def scrim_hour_for(wday)
    case wday
    when 1, 5 # monday, friday
      23
    when 2, 4, 6 # tuesday, thirsday, saturday
      1
    when 3, 7 # wednesday, sunday
      21
    end
  end
end
