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

    def fingerprint_of(cert)
      OpenSSL::Digest::SHA1.hexdigest(cert.to_der).upcase
    end

    # Generates a local development certificate authority.
    #
    # The generated CA is intended for local Docker/Vagrant workflows, not as a
    # public browser-trusted certificate authority.
    #
    # @param cn [String] Common name for the CA certificate.
    # @param days [Integer] Validity period in days.
    # @param org [String] Organization attribute written to the subject.
    # @param country [String] Country attribute written to the subject.
    # @return [Array<OpenSSL::X509::Certificate, OpenSSL::PKey::RSA>] Generated certificate and private key.
    def generate_ca(cn:, days: 3650, org: "VDCM", country: "FR")
      key  = OpenSSL::PKey::RSA.generate(2048)
      cert = OpenSSL::X509::Certificate.new

      cert.version    = 2
      cert.serial     = 1
      cert.subject    = OpenSSL::X509::Name.parse("/CN=#{cn}/O=#{org}/C=#{country}")
      cert.issuer     = cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after  = Time.now + (days * 24 * 60 * 60)

      ef = OpenSSL::X509::ExtensionFactory.new(cert, cert)
      cert.add_extension(ef.create_extension("basicConstraints",     "CA:TRUE",             true))
      cert.add_extension(ef.create_extension("keyUsage",             "keyCertSign,cRLSign", true))
      cert.add_extension(ef.create_extension("subjectKeyIdentifier", "hash"))
      cert.sign(key, OpenSSL::Digest::SHA256.new)

      [cert, key]
    end

    def load_ca(cert_path, key_path)
      [
        OpenSSL::X509::Certificate.new(File.read(cert_path)),
        OpenSSL::PKey::RSA.new(File.read(key_path))
      ]
    end

    # Generates a server certificate signed by the supplied local CA.
    #
    # Modern clients validate the SAN extension; the CN is kept mainly for
    # readability and compatibility with older tooling.
    #
    # @param ca_cert [OpenSSL::X509::Certificate] CA certificate used as issuer.
    # @param ca_key [OpenSSL::PKey::RSA] CA private key used to sign the certificate.
    # @param domain [String] DNS name written to CN and subjectAltName.
    # @param days [Integer] Validity period in days.
    # @param crl_url [String, nil] Optional CRL distribution point URL.
    # @return [Array<OpenSSL::X509::Certificate, OpenSSL::PKey::RSA>] Generated certificate and private key.
    def generate_server(ca_cert, ca_key, domain:, days: 825, crl_url: nil)
      key  = OpenSSL::PKey::RSA.generate(2048)
      cert = OpenSSL::X509::Certificate.new

      cert.version    = 2
      cert.serial     = 2
      cert.subject    = OpenSSL::X509::Name.parse("/CN=#{domain}")
      cert.issuer     = ca_cert.subject
      cert.public_key = key.public_key
      cert.not_before = Time.now
      cert.not_after  = Time.now + (days * 24 * 60 * 60)

      ef = OpenSSL::X509::ExtensionFactory.new(ca_cert, cert)
      cert.add_extension(ef.create_extension("subjectAltName",   "DNS:#{domain}"))
      cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE"))
      cert.add_extension(ef.create_extension("keyUsage",         "digitalSignature,keyEncipherment", true))
      cert.add_extension(ef.create_extension("extendedKeyUsage", "serverAuth"))
      unless crl_url.to_s.strip.empty?
        cert.add_extension(ef.create_extension("crlDistributionPoints", "URI:#{crl_url}"))
      end
      cert.sign(ca_key, OpenSSL::Digest::SHA256.new)

      [cert, key]
    end

    # Generates an empty certificate revocation list for the local CA.
    #
    # @param ca_cert [OpenSSL::X509::Certificate] CA certificate used as issuer.
    # @param ca_key [OpenSSL::PKey::RSA] CA private key used to sign the CRL.
    # @param days [Integer] Validity period in days.
    # @return [OpenSSL::X509::CRL] Signed CRL.
    def generate_crl(ca_cert, ca_key, days: 3650)
      crl = OpenSSL::X509::CRL.new
      crl.issuer      = ca_cert.subject
      crl.version     = 1
      crl.last_update = Time.now
      crl.next_update = Time.now + (days * 24 * 60 * 60)
      crl.sign(ca_key, OpenSSL::Digest::SHA256.new)
      crl
    end
  end
end
