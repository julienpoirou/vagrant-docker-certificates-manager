# frozen_string_literal: true

require "open3"
require "base64"
require_relative "cert"

module VagrantDockerCertificatesManager
  module OS
    module_function

    def detect
      if defined?(Vagrant) && Vagrant.const_defined?(:Util) && Vagrant::Util.const_defined?(:Platform)
        return :mac     if Vagrant::Util::Platform.darwin?
        return :windows if Vagrant::Util::Platform.windows?
        return :linux   if Vagrant::Util::Platform.linux?
      else
        plat = RbConfig::CONFIG["host_os"].downcase
        return :mac     if plat.include?("darwin")
        return :windows if plat =~ /mswin|mingw|windows/
        return :linux   if plat.include?("linux")
      end
      :unknown
    end

    # Runs an external command safely using the array form (no shell interpolation).
    def run(*args)
      out, err, st = Open3.capture3(*args)
      [st.success?, out, err]
    end

    # ── macOS ─────────────────────────────────────────────────────────────────

    def mac_add_trusted_cert(path, _name)
      run("sudo", "security", "add-trusted-cert",
          "-d", "-r", "trustRoot",
          "-k", "/Library/Keychains/System.keychain",
          path.to_s).first
    end

    def mac_has_cert_fingerprint?(fp)
      ok, out, = run("security", "find-certificate", "-a", "-Z",
                     "/Library/Keychains/System.keychain")
      ok && out.include?(fp.to_s)
    end

    def mac_remove_by_fp(fp)
      ok, out, = run("security", "find-certificate", "-a", "-Z",
                     "/Library/Keychains/System.keychain")
      return true unless ok
      hash = out.lines.find { |l| l =~ /SHA-1 hash:\s*#{Regexp.escape(fp)}/i } ? fp : nil
      return true unless hash
      run("sudo", "security", "delete-certificate",
          "-Z", hash.to_s, "/Library/Keychains/System.keychain").first
    end

    # ── Linux ─────────────────────────────────────────────────────────────────

    def linux_install_cert(path, name, nss: true, firefox: false)
      dest = "/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt"
      ok1, = run("sudo", "cp", path.to_s, dest)
      ok2, = run("sudo", "update-ca-certificates")
      okn = nss     ? linux_nss_install(path, name)     : true
      okf = firefox ? linux_firefox_install(path, name) : true
      ok1 && ok2 && okn && okf
    end

    def linux_has_cert_file?(name)
      File.exist?("/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt")
    end

    def linux_uninstall_cert(name, nss: true, firefox: false)
      dest = "/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt"
      run("sudo", "rm", "-f", dest)
      run("sudo", "update-ca-certificates")
      linux_nss_uninstall(name)     if nss
      linux_firefox_uninstall(name) if firefox
      true
    end

    def linux_nss_install(path, name)
      db = "sql:#{File.join(Dir.home, ".pki", "nssdb")}"
      run("certutil", "-d", db, "-A", "-t", "C,,",
          "-n", Cert.nickname_for(name), "-i", path.to_s).first
    end

    def linux_nss_uninstall(name)
      db = "sql:#{File.join(Dir.home, ".pki", "nssdb")}"
      run("certutil", "-d", db, "-D", "-n", Cert.nickname_for(name))
      true
    end

    def linux_firefox_profiles
      home = Dir.home
      [
        "#{home}/.mozilla/firefox",
        "#{home}/.var/app/org.mozilla.firefox/.mozilla/firefox",
        "#{home}/snap/firefox/common/.mozilla/firefox"
      ].select { |d| File.directory?(d) }
        .flat_map { |base| Dir.glob(File.join(base, "*.default*")) }
    end

    def linux_firefox_install(path, name)
      linux_firefox_profiles.all? do |profile|
        run("certutil", "-A",
            "-n", Cert.nickname_for(name), "-t", "C,,",
            "-i", path.to_s, "-d", "sql:#{profile}").first
      end
    end

    def linux_firefox_uninstall(name)
      linux_firefox_profiles.each do |profile|
        run("certutil", "-D", "-n", Cert.nickname_for(name), "-d", "sql:#{profile}")
      end
      true
    end

    # ── Windows ───────────────────────────────────────────────────────────────

    # Firefox on Windows does not ship with NSS certutil, so we enable
    # security.enterprise_roots.enabled in each profile's user.js instead.
    # This makes Firefox delegate trust to the Windows system cert store,
    # which already contains the CA installed by win_install_cert.

    FIREFOX_ENTERPRISE_ROOTS_PREF = 'user_pref("security.enterprise_roots.enabled", true);'
    FIREFOX_ENTERPRISE_ROOTS_KEY  = "security.enterprise_roots.enabled"

    def win_firefox_profiles
      appdata = (ENV["APPDATA"] || File.join(Dir.home, "AppData", "Roaming")).tr("\\", "/")
      base    = "#{appdata}/Mozilla/Firefox/Profiles"
      return [] unless File.directory?(base)
      Dir.glob("#{base}/*").select { |d| File.directory?(d) }
    end

    def win_firefox_enable_enterprise_roots
      win_firefox_profiles.each do |profile|
        user_js = File.join(profile, "user.js")
        content = File.exist?(user_js) ? File.read(user_js) : ""
        next if content.include?(FIREFOX_ENTERPRISE_ROOTS_KEY)
        File.open(user_js, "a") { |f| f.puts FIREFOX_ENTERPRISE_ROOTS_PREF }
      end
      true
    rescue StandardError
      false
    end

    def win_firefox_disable_enterprise_roots
      win_firefox_profiles.each do |profile|
        user_js = File.join(profile, "user.js")
        next unless File.exist?(user_js)
        updated = File.read(user_js)
                      .lines
                      .reject { |l| l.include?(FIREFOX_ENTERPRISE_ROOTS_KEY) }
                      .join
        File.write(user_js, updated)
      end
      true
    rescue StandardError
      false
    end

    def win_install_cert(path, name)
      fp   = Cert.sha1(path)
      nick = Cert.nickname_for(name).gsub("'", "''")
      abs  = File.expand_path(path).tr("/", "\\").gsub("'", "''")

      ps = <<~PS
        $ErrorActionPreference = 'Stop'
        Import-Certificate -FilePath '#{abs}' -CertStoreLocation Cert:\\LocalMachine\\Root | Out-Null
        $cert = Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object { $_.Thumbprint -eq '#{fp}' }
        if ($cert) { $cert.FriendlyName = '#{nick}' }
      PS
      encoded = Base64.strict_encode64(ps.encode("UTF-16LE"))

      # Try non-elevated first (works if already admin)
      ok, = run("powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded)

      unless ok
        # Elevate via UAC
        elev = "Start-Process PowerShell -Verb RunAs -Wait " \
               "-ArgumentList '-NonInteractive','-NoProfile','-EncodedCommand','#{encoded}'"
        elev_encoded = Base64.strict_encode64(elev.encode("UTF-16LE"))
        ok, = run("powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", elev_encoded)
        return false unless ok
      end

      win_firefox_enable_enterprise_roots
      true
    end

    def win_has_cert_fingerprint?(fp)
      ps  = "if (Get-ChildItem Cert:\\LocalMachine\\Root | " \
            "Where-Object { $_.Thumbprint -eq '#{fp}' }) { 'YES' } else { 'NO' }"
      ok, out, = run("powershell", "-NoProfile", "-NonInteractive",
                     "-EncodedCommand", Base64.strict_encode64(ps.encode("UTF-16LE")))
      ok && out.to_s.strip == "YES"
    end

    def win_remove_by_fp(fp)
      ps = <<~PS
        $ErrorActionPreference = 'Stop'
        Get-ChildItem Cert:\\LocalMachine\\Root |
          Where-Object { $_.Thumbprint -eq '#{fp}' } |
          Remove-Item
      PS
      encoded = Base64.strict_encode64(ps.encode("UTF-16LE"))

      ok, = run("powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", encoded)
      return true if ok

      elev = "Start-Process PowerShell -Verb RunAs -Wait " \
             "-ArgumentList '-NonInteractive','-NoProfile','-EncodedCommand','#{encoded}'"
      elev_encoded = Base64.strict_encode64(elev.encode("UTF-16LE"))
      ok = run("powershell", "-NoProfile", "-NonInteractive", "-EncodedCommand", elev_encoded).first
      win_firefox_disable_enterprise_roots if ok
      ok
    end
  end
end
