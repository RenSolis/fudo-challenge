# frozen_string_literal: true

require "zlib"

class GzipCompression
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    request = Rack::Request.new(env)

    if request.params["gzip"] == "true"
      compressed_body = compress_body(body.join)
      headers["content-encoding"] = "gzip"
      headers["content-length"] = compressed_body.bytesize.to_s
      body = [compressed_body]
    end

    [status, headers, body]
  end

  private

  def compress_body(body)
    sio = StringIO.new
    gz = Zlib::GzipWriter.new(sio)
    gz.write(body)
    gz.close
    sio.string
  end
end
