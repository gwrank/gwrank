module GW
  class SkillData
    DATA_PATH = Rails.root.join("data", "skills", "data.json")
    DESC_PATH = Rails.root.join("data", "skills", "desc.json")

    Skill = Struct.new(:id, :name, :description, :is_elite, :profession, keyword_init: true)

    class << self
      def find(id)
        skills[id.to_s]
      end

      private

      def skills
        @skills || mutex.synchronize { @skills ||= build_skills }
      end

      def mutex
        @mutex ||= Mutex.new
      end

      def build_skills
        data = JSON.parse(File.read(DATA_PATH))["skilldata"]
        desc = JSON.parse(File.read(DESC_PATH))["skilldesc"]

        desc.each_with_object({}) do |(id, entry), hash|
          meta = data[id] || {}
          hash[id] = Skill.new(
            id: id.to_i,
            name: entry["name"],
            description: entry["description"],
            is_elite: meta["is_elite"] || false,
            profession: meta["profession"]
          )
        end
      end
    end
  end
end
