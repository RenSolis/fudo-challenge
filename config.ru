require "rack"
require "json"

products = []

app = Proc.new do |env|
  request = Rack::Request.new(env)
  response = Rack::Response.new

  response["Content-Type"] = "application/json"

  case [request.path, request.request_method]
  when ["/api/v1/sessions", "POST"]
  when ["/api/v1/products", "GET"]
    response.write(products.to_json)
    response.status = 200
  when ["/api/v1/products", "POST"]
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
    response.write({ error: "Not found" }.to_json)
    response.status = 404
  end

  response.finish
end

run app
