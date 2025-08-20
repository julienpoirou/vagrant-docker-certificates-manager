# frozen_string_literal: true

require_relative "../util/os"
require_relative "../util/ui"
require_relative "../util/cert"
require_relative "../util/registry"
require_relative "../helpers"

module VagrantDockerCertificatesManager
  module Actions
    class Uninstall
      def initialize(app, env); @app = app; @env = env; end

      def call(env)
        cfg = env[:machine].config.docker_certs
        UiHelpers.set_locale!(cfg.locale || "en")
        if cfg.remove_on_destroy
          Ui.say(env, :info, "uninstall.start", name: cfg.cert_name)
          result = self.class.perform_uninstall(cfg, env)
          Ui.say(env, result[:status] == "success" ? :info : :warn,
                 result[:status] == "success" ? "uninstall.success" : "uninstall.fail",
                 name: cfg.cert_name)
        end
        @app.call(env)
      end

      def self.perform_uninstall(cfg, _env)
        fp_entry = Registry.find_by_path(cfg.cert_path)
        unless fp_entry
          return({ code: 1, status: "error",
                   error: UiHelpers.t("errors.not_found_for_remove", path: cfg.cert_path) })
        end
        fp, rec = fp_entry
        os = OS.detect
        ok = case os
             when :mac     then OS.mac_remove_by_fp(fp)
             when :linux   then OS.linux_uninstall_cert(rec["name"], nss: cfg.manage_nss_browsers,
                                                                     firefox: cfg.manage_firefox)
             when :windows then OS.win_remove_by_fp(fp)
             else return({ code: 2, status: "error", error: UiHelpers.t("errors.os_unsupported") })
             end
        Registry.untrack(fp) if ok
        ok ? { code: 0, status: "success" } : { code: 4, status: "error", error: UiHelpers.t("errors.remove_failed") }
      end
    end
  end
end
