# ABLS-PKGS

Depot de publication RPM et DEB/APT du projet ABLS-HABITAT.

## Preparation de l'hote

Installer les dependances de publication avec:

- `./install_deps.sh`

Le script detecte automatiquement le type d'hote:

- hote RPM: installe `createrepo_c`, `git`, `gnupg2`, `rpm-sign`
- hote Debian: installe `git`, `gnupg`, `reprepro`

## Arborescence

- public/rpms/x86_64
- public/rpms/aarch64
- public/rpms/noarch
- public/deb
- public/rpms/keys
- scripts

## Workflow

1. Deposer les RPM directement dans `public/rpms/$arch` (`x86_64`, `aarch64`, `noarch`)
2. Exporter la clef publique GPG dans `public/rpms/keys/RPM-GPG-KEY-ABLS`
3. Executer `./update.sh`

Mode par defaut (`./update.sh`):

- execute `scripts/update-rpm.sh` puis `scripts/update-deb.sh`
- Mise a jour in-place des metadonnees dans `public/rpms/*`
- Signature automatique des paquets RPM et de `repodata/repomd.xml` pour chaque architecture
- Mise a jour automatique du checksum `public/rpms/keys/RPM-GPG-KEY-ABLS.sha256`
- Mise a jour et signature des metadonnees APT dans `public/deb/*`

Verification finale:

- `scripts/verify-repo.sh`

## Publication DEB/APT

Le meme domaine peut servir RPM et APT, avec des metadonnees separees.

Arborescence DEB geree par `reprepro`:

- `public/deb/conf`
- `public/deb/dists`
- `public/deb/pool`
- `deb-packages/<suite>/` (zone de depot des `.deb` a publier)
- `deb-packages/<suite>/<arch>/` (recommande pour publier plusieurs architectures)

Workflow DEB:

1. Deposer les `.deb` dans `deb-packages/bookworm/` ou `deb-packages/trixie/`
2. Executer `./update.sh` (ou `./scripts/update-deb.sh`)

- importe les `.deb` depuis `deb-packages/<suite>/` et `deb-packages/<suite>/<arch>/`
- regenere `public/deb/dists/*` et les signatures APT associees

Notes:

- Le depot DEB est signe avec la meme clef GPG que le depot RPM.
- Pour Raspberry Pi 64-bit, utiliser `arm64`.
- Pour Raspberry Pi OS 32-bit, utiliser `armhf`.
- `update.sh` publie RPM et DEB dans la meme passe.

Exemples de build puis publication:

- Executer `./build_apt.sh --dist bookworm` sur une machine `arm64`
- Executer `./build_apt.sh --dist bookworm` sur une machine `armhf`
- Copier ensuite les `.deb` dans `deb-packages/bookworm/arm64/` ou `deb-packages/bookworm/armhf/`
- Relancer `./scripts/update-deb.sh`

## Configuration client

Exemple de fichier repo client: `public/abls-rpms.repo`

- gpgcheck=1: verification de signature des paquets
- repo_gpgcheck=1: verification de signature des metadonnees RPM activee

Exemple APT (Debian/RaspiOS):

- `sudo install -d -m 0755 /etc/apt/keyrings`
- `sudo wget -O /etc/apt/keyrings/abls-archive-keyring.gpg https://pkgs.abls-habitat.fr/abls-archive-keyring.gpg`
- `sudo chmod 0644 /etc/apt/keyrings/abls-archive-keyring.gpg`
- `sudo wget -O /etc/apt/sources.list.d/abls-deb.sources https://pkgs.abls-habitat.fr/abls-deb.sources`
- `sudo apt update`

## Publication

Le repertoire `public/` est la cible exposee en HTTP.

Le script `update-rpm.sh` met a jour `public/rpms/` en place.
Le script `update-deb.sh` met a jour `public/deb/` a partir de `deb-packages/`.
En mode normal, `update.sh` choisit automatiquement le bon sous-flux selon l'hote.
