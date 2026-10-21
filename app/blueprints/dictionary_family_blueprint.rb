class DictionaryFamilyBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :dictionary_group_id, :created_at, :updated_at

  association :dictionary_group, blueprint: DictionaryGroupBlueprint
end
