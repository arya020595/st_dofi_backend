FactoryBot.define do
  factory :dictionary do
    sequence(:local_name) { |n| "Ikan #{n}" }
    scientific_name { "Species scientificus" }
  end
end
