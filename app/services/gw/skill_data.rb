module GW
  class SkillData
    DATA_PATH = Rails.root.join("data", "skills", "data.json")
    DESC_PATH = Rails.root.join("data", "skills", "desc.json")

    Skill = Struct.new(:id, :name, :description, :is_elite, :profession, :energy, :activation, :recharge, :adrenaline, keyword_init: true) do
      FRACTIONS = { 0.25 => "¼", 0.5 => "½", 0.75 => "¾" }.freeze

      def cost_badge
        [
          (energy.positive? ? "⚡#{energy}" : nil),
          (adrenaline.positive? ? "🔺#{adrenaline}" : nil),
          (activation.positive? ? "⏱#{format_time(activation)}" : nil),
          (recharge.positive? ? "🔄#{recharge}" : nil)
        ].compact.join(" ")
      end

      private

      def format_time(value)
        return FRACTIONS[value] if FRACTIONS.key?(value)

        (value % 1).zero? ? value.to_i.to_s : value.to_s
      end
    end

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
          balance = meta["pvp_split"] ? (data[meta["split_id"].to_s] || meta) : meta
          description = entry["description"]
          if meta["pvp_split"]
            pvp_entry = desc[meta["split_id"].to_s]
            description = pvp_entry["description"] if pvp_entry
          end

          hash[id] = Skill.new(
            id: id.to_i,
            name: entry["name"],
            description: description,
            is_elite: meta["is_elite"] || false,
            profession: meta["profession"],
            energy: balance["energy"] || 0,
            activation: balance["activation"] || 0,
            recharge: balance["recharge"] || 0,
            adrenaline: balance["adrenaline"] || 0
          )
        end
      end
    end
  end
end
