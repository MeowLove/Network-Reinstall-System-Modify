# CXT-SystemPrep

## Cleaning and Encapsulating the System

`CXT-SystemPrep` prepares a Linux template system for offline capture as a reusable DD, RAW, QCOW2, or VHD image.

It removes disposable logs, histories, caches, package-manager history, container text logs, and transient state. Clone-specific identity operations are explicit and never selected by the default profile.

> **Warning**
>
> This tool is destructive. Use it only on a source system that is deliberately being sealed for cloning. It is not a forensic sanitization utility and cannot erase data already sent to remote logging, monitoring, backups, snapshots, or lower storage layers.

## Download and run

Run the following as `root`. The recommended location is `/run`: it is normally a volatile runtime filesystem and the script will remove its uploaded source copy after successful service dispatch.

```sh
curl -fL --proto '=https' --tlsv1.2 \
  'https://raw.githubusercontent.com/MeowLove/Network-Reinstall-System-Modify/refs/heads/master/Tools/CXT-SystemPrep/CXT-SystemPrep.sh' \
  -o /run/CXT-SystemPrep.sh

chmod 700 /run/CXT-SystemPrep.sh
/bin/sh /run/CXT-SystemPrep.sh --help
```

If `curl` is unavailable:

```sh
wget -O /run/CXT-SystemPrep.sh \
  'https://raw.githubusercontent.com/MeowLove/Network-Reinstall-System-Modify/refs/heads/master/Tools/CXT-SystemPrep/CXT-SystemPrep.sh'
chmod 700 /run/CXT-SystemPrep.sh
```

For repeatable production use, download from an immutable Git tag or commit URL rather than a moving branch reference. Before execution, inspect the file and record its checksum:

```sh
sha256sum /run/CXT-SystemPrep.sh
/bin/sh /run/CXT-SystemPrep.sh --profile seal --poweroff --dry-run
```

## Recommended invocation

The script automatically stages itself under a private `/run/cxt-systemprep.*` directory, creates a transient systemd service, and terminates login sessions. An SSH or console session that starts a real cleanup is therefore expected to disconnect.

To minimize Bash history residue, start a real operation as follows:

```sh
HISTFILE=/dev/null
history -c 2>/dev/null || :
exec /bin/sh /run/CXT-SystemPrep.sh --profile seal --poweroff --yes
```

The `exec` is intentional: the interactive shell is replaced by the script launcher, and the transient service performs the actual cleanup after staging.

## Safe preview

`--dry-run` prints the resolved scope and safety checks only. It does **not** stage the script, create a service, terminate sessions, remove files, or power off the machine.

```sh
/bin/sh /run/CXT-SystemPrep.sh --profile seal --poweroff --dry-run
```

## Profiles

| Profile | Scope |
| --- | --- |
| `test` | Core logs, histories, caches, package history, and container text logs only |
| `seal` | `test` plus machine identity, cloud-init state, network leases, random seed, SSH host keys, and SSH client `known_hosts` |
| `privacy` | `seal` plus mounted filesystem free-space zeroing and active swap wiping |

Profiles do not choose the final power action. `seal` and `privacy` require `--poweroff` or `--reboot` because identity, lease, random-seed, and SSH-host-key cleanup must not be followed by continued normal operation.

Examples:

```sh
# Development-oriented cleanup. The login session will still be terminated.
exec /bin/sh /run/CXT-SystemPrep.sh --profile test --yes

# Normal golden-image sealing.
exec /bin/sh /run/CXT-SystemPrep.sh --profile seal --poweroff --yes

# Privacy-oriented sealing with a reboot.
exec /bin/sh /run/CXT-SystemPrep.sh --profile privacy --reboot --yes
```

`test` is useful for development checks, not final image capture: with no final power action, previously active services are restored and may create fresh logs or transient state after cleanup.

## Options

| Option | Effect |
| --- | --- |
| `--profile test\|seal\|privacy` | Select a preset scope |
| `--poweroff` | Clean, sync, and power off |
| `--reboot` | Clean, sync, and reboot |
| `--remove-machine-identity` | Enable machine-id, cloud-init state, network lease, and random-seed cleanup |
| `--remove-machine-id` | Mark `/etc/machine-id` as uninitialized and remove the legacy D-Bus copy; requires a final power action |
| `--remove-cloud-init-state` | Remove cloud-init instance cache, logs, runtime state, and seed data |
| `--remove-cloud-init-generated-configs` | **High risk:** also run `cloud-init clean --configs all`; implies cloud-init state cleanup and requires `--poweroff` or `--reboot` |
| `--remove-network-leases` | Remove saved DHCP and NetworkManager lease files; requires a final power action |
| `--remove-random-seed` | Remove systemd's saved random seed; requires a final power action |
| `--remove-ssh-host-keys` | Remove SSH server host keys after a boot-time regeneration precheck; requires a final power action |
| `--remove-known-hosts` | Remove user and system-wide SSH client `known_hosts` files |
| `--zero-free-space` | Zero free space on writable ext2/3/4 and XFS filesystems; slow, but improves raw-image compression |
| `--wipe-swap` | Zero active disk swap and recreate its metadata; slow and requires adequate RAM |
| `--paths FILE` | Read dedicated, disposable application log/cache paths from a file |
| `--services FILE` | Stop explicitly listed systemd services during cleanup |
| `--dry-run` | Print the plan without changing the system |
| `--verify` | Write an advisory verification report to `cxt-systemprep.log` in the private runtime directory |
| `--yes` | Skip the typed confirmation |

`--terminate-sessions` and `--self-delete` are deliberately absent. Those actions are automatic for every real execution.

## Automatic transient-service behavior

For a real run, CXT-SystemPrep:

1. validates root access, systemd capability, `/run`, requested safety conditions, and package-manager locks;
2. stages the script and custom list files into a private `0700` directory under `/run`;
3. verifies the staged script with SHA-256;
4. starts a transient `systemd-run` service with `--collect`;
5. removes the original uploaded/downloaded script after successful dispatch;
6. terminates login sessions before user histories are removed;
7. performs cleanup and the selected final power action;
8. removes the staged script and temporary payload on success.

If the service fails after it starts, the private runtime directory is retained for troubleshooting. If `--verify` is enabled and no power action is selected, its report remains under `/run/cxt-systemprep.*/cxt-systemprep.log`. Use a new SSH connection or console session to inspect it:

```sh
find /run -maxdepth 2 -type f -name cxt-systemprep.log -print
journalctl -u 'cxt-systemprep-*' --no-pager
```

With `--poweroff` or `--reboot`, `/run` is cleared during the next boot, so the verification report is intentionally ephemeral.

## Default cleanup scope

The default `test` scope removes:

- system, service, journal, audit, accounting, crash, coredump, and transient log queues;
- shell, client, editor, desktop recent-file, and user cache/thumbnail data;
- DNF/Yum history, logrotate state, temporary files, timer state, and faillock state;
- Docker, Podman, containerd, CRI-O, and Kubernetes **text logs**, while preserving container images, volumes, and application data.

Container data, package databases, and application databases are not general cleanup targets. Extra business logs or caches must be explicitly supplied through `--paths` after reviewing the safety restrictions.

## Cloud-init behavior

`--remove-cloud-init-state` clears cloud-init instance state, logs, runtime state, and seed data, while intentionally retaining cloud-init-generated system configuration.

`--remove-cloud-init-generated-configs` is a separate high-risk option. It requests `cloud-init clean --configs all`, which may remove generated network configuration, SSH daemon fragments, datasource-specific files, and cloud-init-managed `/etc/fstab` entries. Use it only when the next boot is guaranteed to receive compatible cloud-init data and can regenerate the configuration.

Use dry-run before enabling this option:

```sh
/bin/sh /run/CXT-SystemPrep.sh \
  --profile seal \
  --remove-cloud-init-generated-configs \
  --poweroff \
  --dry-run
```

## Custom list files

`--paths FILE` accepts one absolute path per line. Blank lines and `#` comments are ignored. A listed directory is emptied but preserved. The script rejects symlinks, broad system roots, protected configuration/state trees, mount roots, database roots, and suspicious paths outside dedicated log/cache/history/trace/audit/tmp locations.

`--services FILE` accepts one systemd service unit per line. Listed units are stopped and runtime-masked during cleanup. They are restored only when no final power action is selected and they were active before the run.

Custom list files are copied into the private `/run` staging directory for execution, but their original source files are not deleted. Put the originals under `/run` too if they should disappear on the next reboot.

## Platform requirements and limits

Real execution requires root, systemd as PID 1, `systemd-run --collect`, `loginctl`, `findmnt`, a writable tmpfs/ramfs-backed `/run`, and SHA-256 support from `sha256sum` or OpenSSL.

This supports mainstream systemd-based Debian, Ubuntu, RHEL, Rocky Linux, AlmaLinux, Fedora, and similar systems when the required capabilities are present. Alpine Linux running its default OpenRC init is intentionally rejected for real execution.
