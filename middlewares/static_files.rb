require 'rack'


class StaticFiles
  def initialize(app)
    @app = app
  end

  def call(env)
    request_path = env["REQUEST_PATH"]

    if request_path == "/openapi.yaml"
      status, headers, response = @app.call(env)
      headers.delete("Cache-Control")
      return [status, headers, response]
    end

    if request_path == "/AUTHORS"
      response = Rack::Response.new
      response["content-type"] = "text/plain"
      response["cache-control"] = "public, max-age=86400"

      file_path = File.expand_path("AUTHORS", __dir__)
      if File.exist?(file_path)
        response.write(File.read(file_path))
        response.status = 200
      else
        response.write({ error: "File not found" }.to_json)
        response["Content-Type"] = "application/json"
        response.status = 404
      end

      return response.finish
    end

    @app.call(env)
  end
end
