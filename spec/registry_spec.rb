# frozen_string_literal: true

require "rspec"
require_relative "../lib/vagrant-docker-certificates-manager/util/registry"

RSpec.describe VagrantDockerCertificatesManager::Registry do
  it "tracks and untracks entries" do
    fp = "ABC123"
    allow(Dir).to receive(:home).and_return(Dir.pwd)
    described_class.track(fp, { "path" => "/x", "name" => "n", "os" => "linux" })
    expect(described_class.all).to have_key(fp)
    expect(described_class.untrack(fp)).to be(true)
  end
end
