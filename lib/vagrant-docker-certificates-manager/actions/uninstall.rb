# frozen_string_literal: true

require "fileutils"
require_relative "../util/os"
require_relative "../util/ui"
require_relative "../util/cert"
require_relative "../util/generator"
require_relative "../util/registry"
require_relative "../helpers"

module VagrantDockerCertificatesManager
  module Actions
    class Uninstall
      def initialize(app, env); @app = app; @env = env; end

      def call(env)
        cfg = env[:machine].config.docker_certificates
        UiHelpers.set_locale!(cfg.locale || "en")
        if cfg.remove_on_destroy
          Ui.say(env, :info, "uninstall.start", name: cfg.cert_name)
          result = self.class.perform_uninstall(cfg, env)
          Ui.say(env, result[:status] == "success" ? :info : :warn,
                 result[:status] == "success" ? "uninstall.success" : "uninstall.fail",
                 name: cfg.cert_name)
        end
        purge_generated(cfg, env)
        @app.call(env)
      end

      def purge_generated(cfg, env)
        # Generated material is purged only through explicit env flags to avoid
        # deleting a CA/server certificate that may be shared outside this action.
        files = []
        files += [Generator::CA_CERT, Generator::CA_KEY, Generator::CRL] if env_flag("VDCM_PURGE_CA_ON_DESTROY")
        files += [Generator::SRV_CRT, Generator::SRV_KEY]                if env_flag("VDCM_PURGE_SERVER_ON_DESTROY")
        return if files.empty?

        dir = cfg.cert_dir
        files.uniq.each do |name|
          path = File.join(dir, name)
          next unless File.exist?(path)

          File.delete(path)
          Ui.say(env, :info, "purge.removed", path: path)
        rescue StandardError => e
          Ui.say(env, :warn, "purge.failed", path: path, error: e.message)
        end
      end

      def env_flag(name)
        ENV[name].to_s == "1"
      end

      # Removes a configured certificate when the current machine is the last owner.
      #
      # Shared certificates stay installed until every machine recorded in the
      # registry has released ownership.
      #
      # @param cfg [#cert_path, #cert_name] Vagrant certificate configuration.
      # @param env [Hash, nil] Vagrant environment hash.
      # @return [Hash] Normalized result with code, status, data, or error.
      def self.perform_uninstall(cfg, env)
        fp_entry = Registry.find_by_path(cfg.cert_path)
        unless fp_entry
          return({ code: 1, status: "error",
                   error: UiHelpers.t("errors.not_found_for_remove", path: cfg.cert_path) })
        end
        fp, rec = fp_entry
        mid = env && env[:machine]&.id

        if mid && Registry.release(fp, mid)
          return({ code: 0, status: "success", data: { kept: true, cert: rec["name"] } })
        end

        os = OS.detect
        ok = case os
             when :mac     then OS.mac_remove_by_fp(fp)
             when :linux   then OS.linux_uninstall_cert(rec["name"], nss: cfg.manage_nss_browsers,
                                                                     firefox: cfg.manage_firefox)
             when :windows then OS.win_remove_by_fp(fp, disable_firefox: !Registry.others_for_os?(fp, "windows"))
             else return({ code: 2, status: "error", error: UiHelpers.t("errors.os_unsupported") })
             end
        Registry.untrack(fp) if ok
        ok ? { code: 0, status: "success" } : { code: 4, status: "error", error: UiHelpers.t("errors.remove_failed") }
      end
    end
  end
end
