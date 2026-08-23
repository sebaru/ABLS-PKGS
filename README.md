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
2. Exporter automatiquement la clef publique GPG dans `public/rpms/keys/RPM-GPG-KEY-ABLS` depuis la clef locale si elle manque
3. Executer `./scripts/update-rpm.sh`

Workflow RPM (`./scripts/update-rpm.sh`):

- Mise a jour in-place des metadonnees dans `public/rpms/*`
- Signature automatique des paquets RPM et de `repodata/repomd.xml` pour chaque architecture
- Mise a jour automatique du checksum `public/rpms/keys/RPM-GPG-KEY-ABLS.sha256`
- Republie aussi la clef APT partagee `public/abls-archive-keyring.{asc,gpg}`
- Ajoute automatiquement les artefacts RPM et keyrings au prochain commit Git

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

Workflow DEB (2 machines):

1. Deposer les `.deb` dans `deb-packages/bookworm/` ou `deb-packages/trixie/`
2. Sur l'hote d'import (ex: armhf), executer `./scripts/update-deb-import.sh`
3. Commit/push des changements `public/deb/`
4. Sur l'hote de signature (ex: amd64), pull puis executer `./scripts/update-deb-sign.sh`

- `scripts/update-deb-import.sh` importe les `.deb` depuis `deb-packages/<suite>/` et `deb-packages/<suite>/<arch>/` puis regenere les index APT non signes.
- `scripts/update-deb-sign.sh` applique `SignWith`, regenere les metadonnees signees et republie les keyrings APT partages.
- Seuls les artefacts publies (`public/deb/*`, keyrings) sont versionnes; la zone `deb-packages/` reste une zone de transit.

Notes:

- Le depot DEB est signe avec la meme clef GPG que le depot RPM.
- Les artefacts `public/abls-archive-keyring.asc` et `public/abls-archive-keyring.gpg` sont regeneres pendant l'etape de signature depuis cette clef partagee.
- Pour Raspberry Pi 64-bit, utiliser `arm64`.
- Pour Raspberry Pi OS 32-bit, utiliser `armhf`.
- `scripts/update-deb-import.sh` ne requiert pas la clef privee GPG.
- `scripts/update-deb-sign.sh` requiert la clef privee GPG sur l'hote de signature.

Exemples de build puis publication:

- Executer `./build_apt.sh --dist bookworm` sur une machine `arm64`
- Executer `./build_apt.sh --dist bookworm` sur une machine `armhf`
- Copier ensuite les `.deb` dans `deb-packages/bookworm/arm64/` ou `deb-packages/bookworm/armhf/`
- Sur la machine d'import: `./scripts/update-deb-import.sh`
- Commit/push des changements `public/deb/`
- Sur la machine de signature: pull puis `./scripts/update-deb-sign.sh`

## Configuration client

Exemple de fichier repo client: `public/abls-rpms.repo`

- gpgcheck=1: verification de signature des paquets
- repo_gpgcheck=1: verification de signature des metadonnees RPM activee

Exemple APT (Debian/RaspiOS):

- `sudo install -d -m 0755 /etc/apt/keyrings`
- `sudo wget -O /etc/apt/keyrings/abls-archive-keyring.gpg https://pkgs.abls-habitat.fr/abls-archive-keyring.gpg`
- `sudo chmod 0644 /etc/apt/keyrings/abls-archive-keyring.gpg`
- `source /etc/os-release && sudo wget -O /etc/apt/sources.list.d/abls-pkgs.sources https://pkgs.abls-habitat.fr/abls-pkgs-${VERSION_CODENAME}.sources`
- `sudo apt update`

## Publication

Le repertoire `public/` est la cible exposee en HTTP.

Le script `update-rpm.sh` met a jour `public/rpms/` en place.
Le script `update-deb-import.sh` met a jour `public/deb/` a partir de `deb-packages/` sans signature.
Le script `update-deb-sign.sh` signe les metadonnees DEB et met aussi a jour les keyrings APT publics.
`update-rpm.sh` et `update-deb-sign.sh` relancent `scripts/verify-repo.sh`.
