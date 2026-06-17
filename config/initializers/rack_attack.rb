class Rack::Attack
  # Use the Rails cache (Solid Cache) as the throttle store.
  Rack::Attack.cache.store = Rails.cache

  throttle("req/ip", limit: 300, period: 5.minutes, &:ip)

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
