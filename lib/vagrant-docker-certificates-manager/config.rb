# frozen_string_literal: true

module VagrantDockerCertificatesManager
  class Config < Vagrant.plugin("2", :config)
    attr_accessor :cert_path, :cert_name, :install_on_up, :remove_on_destroy,
                  :manage_firefox, :manage_nss_browsers, :locale, :verbose,
                  :container_name

    def initialize
      @cert_path            = "certs/rootca.cert.pem"
      @cert_name            = "local.dev"
      @install_on_up        = false
      @remove_on_destroy    = false
      @manage_firefox       = false
      @manage_nss_browsers  = true
      @locale               = "en"
      @verbose              = false
      @container_name       = nil
    end

    def finalize!
      @cert_path = @container_name unless @container_name.to_s.strip.empty?
      @install_on_up       = !!@install_on_up
      @remove_on_destroy   = !!@remove_on_destroy
      @manage_firefox      = !!@manage_firefox
      @manage_nss_browsers = !!@manage_nss_browsers
      @verbose             = !!@verbose
      @locale              = (@locale || "en").to_s
    end

    def validate(_machine)
      errors = []
      errors << "cert_path must be provided" if @cert_path.to_s.strip.empty?
      errors << "cert_name must be provided" if @cert_name.to_s.strip.empty?
      { "vagrant-docker-certificates-manager" => errors }
    end
  end
end
