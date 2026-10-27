class Rack::Attack
  # Use the Rails cache (Solid Cache) as the throttle store.
  Rack::Attack.cache.store = Rails.cache

  ATTACHMENTS_PATH = "/api/v1/attachments/".freeze

  # A list page loads one authenticated request per thumbnail, so files get their own, higher limit and do not
  # use up the general budget.
  throttle("req/ip", limit: 300, period: 5.minutes) do |req|
    req.ip unless req.path.start_with?(ATTACHMENTS_PATH)
  end

  throttle("attachments/ip", limit: 1500, period: 5.minutes) do |req|
    req.ip if req.path.start_with?(ATTACHMENTS_PATH)
  end

  throttle("logins/ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path == "/api/v1/auth/sign_in" && req.post?
  end
end

Rack::Attack.throttled_responder = lambda do |_request|
  [
    429,
    { "Content-Type" => "application/json" },
    [{ status: "fail", message: "Too many requests. Please try again later." }.to_json]
  ]
end
