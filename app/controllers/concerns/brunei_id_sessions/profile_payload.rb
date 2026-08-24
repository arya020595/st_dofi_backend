module BruneiIdSessions
  module ProfilePayload
    extend ActiveSupport::Concern

    def registration_callback_extras(verified_ic_number, _audience)
      brunei_id_profile_response(verified_ic_number)
    end

    def brunei_id_profile_response(verified_ic_number)
      {
        full_name: brunei_id_full_name,
        brunei_id_profile: brunei_id_profile_payload(verified_ic_number),
        brunei_id_token_metadata: brunei_id_token_metadata_payload
      }.compact
    end

    def brunei_id_full_name
      claims_full_name || userinfo_full_name
    end

    def brunei_id_profile_payload(verified_ic_number)
      claims = Current.brunei_id_claims || {}
      userinfo = Current.brunei_id_userinfo || {}
      brunei_id_profile_attributes(verified_ic_number, claims, userinfo).compact
    end

    def brunei_id_profile_attributes(verified_ic_number, claims, userinfo)
      {
        ic_number: verified_ic_number,
        full_name: brunei_id_full_name,
        given_name: claims["given_name"] || userinfo["given_name"],
        family_name: claims["family_name"] || userinfo["family_name"],
        preferred_username: claims["preferred_username"] || userinfo["preferred_username"],
        subject: claims["sub"]
      }
    end

    def claims_full_name
      lookup_full_name(Current.brunei_id_claims || {})
    end

    def userinfo_full_name
      lookup_full_name(Current.brunei_id_userinfo || {})
    end

    def lookup_full_name(payload)
      payload["full_name"].presence || payload["name"].presence || payload["fullname"].presence
    end

    def brunei_id_token_metadata_payload
      (Current.brunei_id_token_metadata || {}).merge(
        "response_keys" => Current.brunei_id_token_response_keys || []
      )
    end
  end
end
