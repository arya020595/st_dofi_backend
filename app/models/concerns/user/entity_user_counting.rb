module User::EntityUserCounting
  extend ActiveSupport::Concern

  included do
    after_create :increment_company_profile_entity_user_count, if: -> { company_profile_id.present? }
    after_discard :decrement_company_profile_entity_user_count, if: -> { company_profile_id.present? }
    after_undiscard :increment_company_profile_entity_user_count, if: -> { company_profile_id.present? }
  end

  private

  # increment!/decrement! deliberately skip company_profile's own validations: an unrelated data
  # issue on that record must never block a user's create/discard, since this is just a counter.
  def increment_company_profile_entity_user_count
    company_profile.increment!(:entity_user_count) # rubocop:disable Rails/SkipsModelValidations
  end

  def decrement_company_profile_entity_user_count
    company_profile.decrement!(:entity_user_count) # rubocop:disable Rails/SkipsModelValidations
  end
end
