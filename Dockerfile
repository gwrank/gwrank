# Use official Ruby image
FROM ruby:3.4.8-slim

# Install dependencies required for Rails
RUN apt-get update -qq && \
    apt-get install -y \
    build-essential \
    curl \
    git \
    libpq-dev \
    libvips \
    libyaml-dev \
    nodejs \
    npm \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Install Yarn
RUN npm install -g yarn

# Set working directory
WORKDIR /rails

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy package.json and install node packages
COPY package.json yarn.lock ./
RUN yarn install

# Copy the rest of the application
COPY . .

# Precompile assets
RUN yarn build && yarn build:css

# Add a script to be executed every time the container starts
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh
ENTRYPOINT ["entrypoint.sh"]

# Expose port 3000
EXPOSE 3000

# Start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
