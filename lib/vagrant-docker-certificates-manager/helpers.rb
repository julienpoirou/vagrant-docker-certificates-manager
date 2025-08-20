# frozen_string_literal: true

require "i18n"
require "yaml"

module VagrantDockerCertificatesManager
  module UiHelpers
    class MissingTranslationError < StandardError; end
    class UnsupportedLocaleError   < StandardError; end

    SUPPORTED  = [:en, :fr].freeze
    NAMESPACE  = "vdcm".freeze
    OUR_SPACES = %w[messages. errors. usage. help. prompts. log. emoji. cli. add. remove. list. install.
                    uninstall.].freeze

    EMOJI = {
      success:  "✅",
      info:     "🔍",
      ongoing:  "🔁",
      warning:  "⚠️",
      error:    "❌",
      version:  "💾",
      broom:    "🧹",
      question: "❓"
    }.freeze

    module_function

    def setup_i18n!
      return if defined?(@i18n_setup) && @i18n_setup
      ::I18n.enforce_available_locales = false
      base  = File.expand_path("../../locales", __dir__)
      ::I18n.load_path |= Dir[File.join(base, "*.yml")]
      ::I18n.available_locales = SUPPORTED
      default = ((ENV["VDCM_LANG"] || ENV["LANG"] || "en")[0,2] rescue "en").to_sym
      ::I18n.default_locale = SUPPORTED.include?(default) ? default : :en
      ::I18n.backend.load_translations
      @i18n_setup = true
    end

    def set_locale!(lang, strict: false)
        setup_i18n!

        raw = (lang || ENV["VDCM_LANG"] || ENV["LANG"] || "en").to_s
        sym = raw[0, 2].to_s.downcase.to_sym
        sym = :en if sym.nil? || sym == :""

        unless SUPPORTED.include?(sym)
            if strict
            raise UnsupportedLocaleError,
                    "#{e(:error)} Unsupported language: #{sym}. Available: #{SUPPORTED.join(', ')}"
            else
            sym = :en
            end
        end

    ::I18n.locale = sym
    ::I18n.backend.load_translations
    sym
    end

    def e(key, no_emoji: false)
      return "" if no_emoji || ENV["VDCM_NO_EMOJI"] == "1"
      EMOJI[key] || ""
    end

    def ns_key(key)
      k = key.to_s
      k.start_with?("#{NAMESPACE}.") ? k : "#{NAMESPACE}.#{k}"
    end

    def t(key, **opts)
      setup_i18n!
      ::I18n.t(ns_key(key), **opts)
    end

    def t!(key, **opts)
      setup_i18n!
      k = ns_key(key)
      if our_key?(k) && !::I18n.exists?(k, ::I18n.locale)
        raise MissingTranslationError, "#{e(:error)} [#{::I18n.locale}] Missing translation for key: #{k}"
      end
      ::I18n.t(k, **opts)
    end

    def t_hash(key)
      v = t(key, default: {})
      v.is_a?(Hash) ? v : {}
    end

    def level_to_emoji(level)
      case level
      when :success then :success
      when :warn    then :warning
      when :error   then :error
      else               :info
      end
    end

    def say(env_or_ui, level, key = nil, raw: nil, no_emoji: false, **kv)
      setup_i18n!
      ui = (env_or_ui.respond_to?(:[]) ? (env_or_ui[:ui] || env_or_ui[:machine]&.ui) : env_or_ui)
      msg = raw || (key ? t(key, **kv) : nil)
      return if ui.nil? || msg.nil?

      prefix = e(level_to_emoji(level), no_emoji: no_emoji)
      line   = prefix.empty? ? msg : "#{prefix} #{msg}"

      case level
      when :warn  then ui.warn(line)
      when :error then ui.error(line)
      else             ui.info(line)
      end
    end

    def debug(env_or_ui, msg)
      return unless ENV["VDCM_DEBUG"].to_s == "1"
      say(env_or_ui, :info, nil, raw: "#{e(:question)} #{msg}")
    end

    def print_general_help(no_emoji: false, ui: nil)
      setup_i18n!
      lines = []
      lines << "#{e(:info, no_emoji: no_emoji)} #{t('help.general_title')}"
      lines << "  #{t('cli.usage')}"
      t_hash("help.commands").each_value { |line| lines << "  #{line}" }

      if ui
        lines.each { |ln| ui.info(ln) }
      else
        lines.each { |ln| puts ln }
      end
    end

    def print_topic_help(topic, no_emoji: false, ui: nil)
      setup_i18n!
      topic = (topic || "").to_s.strip.downcase
      return print_general_help(no_emoji: no_emoji, ui: ui) if topic.empty?

      base  = "help.topic.#{topic}"
      title = t("#{base}.title",       default: nil)
      usage = t("#{base}.usage",       default: nil)
      desc  = t("#{base}.description", default: nil)
      opts  = t_hash("#{base}.options")
      exs   = ::I18n.t("#{base}.examples", default: [])

      if title.nil? && usage.nil? && desc.nil? && opts.empty? && exs.empty?
        return print_general_help(no_emoji: no_emoji, ui: ui)
      end

      lines = []
      lines << "#{e(:info, no_emoji: no_emoji)} #{title || t('help.topic_fallback_title', topic: topic)}"
      lines << "  #{t('help.usage_label')}"
      lines << "    #{usage || 'vagrant certs help'}"
      if desc && !desc.strip.empty?
        lines << "  #{t('help.description_label')}"
        lines << "    #{desc}"
      end
      unless opts.empty?
        lines << "  #{t('help.options_label')}"
        opts.each_value { |line| lines << "    #{line}" }
      end
      if exs.is_a?(Array) && !exs.empty?
        lines << "  #{t('help.examples_label')}"
        exs.each { |ex| lines << "    #{ex}" }
      end

      if ui
        lines.each { |ln| ui.info(ln) }
      else
        lines.each { |ln| puts ln }
      end
    end

    def our_key?(k)
      OUR_SPACES.any? { |ns| k.start_with?("#{NAMESPACE}.#{ns}") || k.start_with?(ns) }
    end
  end
end
