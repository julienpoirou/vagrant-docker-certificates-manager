# frozen_string_literal: true

require "openssl"

module VagrantDockerCertificatesManager
  module Cert
    MARKER = "VDCM"

    module_function

    def read_cert(path)
      OpenSSL::X509::Certificate.new(File.read(path))
    end

    def sha1(path)
      cert = read_cert(path)
      OpenSSL::Digest::SHA1.hexdigest(cert.to_der).upcase
    end

    def subject_cn(path)
      cert = read_cert(path)
      pair = cert.subject.to_a.find { |(k, _v, _t)| k == "CN" }
      pair ? pair[1].to_s : nil
    end

    def default_name_from(path)
      base = File.basename(path).sub(/\.(pem|crt|cer)$/i, "")
      base.empty? ? "local.dev" : base
    end

    def nickname_for(name)
      "#{MARKER}:#{name}"
    end
  end
end
