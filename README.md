# ABLS-RPMS

Depot RPM du projet ABLS-HABITAT.

## Arborescence

- repo/x86_64
- repo/aarch64
- repo/noarch
- keys
- scripts
- published

## Workflow

1. Executer scripts/bootstrap-repo.sh
2. Exporter la clef publique GPG dans keys/RPM-GPG-KEY-ABLS
3. Executer ./update.sh

Mode par defaut (`./update.sh`):

- Les RPM sont deposes directement dans `repo/*`.
- Publication in-place vers `published/`.

Mode reset explicite (`./update.sh clean`):

- Nettoyage des RPM publies avant republication complete.

Verification finale:

- `scripts/verify-repo.sh`

## Configuration client

Exemple de fichier repo client: abls-rpms.repo

- gpgcheck=1: verification de signature des paquets
- repo_gpgcheck=0: verification de metadonnees desactivee (a activer plus tard si repodata signee)

## Publication

Le repertoire published est la cible exposee en HTTP.

Le script `publish.sh` met a jour `published/` en place.
En mode normal, il conserve les RPM deja publies et ajoute/met a jour ceux presents dans `repo/*`.
En mode `clean`, il supprime les RPM publies avant republication complete.
