# ABLS-RPMS

Depot RPM du projet ABLS-HABITAT.

## Arborescence

- public/x86_64
- public/aarch64
- public/noarch
- public/deb
- public/keys
- scripts

## Workflow

1. Deposer les RPM directement dans `public/$arch` (`x86_64`, `aarch64`, `noarch`)
2. Exporter la clef publique GPG dans `public/keys/RPM-GPG-KEY-ABLS`
3. Executer `./update.sh`

Mode par defaut (`./update.sh`):

- Mise a jour in-place des metadonnees dans `public/*`.
- Mise a jour automatique du checksum `public/keys/RPM-GPG-KEY-ABLS.sha256`.

Mode reset explicite (`./update.sh clean`):

- Nettoyage des RPM presents dans `public/*` avant regeneration complete des metadonnees.

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
2. Executer `./update.sh` (ou `./scripts/publish-deb.sh`)

Notes:

- Si `ABLS_GPG_KEYID` est defini, `publish-deb.sh` configure la signature des metadata Release/InRelease.
- Sans `ABLS_GPG_KEYID`, le depot est publie sans signature metadata.

## Configuration client

Exemple de fichier repo client: `public/abls-rpms.repo`

- gpgcheck=1: verification de signature des paquets
- repo_gpgcheck=0: verification de metadonnees desactivee (a activer plus tard si repodata signee)

## Publication

Le repertoire `public/` est la cible exposee en HTTP.

Le script `publish.sh` met a jour `public/` en place.
En mode normal, il conserve les RPM deja presents et met a jour les metadonnees.
En mode `clean`, il supprime les RPM avant republication complete.
