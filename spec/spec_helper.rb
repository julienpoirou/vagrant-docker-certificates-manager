# frozen_string_literal: true

require "rspec"

ENV["VDCM_TEST_NO_PLUGIN"] = "1"

ENV["VDCM_LANG"]     = "en"
ENV["VDCM_NO_EMOJI"] = "1"

require_relative "../lib/vagrant-docker-certificates-manager/version"
require_relative "../lib/vagrant-docker-certificates-manager/helpers"
require_relative "../lib/vagrant-docker-certificates-manager/util/cert"
require_relative "../lib/vagrant-docker-certificates-manager/util/registry"
require_relative "../lib/vagrant-docker-certificates-manager/util/os"

RSpec.configure do |config|
  config.order = :random
end
