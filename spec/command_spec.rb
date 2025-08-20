# frozen_string_literal: true

require "rspec"
require_relative "../lib/vagrant-docker-certificates-manager/command"
require_relative "../lib/vagrant-docker-certificates-manager/util/registry"

RSpec.describe VagrantDockerCertificatesManager::Command do
  let(:ui){ double("ui", info: nil, warn: nil, error: nil) }
  let(:env){ double("env", ui: ui) }
  let(:instance){ described_class.new(env, []) }

  before do
    allow(VagrantDockerCertificatesManager::Registry).to receive(:all).and_return({})
    allow(VagrantDockerCertificatesManager::Registry).to receive(:track)
    allow(VagrantDockerCertificatesManager::Registry).to receive(:untrack).and_return(true)
  end

  it "shows help when no subcommand" do
    expect(ui).to receive(:info).at_least(:once)
    instance.execute
  end

  it "errors on add with missing file" do
    allow(instance).to receive(:parse_options).and_return(["add"])
    expect(ui).to receive(:error).with(include("Invalid"))
    instance.execute
  end

  it "errors on remove with no path" do
    allow(instance).to receive(:parse_options).and_return(["remove"])
    expect(ui).to receive(:error).with(include("must provide"))
    instance.execute
  end
end
