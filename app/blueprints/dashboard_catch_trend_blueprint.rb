class DashboardCatchTrendBlueprint < Blueprinter::Base
  field(:granularity) { |data| data[:granularity] }

  field :buckets do |data|
    data[:buckets].map do |bucket|
      bucket.merge(total_catch_kg: bucket[:total_catch_kg].to_f.round(3))
    end
  end
end
