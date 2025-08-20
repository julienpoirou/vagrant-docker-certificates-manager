# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "vagrant-docker-certificates-manager" do
  it "has a version" do
    require_relative "../lib/vagrant-docker-certificates-manager/version"
    expect(VagrantDockerCertificatesManager::VERSION).to match(/\d+\.\d+\.\d+/)
  end
end
