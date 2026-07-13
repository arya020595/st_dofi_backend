module Api
  module V1
    module CompanyProfiles
      class ContactsController < ApplicationController
        before_action :set_company_profile
        before_action :set_contact, only: %i[update destroy]

        def create
          authorize CompanyProfileContact

          case CompanyProfileContacts::Create.call(@company_profile, contact_params)
          in Success(contact)
            render json: { status: "success", data: CompanyProfileContactBlueprint.render_as_hash(contact) },
                   status: :created
          in Failure(contact)
            render json: { status: "fail", errors: contact.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          authorize @contact

          case CompanyProfileContacts::Update.call(@contact, contact_params)
          in Success(contact)
            render json: { status: "success", data: CompanyProfileContactBlueprint.render_as_hash(contact) }
          in Failure(contact)
            render json: { status: "fail", errors: contact.errors.full_messages }, status: :unprocessable_content
          end
        end

        def destroy
          authorize @contact

          if @contact.discard
            render json: { status: "success", message: "Contact removed." }
          else
            render json: { status: "fail", errors: @contact.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def set_company_profile
          @company_profile = policy_scope(CompanyProfile).find(params.expect(:company_profile_id))
        end

        def set_contact
          @contact = @company_profile.contacts.kept.find(params.expect(:id))
        end

        def contact_params
          params.expect(contact: %i[full_name gender ic_no ic_colour designation])
        end
      end
    end
  end
end
