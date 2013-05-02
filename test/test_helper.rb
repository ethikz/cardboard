require 'simplecov'
SimpleCov.start 'rails'

ENV["RAILS_ENV"] = "test"
require File.expand_path('../dummy/config/environment', __FILE__)
require "rails/test_help"

require 'database_cleaner'
require "minitest/autorun"
require "minitest/rails"
require "minitest/rails/capybara"
require 'minitest/unit'
require 'minitest/mock'
require File.expand_path('../factories.rb', __FILE__)

begin; require 'turn/autorun'; rescue LoadError; end

DatabaseCleaner.strategy = :truncation

# Uncomment if you want awesome colorful output
# require "minitest/pride"

class ActiveSupport::TestCase
  include FactoryGirl::Syntax::Methods
end

class ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers
  include Capybara::RSpecMatchers
  include Capybara::DSL
end