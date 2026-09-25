module BruneiIdSessions
  module CallbackRendering
    extend ActiveSupport::Concern

    def render_callback_for(user, verified_ic_number:)
      return render_callback_dashboard(user, verified_ic_number) if user&.active?

      render_login_unauthorized(verified_ic_number)
    end

    def render_fisherman_callback(verified_ic_number)
      result = ::Fisherman::Authenticate.call(verified_ic_number: verified_ic_number)
      return render_callback_dashboard(result.value!, verified_ic_number) if result.success?

      render_login_unauthorized(verified_ic_number)
    end
  end
end
