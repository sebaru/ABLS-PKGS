#!/usr/bin/env python3

import bz2
import gzip
import json
import lzma
import os
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from email.parser import Parser


def read_metadata(path):
    if path.suffix == ".zst":
        return subprocess.check_output(["zstd", "--decompress", "--stdout", str(path)])
    open_metadata = {
        ".gz": gzip.open,
        ".bz2": bz2.open,
        ".xz": lzma.open,
    }.get(path.suffix, open)
    with open_metadata(path, "rb") as metadata:
        return metadata.read()


def collect_packages(public_dir):
    packages = []
    for index in sorted((public_dir / "deb" / "dists").glob("*/*/binary-*/Packages")):
        suite = index.relative_to(public_dir / "deb" / "dists").parts[0]
        for stanza in index.read_text(encoding="utf-8").split("\n\n"):
            if not stanza.strip():
                continue
            fields = Parser().parsestr(stanza)
            for field in ("Package", "Version", "Architecture"):
                if not fields[field]:
                    raise ValueError(f"Missing {field} in {index}")
            packages.append({
                "name": fields["Package"],
                "version": fields["Version"],
                "format": "deb",
                "architecture": fields["Architecture"],
                "distribution": suite,
            })

    namespaces = {
        "repo": "http://linux.duke.edu/metadata/repo",
        "common": "http://linux.duke.edu/metadata/common",
    }
    for index in sorted((public_dir / "rpms").glob("*/repodata/repomd.xml")):
        repo = ET.parse(index)
        location = repo.find("repo:data[@type='primary']/repo:location", namespaces)
        if location is None:
            raise ValueError(f"Missing primary metadata in {index}")
        primary = ET.fromstring(read_metadata(index.parent.parent / location.attrib["href"]))
        for package in primary.findall("common:package", namespaces):
            version = package.find("common:version", namespaces).attrib
            full_version = version["ver"]
            if version.get("rel"):
                full_version += "-" + version["rel"]
            if version.get("epoch", "0") != "0":
                full_version = version["epoch"] + ":" + full_version
            packages.append({
                "name": package.find("common:name", namespaces).text,
                "version": full_version,
                "format": "rpm",
                "architecture": package.find("common:arch", namespaces).text,
                "distribution": "",
            })

    return sorted(packages, key=lambda package: (
        package["format"], package["name"], package["distribution"],
        package["architecture"], package["version"],
    ))


def main():
    public_dir = Path(__file__).resolve().parent.parent / "public"
    packages = collect_packages(public_dir)
    inventory = public_dir / "inventory.json"
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=public_dir,
                                         prefix=".inventory-", delete=False) as output:
            temporary_path = Path(output.name)
            json.dump({"packages": packages}, output, indent=2)
            output.write("\n")
            os.fchmod(output.fileno(), 0o644)
        temporary_path.replace(inventory)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    print(f"OK: inventory updated in {inventory} ({len(packages)} packages)")


if __name__ == "__main__":
    main()