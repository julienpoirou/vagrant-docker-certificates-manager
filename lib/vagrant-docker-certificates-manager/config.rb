# frozen_string_literal: true

module VagrantDockerCertificatesManager
  # Vagrant configuration for certificate generation, installation, and cleanup.
  #
  # @!attribute cert_path
  #   @return [String] Path to the CA certificate installed into the trust store.
  # @!attribute cert_name
  #   @return [String] Friendly certificate name used in host trust stores.
  # @!attribute install_on_up
  #   @return [Boolean] Whether to install the certificate during `vagrant up`.
  # @!attribute remove_on_destroy
  #   @return [Boolean] Whether to remove the certificate during `vagrant destroy`.
  # @!attribute manage_firefox
  #   @return [Boolean] Whether Firefox stores should be managed where supported.
  # @!attribute manage_nss_browsers
  #   @return [Boolean] Whether NSS browser stores should be managed where supported.
  # @!attribute generate_on_up
  #   @return [Boolean] Whether local certificate material should be generated during `vagrant up`.
  class Config < Vagrant.plugin("2", :config)
    attr_accessor :cert_path, :cert_name, :install_on_up, :remove_on_destroy,
                  :manage_firefox, :manage_nss_browsers, :locale, :verbose,
                  :container_name,
                  :generate_on_up, :ca_cn, :ca_days, :server_domain, :crl_url

    def initialize
      @cert_path            = UNSET_VALUE
      @cert_name            = UNSET_VALUE
      @install_on_up        = UNSET_VALUE
      @remove_on_destroy    = UNSET_VALUE
      @manage_firefox       = UNSET_VALUE
      @manage_nss_browsers  = UNSET_VALUE
      @locale               = UNSET_VALUE
      @verbose              = UNSET_VALUE
      @container_name       = UNSET_VALUE
      @generate_on_up       = UNSET_VALUE
      @ca_cn                = UNSET_VALUE
      @ca_days              = UNSET_VALUE
      @server_domain        = UNSET_VALUE
      @crl_url              = UNSET_VALUE
    end

    def finalize!
      @cert_path           = "certs/rootca.cert.pem" if @cert_path == UNSET_VALUE
      @cert_name           = "local.dev"             if @cert_name == UNSET_VALUE
      @install_on_up       = false                   if @install_on_up == UNSET_VALUE
      @remove_on_destroy   = false                   if @remove_on_destroy == UNSET_VALUE
      @manage_firefox      = false                   if @manage_firefox == UNSET_VALUE
      @manage_nss_browsers = true                    if @manage_nss_browsers == UNSET_VALUE
      @locale              = "en"                    if @locale == UNSET_VALUE
      @verbose             = false                   if @verbose == UNSET_VALUE
      @container_name      = nil                     if @container_name == UNSET_VALUE
      @generate_on_up      = false                   if @generate_on_up == UNSET_VALUE
      @ca_cn               = "local-ca"              if @ca_cn == UNSET_VALUE
      @ca_days             = 3650                    if @ca_days == UNSET_VALUE
      @server_domain       = nil                     if @server_domain == UNSET_VALUE
      @crl_url             = nil                     if @crl_url == UNSET_VALUE

      @install_on_up       = !!@install_on_up
      @remove_on_destroy   = !!@remove_on_destroy
      @manage_firefox      = !!@manage_firefox
      @manage_nss_browsers = !!@manage_nss_browsers
      @verbose             = !!@verbose
      @generate_on_up      = !!@generate_on_up
      @locale              = (@locale || "en").to_s
      @ca_cn               = (@ca_cn || "local-ca").to_s
      @ca_days             = @ca_days.to_i
    end

    def validate(_machine)
      errors = []
      errors << "cert_path must be provided" if @cert_path.to_s.strip.empty?
      errors << "cert_name must be provided" if @cert_name.to_s.strip.empty?
      unless @locale.is_a?(String) && %w[en fr].include?(@locale.to_s[0, 2].downcase)
        errors << "locale must be 'en' or 'fr'"
      end
      errors << "ca_days must be a positive integer" if @generate_on_up && @ca_days.to_i <= 0
      { "vagrant-docker-certificates-manager" => errors }
    end

    def cert_dir
      d = File.dirname(@cert_path.to_s)
      d.empty? ? "certs" : d
    end
  end
end
