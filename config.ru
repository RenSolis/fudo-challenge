# frozen_string_literal: true

require "rack"
require "json"
require "bcrypt"
require "jwt"
require_relative "middlewares/gzip_compression"
require_relative "middlewares/authorization"

JWT_SECRET = "static_secret_key" # save in environment variable

users = [
  { username: "rensolis", password: BCrypt::Password.create("password123") }
]
products = []

app = Rack::Builder.new do
  use GzipCompression

  map "/api/v1/sessions" do
    run Proc.new { |env|
      request = Rack::Request.new(env)
      response = Rack::Response.new
      response["content-type"] = "application/json"

      data = JSON.parse(request.body.read)
      username = data["username"]
      password = data["password"]

      user = users.find { |u| u[:username] == username }

      if user && BCrypt::Password.new(user[:password]) == password
        payload = { username: username, exp: Time.now.to_i + 3600 }
        token = JWT.encode(payload, JWT_SECRET, "HS256")

        response.write({ token: token }.to_json)
        response.status = 200
      else
        response.write({ error: "Invalid username or password" }.to_json)
        response.status = 401
      end

      response.finish
    }
  end

  map "/api/v1/products" do
    use Authorization

    run Proc.new { |env|
      request = Rack::Request.new(env)
      response = Rack::Response.new
      response["content-type"] = "application/json"

      case request.request_method
      when "GET"
        response.write(products.to_json)
        response.status = 200
      when "POST"

        data = JSON.parse(request.body.read)

        Thread.new do
          sleep 5

          new_product = {
            id: products.size + 1,
            name: data["name"],
            price: data["price"]
          }

          products << new_product
        end

        response.write({ message: "Product creation in progress" }.to_json)
        response.status = 202
      else
        response.write({ error: "Method not allowed" }.to_json)
        response.status = 405
      end

      response.finish
    }
  end

  run Proc.new { |env|
    response = Rack::Response.new
    response["content-type"] = "application/json"
    response.write({ error: "Not found" }.to_json)
    response.status = 404
    response.finish
  }
end

run app
