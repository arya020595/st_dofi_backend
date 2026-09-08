require "test_helper"

class DictionaryTest < ActiveSupport::TestCase
  test "requires the selected family to belong to the selected group" do
    dictionary_group = create(:dictionary_group)
    another_group = create(:dictionary_group)
    dictionary_family = create(:dictionary_family, dictionary_group: another_group)
    dictionary = build(:dictionary, dictionary_group:, dictionary_family:)

    assert_not_predicate dictionary, :valid?
    assert_includes dictionary.errors[:dictionary_family], "must belong to the selected dictionary group"
  end

  test "does not allow moving a family used by species to another group" do
    dictionary = create(:dictionary)
    another_group = create(:dictionary_group)
    dictionary_family = dictionary.dictionary_family

    dictionary_family.dictionary_group = another_group

    assert_not_predicate dictionary_family, :valid?
    assert_includes dictionary_family.errors[:dictionary_group], "cannot change while the family is used by species"
  end
end

# == Schema Information
#
# Table name: dictionaries
# Database name: primary
#
#  id                   :uuid             not null, primary key
#  local_name           :string           not null
#  scientific_name      :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  dictionary_family_id :uuid             not null
#  dictionary_group_id  :uuid             not null
#
# Indexes
#
#  idx_dictionaries_local_name_trgm            (local_name) USING gin
#  idx_dictionaries_scientific_name_trgm       (scientific_name) USING gin
#  index_dictionaries_on_dictionary_family_id  (dictionary_family_id)
#  index_dictionaries_on_dictionary_group_id   (dictionary_group_id)
#  index_dictionaries_on_local_name            (local_name)
#
# Foreign Keys
#
#  fk_rails_...  (dictionary_family_id => dictionary_families.id)
#  fk_rails_...  (dictionary_group_id => dictionary_groups.id)
#
