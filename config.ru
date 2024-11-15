# frozen_string_literal: true

require "rack"
require "json"
require "bcrypt"
require "jwt"
require "securerandom"
require_relative "middlewares/gzip_compression"
require_relative "middlewares/authorization"
require_relative "middlewares/static_files"


JWT_SECRET = "static_secret_key" # save in environment variable

users = [
  { username: "rensolis", password: BCrypt::Password.create("password123") }
]
products = []
product_jobs = {}

app = Rack::Builder.new do
  use Rack::Static, urls: ["/openapi.yaml", "/AUTHORS"], root: "."
  use StaticFiles
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
        job_id = SecureRandom.uuid

        product_jobs[job_id] = { status: "pending" }

        Thread.new do
          sleep 5

          errors = {}

          if !data["name"]
            errors["name"] = "Nombre en blanco"
          end

          if !data["price"]
            errors["price"] = "Precio en blanco"
          end

          if errors.keys.length > 0
            product_jobs[job_id][:status] = "failed"
            product_jobs[job_id][:errors] = errors
          else
            new_product = {
              id: products.size + 1,
              name: data["name"],
              price: data["price"]
            }

            products << new_product
            product_jobs[job_id][:status] = "completed"
            product_jobs[job_id][:product] = new_product
          end
        end

        response.write({ job_id: job_id }.to_json)
        response.status = 202
      else
        response.write({ error: "Method not allowed" }.to_json)
        response.status = 405
      end

      response.finish
    }
  end

  map "/api/v1/jobs" do
    use Authorization

    run Proc.new { |env|
      request = Rack::Request.new(env)
      response = Rack::Response.new
      response["content-type"] = "application/json"

      job_id = request.params["job_id"]
      job = product_jobs[job_id]

      if job
        response.write(job.to_json)
        response.status = 200
      else
        response.write({ error: "Job not found" }.to_json)
        response.status = 404
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
