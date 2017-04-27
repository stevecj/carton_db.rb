# coding: utf-8
require "bundler/gem_tasks"
require "rspec/core/rake_task"

namespace :spec do

  desc 'Run all RSpec code examples'
  RSpec::Core::RakeTask.new(:all)

  desc 'Run RSpec code examples except those tagged as slow'
  RSpec::Core::RakeTask.new(:fast) do |t|
    t.rspec_opts = '--tag ~slow'
  end

  desc 'Run RSpec code examples that are tagged as slow'
  RSpec::Core::RakeTask.new(:slow) do |t|
    t.rspec_opts = '--tag slow'
  end

end

task :default => 'spec:all'
