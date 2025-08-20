# frozen_string_literal: true

require "json"
require_relative "../helpers"

module VagrantDockerCertificatesManager
  module Ui
    module_function

    def say(env, level, key = nil, raw: nil, **kv)
      UiHelpers.say(env, level, key, raw: raw, **kv)
    end

    def emit(json, action, result)
      if json
        puts JSON.dump(result.merge(action: action))
        return
      end
      no_emoji = ENV["VDCM_NO_EMOJI"].to_s == "1"
      ok_mark  = no_emoji ? "[OK]"  : UiHelpers.e(:success)
      ko_mark  = no_emoji ? "[ERR]" : UiHelpers.e(:error)

      status = result[:status] || result[:state]
      if status == "success" || status == "ok"
        puts "#{ok_mark} #{action}"
      else
        puts "#{ko_mark} #{action}: #{result[:error] || 'error'}"
      end
    end
  end
end
