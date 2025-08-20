# frozen_string_literal: true

require "optparse"

require_relative "util/ui"
require_relative "util/cert"
require_relative "util/registry"
require_relative "util/os"
require_relative "version"
require_relative "helpers"

module VagrantDockerCertificatesManager
  BASE_CMD = if defined?(Vagrant) && Vagrant.respond_to?(:plugin)
               Vagrant.plugin("2", :command)
             else
               Class.new do
                 def initialize(argv = [], env = {})
                   @argv = argv || []
                   @env  = env  || {}
                 end

                 def parse_options(parser)
                   parser.order!(@argv)
                   @argv
                 rescue OptionParser::InvalidOption
                   nil
                 end
               end
             end

  class Command < BASE_CMD
    def initialize(*args)
      argv, env =
        if args.size == 2 && args.first.is_a?(Array)
          [args.first, args.last]
        elsif args.size == 2 && args.last.is_a?(Array)
          [args.last, args.first]
        else
          [args[0].is_a?(Array) ? args[0] : [], args[1] || {}]
        end

      super(argv, env) if defined?(super)
      @argv = argv
      @env  = env
    end

    def execute
      UiHelpers.setup_i18n!

      opts = { lang: nil, no_emoji: false }

      parser = OptionParser.new do |o|
        o.banner = UiHelpers.t("cli.usage", default: "Usage: vagrant certs <add|remove|list|version|help> [options]")
        o.on("--lang LANG", UiHelpers.t("cli.opt_lang", default: "Force language (en|fr)")) { |v| opts[:lang] = v }
        o.on("--no-emoji",  UiHelpers.t("cli.opt_no_emoji", default: "Disable emoji in CLI output")) do
          opts[:no_emoji] = true
        end
        o.on("-h", "--help", UiHelpers.t("cli.opt_help", default: "Show help and exit")) do
          UiHelpers.print_general_help(no_emoji: opts[:no_emoji], ui: @env.ui)
          return 0
        end
      end

      argv = parse_options(parser)
      return 0 unless argv

      UiHelpers.set_locale!(opts[:lang] || "en")
      ENV["VDCM_NO_EMOJI"] = "1" if opts[:no_emoji]

      env = { ui: @env.ui, no_emoji: opts[:no_emoji] }

      sub = argv.shift
      case sub
      when "add", "install"
        path = argv.shift
        unless path && File.file?(path)
          Ui.say(env, :error, "errors.invalid_path", path: (path || "").to_s)
          return 1
        end

        name = Cert.default_name_from(path)
        fp   = Cert.sha1(path)
        nick = Cert.nickname_for(name)

        if Registry.all.key?(fp)
          Ui.say(env, :error, "errors.already_present", name: name)
          return 1
        end

        os = OS.detect
        ok = case os
             when :mac
               OS.mac_has_cert_fingerprint?(fp) ? false : OS.mac_add_trusted_cert(path, name)
             when :linux
               OS.linux_has_cert_file?(name) ? false : OS.linux_install_cert(path, name, nss: true, firefox: false)
             when :windows
               OS.win_has_cert_fingerprint?(fp) ? false : OS.win_install_cert(path, name)
             else
               Ui.say(env, :error, "errors.os_unsupported")
               return 2
             end

        unless ok
          Ui.say(env, :error, "errors.install_failed")
          return 3
        end

        Registry.track(fp, {
          "path"      => File.expand_path(path),
          "name"      => name,
          "nickname"  => nick,
          "os"        => os.to_s
        })
        Ui.say(env, :info, "add.success", name: name)
        0

      when "remove", "uninstall"
        path = argv.shift
        unless path && !path.strip.empty?
          Ui.say(env, :error, "errors.missing_path_remove")
          return 1
        end

        fp = if File.file?(path)
               Cert.sha1(path)
             else
               (Registry.find_by_path(path) || [nil]).first
             end

        unless fp
          Ui.say(env, :error, "errors.not_found_for_remove", path: path)
          return 1
        end

        name_for_remove = (Registry.all[fp] || {})["name"] || Cert.default_name_from(path)

        os = OS.detect
        ok = case os
             when :mac     then OS.mac_remove_by_fp(fp)
             when :linux   then OS.linux_uninstall_cert(name_for_remove)
             when :windows then OS.win_remove_by_fp(fp)
             else
               Ui.say(env, :error, "errors.os_unsupported")
               return 2
             end

        if ok
          Registry.untrack(fp)
          Ui.say(env, :info, "remove.success")
          0
        else
          Ui.say(env, :warn, "errors.remove_failed")
          4
        end

      when "list", "status"
        entries = Registry.all
        if entries.empty?
          Ui.say(env, :info, "list.empty")
          return 0
        end
        Ui.say(env, :info, "list.header")
        entries.each do |fp, v|
          @env.ui.info("  • #{v['name']}  (#{fp})  [#{v['os']}]  #{v['path']}")
        end
        0

      when "version"
        emoji = UiHelpers.e(:version, no_emoji: opts[:no_emoji])
        line  = UiHelpers.t("messages.version_line", default: "v%{v}.", v: VagrantDockerCertificatesManager::VERSION)
        @env.ui.info("#{emoji} #{line}".strip)
        0

      when "help", "helps", nil, ""
        topic = argv.shift
        if topic && !topic.strip.empty?
          UiHelpers.print_topic_help(topic, no_emoji: opts[:no_emoji], ui: @env.ui)
        else
          UiHelpers.print_general_help(no_emoji: opts[:no_emoji], ui: @env.ui)
        end
        0

      else
        Ui.say(env, :error, "errors.unknown_command", cmd: sub)
        UiHelpers.print_general_help(no_emoji: opts[:no_emoji], ui: @env.ui)
        1
      end
    end
  end
end
