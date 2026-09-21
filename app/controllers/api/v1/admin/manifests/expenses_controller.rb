module Api
  module V1
    module Admin
      module Manifests
        class ExpensesController < ApplicationController
          include ::Manifests::ExpenseReadable
        end
      end
    end
  end
end
