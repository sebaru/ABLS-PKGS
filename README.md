# ABLS-PKGS

Depot RPM du projet ABLS-HABITAT.

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

- Mise a jour in-place des metadonnees dans `public/rpms/*`.
- Signature automatique de `repodata/repomd.xml` pour chaque architecture.
- Mise a jour automatique du checksum `public/rpms/keys/RPM-GPG-KEY-ABLS.sha256`.

Verification finale:

- `scripts/verify-repo.sh`

## Publication DEB/APT

Le meme domaine peut servir RPM et APT, avec des metadonnees separees.

Arborescence DEB geree par `reprepro`:

- `public/deb/conf`
- `public/deb/dists`
- `public/deb/pool`
- `deb-packages/<suite>/` (zone de depot des `.deb` a publier)

Workflow DEB:

1. Deposer les `.deb` dans `deb-packages/bookworm/` ou `deb-packages/trixie/`
2. Executer `./update.sh` (ou `./scripts/update-deb.sh`)

Notes:

- Le depot DEB est signe avec la meme clef GPG que le depot RPM.

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
En mode normal, il conserve les RPM deja presents et met a jour les metadonnees.
