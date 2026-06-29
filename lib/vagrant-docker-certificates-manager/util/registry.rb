# frozen_string_literal: true

require "json"
require "fileutils"

module VagrantDockerCertificatesManager
  module Registry
    module_function

    def db_path
      File.join(Dir.home, ".vagrant.d", "vdcm", "certs.json")
    end

    def ensure_dir!
      FileUtils.mkdir_p(File.dirname(db_path))
    end

    # Loads tracked certificates from the best-effort local registry.
    #
    # A corrupt or missing registry must not block Vagrant actions, because the
    # OS trust store remains the source of truth.
    #
    # @return [Hash] Registry data keyed by certificate fingerprint.
    def load
      ensure_dir!
      return {} unless File.exist?(db_path)
      JSON.parse(File.read(db_path))
    rescue StandardError
      {}
    end

    def save(data)
      ensure_dir!
      File.write(db_path, JSON.pretty_generate(data))
    end

    # Tracks a certificate fingerprint and its ownership metadata.
    #
    # @param fp [String] Certificate fingerprint.
    # @param attrs [Hash] Persisted metadata such as path, name, OS, and owners.
    # @return [void]
    def track(fp, attrs)
      data = load
      data[fp] = attrs
      save(data)
    end

    def untrack(fp)
      data = load
      removed = !data.delete(fp).nil?
      save(data)
      removed
    end

    # Adds an owner to an already tracked certificate.
    #
    # @param fp [String] Certificate fingerprint.
    # @param owner [String, #to_s] Vagrant machine id adopting the certificate.
    # @return [Boolean] Whether the certificate was already tracked.
    def adopt(fp, owner)
      data = load
      return false unless data[fp]
      data[fp]["owners"] = Array(data[fp]["owners"]) | [owner.to_s]
      save(data)
      true
    end

    # Releases one owner from a tracked certificate.
    #
    # Keep the certificate installed while at least one Vagrant machine still
    # owns it.
    #
    # @param fp [String] Certificate fingerprint.
    # @param owner [String, #to_s] Vagrant machine id releasing the certificate.
    # @return [Boolean] Whether other owners remain after the release.
    def release(fp, owner)
      data = load
      rec  = data[fp]
      return false unless rec
      owners = Array(rec["owners"])
      owners.delete(owner.to_s)
      rec["owners"] = owners
      save(data)
      !owners.empty?
    end

    def find_by_path(path)
      data = load
      data.find { |_fp, v| File.expand_path(v["path"]) == File.expand_path(path) }
    end

    def all
      load
    end

    def others_for_os?(fp, os)
      load.any? { |k, v| k != fp && v["os"].to_s == os.to_s }
    end
  end
end
