# frozen_string_literal: true

require "rake"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

YARD_RUNNER = [
  "bundle exec ruby",
  "-ryard/core_ext/array",
  "-ryard/core_ext/file",
  "-ryard/core_ext/hash",
  "-ryard/core_ext/insertion",
  "-ryard/core_ext/module",
  "-ryard/core_ext/string",
  "-ryard/core_ext/symbol_hash",
  "-e \"ARGV.unshift('doc', '--quiet'); load Gem.bin_path('yard', 'yard')\""
].join(" ")

desc "Generate RubyDoc/YARD documentation"
task :doc do
  sh YARD_RUNNER
end

task default: :spec
