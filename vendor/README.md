# Vendor files

This directory is for local-only vendor artifacts that cannot be redistributed
in this repository.

Some vendored dependencies are required for EL2 boot support, but the files
themselves are not committed. To keep a local password-protected backup, create:

```console
./scripts/create-vendor-archive.sh
```

To restore vendored dependencies from the local encrypted archive:

```console
./scripts/restore-vendor-dependencies.sh
```

The encrypted archive path is:

```text
vendor/dependencies.tar.gz.enc
```

That archive is ignored by Git.
