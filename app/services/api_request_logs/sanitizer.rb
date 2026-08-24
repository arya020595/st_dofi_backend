module ApiRequestLogs
  class Sanitizer
    class << self
      def filter(payload)
        normalized = normalize(payload)
        return if normalized.nil?

        parameter_filter.filter(normalized)
      end

      def masked_ic_number(ic_number)
        return if ic_number.blank?

        prefix = ic_number.to_s.split("-").first
        "#{prefix}-xxxxxx"
      end

      private

      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end

      def normalize(payload)
        case payload
        when ActionController::Parameters then payload.to_unsafe_h
        when Hash then payload.deep_dup
        when Array then normalize_array(payload)
        when nil, "" then nil
        else
          payload
        end
      end

      def normalize_array(payload)
        payload.map { |item| normalize(item) }
      end
    end
  end
end
