# frozen_string_literal: true

require "vagrant"
require_relative "version"
require_relative "config"
require_relative "command"
require_relative "helpers"

module VagrantDockerCertificatesManager
  class Plugin < Vagrant.plugin("2")
    name "docker_certificates"

    UiHelpers.setup_i18n!

    config(:docker_certificates) do
      require_relative "config"
      VagrantDockerCertificatesManager::Config
    end

    command("certs") { Command }

    action_hook(:install_cert_on_up, :machine_action_up) do |hook|
      require_relative "actions/install"
      hook.after Vagrant::Action::Builtin::Provision, Actions::Install
    end

    action_hook(:uninstall_cert_on_destroy, :machine_action_destroy) do |hook|
      require_relative "actions/uninstall"
      hook.before Vagrant::Action::Builtin::GracefulHalt, Actions::Uninstall
    end
  end
end
