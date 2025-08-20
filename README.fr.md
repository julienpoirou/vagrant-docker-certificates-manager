# vagrant-docker-certificates-manager

[![CI](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/ci.yml)
[![CodeQL](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/codeql.yml/badge.svg)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/actions/workflows/codeql.yml)
[![Release](https://img.shields.io/github/v/release/julienpoirou/vagrant-docker-certificates-manager?include_prereleases&sort=semver)](https://github.com/julienpoirou/vagrant-docker-certificates-manager/releases)
[![RubyGems](https://img.shields.io/gem/v/vagrant-docker-certificates-manager.svg)](https://rubygems.org/gems/vagrant-docker-certificates-manager)
[![License](https://img.shields.io/github/license/julienpoirou/vagrant-docker-certificates-manager.svg)](LICENSE.md)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196.svg)](https://www.conventionalcommits.org)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-brightgreen.svg)](https://renovatebot.com)
[![Total downloads](https://img.shields.io/gem/dt/vagrant-docker-certificates-manager?logo=rubygems&label=downloads)](https://rubygems.org/gems/vagrant-docker-certificates-manager)

Plugin Vagrant pour **installer/désinstaller une autorité de certification locale (Root CA)** dans les magasins de confiance **système** et, en option, dans les magasins **NSS** des navigateurs. Fonctionne sous **macOS, Linux et Windows**.

- Peut installer le certificat lors de `vagrant up` (opt‑in)
- CLI : `vagrant certs add | remove | list | version | help`
- Support optionnel pour les navigateurs Firefox et basés sur Chromium (NSS)
- Sortie multilingue (**en**, **fr**) et option `--no-emoji`

> Prérequis : **Vagrant ≥ 2.2**, **Ruby ≥ 3.1**.  
> Sous Linux : `update-ca-certificates` (Debian/Ubuntu) et `libnss3-tools` pour la gestion navigateur (facultatif).  
> ⚠️ **N’installez que des certificats de confiance**.

---

## Sommaire

- [Pourquoi ce plugin ?](#pourquoi-ce-plugin-)
- [Installation](#installation)
- [Démarrage rapide](#démarrage-rapide)
- [Configuration Vagrantfile](#configuration-vagrantfile)
- [Utilisation CLI](#utilisation-cli)
- [Fonctionnement](#fonctionnement)
- [Notes spécifiques aux OS](#notes-spécifiques-aux-os)
- [Variables d’environnement](#variables-denvironnement)
- [Dépannage](#dépannage)
- [Contribuer & Développement](#contribuer--développement)
- [Licence](#licence)

> 🇬🇧 **English:** see [README.md](README.md)

---

## Pourquoi ce plugin ?

En développement local HTTPS, on utilise souvent une **CA locale** (ex. `rootca.cert.pem`) pour signer les certificats du projet (`*.local`). Ajouter manuellement cette CA dans le **magasin système** et les **navigateurs** de chaque membre est fastidieux. Ce plugin rend l’opération **répétable**, **scriptable** et **multi‑plateforme**.

---

## Installation

Depuis RubyGems (une fois publié) :

```bash
vagrant plugin install vagrant-docker-certificates-manager
```

Depuis les sources :

```bash
git clone https://github.com/julienpoirou/vagrant-docker-certificates-manager
cd vagrant-docker-certificates-manager
bundle install
rake
vagrant plugin install .
```

---

## Démarrage rapide

### Vagrantfile minimal

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/ubuntu-22.04"

  # Obligatoire
  config.docker_certificates.cert_path = "./certs/rootca.cert.pem" # votre Root CA
  config.docker_certificates.cert_name = "noesi.local"

  # Optionnel
  config.docker_certificates.install_on_up       = true  # installation auto lors de `vagrant up`
  # config.docker_certificates.manage_firefox      = true
  # config.docker_certificates.manage_nss_browsers = true
  # config.docker_certificates.locale              = "fr" # ou "en"
end
```

Lancez la VM :

```bash
vagrant up
```

Le plugin tentera d’installer la CA dans le magasin système (et navigateurs, si activé) via les commandes spécifiques à l’OS.

---

## Configuration Vagrantfile

| Clé                       | Type    | Défaut     | Description |
|---------------------------|---------|------------|-------------|
| `cert_path`               | String  | `nil`      | **Obligatoire.** Chemin vers le fichier PEM de la Root CA sur l’**hôte**. |
| `cert_name`               | String  | `local.dev`| Nom lisible/affiché dans les stores OS/navigateurs. |
| `install_on_up`           | Bool    | `false`    | Installer automatiquement lors de `vagrant up`. |
| `manage_firefox`          | Bool    | `false`    | Tenter l’ajout dans les profils Firefox (si trouvés). |
| `manage_nss_browsers`     | Bool    | `true`     | Tenter l’ajout dans la base NSS utilisateur (Chromium/Brave/etc.). |
| `locale`                  | String  | `"en"`     | Langue des messages (`"en"` ou `"fr"`). |
| `verbose`                 | Bool    | `false`    | Journalisation supplémentaire (si disponible). |

**Validation**  
- `cert_path` doit exister et être un fichier.  
- Sous Linux, il faut souvent `sudo` et `libnss3-tools` pour les navigateurs.

---

## Utilisation CLI

```
vagrant certs <commande> [--lang en|fr] [--no-emoji]

Commandes :
  add <PATH>       Installe la CA depuis PATH dans les stores système/navigateurs
  remove <PATH>    Supprime la CA précédemment installée depuis PATH
  list             Affiche les certificats suivis par le plugin
  version          Affiche la version du plugin
  help [TOPIC]     Affiche l’aide (sujets : add, remove, list, version, help)
```

Exemples :

```bash
vagrant certs add ./certs/rootca.cert.pem
vagrant certs remove ./certs/rootca.cert.pem --lang fr
vagrant certs list --no-emoji
vagrant certs version
vagrant certs help add
```

---

## Fonctionnement

- **macOS** : `security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain` pour ajouter ; suppression via `security delete-certificate -Z <sha1>`.
- **Linux (Debian/Ubuntu)** : copie la CA dans `/usr/local/share/ca-certificates/<name>.crt` puis exécute `update-ca-certificates`. Pour les navigateurs, utilise `certutil` (NSS) si présent et si des profils sont trouvés.  
- **Windows** : `certutil -addstore -f ROOT <path>` pour ajouter dans « Autorités de certification racines de confiance » ; suppression via `certutil -delstore ROOT <empreinte>`.

Le plugin peut aussi **installer automatiquement** lors de `vagrant up` si `install_on_up` vaut `true`.

---

## Notes spécifiques aux OS

- **Privilèges** : l’écriture dans les magasins système nécessite souvent **Admin/root**.
- **Firefox** : si activé, le plugin détecte les profils (natif, Flatpak, Snap sous Linux). Sans `certutil`, l’intégration Firefox est ignorée.
- **Navigateurs NSS** : pour Chromium/Brave/Opera/etc., on utilise `~/.pki/nssdb` ou les profils dédiés selon la distribution.
- **Format PEM** : la CA doit être au format PEM. Conversion possible : `openssl x509 -in rootca.crt -out rootca.pem -outform pem`.

---

## Variables d’environnement

| Variable        | Rôle |
|-----------------|------|
| `VDCM_LANG`     | Force la langue (`en`/`fr`) indépendamment de la config. |
| `VDCM_NO_EMOJI` | À `1`, désactive les émojis dans la sortie. |
| `VDCM_DEBUG`    | À `1`, active des journaux de débogage supplémentaires. |

---

## Dépannage

- **Permission refusée** : exécutez dans un shell avec privilèges (Admin sous Windows, `sudo` sous Linux/macOS).
- **Linux : `certutil` manquant** : installer les outils NSS, ex. `sudo apt-get update && sudo apt-get install -y libnss3-tools`.
- **Firefox non mis à jour** : fermez Firefox ; vérifiez l’existence des dossiers de profil ; attention aux variantes Flatpak/Snap.
- **Mauvais certificat** : vérifiez le chemin et le format (`*.pem`). Test : `openssl x509 -in rootca.pem -text -noout`.

---

## Contribuer & Développement

```bash
git clone https://github.com/julienpoirou/vagrant-docker-certificates-manager
cd vagrant-docker-certificates-manager
bundle install
rake          # exécute RSpec
```

- Commits conventionnels bienvenus.
- La CI exécute les tests et le linting.
- Issues et PRs appréciées !

---

## Licence

MIT © 2025 Julien Poirou
