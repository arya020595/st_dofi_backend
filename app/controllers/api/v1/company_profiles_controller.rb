module Api
  module V1
    class CompanyProfilesController < ApplicationController
      include RansackSearchable

      before_action :set_company_profile, only: %i[show update destroy]

      def index
        authorize CompanyProfile
        result = apply_ransack_search(policy_scope(CompanyProfile), default_sort: "created_at desc")
        pagy, records = pagy(:offset, result)
        render json: { status: "success", data: CompanyProfileDetailBlueprint.render_as_hash(records),
                       meta: pagination_meta(pagy) }
      end

      def show
        authorize @company_profile
        render json: { status: "success", data: CompanyProfileDetailBlueprint.render_as_hash(@company_profile) }
      end

      def create
        authorize CompanyProfile

        case ::CompanyProfiles::Create.call(create_params)
        in Success(result)
          render json: { status: "success", data: create_response_data(result) }, status: :created
        in Failure(profile)
          render json: { status: "fail", errors: profile.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        authorize @company_profile

        case ::CompanyProfiles::Update.call(@company_profile, company_profile_params)
        in Success(profile)
          render json: { status: "success", data: CompanyProfileDetailBlueprint.render_as_hash(profile) }
        in Failure(profile)
          render json: { status: "fail", errors: profile.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        authorize @company_profile

        case ::CompanyProfiles::Destroy.call(@company_profile)
        in Success(_profile)
          render json: { status: "success", message: "Profiling entry removed." }
        in Failure(profile)
          render json: { status: "fail", errors: profile.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def create_response_data(result)
        { company_profile: CompanyProfileDetailBlueprint.render_as_hash(result.company_profile),
          owner_profile: CompanyProfileContactBlueprint.render_as_hash(result.owner),
          admin_profile: result.admin && CompanyProfileContactBlueprint.render_as_hash(result.admin) }
      end

      def set_company_profile
        @company_profile = policy_scope(CompanyProfile).find(params.expect(:id))
      end

      def company_profile_params
        params.expect(company_profile: %i[registration_type company_name company_address rocbn_no contact_no
                                          district mukim village fisherman_card_no issue_date license_expiry_date
                                          worker_quota])
      end

      def create_params
        params.expect(company_profile: %i[registration_type company_name company_address rocbn_no contact_no
                                          district mukim village fisherman_card_no issue_date license_expiry_date
                                          worker_quota] +
                                        [{ owner: %i[full_name gender ic_no ic_colour],
                                           admin: %i[full_name gender ic_no ic_colour] }])
      end
    end
  end
end
