require "test_helper"
require "tmpdir"

class SkillsTasksTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks
  end

  test "update_campaigns reads the data file" do
    mist_form = skills(:mist_form)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "campaigns.txt")
      File.write(path, "#{mist_form.skill_id} Factions\n")
      ENV["CAMPAIGNS_FILE"] = path
      Rake::Task["skills:update_campaigns"].reenable
      capture_io { Rake::Task["skills:update_campaigns"].invoke }
      assert_equal "Factions", mist_form.reload.campaign
    end
  ensure
    ENV.delete("CAMPAIGNS_FILE")
  end
end
