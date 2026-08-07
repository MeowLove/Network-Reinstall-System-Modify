# CXT-SystemPrep

## Cleaning and Encapsulating the System

`CXT-SystemPrep` prepares a Linux installation for offline capture as a reusable DD, RAW, or VHD image.

It removes disposable logs, histories, caches, package-manager history, container text logs, and other transient state. Identity-reset operations are opt-in through explicit switches or profiles.

This is a destructive image-preparation tool. Run it only on a system that is intentionally being sealed for cloning.

## Safety and platform requirements

Real execution requires:

- root privileges; `sudo` is not required;
- Linux with systemd as PID 1;
- `systemd-run` with `--collect` support;
- `loginctl`, `findmnt`, `mktemp`, `cp`, and `sha256sum` or OpenSSL;
- a writable `/run` backed by `tmpfs` or `ramfs`.

Alpine Linux with its default OpenRC init is not supported by the real-execution path. `--help` and `--dry-run` remain available for inspection.

The tool does not provide forensic-grade sanitization. External monitoring systems, remote logging platforms, snapshots, backups, and storage-level remnants are outside its scope.

## Execution lifecycle

For every real run, the script:

1. validates the host and requested operations;
2. copies itself and any custom list files into a private `0700` directory under `/run`;
3. verifies the staged script using SHA-256;
4. starts a transient systemd service with `--collect`;
5. terminates login sessions before deleting histories;
6. performs the requested cleanup;
7. removes the runtime script, transient payload, and source script after successful dispatch/cleanup.

If the service fails after dispatch, the private `/run/cxt-systemprep.*` directory is retained for troubleshooting. On a reboot or poweroff, `/run` is normally cleared automatically.

`--help` and `--dry-run` never stage files, create a service, terminate sessions, or delete the source script.

## Profiles

Profiles never choose a reboot or poweroff action:

| Profile | Includes |
| --- | --- |
| `test` | Core logs, histories, caches, package history, and container text logs |
| `seal` | `test` plus machine identity, cloud-init state, network leases, random seed, SSH host keys, and user `known_hosts` |
| `privacy` | `seal` plus filesystem free-space zeroing and active swap wiping |

For an image that is ready to capture, explicitly add `--poweroff` or `--reboot`.

## Options

| Option | Description |
| --- | --- |
| `--profile test\|seal\|privacy` | Select a preset |
| `--poweroff` | Clean, sync, and power off |
| `--reboot` | Clean, sync, and reboot |
| `--remove-machine-identity` | Enable machine-id, cloud-init state, network lease, and random-seed removal |
| `--remove-machine-id` | Reset `/etc/machine-id` and the legacy D-Bus copy |
| `--remove-cloud-init-state` | Remove cloud-init instance state, logs, runtime state, and seed |
| `--remove-cloud-init-generated-configs` | High risk: also run `cloud-init clean --configs all`; implies state cleanup and requires `--poweroff` or `--reboot` |
| `--remove-network-leases` | Remove saved DHCP and NetworkManager lease files |
| `--remove-random-seed` | Remove systemd's saved random seed |
| `--remove-ssh-host-keys` | Remove SSH server host keys after a boot-time regeneration precheck |
| `--remove-known-hosts` | Remove users' SSH client `known_hosts` files |
| `--zero-free-space` | Zero free space on mounted writable ext2/3/4 and XFS filesystems |
| `--wipe-swap` | Zero active disk swap and recreate its metadata |
| `--paths FILE` | Remove explicitly listed application log/cache paths |
| `--services FILE` | Stop explicitly listed systemd services during cleanup |
| `--dry-run` | Print the plan and make no changes |
| `--verify` | Write an advisory verification report to `cxt-systemprep.log` in the private runtime directory |
| `--yes` | Skip the interactive confirmation |

The former `--terminate-sessions` and `--self-delete` options are intentionally removed because those behaviors are now automatic for every real execution.

## What is cleaned by default

The default cleanup includes system and service logs, journald and audit queues, binary login accounting files, crash and coredump residue, shell/client/editor histories, desktop recent-file records, all users' `.cache` and thumbnail directories, `/tmp`, `/var/tmp`, systemd timer state, DNF/Yum history, logrotate state, container text logs, Kubernetes pod logs, faillock state, and selected volatile logging state.

Container data and application databases are preserved unless explicitly listed through a custom path file. Protected roots and database directories are rejected by the custom-path safety checks.

## Cloud-init warning

By default, `--remove-cloud-init-state` removes instance cache, logs, runtime state, and seed data while preserving cloud-init-generated system configuration.

`--remove-cloud-init-generated-configs` additionally requests `cloud-init clean --configs all`. Depending on the installed cloud-init version and datasource, this may remove generated network configuration, SSH daemon fragments, datasource-specific files, and cloudconfig-tagged `/etc/fstab` entries. Use it only when the next boot is known to provide a compatible datasource and can regenerate the required configuration.

The script performs a dry-run preview of standard generated files and matching `/etc/fstab` entries, but datasource-specific cleanup remains version- and platform-dependent.

## Recommended commands

Preview a seal operation:

```sh
HISTFILE=/dev/null
history -c
exec /bin/sh ./cxt-systemprep.sh --profile seal --poweroff --dry-run
```

Seal and power off:

```sh
HISTFILE=/dev/null
history -c
exec /bin/sh ./cxt-systemprep.sh --profile seal --poweroff --yes
```

Privacy-oriented preparation with a reboot:

```sh
HISTFILE=/dev/null
history -c
exec /bin/sh ./cxt-systemprep.sh --profile privacy --reboot --yes
```

High-risk cloud-init generated-configuration removal:

```sh
HISTFILE=/dev/null
history -c
exec /bin/sh ./cxt-systemprep.sh \
  --profile seal \
  --remove-cloud-init-generated-configs \
  --poweroff \
  --yes
```

For development and troubleshooting, add `--verify`. Without a power action, the report remains under the private `/run/cxt-systemprep.*` directory. With `--reboot` or `--poweroff`, it is intentionally lost when `/run` is cleared.

## Custom list formats

Custom path files contain one absolute file or directory per line. Blank lines and lines beginning with `#` are ignored. Directories are emptied but preserved. Broad roots, mount roots, database roots, and symlinks are rejected.

Custom service files contain one systemd unit name per line. Blank lines and comments are ignored. Listed units are stopped and runtime-masked during cleanup, then restored only when the final action is `none` and they were active before the run.

## License and contribution

Place this directory under:

```text
Tools/CXT-SystemPrep/
```

The repository owner should apply the repository's chosen license and contribution policy when publishing the files.
