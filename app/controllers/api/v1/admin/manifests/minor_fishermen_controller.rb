module Api
  module V1
    module Admin
      module Manifests
        class MinorFishermenController < ApplicationController
          include ::Manifests::MinorFishermenReadable

          private

          def manifest_policy_class = ManifestApprovalPolicy
          def manifest_policy_scope_class = ManifestApprovalPolicy::Scope
        end
      end
    end
  end
end
