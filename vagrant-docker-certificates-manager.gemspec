# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "vagrant-docker-certificates-manager"
  s.version     = File.read(File.join(__dir__, "lib/vagrant-docker-certificates-manager/VERSION")).strip
  s.summary = "Manages installation/uninstallation of a local CA in system " \
              "stores and browsers (macOS/Linux/Windows)."
  s.description = "Vagrant plugin that installs a local certificate authority " \
                  "(Root CA) on the host machine, with NSS support " \
                  "(Firefox/Chromium). CLI command `vagrant cert`."
  s.authors     = ["Julien Poirou"]
  s.email       = ["julienpoirou@protonmail.com"]
  s.homepage    = "https://github.com/julienpoirou/vagrant-docker-certificates-manager"
  s.license     = "MIT"

  s.required_ruby_version = ">= 3.1"

  s.files = Dir[
    "lib/**/*",
    "locales/*.yml",
    "README.md",
    "LICENSE.md",
    "CHANGELOG.md"
  ]
  s.require_paths = ["lib"]

  s.add_dependency "i18n", ">= 1.8"

  s.add_development_dependency "rspec", "~> 3.12"
  s.add_development_dependency "rake", "~> 13.0"

  s.metadata = {
    "rubygems_mfa_required" => "true",
    "bug_tracker_uri" => "https://github.com/julienpoirou/vagrant-docker-certificates-manager/issues",
    "changelog_uri" => "https://github.com/julienpoirou/vagrant-docker-certificates-manager/blob/main/CHANGELOG.md",
    "source_code_uri" => "https://github.com/julienpoirou/vagrant-docker-certificates-manager",
    "homepage_uri" => "https://github.com/julienpoirou/vagrant-docker-certificates-manager"
  }
end
