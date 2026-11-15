# External SSD storage

The project uses /Volumes/siva_ssd/Development/Omarchy for large files. The existing SSD is APFS without case sensitivity. OmarchyBuild.sparsebundle inside that folder is a 160 GiB maximum, dynamically allocated case-sensitive APFS image. It mounts at /Volumes/OmarchyBuild. No SSD repartition or format operation was performed.

- artifacts/work: firmware, exact device backups, tool downloads and scratch files.
- OmarchyBuild.sparsebundle: Linux checkout and baseline/minimal build directories.
- Repository: /Users/siva/Development/Omarchy, retaining the existing Git remote/history.

Local paths are configured in ignored storage.local.env. Before building after reconnecting the SSD:

```sh
hdiutil attach /Volumes/siva_ssd/Development/Omarchy/OmarchyBuild.sparsebundle -nobrowse
bash scripts/prepare-linux-source.sh
```

Scripts require the marker inside the mounted image and use read-only source mounts. Do not unplug the SSD during builds. Stop build containers and detach the image before ejecting the SSD. Original Docker baseline volumes remain available as a fallback; they have not been removed. The work directory is switched to an SSD symlink only after copy verification.

Baseline Image/vmlinux/config/overlay hashes and source cleanliness are checked after migration. The firmware/work copy is compared by rsync checksums before switching. Raw device images, diagnostics and keys remain excluded from Git.
