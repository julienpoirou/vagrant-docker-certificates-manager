# frozen_string_literal: true

require "open3"
require_relative "cert"

module VagrantDockerCertificatesManager
  module OS
    module_function

    def detect
      if defined?(Vagrant) && Vagrant.const_defined?(:Util) && Vagrant::Util.const_defined?(:Platform)
        return :mac if Vagrant::Util::Platform.darwin?
        return :windows if Vagrant::Util::Platform.windows?
        return :linux if Vagrant::Util::Platform.linux?
      else
        plat = RbConfig::CONFIG["host_os"].downcase
        return :mac if plat.include?("darwin")
        return :windows if plat =~ /mswin|mingw|windows/
        return :linux if plat.include?("linux")
      end
      :unknown
    end

    def run(cmd)
      out, err, st = Open3.capture3(cmd)
      [st.success?, out, err]
    end

    def mac_add_trusted_cert(path, name)
      ok, *_ = run(%(sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "#{path}"))
      ok
    end

    def mac_has_cert_fingerprint?(fp)
      ok, out, _ = run(%(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null))
      return false unless ok
      out.include?(fp)
    end

    def mac_remove_by_fp(fp)
      ok, out, _ = run(%(security find-certificate -a -Z /Library/Keychains/System.keychain 2>/dev/null))
      return true unless ok
      hash = out.lines.find { |l| l =~ /SHA-1 hash:\s*#{fp}/i } ? fp : nil
      return true unless hash
      run(%(sudo security delete-certificate -Z #{hash} /Library/Keychains/System.keychain)).first
    end

    def linux_install_cert(path, name, nss: true, firefox: false)
      dest = "/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt"
      ok1, = run(%(sudo cp "#{path}" "#{dest}"))
      ok2, = run("sudo update-ca-certificates")
      okn = true
      okn &&= linux_nss_install(path, name) if nss
      okf = true
      okf &&= linux_firefox_install(path, name) if firefox
      ok1 && ok2 && okn && okf
    end

    def linux_has_cert_file?(name)
      File.exist?("/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt")
    end

    def linux_uninstall_cert(name, nss: true, firefox: false)
      dest = "/usr/local/share/ca-certificates/#{Cert::MARKER.downcase}-#{name}.crt"
      run(%(sudo rm -f "#{dest}"))
      run("sudo update-ca-certificates")
      linux_nss_uninstall(name) if nss
      linux_firefox_uninstall(name) if firefox
      true
    end

    def linux_nss_install(path, name)
      db = %(sql:"$HOME/.pki/nssdb")
      run(%(certutil -d #{db} -A -t "C,," -n "#{Cert.nickname_for(name)}" -i "#{path}")).first
    end

    def linux_nss_uninstall(name)
      db = %(sql:"$HOME/.pki/nssdb")
      run(%(certutil -d #{db} -D -n "#{Cert.nickname_for(name)}"))
      true
    end

    def linux_firefox_profiles
      home = ENV["HOME"]
      [
        "#{home}/.mozilla/firefox",
        "#{home}/.var/app/org.mozilla.firefox/.mozilla/firefox",
        "#{home}/snap/firefox/common/.mozilla/firefox"
      ].select { |d| File.directory?(d) }.flat_map { |base| Dir.glob(File.join(base, "*.default*")) }
    end

    def linux_firefox_install(path, name)
      profiles = linux_firefox_profiles
      profiles.all? do |profile|
        run(%(certutil -A -n "#{Cert.nickname_for(name)}" -t "C,," -i "#{path}" -d "sql:#{profile}")).first
      end
    end

    def linux_firefox_uninstall(name)
      linux_firefox_profiles.each do |profile|
        run(%(certutil -D -n "#{Cert.nickname_for(name)}" -d "sql:#{profile}"))
      end
      true
    end

    def win_install_cert(path, name)
      ok, out, err = run(%(certutil -addstore -f "ROOT" "#{path}"))
      return false unless ok
      fp = Cert.sha1(path)
      ps = %(
        $cert = Get-ChildItem Cert:\\LocalMachine\\Root | Where-Object { $_.Thumbprint -eq "#{fp}" };
        if ($cert) { $cert.FriendlyName = "#{Cert.nickname_for(name)}"; }
      ).strip
      run(%(powershell -NoProfile -NonInteractive -Command "#{ps}"))
      true
    end

    def win_has_cert_fingerprint?(fp)
        ps = %q{
            $c = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq "__FP__" };
            if ($c) { "YES" } else { "NO" }
        }.strip.gsub("__FP__", fp.to_s)

        ok, out, _ = run(%(powershell -NoProfile -NonInteractive -Command "#{ps}"))
        ok && out.to_s.strip == "YES"
    end

    def win_remove_by_fp(fp)
      run(%(certutil -delstore "ROOT" #{fp})).first
    end
  end
end
