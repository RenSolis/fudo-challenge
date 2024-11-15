# frozen_string_literal: true

require "jwt"

class Authorization
  JWT_SECRET = "static_secret_key" # save in environment variable

  def initialize(app)
    @app = app
  end

  def call(env)
    request = Rack::Request.new(env)
    auth_header = request.env["HTTP_AUTHORIZATION"]

    if auth_header && auth_header.start_with?("Bearer ")
      token = auth_header.split(" ")[1]

      begin
        JWT.decode(token, JWT_SECRET, true, { algorithm: "HS256" })
        @app.call(env)
      rescue JWT::DecodeError
        [401, { "content-type" => "application/json" }, [{ error: "Invalid or expired token" }.to_json]]
      end
    else
      [401, { "content-type" => "application/json" }, [{ error: "Authorization header missing or invalid" }.to_json]]
    end
  end
end
