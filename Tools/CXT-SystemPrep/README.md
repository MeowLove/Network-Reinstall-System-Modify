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
| `--extra-paths FILE` | Read dedicated, disposable application log/cache paths from a file |
| `--extra-services FILE` | Stop explicitly listed system-manager units during cleanup; useful for activators or services that need an explicit pause |
| `--dry-run` | Print the plan without changing the system |
| `--verify` | Write an advisory verification report to `cxt-systemprep.log` in the private runtime directory |
| `--yes` | Skip the typed confirmation |

`--terminate-sessions`, `--self-delete`, `--audit-open-log-writers`, and
`--ignore-unknown-log-writers` are deliberately absent. Session termination,
source/runtime collection, and log-writer auditing are automatic. An unmapped or
protected writer is a hard safety failure; it cannot be ignored.

## Automatic transient-service behavior

For a real run, CXT-SystemPrep:

1. validates root access, systemd capability, `/run`, requested safety conditions, and package-manager locks;
2. stages the script and extra list files into a private `0700` directory under `/run`;
3. verifies the staged script with SHA-256;
4. starts a transient `systemd-run` service with `--collect`;
5. removes the original uploaded/downloaded script after successful dispatch;
6. terminates interactive login sessions before user histories are removed; with a final power action, all user resources are terminated as well;
7. performs cleanup and the selected final power action;
8. removes the staged script and temporary payload on success.

If the service fails after it starts, the private runtime directory is retained for troubleshooting. If `--verify` is enabled and no power action is selected, its report remains under `/run/cxt-systemprep.*/cxt-systemprep.log`. Use a new SSH connection or console session to inspect it:

```sh
find /run -maxdepth 2 -type f -name cxt-systemprep.log -print
journalctl -u 'cxt-systemprep-*' --no-pager
```

With `--poweroff` or `--reboot`, `/run` is cleared during the next boot, so the verification report is intentionally ephemeral.

## Automatic cleanup-writer handling

Before deleting files, the runtime service scans writable file descriptors,
including pathname-backed Unix sockets, and maps selected cleanup targets and
other log-like paths to their systemd service through the process cgroup. Every
mapped system-service writer is stopped and runtime-masked automatically, including services
not listed in the built-in table. This means a deployed service such as
`picoclaw.service`, `nginx.service`, or a locally installed agent can be paused
without adding its unit name first.

The service itself is never deleted, disabled, edited, or uninstalled. Socket,
timer, and path activators are also paused when necessary. If the final action is
omitted, system units that were active before cleanup are unmasked and restarted. With
`--reboot` or `--poweroff`, they are left stopped for the final transaction; the
captured system's original `enabled` state is unchanged and controls the next
boot.

Only the file contents selected by the cleanup scope are removed. A custom
application log outside the standard system locations is stopped automatically
but preserved unless it is listed in `--extra-paths`. For example, PicoClaw's
`/home/picoclaw/.picoclaw/logs` is preserved by default; add that directory to an
extra-path file when it should be emptied. Nginx logs under `/var/log/nginx` are
part of the standard `/var/log/**` tree and are cleaned automatically.

If a cleanup-related writer cannot be mapped to a systemd service, or belongs to
a protected runtime dependency, the operation stops with an error. There is no
ignore switch because proceeding would allow deleted data to be rewritten while
the image is being sealed.

Systemd user services are handled conservatively. With `--poweroff` or
`--reboot`, user sessions, user managers, and their services are terminated before
the final transaction; their enabled state is not edited, so normal boot policy
controls the cloned system. Without a final power action, user managers are
preserved. If a user service still owns a selected cleanup path or another
log-like file, dry-run reports `BLOCKED` and real cleanup aborts because the tool
cannot guarantee an exact stop-and-restore cycle through every per-user manager.

Dry-run discovery labels:

| Label | Meaning |
| --- | --- |
| `BUILT-IN-STOP` | A built-in platform service will be stopped and its selected data cleaned |
| `AUTO-STOP` | An unlisted service was discovered automatically and its selected data will be cleaned |
| `AUTO-STOP-PRESERVE` | The service will be stopped, but its nonstandard application log is outside the cleanup scope |
| `EXTRA-STOP` | The service was also present in `--extra-services` |
| `USER-STOP` | A systemd user service writes selected data and its user resources will terminate before reboot or poweroff |
| `USER-STOP-PRESERVE` | A user service will terminate before the final power action, but its nonstandard application log is preserved |
| `BLOCKED` | The writer cannot be stopped safely; a real run will abort |

## Default cleanup scope

The default `test` scope removes:

- system, service, journal, audit, accounting, crash, coredump, and transient log queues;
- shell, client, editor, desktop recent-file, and user cache/thumbnail data;
- DNF/Yum history, logrotate state, temporary files, timer state, and faillock state;
- Docker, Podman, containerd, CRI-O, and Kubernetes **text logs**, while preserving container images, volumes, and application data.

Fail2ban/CrowdSec databases, container data, package databases, security rules,
and application databases are not general cleanup targets. In particular, the
Fail2ban ban database is retained because it is operational state rather than a
log. Extra business logs or caches must be explicitly supplied through
`--extra-paths` after reviewing the safety restrictions.

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

## Extra list files

`--extra-paths FILE` accepts one absolute path per line. Blank lines and `#`
comments are ignored. A listed directory is emptied but preserved. The script
rejects symlinks, broad system roots, protected configuration/state trees, mount
roots, database roots, and suspicious paths outside dedicated
log/cache/history/trace/audit/tmp locations. This is the normal mechanism for
cleaning application-owned paths such as `/home/picoclaw/.picoclaw/logs`.

`--extra-services FILE` accepts one system-manager `.service`, `.socket`,
`.timer`, or `.path` unit per line. Arbitrary `.target` units, critical runtime
dependencies, systemd user-manager units, and missing or unloaded units are
rejected before staging. Listed units are stopped and runtime-masked during
cleanup. They are restored only when no final power action is selected and they
were active before the run. This option is an advanced override for activators
or services that cannot be discovered from a currently open log file; it is not
normally needed for a service that writes a standard or extra log path.

Extra list files are copied into the private `/run` staging directory for
execution, but their original source files are not deleted. Put the originals
under `/run` too if they should disappear on the next reboot.

Example for PicoClaw:

```sh
printf '%s\n' /home/picoclaw/.picoclaw/logs > /run/cxt-extra-paths.list
exec /bin/sh /run/CXT-SystemPrep.sh \
  --profile test --extra-paths /run/cxt-extra-paths.list --yes
```

## Platform requirements and limits

Real execution requires root, systemd as PID 1, `systemd-run --collect`, `loginctl`, `findmnt`, a writable tmpfs/ramfs-backed `/run`, and SHA-256 support from `sha256sum` or OpenSSL.

This supports mainstream systemd-based Debian, Ubuntu, RHEL, Rocky Linux, AlmaLinux, Fedora, and similar systems when the required capabilities are present. Alpine Linux running its default OpenRC init is intentionally rejected for real execution.
