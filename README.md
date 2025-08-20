# vagrant-docker-certificates-manager

[![CI](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/ci.yml)
[![CodeQL](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/codeql.yml/badge.svg)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/codeql.yml)
[![Release](https://img.shields.io/github/v/release/julienpoirou/vagrant-docker-certificates-manager?include_prereleases&sort=semver)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/releases)
[![RubyGems](https://img.shields.io/gem/v/vagrant-docker-certificates-manager.svg)](https://rubygems.org/gems/vagrant-docker-certificates-manager)
[![License](https://img.shields.io/github/license/julienpoirou/vagrant-docker-certificates-manager.svg)](LICENSE.md)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196.svg)](https://www.conventionalcommits.org)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg)](https://renovatebot.com)
[![Total downloads](https://img.shields.io/gem/dt/vagrant-docker-certificates-manager?logo=rubygems&label=downloads)](https://rubygems.org/gems/vagrant-docker-certificates-manager)

Vagrant plugin to **install/uninstall a local Root CA certificate** into the host system trust stores and (optionally) browser NSS stores. Works on **macOS, Linux and Windows**.

- Can install the certificate on `vagrant up` (opt‑in)
- CLI: `vagrant certs add | remove | list | version | help`
- Optional support for Firefox and Chromium-based browsers (NSS)
- Multilingual output (**en**, **fr**) and `--no-emoji` option

> Requirements: **Vagrant ≥ 2.2**, **Ruby ≥ 3.1**.  
> For Linux: `update-ca-certificates` (Debian/Ubuntu) and optional `libnss3-tools` for browser stores.  
> ⚠️ **Only install certificates you trust**.

---

## Table of contents

- [Why this plugin?](#why-this-plugin)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Vagrantfile configuration](#vagrantfile-configuration)
- [CLI usage](#cli-usage)
- [How it works](#how-it-works)
- [OS-specific notes](#os-specific-notes)
- [Environment variables](#environment-variables)
- [Troubleshooting](#troubleshooting)
- [Contributing & Development](#contributing--development)
- [License](#license)

> 🇫🇷 **Français :** voir [README.fr.md](README.fr.md)

---

## Why this plugin?

Local development with HTTPS often relies on a **local CA** (e.g. `rootca.cert.pem`) to sign project certificates (`*.local`). Manually adding that CA to each teammate’s **system trust store** and **browser** is tedious and error‑prone. This plugin makes it **repeatable**, **scriptable** and **cross‑platform**.

---

## Installation

From RubyGems (once published):

```bash
vagrant plugin install vagrant-docker-certificates-manager
```

From source:

```bash
git clone https://github.com/julienpoirou/vagrant-docker-certificates-manager
cd vagrant-docker-certificates-manager
bundle install
rake
vagrant plugin install .
```

---

## Quick start

### Minimal Vagrantfile

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/ubuntu-22.04"

  # Required
  config.docker_certificates.cert_path = "./certs/rootca.cert.pem" # your Root CA
  config.docker_certificates.cert_name = "noesi.local"

  # Optional
  config.docker_certificates.install_on_up       = true  # auto-install on `vagrant up`
  # config.docker_certificates.manage_firefox      = true
  # config.docker_certificates.manage_nss_browsers = true
  # config.docker_certificates.locale              = "fr" # or "en"
end
```

Bring the VM up:

```bash
vagrant up
```

This will attempt to install the CA into the host trust store (and optional browsers) using OS-specific commands.

---

## Vagrantfile configuration

| Key                       | Type    | Default  | Description |
|---------------------------|---------|----------|-------------|
| `cert_path`               | String  | `nil`    | **Required.** Path to your Root CA PEM file on the **host**. |
| `cert_name`               | String  | `local.dev` | Display/friendly name for OS/browser stores. |
| `install_on_up`           | Bool    | `false`  | Install automatically during `vagrant up`. |
| `manage_firefox`          | Bool    | `false`  | Attempt to add CA to Firefox profiles (if found). |
| `manage_nss_browsers`     | Bool    | `true`   | Attempt to add CA to user NSS DB (Chromium/Brave/etc.). |
| `locale`                  | String  | `"en"`   | Language for messages (`"en"` or `"fr"`). |
| `verbose`                 | Bool    | `false`  | Print extra diagnostics (when supported). |

**Validation**  
- `cert_path` must exist and be a file.  
- On Linux, you may need `sudo` and `libnss3-tools` for browser stores.

---

## CLI usage

```
vagrant certs <command> [--lang en|fr] [--no-emoji]

Commands:
  add <PATH>       Install the CA from PATH into system/browser stores
  remove <PATH>    Remove the CA that was installed from PATH
  list             Show tracked certificates installed via this plugin
  version          Print plugin version
  help [TOPIC]     Show help (topics: add, remove, list, version, help)
```

Examples:

```bash
vagrant certs add ./certs/rootca.cert.pem
vagrant certs remove ./certs/rootca.cert.pem --lang fr
vagrant certs list --no-emoji
vagrant certs version
vagrant certs help add
```

---

## How it works

- **macOS**: uses `security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain` to add a CA; removal via `security delete-certificate -Z <sha1>`.
- **Linux (Debian/Ubuntu)**: copies the CA into `/usr/local/share/ca-certificates/<name>.crt` and runs `update-ca-certificates`. For browser stores, uses `certutil` (NSS) if present and profiles are found.  
- **Windows**: uses `certutil -addstore -f ROOT <path>` to add the CA to the “Trusted Root Certification Authorities”; removal via `certutil -delstore ROOT <thumbprint>`.

The plugin can also auto‑install on `vagrant up` when `install_on_up` is `true`.

---

## OS-specific notes

- **Privileges**: writing to system trust stores often needs **Admin/root**. You may be prompted for your password or need to run an elevated shell.
- **Firefox**: when enabled, the plugin scans for profiles (native, Flatpak, Snap on Linux). If `certutil` is not installed, Firefox integration is skipped.
- **NSS browsers**: for Chromium/Brave/Opera/etc., we try `~/.pki/nssdb` or browser-specific profile DBs. Behavior varies by distro and packaging.
- **PEM format**: the Root CA should be in PEM. If needed, convert with `openssl x509 -in rootca.crt -out rootca.pem -outform pem`.

---

## Environment variables

| Variable        | Purpose |
|-----------------|---------|
| `VDCM_LANG`     | Force language (`en`/`fr`) regardless of config. |
| `VDCM_NO_EMOJI` | When `1`, disables emoji in output. |
| `VDCM_DEBUG`    | When `1`, prints extra debug logs from the plugin. |

---

## Troubleshooting

- **Permission denied**: run an elevated shell (Admin on Windows, `sudo` on Linux/macOS) or allow the password prompt.
- **Linux: `certutil` missing**: install NSS tools, e.g. `sudo apt-get update && sudo apt-get install -y libnss3-tools`.
- **Firefox not updated**: ensure Firefox is closed; confirm the profile directories exist; Flatpak/Snap paths differ.
- **Wrong certificate**: verify the file path and format (`*.pem`). Check with `openssl x509 -in rootca.pem -text -noout`.

---

## Contributing & Development

```bash
git clone https://github.com/julienpoirou/vagrant-docker-certificates-manager
cd vagrant-docker-certificates-manager
bundle install
rake          # runs RSpec
```

- Conventional Commits are welcome.
- CI runs tests and linting.
- Issues and PRs are appreciated!

---

## License

MIT © 2025 Julien Poirou
