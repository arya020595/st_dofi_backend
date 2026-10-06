class BruneiIdSessionBlueprint < Blueprinter::Base
  field :status do |session|
    session.key?(:status) ? "fail" : "success"
  end

  field :message, if: ->(_field, session, _options) { session.key?(:message) }
  field :code, if: ->(_field, session, _options) { session.key?(:code) }

  field :data, if: ->(_field, session, _options) { session.key?(:kind) } do |session, options|
    case session[:kind]
    when :mock_status then UserBlueprint.render_as_hash(session.fetch(:user))
    when :mock_dashboard
      { user: UserBlueprint.render_as_hash(session.fetch(:user)) }.merge(dashboard_tokens(options))
    else callback_data(session, options)
    end
  end

  class << self
    private

    def callback_data(session, options)
      data = registration_data(session).merge(profile_data(session.fetch(:ic_number)))
      session[:kind] == :dashboard ? data.merge(dashboard_tokens(options)) : data
    end

    def registration_data(session)
      {
        next_action: session[:kind] == :dashboard ? "dashboard" : "registration_status",
        ic_number: session.fetch(:ic_number),
        registration_status: session[:user]&.lifecycle_status || session.fetch(:kind).to_s
      }.tap do |data|
        data[:user] = UserBlueprint.render_as_hash(session[:user]) if session[:user]
      end
    end

    def dashboard_tokens(options)
      { access_token: options[:access_token] }.merge(options.fetch(:realtime_tokens))
    end

    def profile_data(ic_number)
      claims = Current.brunei_id_claims || {}
      userinfo = Current.brunei_id_userinfo || {}
      full_name = full_name_for(claims) || full_name_for(userinfo)
      {
        full_name:,
        brunei_id_profile: profile_attributes(ic_number, claims, userinfo, full_name).compact,
        brunei_id_token_metadata: (Current.brunei_id_token_metadata || {}).merge(
          "response_keys" => Current.brunei_id_token_response_keys || []
        )
      }.compact
    end

    def profile_attributes(ic_number, claims, userinfo, full_name)
      {
        ic_number:, full_name:,
        given_name: claims["given_name"] || userinfo["given_name"],
        family_name: claims["family_name"] || userinfo["family_name"],
        preferred_username: claims["preferred_username"] || userinfo["preferred_username"],
        subject: claims["sub"]
      }
    end

    def full_name_for(payload)
      payload["full_name"].presence || payload["name"].presence || payload["fullname"].presence
    end
  end
end
