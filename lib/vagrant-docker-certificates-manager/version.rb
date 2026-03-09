# frozen_string_literal: true

module VagrantDockerCertificatesManager
  unless defined?(VERSION)
    VERSION = begin
      path = File.expand_path("VERSION", __dir__)
      File.exist?(path) ? File.read(path).strip : "0.1.0"
    rescue StandardError
      "0.1.0"
    end
  end
end
