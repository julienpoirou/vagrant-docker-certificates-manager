# frozen_string_literal: true

require "rspec"
require_relative "../lib/vagrant-docker-certificates-manager/util/os"

RSpec.describe VagrantDockerCertificatesManager::OS do
  it "builds linux firefox profiles list without raising" do
    allow(Dir).to receive(:home).and_return(Dir.home)
    expect { described_class.linux_firefox_profiles }.not_to raise_error
  end
end
