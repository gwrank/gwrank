module GW
  class Attributes
    PATH = Rails.root.join("data", "code_attributes.txt")

    class << self
      def name_for(id)
        names[id.to_i]
      end

      private

      def names
        @names || mutex.synchronize { @names ||= build_names }
      end

      def mutex
        @mutex ||= Mutex.new
      end

      def build_names
        File.read(PATH).each_line.each_with_object({}) do |line, hash|
          id, name = line.strip.split(" ", 2)
          hash[id.to_i] = name
        end
      end
    end
  end
end
