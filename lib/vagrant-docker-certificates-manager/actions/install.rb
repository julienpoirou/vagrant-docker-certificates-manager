# frozen_string_literal: true

require_relative "../util/os"
require_relative "../util/ui"
require_relative "../util/cert"
require_relative "../util/registry"
require_relative "../helpers"

module VagrantDockerCertificatesManager
  module Actions
    class Install
      def initialize(app, env); @app = app; @env = env; end

      def call(env)
        cfg = env[:machine].config.docker_certificates
        UiHelpers.set_locale!(cfg.locale || ENV["LANG"] || "en")
        if cfg.install_on_up
          Ui.say(env, :info, "install.start", name: cfg.cert_name, path: cfg.cert_path)
          result = self.class.perform_install(cfg, env)
          Ui.say(env, result[:status] == "success" ? :info : :error,
                 result[:status] == "success" ? "install.success" : "install.fail",
                 name: cfg.cert_name)
        end
        @app.call(env)
      end

      # Installs a configured certificate into the current host trust store.
      #
      # The operation is idempotent: when the fingerprint is already tracked,
      # the current machine adopts the existing registry entry instead of
      # reinstalling the certificate.
      #
      # @param cfg [#cert_path, #cert_name] Vagrant certificate configuration.
      # @param env [Hash, nil] Vagrant environment hash.
      # @return [Hash] Normalized result with code, status, data, or error.
      def self.perform_install(cfg, env)
        unless File.file?(cfg.cert_path)
          return { code: 1, status: "error",
error: UiHelpers.t("errors.invalid_path", path: cfg.cert_path) }
        end

        name = cfg.cert_name.to_s.strip.empty? ? Cert.default_name_from(cfg.cert_path) : cfg.cert_name
        fp   = Cert.sha1(cfg.cert_path)
        mid  = env && env[:machine]&.id

        if Registry.all.key?(fp)
          Registry.adopt(fp, mid) if mid
          return { code: 0, status: "success", data: { os: OS.detect, cert: name, already: true } }
        end

        os = OS.detect
        ok = case os
             when :mac     then OS.mac_add_trusted_cert(cfg.cert_path, name)
             when :linux   then OS.linux_install_cert(cfg.cert_path, name, nss: cfg.manage_nss_browsers,
firefox: cfg.manage_firefox)
             when :windows then OS.win_install_cert(cfg.cert_path, name)
             else return { code: 2, status: "error", error: UiHelpers.t("errors.os_unsupported") }
             end
        return({ code: 3, status: "error", error: UiHelpers.t("errors.install_failed") }) unless ok

        Registry.track(fp, {
          "path"      => File.expand_path(cfg.cert_path),
          "name"      => name,
          "nickname"  => Cert.nickname_for(name),
          "os"        => os.to_s,
          "owners"    => [mid].compact
        })
        { code: 0, status: "success", data: { os: os, cert: name } }
      end
    end
  end
end
