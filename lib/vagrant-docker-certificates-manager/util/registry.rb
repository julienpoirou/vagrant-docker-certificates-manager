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

    def load
      ensure_dir!
      return {} unless File.exist?(db_path)
      JSON.parse(File.read(db_path))
    rescue
      {}
    end

    def save(data)
      ensure_dir!
      File.write(db_path, JSON.pretty_generate(data))
    end

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

    def find_by_path(path)
      data = load
      data.find { |_fp, v| File.expand_path(v["path"]) == File.expand_path(path) }
    end

    def all
      load
    end
  end
end
