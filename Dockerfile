FROM ruby:3.2

RUN apt-get update -qq

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

EXPOSE 9292

CMD ["rackup", "-o", "0.0.0.0", "-p", "9292"]
