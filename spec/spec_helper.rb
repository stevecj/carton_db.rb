# -*- coding: UTF-8 -*-
require "bundler/setup"
require "carton_db"

gem 'rspec-prof'
require 'rspec-prof'

SPEC_ROOT = File.dirname(__FILE__)
PROJECT_ROOT = File.dirname(SPEC_ROOT)
TEMP_DIR = File.join(PROJECT_ROOT, 'tmp')

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
