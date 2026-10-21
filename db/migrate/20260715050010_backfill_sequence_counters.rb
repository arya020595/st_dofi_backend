class BackfillSequenceCounters < ActiveRecord::Migration[8.1]
  class Manifest < ActiveRecord::Base; end
  class SequenceCounter < ActiveRecord::Base; end

  # Seeds sequence_counters with the highest number already issued under the old MAX(...)+1
  # scheme, per (key, period-prefix), so SequenceGenerator continues from where that scheme left
  # off instead of restarting at 1 and colliding with already-issued numbers.
  def up
    backfill(Manifest, :manifest_number, key: "manifest_number", prefix_pattern: /\ADOF-\d{8}-(\d+)\z/,
                                         prefix_length: "DOF-YYYYMMDD-".length)
  end

  def down
    SequenceCounter.where("key LIKE 'manifest_number:%'").delete_all
  end

  private

  def backfill(model, column, key:, prefix_pattern:, prefix_length:)
    values = model.where.not(column => nil).pluck(column)
    max_by_prefix = values.each_with_object({}) do |value, memo|
      match = prefix_pattern.match(value)
      next unless match

      prefix = value[0, prefix_length]
      number = match[1].to_i
      memo[prefix] = number if number > memo[prefix].to_i
    end

    max_by_prefix.each do |prefix, max|
      SequenceCounter.create!(key: "#{key}:#{prefix}", value: max)
    end
  end
end
