module Rocbn
  # A registry text column that reads back as nil when it only holds one of the registry's "not provided" markers.
  # The registry fills missing address and contact values with these instead of leaving them empty; passing them on
  # would autofill "-" into fields the Add Profiling form requires, so the officer would never be asked for them.
  class NotProvidedText < ActiveModel::Type::String
    MARKERS = ["-", "n/a", "not specified"].freeze

    def deserialize(value)
      text = super&.strip
      text unless text.blank? || MARKERS.include?(text.downcase)
    end
  end
end
