module IcNumbers
  class Normalize
    def self.call(value)
      value.to_s.gsub(/[^a-zA-Z0-9]/, "").upcase
    end
  end
end
