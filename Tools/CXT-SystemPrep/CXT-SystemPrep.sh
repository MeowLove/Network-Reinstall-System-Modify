#!/bin/sh
# CXT-SystemPrep - Cleaning and Encapsulating the System
# Sealed release: 2026-08-07
# Prepare a Linux installation for offline capture as a reusable disk image.
#
# Run only on a source/template system intended for image preparation.
# Default: remove logs/history/caches/transient state without resetting clone
# identity and without rebooting or powering off.
# Custom application logs outside standard locations are read only when an explicit
# --paths/--services file is supplied.

set -eu

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
umask 077

ACTION=none
ACTION_SELECTED=0
ASSUME_YES=0
REMOVE_MACHINE_ID=0
REMOVE_CLOUD_INIT_STATE=0
REMOVE_CLOUD_INIT_GENERATED_CONFIGS=0
REMOVE_NETWORK_LEASES=0
REMOVE_RANDOM_SEED=0
REMOVE_SSH_HOST_KEYS=0
REMOVE_KNOWN_HOSTS=0
ZERO_FREE_SPACE=0
WIPE_SWAP=0
CUSTOM_PATH_FILE=
CUSTOM_SERVICE_FILE=
DRY_RUN=0
VERIFY=0
SCRIPT_PATH=
VERIFY_LOG=
IN_RUNTIME_SERVICE=0
SOURCE_SCRIPT_PATH=
RUNTIME_DIR=
PROFILE=default
PROFILE_SELECTED=0
PLAN_BLOCKED=0
STATE_DIR=
ACTIVE_SYSTEMD_UNITS=
ACTIVE_SYSV_SERVICES=
RUNTIME_MASKED_UNITS=
AUDIT_WAS_ENABLED=
EXEC_ENV_ERROR=
RUNTIME_RESTORED=0
FINAL_JOURNAL_STOPPED=0
ACTIVE_ZERO_FILE=
DISABLED_SWAP_TARGETS=
POWER_ACTION_IN_PROGRESS=0

STANDARD_CLEANUP_UNITS='
rsyslog.service
syslog-ng.service
systemd-journal-upload.service
systemd-journal-remote.service
systemd-journal-remote.socket
systemd-journal-gatewayd.service
systemd-journal-gatewayd.socket
acct.service
psacct.service
atop.service
auditd.service
cron.service
crond.service
anacron.service
atd.service
timers.target
logrotate.service
logrotate.timer
systemd-tmpfiles-clean.service
systemd-tmpfiles-clean.timer
fail2ban.service
denyhosts.service
crowdsec.service
docker.service
docker.socket
containerd.service
podman.service
podman.socket
podman-auto-update.service
podman-auto-update.timer
crio.service
kubelet.service
packagekit.service
apt-daily.service
apt-daily.timer
apt-daily-upgrade.service
apt-daily-upgrade.timer
unattended-upgrades.service
dnf-makecache.service
dnf-makecache.timer
dnf-automatic.service
dnf-automatic.timer
dnf5daemon-server.service
yum-cron.service
yum-cron.timer
systemd-random-seed.service
'

NETWORK_LEASE_UNITS='
NetworkManager.service
systemd-networkd.service
networking.service
network.service
wicked.service
wicked-dhcp4.service
wicked-dhcp6.service
dhcpcd.service
connman.service
'

usage() {
    cat <<'EOF'
Usage: CXT-SystemPrep.sh [options]

Options:
  --profile PROFILE        Feature preset: test, seal, or privacy
  --poweroff               Clean, sync, and power off; default is no power action
  --reboot                 Clean, sync, and reboot; default is no power action
  --remove-machine-identity
                           Enable machine-id, cloud-init state, network lease,
                           and random-seed removal
  --remove-machine-id      Mark /etc/machine-id uninitialized and remove the
                           legacy D-Bus copy; requires --poweroff or --reboot
  --remove-cloud-init-state
                           Clean cloud-init instance cache, logs, runtime, and seed
  --remove-cloud-init-generated-configs
                           HIGH RISK: also run cloud-init clean --configs all;
                           implies --remove-cloud-init-state and requires --poweroff
                           or --reboot. Not included in any profile. Use only when
                           the next boot has a compatible cloud-init datasource.
  --remove-network-leases  Remove DHCP/network-manager lease files; requires a
                           final power action so active networking cannot repopulate them
  --remove-random-seed     Remove systemd's saved random seed; requires a final
                           power action so shutdown cannot save it again
  --remove-ssh-host-keys   Remove SSH server host keys; requires --poweroff or
                           --reboot and verified boot-time regeneration
  --remove-known-hosts     Remove user and system-wide SSH client known_hosts files
  --zero-free-space        Fill free space on mounted ext2/3/4 and XFS filesystems
                           with zeros (slow; improves raw DD image compression)
  --wipe-swap              Zero active disk swap and recreate its UUID/label; swap
                           remains off until next boot (slow; requires enough RAM)
  --paths FILE             Read extra application log paths from FILE
  --services FILE          Stop extra application units listed in FILE
  --dry-run                Print the resolved plan; make no changes
  --verify                 Write advisory verification to cxt-systemprep.log in
                           the private runtime directory
  --yes                    Skip the interactive confirmation
  -h, --help               Show this help

Extra-path file format:
  One absolute file or directory per line. Empty lines and lines beginning with #
  are ignored. A directory's contents are removed but the directory is preserved.
  Protected system/configuration/state trees and mount roots are rejected. Outside
  /var/log and /var/cache, the path must contain a dedicated log, cache, history,
  trace, audit, tmp, or temp component. List only disposable application data.

Service-file format:
  One systemd service unit per line; empty lines and # comments are ignored.

Profiles never select reboot or poweroff:
  test     Core logs, histories, caches, package history, and container logs only
  seal     test + machine identity + SSH host keys + SSH client known_hosts
  privacy  seal + mounted filesystem free-space zeroing + active swap wiping
  seal and privacy must be combined with --poweroff or --reboot.

Real execution requirements and lifecycle:
  A modern systemd host with systemd-run --collect and loginctl is required.
  The script copies itself and custom list files into a private 0700 directory
  under tmpfs-backed /run, verifies the script copy by SHA-256, starts a
  transient service, terminates login sessions, and removes the source script.
  Original --paths/--services list files are not deleted; place them under /run
  as well when their automatic removal at reboot is desired.
  On success, the runtime script and transient payload are also removed.
  --help and --dry-run never stage, start a service, terminate sessions, or
  delete the script. Alpine Linux using its default OpenRC init is unsupported.
EOF
}

log() { printf '%s\n' "[CXT-SystemPrep] $*"; }
warn() { printf '%s\n' "[CXT-SystemPrep] WARNING: $*" >&2; }
die() { printf '%s\n' "[CXT-SystemPrep] ERROR: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
resolve_script_path() {
    case $0 in
        /*) resolved_script=$0 ;;
        */*)
            resolved_dir=$(dirname -- "$0")
            resolved_base=$(basename -- "$0")
            resolved_script=$(cd -P -- "$resolved_dir" 2>/dev/null &&
                printf '%s/%s' "$(pwd -P)" "$resolved_base") || resolved_script=
            ;;
        *)
            if [ -f "$0" ]; then
                resolved_script=$(printf '%s/%s' "$(pwd -P)" "$0")
            else
                resolved_script=$(command -v "$0" 2>/dev/null || printf '')
            fi
            case $resolved_script in /*) ;; *) resolved_script= ;; esac
            ;;
    esac
    [ -n "$resolved_script" ] || return 1
    printf '%s\n' "$resolved_script"
}

in_detached_service() {
    grep -Eq '/[^/]+\.service(/|$)' /proc/$$/cgroup 2>/dev/null
}
sha256_file() {
    hash_target=$1
    if have sha256sum; then
        sha256sum -- "$hash_target" | awk '{print $1}'
    elif have openssl; then
        openssl dgst -sha256 "$hash_target" | awk '{print $NF}'
    else
        return 1
    fi
}
check_execution_environment() {
    EXEC_ENV_ERROR=
    [ -r /proc/1/comm ] || {
        EXEC_ENV_ERROR='cannot identify PID 1; a systemd host is required'
        return 1
    }
    [ "$(tr -d '\r\n' < /proc/1/comm 2>/dev/null || printf unknown)" = systemd ] || {
        EXEC_ENV_ERROR='PID 1 is not systemd; OpenRC, SysV init, and container-only environments are unsupported'
        return 1
    }
    have systemctl || { EXEC_ENV_ERROR='systemctl is required'; return 1; }
    have systemd-run || { EXEC_ENV_ERROR='systemd-run is required'; return 1; }
    have loginctl || { EXEC_ENV_ERROR='loginctl is required to terminate login sessions'; return 1; }
    have findmnt || { EXEC_ENV_ERROR='findmnt is required to verify /run'; return 1; }
    have readlink || { EXEC_ENV_ERROR='readlink is required for path and open-log safety checks'; return 1; }
    have mktemp || { EXEC_ENV_ERROR='mktemp is required for private runtime staging'; return 1; }
    have cp || { EXEC_ENV_ERROR='cp is required for private runtime staging'; return 1; }
    have sha256sum || have openssl || {
        EXEC_ENV_ERROR='sha256sum or openssl is required to verify the staged script'
        return 1
    }
    [ -d /run ] && [ ! -L /run ] && [ -w /run ] || {
        EXEC_ENV_ERROR='/run must be a writable real directory'
        return 1
    }
    [ -d /run/systemd/system ] || {
        EXEC_ENV_ERROR='systemd is not managing this boot (/run/systemd/system is missing)'
        return 1
    }
    run_fstype=$(findmnt -n -T /run -o FSTYPE 2>/dev/null | awk 'NR == 1 {print; exit}')
    case $run_fstype in
        tmpfs|ramfs) ;;
        '') EXEC_ENV_ERROR='could not determine the filesystem backing /run'; return 1 ;;
        *) EXEC_ENV_ERROR="/run is backed by $run_fstype, not tmpfs or ramfs"; return 1 ;;
    esac
    systemd-run --help 2>&1 | grep -q -- '--collect' || {
        EXEC_ENV_ERROR='this systemd-run does not support --collect; a newer systemd release is required'
        return 1
    }
    return 0
}
select_action() {
    requested_action=$1
    if [ "$ACTION_SELECTED" -eq 1 ]; then
        die "select at most one final action: --poweroff or --reboot"
    fi
    ACTION=$requested_action
    ACTION_SELECTED=1
}
select_profile() {
    requested_profile=$1
    [ "$PROFILE_SELECTED" -eq 0 ] || die "--profile may be specified only once"
    case $requested_profile in
        test) ;;
        seal)
            REMOVE_MACHINE_ID=1
            REMOVE_CLOUD_INIT_STATE=1
            REMOVE_NETWORK_LEASES=1
            REMOVE_RANDOM_SEED=1
            REMOVE_SSH_HOST_KEYS=1
            REMOVE_KNOWN_HOSTS=1
            ;;
        privacy)
            REMOVE_MACHINE_ID=1
            REMOVE_CLOUD_INIT_STATE=1
            REMOVE_NETWORK_LEASES=1
            REMOVE_RANDOM_SEED=1
            REMOVE_SSH_HOST_KEYS=1
            REMOVE_KNOWN_HOSTS=1
            ZERO_FREE_SPACE=1
            WIPE_SWAP=1
            ;;
        *) die "invalid profile: $requested_profile (expected test, seal, or privacy)" ;;
    esac
    PROFILE=$requested_profile
    PROFILE_SELECTED=1
}

while [ "$#" -gt 0 ]; do
    case $1 in
        --profile)
            [ "$#" -ge 2 ] || die "--profile requires test, seal, or privacy"
            shift
            select_profile "$1"
            ;;
        --poweroff) select_action poweroff ;;
        --reboot) select_action reboot ;;
        --remove-machine-identity)
            REMOVE_MACHINE_ID=1
            REMOVE_CLOUD_INIT_STATE=1
            REMOVE_NETWORK_LEASES=1
            REMOVE_RANDOM_SEED=1
            ;;
        --remove-machine-id) REMOVE_MACHINE_ID=1 ;;
        --remove-cloud-init-state) REMOVE_CLOUD_INIT_STATE=1 ;;
        --remove-cloud-init-generated-configs)
            REMOVE_CLOUD_INIT_STATE=1
            REMOVE_CLOUD_INIT_GENERATED_CONFIGS=1
            ;;
        --remove-network-leases) REMOVE_NETWORK_LEASES=1 ;;
        --remove-random-seed) REMOVE_RANDOM_SEED=1 ;;
        --remove-ssh-host-keys) REMOVE_SSH_HOST_KEYS=1 ;;
        --remove-known-hosts) REMOVE_KNOWN_HOSTS=1 ;;
        --zero-free-space) ZERO_FREE_SPACE=1 ;;
        --wipe-swap) WIPE_SWAP=1 ;;
        --paths)
            [ "$#" -ge 2 ] || die "--paths requires a file"
            shift
            CUSTOM_PATH_FILE=$1
            ;;
        --services)
            [ "$#" -ge 2 ] || die "--services requires a file"
            shift
            CUSTOM_SERVICE_FILE=$1
            ;;
        --dry-run) DRY_RUN=1 ;;
        --verify) VERIFY=1 ;;
        --yes) ASSUME_YES=1 ;;
        --_runtime-service) IN_RUNTIME_SERVICE=1 ;;
        --_source-script)
            [ "$#" -ge 2 ] || die "--_source-script requires a path"
            shift
            SOURCE_SCRIPT_PATH=$1
            ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

SCRIPT_PATH=$(resolve_script_path) || die "could not resolve the running script path"
script_dir=$(dirname -- "$SCRIPT_PATH")
script_base=$(basename -- "$SCRIPT_PATH")
case $script_base in
    *.sh) verify_base=${script_base%.sh} ;;
    *) verify_base=$script_base ;;
esac
if [ "$IN_RUNTIME_SERVICE" -eq 1 ]; then
    RUNTIME_DIR=$script_dir
    VERIFY_LOG=$RUNTIME_DIR/$verify_base.log
else
    VERIFY_LOG=/run/cxt-systemprep.XXXXXX/$verify_base.log
fi

if [ "$IN_RUNTIME_SERVICE" -eq 1 ]; then
    case $RUNTIME_DIR in
        /run/cxt-systemprep.*) ;;
        *) die "internal runtime service must execute from a private /run/cxt-systemprep.* directory" ;;
    esac
    [ -n "${INVOCATION_ID:-}" ] || die "internal runtime service is missing systemd invocation context"
    in_detached_service || die "internal runtime service is not running in a detached systemd service"
    [ -n "$SOURCE_SCRIPT_PATH" ] || die "internal runtime service is missing its source script path"
    case $SOURCE_SCRIPT_PATH in /*) ;; *) die "internal source script path must be absolute" ;; esac
else
    [ -z "$SOURCE_SCRIPT_PATH" ] || die "--_source-script is an internal option"
fi

[ -r /etc/os-release ] || die "this does not look like a normal Linux installation"
[ -d /var/log ] || die "/var/log is missing"

SSH_REGEN_METHOD=
SSH_HOST_CERT_RISK=
CLOUD_INIT_BOOT_METHOD=
detect_cloud_init_boot_integration() {
    CLOUD_INIT_BOOT_METHOD=
    if have systemctl; then
        for cloud_unit in cloud-init-local.service cloud-init-network.service \
            cloud-init.service cloud-config.service cloud-final.service cloud-init.target; do
            if systemctl cat "$cloud_unit" >/dev/null 2>&1; then
                cloud_unit_state=$(systemctl is-enabled "$cloud_unit" 2>/dev/null || :)
                case $cloud_unit_state in
                    disabled|masked|masked-runtime|not-found|'') continue ;;
                esac
                CLOUD_INIT_BOOT_METHOD="systemd unit: $cloud_unit"
                return 0
            fi
        done
    fi
    for cloud_init_script in /etc/init.d/cloud-init /etc/init.d/cloud-init-local; do
        if [ -x "$cloud_init_script" ]; then
            CLOUD_INIT_BOOT_METHOD="boot script: $cloud_init_script"
            return 0
        fi
    done
    return 1
}

detect_ssh_host_key_regeneration() {
    SSH_REGEN_METHOD=
    if have systemctl; then
        for ssh_unit in ssh.service sshd.service; do
            if systemctl cat "$ssh_unit" 2>/dev/null |
                grep -Eiq '(ssh-keygen[[:space:]]+-A|ssh-keygen-start|sshd-keygen|sshdgenkeys|ssh.*gen.*key)'; then
                SSH_REGEN_METHOD="SSH service boot command: $ssh_unit"
                return 0
            fi
            if systemctl list-dependencies --plain "$ssh_unit" 2>/dev/null |
                grep -Eiq '(ssh-keygen|sshd-keygen|sshdgenkeys|ssh.*gen.*key)'; then
                SSH_REGEN_METHOD="SSH service key-generation dependency: $ssh_unit"
                return 0
            fi
        done
    fi

    for candidate in \
        /etc/init.d/ssh /etc/init.d/sshd \
        /usr/lib/systemd/system/ssh.service \
        /usr/lib/systemd/system/sshd.service \
        /lib/systemd/system/ssh.service \
        /lib/systemd/system/sshd.service; do
        if [ -r "$candidate" ] &&
            grep -Eiq '(ssh-keygen[[:space:]]+-A|ssh-keygen-start|sshd-keygen|sshdgenkeys|ssh.*gen.*key)' "$candidate"; then
            SSH_REGEN_METHOD="boot script or unit: $candidate"
            return 0
        fi
    done

    if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ] && have cloud-init && grep -R -Eqs \
        '^[[:space:]]*ssh_deletekeys:[[:space:]]*true([[:space:]]|$)' \
        /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.d 2>/dev/null; then
        SSH_REGEN_METHOD="cloud-init with ssh_deletekeys: true"
        return 0
    fi
    return 1
}

detect_ssh_host_certificate_risk() {
    SSH_HOST_CERT_RISK=
    ssh_host_certificate=$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*-cert.pub' \
        -print -quit 2>/dev/null || printf '')
    if [ -n "$ssh_host_certificate" ]; then
        SSH_HOST_CERT_RISK="host certificate file: $ssh_host_certificate"
        return 0
    fi
    if grep -R -Eqs '^[[:space:]]*HostCertificate[[:space:]]+' \
        /etc/ssh/sshd_config /etc/ssh/sshd_config.d 2>/dev/null; then
        SSH_HOST_CERT_RISK='an active HostCertificate directive is configured'
        return 0
    fi
    return 1
}

print_boolean() {
    [ "$1" -eq 1 ] && printf enabled || printf disabled
}

safe_custom_path() {
    custom=$1
    case $custom in
        /*) ;;
        *) return 1 ;;
    esac
    case "$custom/" in
        *'/../'*|*'/./'*|*'//'*) return 1 ;;
    esac
    case $custom in
        /|/bin|/boot|/dev|/etc|/home|/lib|/lib32|/lib64|/media|/mnt|/opt|/proc|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|/var/cache|/var/lib|/var/log|/var/spool|/var/tmp)
            return 1
            ;;
        /bin/*|/boot/*|/dev/*|/etc/*|/lib/*|/lib32/*|/lib64/*|/proc/*|/run/*|/sbin/*|/sys/*|/usr/*|/var/db/*|/var/lib/*|/var/spool/*)
            return 1
            ;;
    esac
    custom_lower=$(printf '%s\n' "$custom" | tr '[:upper:]' '[:lower:]')
    case $custom_lower in
        /var/log/*|/var/cache/*) return 0 ;;
        */log|*/logs|*/cache|*/caches|*/history|*/histories|*/trace|*/traces|*/audit|*/tmp|*/temp|\
        */log/*|*/logs/*|*/cache/*|*/caches/*|*/history/*|*/histories/*|*/trace/*|*/traces/*|*/audit/*|*/tmp/*|*/temp/*|\
        *.log|*.log.[0-9]*|*.trace|*.history|*.out|*.err) return 0 ;;
    esac
    return 1
}

custom_path_is_mount_root() {
    custom_mount_path=$1
    [ -e "$custom_mount_path" ] || return 1
    have findmnt || return 1
    custom_mount_target=$(findmnt -rn -T "$custom_mount_path" -o TARGET 2>/dev/null |
        awk 'NR == 1 {print; exit}')
    [ -n "$custom_mount_target" ] || return 1
    if have readlink; then
        custom_mount_path=$(readlink -f -- "$custom_mount_path" 2>/dev/null || printf '')
        custom_mount_target=$(readlink -f -- "$custom_mount_target" 2>/dev/null || printf '')
    fi
    [ -n "$custom_mount_path" ] && [ "$custom_mount_path" = "$custom_mount_target" ]
}

validate_custom_lists() {
    if [ -n "$CUSTOM_SERVICE_FILE" ]; then
        [ -r "$CUSTOM_SERVICE_FILE" ] || die "custom service file is not readable: $CUSTOM_SERVICE_FILE"
        while IFS= read -r unit || [ -n "$unit" ]; do
            case $unit in ''|'#'*) continue ;; esac
            case $unit in *[!A-Za-z0-9_.@:-]*) die "invalid unit name: $unit" ;; esac
        done < "$CUSTOM_SERVICE_FILE"
    fi

    if [ -n "$CUSTOM_PATH_FILE" ]; then
        [ -r "$CUSTOM_PATH_FILE" ] || die "custom path file is not readable: $CUSTOM_PATH_FILE"
        have readlink || die "custom path validation requires readlink"
        have findmnt || die "custom path validation requires findmnt"
        while IFS= read -r custom || [ -n "$custom" ]; do
            case $custom in ''|'#'*) continue ;; esac
            safe_custom_path "$custom" || die "unsafe custom path rejected: $custom"
            if have readlink && [ -e "$custom" ]; then
                canonical=$(readlink -f -- "$custom" 2>/dev/null || printf '')
                [ -n "$canonical" ] || die "could not resolve custom path: $custom"
                safe_custom_path "$canonical" ||
                    die "custom path resolves to a protected target: $custom -> $canonical"
            fi
            [ ! -L "$custom" ] || die "symlinked custom path rejected: $custom"
            custom_path_is_mount_root "$custom" && die "mount-root custom path rejected: $custom"
            :
        done < "$CUSTOM_PATH_FILE"
    fi
    return 0
}

print_cloud_init_generated_config_preview() {
    printf '%s\n' \
        '' \
        'HIGH-RISK cloud-init generated configuration preview:' \
        '  cloud-init clean --configs all may remove these currently existing files:'
    preview_found=0
    for generated_config in \
        /etc/netplan/50-cloud-init.yaml \
        /etc/network/interfaces.d/50-cloud-init \
        /etc/NetworkManager/conf.d/99-cloud-init.conf \
        /etc/NetworkManager/conf.d/99-cloud-init-dns.conf \
        /etc/NetworkManager/system-connections/cloud-init-*.nmconnection \
        /run/NetworkManager/conf.d/10-globally-managed-devices.conf \
        /run/NetworkManager/system-connections/cloud-init-*.nmconnection \
        /etc/systemd/network/10-cloud-init-* \
        /etc/ssh/sshd_config.d/50-cloud-init.conf; do
        if [ -e "$generated_config" ] || [ -L "$generated_config" ]; then
            printf '    %s\n' "$generated_config"
            preview_found=1
        fi
    done
    [ "$preview_found" -eq 1 ] || printf '%s\n' '    none of the standard generated files were found'
    printf '%s\n' '  /etc/fstab entries tagged comment=cloudconfig:'
    if [ -r /etc/fstab ] && grep -n 'comment=cloudconfig' /etc/fstab 2>/dev/null; then
        :
    else
        printf '%s\n' '    none found'
    fi
    printf '%s\n' \
        '  The current datasource cleanup hook may remove additional provider-specific' \
        '  files or configuration. Its exact targets depend on the installed cloud-init' \
        '  version and detected datasource and cannot be enumerated generically.'
}

print_plan() {
    ROOT_DEVICE=$(findmnt -n -o SOURCE / 2>/dev/null || printf unknown)
    HOST_NAME=$(hostname 2>/dev/null || printf unknown)
    printf '%s\n' \
        'CXT-SystemPrep dry-run plan (no changes made)' \
        "  host: $HOST_NAME" \
        "  root filesystem: $ROOT_DEVICE" \
        "  running script: $SCRIPT_PATH" \
        '  real execution stages to: /run/cxt-systemprep.XXXXXX/cxt-systemprep.sh' \
        "  source script removed after dispatch: $SCRIPT_PATH" \
        "  profile: $PROFILE" \
        "  final power action: $ACTION" \
        '' \
        'Always-cleaned scope:' \
        '  system/journal/audit/accounting/crash logs and transient log queues' \
        '  shell, client, editor, recent-file, and desktop histories' \
        '  all users cache and thumbnail directories' \
        '  package-manager caches/history and logrotate state' \
        '  Docker/Podman/containerd/Kubernetes text logs (container data preserved)' \
        '  /tmp, /var/tmp, timers, faillock, and selected volatile state' \
        '' \
        'Identity and privacy switches:' \
        "  remove /etc machine-id: $(print_boolean "$REMOVE_MACHINE_ID")" \
        "  remove cloud-init state: $(print_boolean "$REMOVE_CLOUD_INIT_STATE")" \
        "  remove cloud-init generated configs: $(print_boolean "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS")" \
        "  remove network leases: $(print_boolean "$REMOVE_NETWORK_LEASES")" \
        "  remove random seed: $(print_boolean "$REMOVE_RANDOM_SEED")" \
        "  remove SSH host keys: $(print_boolean "$REMOVE_SSH_HOST_KEYS")" \
        "  remove user/system known_hosts: $(print_boolean "$REMOVE_KNOWN_HOSTS")" \
        "  zero filesystem free space: $(print_boolean "$ZERO_FREE_SPACE")" \
        "  wipe active swap: $(print_boolean "$WIPE_SWAP")" \
        '  private /run staging: enabled for every real execution' \
        '  transient service + login termination: enabled for every real execution' \
        '  systemd --collect + automatic script deletion: enabled for every real execution' \
        "  advisory final verification: $(print_boolean "$VERIFY")"
    if [ "$VERIFY" -eq 1 ]; then
        printf '  verification log: %s\n' "$VERIFY_LOG"
    fi

    printf '%s\n' '' 'Standard cleanup paths and records:' \
        '  /var/log/** (including journal, audit, wtmp, btmp, and lastlog)' \
        '  /run/log/**, /run/utmp, /var/run/utmp, and faillock state' \
        '  /var/adm/**, /var/account/**, /var/crash/**, ABRT/Apport/coredump/pstore' \
        '  rsyslog/syslog-ng/audit queues, package caches/history, logrotate status' \
        '  Docker/Podman/containerd/Kubernetes container text log paths' \
        '  users shell/client/editor/recent-file histories, .cache, and .thumbnails' \
        '  /tmp/**, /var/tmp/**, systemd timer state, and selected volatile caches'

    if [ "$REMOVE_SSH_HOST_KEYS" -eq 1 ]; then
        if [ "$ACTION" = none ]; then
            printf '%s\n' '  SSH host-key removal: BLOCKED (requires --poweroff or --reboot to avoid remote lockout)'
            PLAN_BLOCKED=1
        elif detect_ssh_host_certificate_risk; then
            printf '  SSH host-key regeneration precheck: BLOCKED (%s)\n' "$SSH_HOST_CERT_RISK"
            PLAN_BLOCKED=1
        elif detect_ssh_host_key_regeneration; then
            printf '  SSH host-key regeneration precheck: PASS (%s)\n' "$SSH_REGEN_METHOD"
        else
            printf '%s\n' '  SSH host-key regeneration precheck: BLOCKED (no supported mechanism found)'
            PLAN_BLOCKED=1
        fi
    fi
    if [ "$REMOVE_MACHINE_ID" -eq 1 ] && [ "$ACTION" = none ]; then
        printf '%s\n' '  machine-id removal: BLOCKED (requires --poweroff or --reboot)'
        PLAN_BLOCKED=1
    fi
    if [ "$REMOVE_NETWORK_LEASES" -eq 1 ] && [ "$ACTION" = none ]; then
        printf '%s\n' '  network-lease removal: BLOCKED (requires --poweroff or --reboot)'
        PLAN_BLOCKED=1
    fi
    if [ "$REMOVE_RANDOM_SEED" -eq 1 ] && [ "$ACTION" = none ]; then
        printf '%s\n' '  random-seed removal: BLOCKED (requires --poweroff or --reboot)'
        PLAN_BLOCKED=1
    fi
    if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ]; then
        if [ -e /etc/cloud/cloud-init.disabled ]; then
            printf '%s\n' '  cloud-init rearm precheck: BLOCKED (/etc/cloud/cloud-init.disabled exists)'
            PLAN_BLOCKED=1
        elif [ -r /proc/cmdline ] &&
            grep -Eq '(^|[[:space:]])cloud-init=disabled([[:space:]]|$)' /proc/cmdline; then
            printf '%s\n' '  cloud-init rearm precheck: BLOCKED (disabled by kernel command line)'
            PLAN_BLOCKED=1
        elif ! have cloud-init; then
            printf '%s\n' '  cloud-init rearm precheck: N/A (cloud-init is not installed)'
        elif detect_cloud_init_boot_integration; then
            cloud_plan_status=$(cloud-init status 2>/dev/null || printf 'status: unknown')
            if printf '%s\n' "$cloud_plan_status" | grep -Eiq 'status:[[:space:]]*(running|disabled)'; then
                printf '  cloud-init rearm precheck: BLOCKED (%s)\n' "$cloud_plan_status"
                PLAN_BLOCKED=1
            else
                printf '  cloud-init rearm precheck: PASS (%s; instance cache, logs, and seed will be cleaned)\n' "$CLOUD_INIT_BOOT_METHOD"
            fi
        else
            printf '%s\n' '  cloud-init rearm precheck: BLOCKED (no enabled boot integration found)'
            PLAN_BLOCKED=1
        fi
    fi
    if [ "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS" -eq 1 ]; then
        if [ "$ACTION" = none ]; then
            printf '%s\n' '  cloud-init generated-config cleanup: BLOCKED (requires --poweroff or --reboot)'
            PLAN_BLOCKED=1
        fi
        if ! have cloud-init; then
            printf '%s\n' '  cloud-init generated-config cleanup: BLOCKED (cloud-init is not installed)'
            PLAN_BLOCKED=1
        elif ! cloud-init clean --help 2>&1 | grep -q -- '--configs'; then
            printf '%s\n' '  cloud-init generated-config cleanup: BLOCKED (installed cloud-init lacks --configs)'
            PLAN_BLOCKED=1
        else
            printf '%s\n' '  cloud-init generated-config cleanup: HIGH RISK / explicitly enabled'
            print_cloud_init_generated_config_preview
        fi
    fi
    if [ "$WIPE_SWAP" -eq 1 ]; then
        for required_command in swapon swapoff mkswap blkid blockdev; do
            if ! have "$required_command"; then
                printf '  swap wipe prerequisite: BLOCKED (missing %s)\n' "$required_command"
                PLAN_BLOCKED=1
            fi
        done
    fi
    if [ "$ZERO_FREE_SPACE" -eq 1 ] && ! have findmnt; then
        printf '%s\n' '  free-space zeroing prerequisite: BLOCKED (missing findmnt)'
        PLAN_BLOCKED=1
    fi

    if check_execution_environment; then
        printf '%s\n' '' 'Execution environment: PASS (systemd, --collect, loginctl, and tmpfs-backed /run)'
    else
        printf 'Execution environment: BLOCKED (%s)\n' "$EXEC_ENV_ERROR"
        PLAN_BLOCKED=1
    fi
    if have auditctl; then
        audit_plan_state=$(auditctl -s 2>/dev/null | awk '$1 == "enabled" { print $2; exit }' || printf unknown)
        if [ "$audit_plan_state" = 2 ]; then
            printf '%s\n' 'Audit precheck: BLOCKED (kernel auditing is immutable)'
            PLAN_BLOCKED=1
        else
            printf 'Audit precheck: PASS (enabled state: %s)\n' "$audit_plan_state"
        fi
    fi

    printf '%s\n' '' 'Services considered for temporary stop:' \
        '  rsyslog, syslog-ng, systemd journal upload/remote/gateway' \
        '  auditd, acct, psacct, atop, cron/crond, anacron, atd, timers.target' \
        '  fail2ban, denyhosts, crowdsec' \
        '  Docker, Podman, containerd, CRI-O, kubelet, systemd-random-seed' \
        '  PackageKit, apt-daily/unattended-upgrades, DNF/Yum cache timers'

    if [ -n "$CUSTOM_SERVICE_FILE" ]; then
        printf '  custom service list: %s\n' "$CUSTOM_SERVICE_FILE"
        [ -r "$CUSTOM_SERVICE_FILE" ] || die "custom service file is not readable: $CUSTOM_SERVICE_FILE"
        sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; s/^/    /p' "$CUSTOM_SERVICE_FILE"
    else
        printf '%s\n' '  custom service list: none'
    fi
    if [ -n "$CUSTOM_PATH_FILE" ]; then
        printf '  custom path list: %s\n' "$CUSTOM_PATH_FILE"
        [ -r "$CUSTOM_PATH_FILE" ] || die "custom path file is not readable: $CUSTOM_PATH_FILE"
        sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; s/^/    /p' "$CUSTOM_PATH_FILE"
    else
        printf '%s\n' '  custom path list: none'
    fi
    if [ "$(id -u)" -ne 0 ]; then
        warn "dry-run is non-root; service visibility may be incomplete"
    fi
    [ "$PLAN_BLOCKED" -eq 0 ]
}

validate_custom_lists

if [ "$DRY_RUN" -eq 1 ]; then
    print_plan || exit 2
    exit 0
fi

[ "$(id -u)" -eq 0 ] || die "run this script as root"
[ -f "$SCRIPT_PATH" ] && [ ! -L "$SCRIPT_PATH" ] ||
    die "real execution requires the source script to be a regular, non-symlinked file"
[ -w "$script_dir" ] ||
    die "the source script directory must be writable so the verified source copy can be removed"
check_execution_environment || die "$EXEC_ENV_ERROR"
if have auditctl; then
    audit_preflight=$(auditctl -s 2>/dev/null | awk '$1 == "enabled" { print $2; exit }' || printf '')
    [ "$audit_preflight" != 2 ] ||
        die "kernel auditing is immutable; reboot with an audit policy that permits disabling before sealing"
fi
if [ "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS" -eq 1 ]; then
    [ "$ACTION" != none ] ||
        die "--remove-cloud-init-generated-configs requires --poweroff or --reboot"
    have cloud-init || die "--remove-cloud-init-generated-configs requires cloud-init"
    cloud-init clean --help 2>&1 | grep -q -- '--configs' ||
        die "installed cloud-init does not support clean --configs"
    warn "HIGH RISK: cloud-init generated network, SSH, datasource, and fstab configuration will be removed"
fi
if [ "$REMOVE_MACHINE_ID" -eq 1 ]; then
    [ "$ACTION" != none ] ||
        die "--remove-machine-id requires --poweroff or --reboot"
fi
if [ "$REMOVE_NETWORK_LEASES" -eq 1 ]; then
    [ "$ACTION" != none ] ||
        die "--remove-network-leases requires --poweroff or --reboot"
fi
if [ "$REMOVE_RANDOM_SEED" -eq 1 ]; then
    [ "$ACTION" != none ] ||
        die "--remove-random-seed requires --poweroff or --reboot"
fi
if [ "$REMOVE_SSH_HOST_KEYS" -eq 1 ]; then
    [ "$ACTION" != none ] ||
        die "--remove-ssh-host-keys requires --poweroff or --reboot to avoid remote lockout"
    detect_ssh_host_certificate_risk &&
        die "refusing to remove SSH host keys while host certificates are configured: $SSH_HOST_CERT_RISK"
    detect_ssh_host_key_regeneration ||
        die "refusing to remove SSH host keys: no supported boot-time regeneration mechanism was found"
    log "SSH host-key regeneration precheck passed: $SSH_REGEN_METHOD"
fi
if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ]; then
    if [ -e /etc/cloud/cloud-init.disabled ]; then
        die "cloud-init is disabled by /etc/cloud/cloud-init.disabled"
    fi
    if [ -r /proc/cmdline ] && grep -Eq '(^|[[:space:]])cloud-init=disabled([[:space:]]|$)' /proc/cmdline; then
        die "cloud-init is disabled by the kernel command line"
    fi
    if have cloud-init; then
        detect_cloud_init_boot_integration ||
            die "cloud-init is installed but no enabled boot integration was found"
        cloud_status=$(cloud-init status 2>/dev/null || printf 'status: unknown')
        printf '%s\n' "$cloud_status" | grep -Eiq 'status:[[:space:]]*disabled' &&
            die "cloud-init reports that it is disabled"
        printf '%s\n' "$cloud_status" | grep -Eiq 'status:[[:space:]]*running' &&
            die "cloud-init is still running; wait for it to finish before cleaning"
    elif [ -d /var/lib/cloud ] &&
        find /var/lib/cloud -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        die "cloud-init state exists in /var/lib/cloud but the cloud-init command is unavailable"
    fi
fi
if [ "$WIPE_SWAP" -eq 1 ]; then
    have swapon || die "--wipe-swap requires swapon"
    have swapoff || die "--wipe-swap requires swapoff"
    have mkswap || die "--wipe-swap requires mkswap"
    have blkid || die "--wipe-swap requires blkid to preserve swap UUID and label"
    have blockdev || die "--wipe-swap requires blockdev to zero block swap exactly"
fi
if [ "$ZERO_FREE_SPACE" -eq 1 ]; then
    have findmnt || die "--zero-free-space requires findmnt"
fi
ROOT_DEVICE=$(findmnt -n -o SOURCE / 2>/dev/null || printf unknown)
HOST_NAME=$(hostname 2>/dev/null || printf unknown)
log "target host: $HOST_NAME; root filesystem: $ROOT_DEVICE; final action: $ACTION"
warn "this permanently removes audit records, logs, command histories, crash data, and transient state"

if [ "$ASSUME_YES" -ne 1 ]; then
    [ -t 0 ] || die "non-interactive input requires --yes"
    printf 'Type SANITIZE-%s to continue: ' "$HOST_NAME" >&2
    IFS= read -r answer
    [ "$answer" = "SANITIZE-$HOST_NAME" ] || die "confirmation did not match"
fi

lock_is_held() {
    lock_path=$1
    if have fuser && fuser "$lock_path" >/dev/null 2>&1; then
        return 0
    fi
    if have lslocks && lslocks -rn -o PATH 2>/dev/null | grep -Fqx -- "$lock_path"; then
        return 0
    fi
    return 1
}

# Refuse to run while package operations are active. Their databases must never be
# interrupted or mistaken for disposable history.
for lock in /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/lib/rpm/.rpm.lock; do
    if [ -e "$lock" ] && lock_is_held "$lock"; then
        die "a package manager is active on $lock"
    fi
done

stage_file_verified() {
    source_file=$1
    staged_file=$2
    cp -- "$source_file" "$staged_file" || return 1
    source_hash=$(sha256_file "$source_file") || return 1
    staged_hash=$(sha256_file "$staged_file") || return 1
    [ "$source_hash" = "$staged_hash" ]
}

cleanup_failed_staging() {
    failed_runtime_dir=$1
    case $failed_runtime_dir in
        /run/cxt-systemprep.*) rm -rf -- "$failed_runtime_dir" 2>/dev/null || : ;;
    esac
}

stage_and_dispatch() {
    runtime_dir=$(mktemp -d /run/cxt-systemprep.XXXXXX) ||
        die "could not create a private runtime directory under /run"
    chmod 700 "$runtime_dir" || { cleanup_failed_staging "$runtime_dir"; die "could not secure $runtime_dir"; }
    chown root:root "$runtime_dir" 2>/dev/null || { cleanup_failed_staging "$runtime_dir"; die "could not assign $runtime_dir to root"; }

    staged_script=$runtime_dir/cxt-systemprep.sh
    if ! stage_file_verified "$SCRIPT_PATH" "$staged_script"; then
        cleanup_failed_staging "$runtime_dir"
        die "failed to copy and SHA-256 verify the runtime script"
    fi
    chmod 700 "$staged_script" || { cleanup_failed_staging "$runtime_dir"; die "could not secure the runtime script"; }
    chown root:root "$staged_script" 2>/dev/null || { cleanup_failed_staging "$runtime_dir"; die "could not assign the runtime script to root"; }

    staged_path_file=
    if [ -n "$CUSTOM_PATH_FILE" ]; then
        staged_path_file=$runtime_dir/custom-paths.list
        stage_file_verified "$CUSTOM_PATH_FILE" "$staged_path_file" || {
            cleanup_failed_staging "$runtime_dir"
            die "failed to copy and verify the custom path list"
        }
        chmod 600 "$staged_path_file" 2>/dev/null || :
    fi
    staged_service_file=
    if [ -n "$CUSTOM_SERVICE_FILE" ]; then
        staged_service_file=$runtime_dir/custom-services.list
        stage_file_verified "$CUSTOM_SERVICE_FILE" "$staged_service_file" || {
            cleanup_failed_staging "$runtime_dir"
            die "failed to copy and verify the custom service list"
        }
        chmod 600 "$staged_service_file" 2>/dev/null || :
    fi

    transient_unit=cxt-systemprep-$(date +%Y%m%d-%H%M%S)-$$
    set -- systemd-run --unit="$transient_unit" --collect \
        --property=UMask=0077 \
        /bin/sh "$staged_script" --_runtime-service --_source-script "$SCRIPT_PATH" --yes
    [ "$PROFILE" = default ] || set -- "$@" --profile "$PROFILE"
    case $ACTION in
        poweroff) set -- "$@" --poweroff ;;
        reboot) set -- "$@" --reboot ;;
    esac
    [ "$REMOVE_MACHINE_ID" -eq 0 ] || set -- "$@" --remove-machine-id
    [ "$REMOVE_CLOUD_INIT_STATE" -eq 0 ] || set -- "$@" --remove-cloud-init-state
    [ "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS" -eq 0 ] || set -- "$@" --remove-cloud-init-generated-configs
    [ "$REMOVE_NETWORK_LEASES" -eq 0 ] || set -- "$@" --remove-network-leases
    [ "$REMOVE_RANDOM_SEED" -eq 0 ] || set -- "$@" --remove-random-seed
    [ "$REMOVE_SSH_HOST_KEYS" -eq 0 ] || set -- "$@" --remove-ssh-host-keys
    [ "$REMOVE_KNOWN_HOSTS" -eq 0 ] || set -- "$@" --remove-known-hosts
    [ "$ZERO_FREE_SPACE" -eq 0 ] || set -- "$@" --zero-free-space
    [ "$WIPE_SWAP" -eq 0 ] || set -- "$@" --wipe-swap
    [ "$VERIFY" -eq 0 ] || set -- "$@" --verify
    [ -z "$staged_path_file" ] || set -- "$@" --paths "$staged_path_file"
    [ -z "$staged_service_file" ] || set -- "$@" --services "$staged_service_file"
    if "$@"; then
        log "dispatched transient service: $transient_unit.service"
        log "private runtime directory: $runtime_dir"
        if [ "$VERIFY" -eq 1 ]; then
            log "verification report: $runtime_dir/cxt-systemprep.log"
        fi
        # The service also removes this exact source copy before terminating the
        # login session. This parent-side attempt closes the small dispatch race.
        if [ -f "$SCRIPT_PATH" ] && [ ! -L "$SCRIPT_PATH" ]; then
            current_source_hash=$(sha256_file "$SCRIPT_PATH" 2>/dev/null || printf '')
            staged_source_hash=$(sha256_file "$staged_script" 2>/dev/null || printf '')
            [ -z "$current_source_hash" ] || [ "$current_source_hash" != "$staged_source_hash" ] ||
                rm -f -- "$SCRIPT_PATH" 2>/dev/null || :
        fi
        exit 0
    fi
    cleanup_failed_staging "$runtime_dir"
    die "failed to dispatch transient service: $transient_unit.service"
}

if [ "$IN_RUNTIME_SERVICE" -eq 0 ]; then
    stage_and_dispatch
    # Defensive assertion: stage_and_dispatch normally exits or calls die.
    # shellcheck disable=SC2317
    die "internal error: transient service dispatch returned unexpectedly"
fi

if [ "$VERIFY" -eq 1 ]; then
    : > "$VERIFY_LOG" || die "cannot create verification log: $VERIFY_LOG"
    chmod 600 "$VERIFY_LOG" 2>/dev/null || :
fi

cleanup_state_dir() {
    [ "$STATE_DIR" = "$RUNTIME_DIR/.state" ] || return 0
    rm -rf -- "$STATE_DIR" 2>/dev/null || :
}
STATE_DIR=$RUNTIME_DIR/.state
ACTIVE_SYSTEMD_UNITS=$STATE_DIR/active-systemd-units
ACTIVE_SYSV_SERVICES=$STATE_DIR/active-sysv-services
RUNTIME_MASKED_UNITS=$STATE_DIR/runtime-masked-units
DISABLED_SWAP_TARGETS=$STATE_DIR/disabled-swap-targets
mkdir -p "$STATE_DIR"
: > "$ACTIVE_SYSTEMD_UNITS"
: > "$ACTIVE_SYSV_SERVICES"
: > "$RUNTIME_MASKED_UNITS"
: > "$DISABLED_SWAP_TARGETS"

restore_runtime_state() {
    [ "$RUNTIME_RESTORED" -eq 0 ] || return 0
    if have systemctl; then
        if [ -r "$RUNTIME_MASKED_UNITS" ]; then
            awk '!seen[$0]++' "$RUNTIME_MASKED_UNITS" |
                while IFS= read -r restore_unit; do
                    [ -n "$restore_unit" ] &&
                        systemctl unmask --runtime "$restore_unit" >/dev/null 2>&1 || :
                done
        fi
        if [ "$FINAL_JOURNAL_STOPPED" -eq 1 ]; then
            systemctl unmask --runtime systemd-journald.service \
                systemd-journald.socket systemd-journald-dev-log.socket \
                systemd-journald-audit.socket >/dev/null 2>&1 || :
            systemctl start systemd-journald.socket systemd-journald.service \
                >/dev/null 2>&1 || warn "could not restore systemd-journald after failure"
        fi
        if [ -r "$ACTIVE_SYSTEMD_UNITS" ]; then
            awk '!seen[$0]++' "$ACTIVE_SYSTEMD_UNITS" |
                while IFS= read -r restore_unit; do
                    [ -n "$restore_unit" ] || continue
                    if ! systemctl start "$restore_unit" >/dev/null 2>&1; then
                        case $restore_unit in
                            auditd.service)
                                service auditd start >/dev/null 2>&1 ||
                                    warn "could not restore previously active unit: $restore_unit"
                                ;;
                            *) warn "could not restore previously active unit: $restore_unit" ;;
                        esac
                    fi
                done
        fi
    fi
    if [ -r "$ACTIVE_SYSV_SERVICES" ] && have service; then
        awk '!seen[$0]++' "$ACTIVE_SYSV_SERVICES" |
            while IFS= read -r restore_service; do
                [ -n "$restore_service" ] &&
                    service "$restore_service" start >/dev/null 2>&1 || :
            done
    fi
    if [ "$AUDIT_WAS_ENABLED" = 1 ] && have auditctl; then
        auditctl -e 1 >/dev/null 2>&1 || warn "could not re-enable kernel auditing"
    fi
    RUNTIME_RESTORED=1
}

# Invoked indirectly by the EXIT trap below.
# shellcheck disable=SC2329
on_exit() {
    exit_status=$1
    trap - EXIT HUP INT TERM
    if [ "$exit_status" -ne 0 ]; then
        set +e
        if [ "$POWER_ACTION_IN_PROGRESS" -eq 1 ]; then
            # systemd normally terminates this service as part of the requested
            # reboot/poweroff transaction. Do not fight shutdown by restoring units.
            :
        else
            warn "cleanup failed; restoring services and runtime masks where possible"
            case $ACTIVE_ZERO_FILE in
                /.cxt-systemprep-zero-fill.tmp|/*/.cxt-systemprep-zero-fill.tmp)
                    rm -f -- "$ACTIVE_ZERO_FILE" 2>/dev/null || :
                    sync
                    ;;
            esac
            if [ -r "$DISABLED_SWAP_TARGETS" ] && have swapon; then
                while IFS= read -r restore_swap; do
                    [ -n "$restore_swap" ] && swapon "$restore_swap" >/dev/null 2>&1 || :
                done < "$DISABLED_SWAP_TARGETS"
            fi
            restore_runtime_state
            warn "private failure artifacts retained for inspection: $RUNTIME_DIR"
        fi
    fi
    exit "$exit_status"
}

trap 'on_exit $?' EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
if have auditctl; then
    AUDIT_WAS_ENABLED=$(auditctl -s 2>/dev/null | awk '$1 == "enabled" { print $2; exit }' || printf '')
    case $AUDIT_WAS_ENABLED in
        2) die "kernel auditing is immutable; reboot with an audit policy that permits disabling before sealing" ;;
        1)
            auditctl -e 0 >/dev/null 2>&1 ||
                die "kernel auditing could not be disabled safely"
            audit_now=$(auditctl -s 2>/dev/null | awk '$1 == "enabled" { print $2; exit }' || printf unknown)
            [ "$audit_now" = 0 ] || die "kernel auditing remains enabled: $audit_now"
            ;;
    esac
fi

remove_source_script_copy() {
    [ "$SOURCE_SCRIPT_PATH" != "$SCRIPT_PATH" ] ||
        die "runtime script and source script unexpectedly resolve to the same path"
    if [ ! -e "$SOURCE_SCRIPT_PATH" ]; then
        log "source script was already removed after successful dispatch"
        return 0
    fi
    [ -f "$SOURCE_SCRIPT_PATH" ] && [ ! -L "$SOURCE_SCRIPT_PATH" ] ||
        die "refusing to delete a non-regular or symlinked source script: $SOURCE_SCRIPT_PATH"
    runtime_hash=$(sha256_file "$SCRIPT_PATH") || die "could not hash the runtime script"
    source_hash=$(sha256_file "$SOURCE_SCRIPT_PATH") || {
        [ ! -e "$SOURCE_SCRIPT_PATH" ] && return 0
        die "could not hash the source script before deletion"
    }
    [ "$runtime_hash" = "$source_hash" ] ||
        die "source script changed after staging; retained it and stopped cleanup"
    rm -f -- "$SOURCE_SCRIPT_PATH" || die "could not remove source script: $SOURCE_SCRIPT_PATH"
    log "removed source script after verified staging: $SOURCE_SCRIPT_PATH"
}

terminate_login_sessions() {
    have loginctl || die "loginctl is required to terminate login sessions"
    in_detached_service || die "login termination must run inside a detached systemd service"
    log "terminating login sessions so shell histories cannot be written back later"
    loginctl list-users --no-legend 2>/dev/null |
        while IFS=' ' read -r user_id _; do
            [ -n "$user_id" ] && loginctl terminate-user "$user_id" >/dev/null 2>&1 || :
        done
    loginctl list-sessions --no-legend 2>/dev/null |
        while IFS=' ' read -r session_id _; do
            [ -n "$session_id" ] &&
                loginctl terminate-session "$session_id" >/dev/null 2>&1 || :
        done
    session_wait=0
    remaining_session=
    while [ "$session_wait" -lt 30 ]; do
        remaining_session=$(loginctl list-sessions --no-legend 2>/dev/null |
            awk 'NF {print $1; exit}')
        [ -n "$remaining_session" ] || break
        sleep 1
        session_wait=$((session_wait + 1))
    done
    [ -z "$remaining_session" ] ||
        die "a login session remains after termination requests: $remaining_session"
    if have ps; then
        remaining_shell=$(ps -eo pid=,tty=,comm= 2>/dev/null |
            awk '$2 != "?" && $3 ~ /^(sh|bash|dash|ash|zsh|ksh|fish)$/ {print; exit}')
        [ -z "$remaining_shell" ] ||
            die "an interactive shell remains and may rewrite history:$remaining_shell"
    fi
}

# Delete the uploaded/downloaded source before ending its login session. The
# verified runtime copy remains available on failure and is removed only on success.
remove_source_script_copy
terminate_login_sessions

stop_unit() {
    unit=$1
    if have systemctl; then
        load_state=$(systemctl show -p LoadState --value "$unit" 2>/dev/null || printf not-found)
        [ "$load_state" != not-found ] || return 0
        if systemctl is-active --quiet "$unit"; then
            printf '%s\n' "$unit" >> "$ACTIVE_SYSTEMD_UNITS"
        fi
        systemctl stop "$unit" >/dev/null 2>&1 || warn "could not stop $unit"
    elif have service; then
        case $unit in
            *.service) service_name=${unit%.service} ;;
            *) return 0 ;;
        esac
        if service "$service_name" status >/dev/null 2>&1; then
            printf '%s\n' "$service_name" >> "$ACTIVE_SYSV_SERVICES"
        fi
        service "$service_name" stop >/dev/null 2>&1 || :
    fi
}

runtime_mask_unit() {
    unit=$1
    if have systemctl; then
        load_state=$(systemctl show -p LoadState --value "$unit" 2>/dev/null || printf not-found)
        [ "$load_state" != not-found ] || return 0
        enabled_state=$(systemctl is-enabled "$unit" 2>/dev/null || printf unknown)
        case $enabled_state in masked|masked-runtime) return 0 ;; esac
        if systemctl mask --runtime "$unit" >/dev/null 2>&1; then
            printf '%s\n' "$unit" >> "$RUNTIME_MASKED_UNITS"
        else
            die "could not create required runtime mask for $unit"
        fi
    fi
}

stop_required_unit() {
    unit=$1
    have systemctl || die "systemctl is required to stop custom unit $unit"
    load_state=$(systemctl show -p LoadState --value "$unit" 2>/dev/null || printf not-found)
    [ "$load_state" != not-found ] || die "custom unit does not exist: $unit"
    if systemctl is-active --quiet "$unit"; then
        printf '%s\n' "$unit" >> "$ACTIVE_SYSTEMD_UNITS"
    fi
    systemctl stop "$unit" >/dev/null 2>&1 || die "could not stop custom unit $unit"
    if systemctl is-active --quiet "$unit"; then
        die "custom unit is still active: $unit"
    fi
    runtime_mask_unit "$unit"
}

purge_non_directories() {
    dir=$1
    [ -d "$dir" ] || return 0
    [ ! -L "$dir" ] || return 0
    # Keep the directory structure, owners, modes, ACLs, mount points, and service
    # expectations and symlink topology; remove file contents, sockets, and FIFOs.
    find "$dir" -xdev -mindepth 1 \
        \( -type f -o -type p -o -type s \) -delete 2>/dev/null ||
        find "$dir" -xdev -mindepth 1 \
            \( -type f -o -type p -o -type s \) -exec rm -f -- {} \; 2>/dev/null ||
        warn "some log entries could not be removed from $dir"
}

purge_directory_contents() {
    dir=$1
    [ -d "$dir" ] || return 0
    if [ -L "$dir" ]; then
        warn "skipping symlinked directory: $dir"
        return 0
    fi
    # Never recurse through a nested mount. A busy mount point may remain and is
    # reported, but its contents are not crossed or removed accidentally.
    find "$dir" -xdev -mindepth 1 -depth -delete 2>/dev/null ||
        warn "some entries could not be removed from $dir (possibly a mount point)"
}

log "stopping log writers and accounting services"
for unit in $STANDARD_CLEANUP_UNITS; do
    stop_unit "$unit"
done
if have service; then
    service auditd stop >/dev/null 2>&1 || :
fi
if have systemctl && systemctl is-active --quiet auditd.service; then
    systemctl kill --kill-who=all auditd.service >/dev/null 2>&1 || :
    sleep 1
    systemctl is-active --quiet auditd.service &&
        die "auditd is still active; refusing to remove its log while it is being written"
fi
if [ -n "$CUSTOM_SERVICE_FILE" ]; then
    log "stopping explicitly configured application units from $CUSTOM_SERVICE_FILE"
    while IFS= read -r unit || [ -n "$unit" ]; do
        case $unit in ''|'#'*) continue ;; esac
        case $unit in *[!A-Za-z0-9_.@:-]*) die "invalid unit name: $unit" ;; esac
        stop_required_unit "$unit"
    done < "$CUSTOM_SERVICE_FILE"
fi

# Rotate/flush first so daemon buffers do not repopulate files after deletion.
if have journalctl; then
    journalctl --rotate >/dev/null 2>&1 || :
    journalctl --flush >/dev/null 2>&1 || :
fi

# Prevent late shutdown and utmp writers for this boot only. Runtime masks vanish
# with /run and do not affect the captured system's next boot.
for unit in $STANDARD_CLEANUP_UNITS \
    systemd-update-utmp.service systemd-update-utmp-runlevel.service \
    systemd-update-utmp-shutdown.service; do
    runtime_mask_unit "$unit"
done

for unit in $STANDARD_CLEANUP_UNITS; do
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        die "log/state-writing unit is still active after stop and runtime mask: $unit"
    fi
done

find_open_log_writer() {
    OPEN_LOG_WRITER=
    for open_fd in /proc/[0-9]*/fd/*; do
        [ -L "$open_fd" ] || continue
        open_target=$(readlink -- "$open_fd" 2>/dev/null || printf '')
        case $open_target in
            /var/log/journal/*|/run/log/journal/*) continue ;;
            /var/log/*|/run/log/*|/var/adm/*|/var/account/*|/var/crash/*|\
            /var/spool/abrt/*|/var/lib/systemd/coredump/*|/var/lib/apport/coredump/*|\
            /var/lib/docker/containers/*|/var/lib/containers/storage/overlay-containers/*|\
            /var/lib/kubelet/pods/*/containers/*.log*|*/*.log*|*/*.trace*|*/*.out|*/*.err)
                open_proc=${open_fd#/proc/}
                open_pid=${open_proc%%/*}
                open_comm=$(cat "/proc/$open_pid/comm" 2>/dev/null || printf unknown)
                OPEN_LOG_WRITER="pid=$open_pid process=$open_comm target=$open_target"
                return 0
                ;;
        esac
    done
    return 1
}

if find_open_log_writer; then
    die "a process still has a log open; add its unit to --services and any nonstandard log path to --paths: $OPEN_LOG_WRITER"
fi

log "removing system, service, audit, journal, accounting, and crash logs"
# Preserve distro-specific inode metadata for binary accounting files.
for accounting_file in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    if [ -L "$accounting_file" ] && have readlink; then
        accounting_target=$(readlink -f -- "$accounting_file" 2>/dev/null || printf '')
        case $accounting_target in
            /var/log/*|/run/*)
                [ -f "$accounting_target" ] && : > "$accounting_target"
                ;;
            *) warn "accounting symlink has an unexpected target and was not followed: $accounting_file" ;;
        esac
    elif [ -f "$accounting_file" ]; then
        : > "$accounting_file"
    fi
done
if [ -d /var/log ] && [ ! -L /var/log ]; then
    find /var/log -xdev -mindepth 1 \
        \( -type f -o -type p -o -type s \) \
        ! -path '/var/log/journal/*' \
        ! -path /var/log/wtmp ! -path /var/log/btmp ! -path /var/log/lastlog \
        -delete 2>/dev/null ||
        find /var/log -xdev -mindepth 1 \
            \( -type f -o -type p -o -type s \) \
            ! -path '/var/log/journal/*' \
            ! -path /var/log/wtmp ! -path /var/log/btmp ! -path /var/log/lastlog \
            -exec rm -f -- {} \;
fi
if [ -d /run/log ] && [ ! -L /run/log ]; then
    find /run/log -xdev -mindepth 1 \
        \( -type f -o -type p -o -type s \) \
        ! -path '/run/log/journal/*' -delete 2>/dev/null ||
        warn "some runtime log entries could not be removed from /run/log"
fi
purge_non_directories /var/adm
purge_non_directories /var/account
purge_non_directories /var/spool/abrt
purge_non_directories /var/crash
purge_non_directories /var/lib/systemd/coredump
purge_non_directories /var/lib/apport/coredump
purge_non_directories /var/lib/systemd/pstore
purge_non_directories /sys/fs/pstore

# Runtime login/failure state. Persistent equivalents under /var/log were removed
# above. Do this late because the current login remains active until final shutdown.
rm -f -- /run/utmp /var/run/utmp 2>/dev/null || :
purge_directory_contents /run/faillock
purge_directory_contents /var/run/faillock
purge_directory_contents /var/lib/faillock
purge_directory_contents /var/lib/lastlog
rm -f -- /var/lib/fail2ban/fail2ban.sqlite3 \
    /var/lib/fail2ban/fail2ban.sqlite3-shm \
    /var/lib/fail2ban/fail2ban.sqlite3-wal 2>/dev/null || :

# State files that otherwise preserve an offset/reference to deleted log streams.
rm -f -- \
    /var/lib/rsyslog/imjournal.state \
    /var/lib/rsyslog/imjournal.state.tmp \
    /var/lib/logrotate/status \
    /var/lib/logrotate.status \
    /var/lib/systemd/catalog/database \
    2>/dev/null || :
purge_directory_contents /var/lib/rsyslog
purge_directory_contents /var/spool/rsyslog
purge_directory_contents /var/lib/syslog-ng
purge_directory_contents /var/spool/audit
purge_directory_contents /var/spool/audispd
purge_directory_contents /var/spool/anacron
purge_directory_contents /var/lib/systemd/journal-upload
rm -f -- /var/lib/dnf/history.sqlite /var/lib/dnf/history.sqlite-shm \
    /var/lib/dnf/history.sqlite-wal 2>/dev/null || :
purge_directory_contents /var/lib/yum/history

log "removing container and Kubernetes text logs while preserving container data"
if [ -d /var/lib/docker/containers ]; then
    find /var/lib/docker/containers -xdev -type f \
        \( -name '*-json.log' -o -name 'container.log' \) -delete 2>/dev/null || :
fi
if [ -d /var/lib/containers/storage/overlay-containers ]; then
    find /var/lib/containers/storage/overlay-containers -xdev -type f \
        \( -name 'ctr.log' -o -name 'container.log' \) -delete 2>/dev/null || :
fi
purge_directory_contents /var/log/containers
purge_directory_contents /var/log/pods
if [ -d /var/lib/kubelet/pods ]; then
    find /var/lib/kubelet/pods -xdev -type f -path '*/containers/*.log' -delete 2>/dev/null || :
fi

clean_home() {
    home_dir=$1
    [ -d "$home_dir" ] || return 0
    [ "$home_dir" != / ] || return 0

    rm -f -- \
        "$home_dir/.bash_history" "$home_dir/.zsh_history" \
        "$home_dir/.sh_history" "$home_dir/.ash_history" \
        "$home_dir/.ksh_history" "$home_dir/.history" \
        "$home_dir/.python_history" "$home_dir/.node_repl_history" \
        "$home_dir/.gdb_history" "$home_dir/.lua_history" \
        "$home_dir/.irb_history" "$home_dir/.pry_history" \
        "$home_dir/.Rhistory" "$home_dir/.php_history" \
        "$home_dir/.mysql_history" "$home_dir/.psql_history" \
        "$home_dir/.sqlite_history" "$home_dir/.rediscli_history" \
        "$home_dir/.lesshst" "$home_dir/.viminfo" \
        "$home_dir/.nano_history" "$home_dir/.wget-hsts" \
        "$home_dir/.lastlogin" "$home_dir/.local/share/recently-used.xbel" \
        "$home_dir/.config/fish/fish_history" \
        "$home_dir/.local/share/fish/fish_history" \
        "$home_dir/.local/state/bash/history" \
        "$home_dir/.local/state/zsh/history" \
        "$home_dir/.local/share/mc/history" \
        "$home_dir/.config/mc/history" \
        "$home_dir/.dbshell" \
        2>/dev/null || :

    if [ "$REMOVE_KNOWN_HOSTS" -eq 1 ]; then
        rm -f -- "$home_dir/.ssh/known_hosts" "$home_dir/.ssh/known_hosts.old" \
            "$home_dir/.ssh/known_hosts2" "$home_dir/.ssh/known_hosts2.old" \
            2>/dev/null || :
    fi

    purge_directory_contents "$home_dir/.local/share/recently-used"
    purge_directory_contents "$home_dir/.local/share/Trash"
    purge_directory_contents "$home_dir/.local/share/zeitgeist"
    purge_directory_contents "$home_dir/.local/share/gnome-shell/application_state"
    purge_directory_contents "$home_dir/.local/share/kactivitymanagerd"
    purge_directory_contents "$home_dir/.aws/cli/history"
    purge_directory_contents "$home_dir/.local/share/powershell/PSReadLine"
    purge_directory_contents "$home_dir/.cache/mesa_shader_cache"

    purge_directory_contents "$home_dir/.cache"
    purge_directory_contents "$home_dir/.thumbnails"
}

log "removing command, client, editor, recent-file, and user cache histories"
clean_home /root
if [ -r /etc/passwd ]; then
    while IFS=: read -r _ _ _ _ _ account_home _; do
        case $account_home in
            /|/bin|/boot|/dev|/etc|/lib|/lib64|/proc|/run|/sbin|/sys|/usr|/var|'') continue ;;
        esac
        clean_home "$account_home"
    done < /etc/passwd
fi
for account_home in /home/*; do
    [ -d "$account_home" ] && clean_home "$account_home"
done

if [ "$REMOVE_KNOWN_HOSTS" -eq 1 ]; then
    log "removing system-wide SSH client known-host records"
    rm -f -- /etc/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts.old \
        /etc/ssh/ssh_known_hosts2 /etc/ssh/ssh_known_hosts2.old 2>/dev/null || :
    if [ -d /etc/ssh/ssh_known_hosts.d ] && [ ! -L /etc/ssh/ssh_known_hosts.d ]; then
        find /etc/ssh/ssh_known_hosts.d -xdev -mindepth 1 \
            \( -type f -o -type l \) -delete 2>/dev/null ||
            warn "some system-wide SSH known-host records could not be removed"
    fi
fi

log "removing temporary files and volatile application residue"
purge_directory_contents /tmp
purge_directory_contents /var/tmp
purge_directory_contents /var/cache/abrt-di
purge_directory_contents /var/lib/systemd/timers
purge_directory_contents /var/cache/dnf
purge_directory_contents /var/cache/libdnf5
purge_directory_contents /var/cache/yum
purge_directory_contents /var/cache/PackageKit
purge_directory_contents /var/cache/apt/archives
purge_directory_contents /var/lib/apt/lists
rm -f -- /var/cache/apt/pkgcache.bin /var/cache/apt/srcpkgcache.bin \
    /var/lib/PackageKit/transactions.db /var/lib/PackageKit/transactions.db-shm \
    /var/lib/PackageKit/transactions.db-wal \
    /usr/lib/sysimage/libdnf5/transaction_history.sqlite \
    /usr/lib/sysimage/libdnf5/transaction_history.sqlite-shm \
    /usr/lib/sysimage/libdnf5/transaction_history.sqlite-wal 2>/dev/null || :

if [ -n "$CUSTOM_PATH_FILE" ]; then
    log "cleaning explicitly configured application log paths from $CUSTOM_PATH_FILE"
    while IFS= read -r custom || [ -n "$custom" ]; do
        case $custom in ''|'#'*) continue ;; esac
        safe_custom_path "$custom" || die "unsafe custom path rejected: $custom"
        if have readlink && [ -e "$custom" ]; then
            canonical=$(readlink -f -- "$custom" 2>/dev/null || printf '')
            [ -n "$canonical" ] || die "could not resolve custom path: $custom"
            safe_custom_path "$canonical" || die "custom path resolves to a protected target: $custom -> $canonical"
        fi
        if [ -L "$custom" ]; then
            die "symlinked custom path rejected: $custom"
        elif custom_path_is_mount_root "$custom"; then
            die "mount-root custom path rejected at execution time: $custom"
        elif [ -d "$custom" ]; then
            purge_directory_contents "$custom"
        elif [ -f "$custom" ]; then
            rm -f -- "$custom"
        else
            warn "custom path does not exist: $custom"
        fi
    done < "$CUSTOM_PATH_FILE"
fi

if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ]; then
    log "removing cloud-init instance state and logs"
    if have cloud-init; then
        if [ "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS" -eq 1 ]; then
            log "removing cloud-init generated configuration with --configs all"
            if cloud-init clean --help 2>&1 | grep -Eq '(^|[[:space:],])--seed([=[:space:],]|$)'; then
                cloud-init clean --logs --seed --configs all >/dev/null 2>&1 ||
                    die "cloud-init failed to clean state, logs, seed, and generated configuration"
            else
                cloud-init clean --logs --configs all >/dev/null 2>&1 ||
                    die "cloud-init failed to clean state, logs, and generated configuration"
                purge_directory_contents /var/lib/cloud/seed
            fi
        elif cloud-init clean --help 2>&1 | grep -Eq '(^|[[:space:],])--seed([=[:space:],]|$)'; then
            cloud-init clean --logs --seed >/dev/null 2>&1 ||
                die "cloud-init failed to clean instance artifacts, logs, and seed data"
        else
            cloud-init clean --logs >/dev/null 2>&1 ||
                die "cloud-init failed to clean instance artifacts and logs"
            # Older cloud-init releases do not expose --seed. Remove only the cached
            # seed content; external NoCloud/ConfigDrive media is not touched.
            purge_directory_contents /var/lib/cloud/seed
        fi
        purge_directory_contents /run/cloud-init
        cloud_residual=$(find /var/lib/cloud /run/cloud-init -mindepth 1 ! -type d \
            -print -quit 2>/dev/null || printf '')
        [ -z "$cloud_residual" ] ||
            die "cloud-init residual remains after cleanup: $cloud_residual"
    else
        log "cloud-init is not installed and no cached cloud-init state exists"
    fi
fi

if [ "$REMOVE_MACHINE_ID" -eq 1 ]; then
    log "removing clone-specific machine-id"
    # systemd explicitly recommends 'uninitialized' for a golden image so the next
    # boot satisfies first-boot semantics and generates a unique machine-id.
    if [ -d /run/systemd/system ] || have systemctl; then
        printf '%s\n' uninitialized > /etc/machine-id
        chmod 444 /etc/machine-id 2>/dev/null || :
    else
        rm -f -- /etc/machine-id 2>/dev/null || :
    fi
    if [ ! -L /var/lib/dbus/machine-id ]; then
        rm -f -- /var/lib/dbus/machine-id 2>/dev/null || :
    fi
fi

if [ "$REMOVE_RANDOM_SEED" -eq 1 ]; then
    log "removing saved system random seed"
    rm -f -- /var/lib/systemd/random-seed 2>/dev/null || :
fi

if [ "$REMOVE_NETWORK_LEASES" -eq 1 ]; then
    log "removing saved network leases"
    rm -f -- \
        /var/lib/dhcp/*.lease /var/lib/dhcp/*.leases \
        /var/lib/dhcp3/*.lease /var/lib/dhcp3/*.leases \
        /var/lib/dhclient/*.lease /var/lib/dhclient/*.leases \
        /var/lib/dhcpcd/*.lease /var/lib/dhcpcd/*.leases \
        /var/lib/NetworkManager/*.lease /var/lib/NetworkManager/*.leases \
        /var/lib/systemd/network/*.lease /var/lib/systemd/network/*.leases \
        /run/NetworkManager/*.lease /run/NetworkManager/*.leases \
        2>/dev/null || :
    purge_directory_contents /run/systemd/netif/leases
fi

VERIFY_WARNINGS=0
verify_emit() {
    printf '%s\n' "$*"
    printf '%s\n' "$*" >> "$VERIFY_LOG"
}

verify_warn() {
    VERIFY_WARNINGS=$((VERIFY_WARNINGS + 1))
    verify_emit "[CXT-SystemPrep][verify] WARN: $*"
}

verify_empty_file() {
    verify_file=$1
    if [ -e "$verify_file" ] && [ -s "$verify_file" ]; then
        verify_warn "non-empty file remains: $verify_file"
    fi
}

verify_no_matching_files() {
    verify_dir=$1
    shift
    [ -d "$verify_dir" ] || return 0
    verify_match=$(find "$verify_dir" -xdev -type f "$@" -print -quit 2>/dev/null || printf '')
    [ -z "$verify_match" ] || verify_warn "matching file remains: $verify_match"
}

verify_home() {
    verify_home_dir=$1
    [ -d "$verify_home_dir" ] || return 0
    verify_history=$(find "$verify_home_dir" -xdev -type f \
        \( -name '.bash_history' -o -name '.zsh_history' -o -name '.sh_history' \
        -o -name '.ash_history' -o -name '.ksh_history' -o -name '.history' \
        -o -name '.python_history' -o -name '.node_repl_history' \
        -o -name '.mysql_history' -o -name '.psql_history' \
        -o -name '.sqlite_history' -o -name '.rediscli_history' \
        -o -name '.viminfo' -o -name '.lesshst' -o -name '.nano_history' \) \
        -size +0c -print -quit 2>/dev/null || printf '')
    [ -z "$verify_history" ] || verify_warn "non-empty user history remains: $verify_history"
    if [ "$REMOVE_KNOWN_HOSTS" -eq 1 ]; then
        verify_known=$(find "$verify_home_dir/.ssh" -maxdepth 1 -type f \
            \( -name known_hosts -o -name known_hosts.old \
            -o -name known_hosts2 -o -name known_hosts2.old \) \
            -size +0c -print -quit 2>/dev/null || printf '')
        [ -z "$verify_known" ] ||
            verify_warn "non-empty SSH client history remains: $verify_known"
    fi
    if [ -d "$verify_home_dir/.cache" ] &&
        find "$verify_home_dir/.cache" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        verify_warn "user cache was repopulated or could not be emptied: $verify_home_dir/.cache"
    fi
}

run_verification() {
    VERIFY_WARNINGS=0
    verify_emit '[CXT-SystemPrep][verify] starting advisory verification'
    verify_emit "[CXT-SystemPrep][verify] time: $(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date)"
    verify_emit "[CXT-SystemPrep][verify] host: $HOST_NAME; profile: $PROFILE; action: $ACTION"

    for verify_file in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
        verify_empty_file "$verify_file"
    done
    [ ! -e /run/utmp ] || verify_warn "runtime login record remains: /run/utmp"

    verify_log=$(find /var/log -xdev -type f -size +0c \
        ! -path '/var/log/journal/*' \
        ! -path /var/log/wtmp ! -path /var/log/btmp ! -path /var/log/lastlog \
        -print -quit 2>/dev/null || printf '')
    [ -z "$verify_log" ] || verify_warn "non-empty standard log remains: $verify_log"

    if [ "$ACTION" = none ]; then
        verify_journal=$(find /var/log/journal /run/log/journal -xdev -type f \
            \( -name '*@*.journal*' -o -name '*.journal~' \) \
            -print -quit 2>/dev/null || printf '')
        [ -z "$verify_journal" ] ||
            verify_warn "archived systemd journal remains after vacuum: $verify_journal"
    else
        verify_journal=$(find /var/log/journal /run/log/journal -xdev -type f \
            -print -quit 2>/dev/null || printf '')
        [ -z "$verify_journal" ] ||
            verify_warn "systemd journal file remains in final shutdown phase: $verify_journal"
    fi

    verify_home /root
    if [ -r /etc/passwd ]; then
        while IFS=: read -r _ _ _ _ _ verify_home_dir _; do
            case $verify_home_dir in
                /|/bin|/boot|/dev|/etc|/lib|/lib64|/proc|/run|/sbin|/sys|/usr|/var|'') continue ;;
            esac
            [ "$verify_home_dir" = /root ] || verify_home "$verify_home_dir"
        done < /etc/passwd
    fi

    for verify_cache_dir in /var/cache/dnf /var/cache/libdnf5 /var/cache/yum /var/cache/PackageKit \
        /var/cache/apt/archives /var/lib/apt/lists /var/lib/yum/history; do
        if [ -d "$verify_cache_dir" ] &&
            find "$verify_cache_dir" -xdev -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
            verify_warn "package cache/history directory is not empty: $verify_cache_dir"
        fi
    done
    for verify_package_record in /var/lib/dnf/history.sqlite \
        /var/lib/PackageKit/transactions.db \
        /usr/lib/sysimage/libdnf5/transaction_history.sqlite; do
        [ ! -e "$verify_package_record" ] ||
            verify_warn "package transaction history remains: $verify_package_record"
    done

    if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ] && [ -d /var/lib/cloud ] &&
        find /var/lib/cloud -mindepth 1 ! -type d -print -quit 2>/dev/null | grep -q .; then
        verify_warn "cloud-init cached state remains under /var/lib/cloud"
    fi
    if [ "$REMOVE_CLOUD_INIT_STATE" -eq 1 ] && [ -d /run/cloud-init ] &&
        find /run/cloud-init -mindepth 1 ! -type d -print -quit 2>/dev/null | grep -q .; then
        verify_warn "cloud-init runtime state remains under /run/cloud-init"
    fi
    if [ "$REMOVE_CLOUD_INIT_GENERATED_CONFIGS" -eq 1 ]; then
        for verify_generated_config in \
            /etc/netplan/50-cloud-init.yaml \
            /etc/network/interfaces.d/50-cloud-init \
            /etc/NetworkManager/conf.d/99-cloud-init.conf \
            /etc/NetworkManager/conf.d/99-cloud-init-dns.conf \
            /etc/NetworkManager/system-connections/cloud-init-*.nmconnection \
            /run/NetworkManager/conf.d/10-globally-managed-devices.conf \
            /run/NetworkManager/system-connections/cloud-init-*.nmconnection \
            /etc/systemd/network/10-cloud-init-* \
            /etc/ssh/sshd_config.d/50-cloud-init.conf; do
            if [ -e "$verify_generated_config" ] || [ -L "$verify_generated_config" ]; then
                verify_warn "cloud-init generated configuration remains: $verify_generated_config"
                break
            fi
        done
        if [ -r /etc/fstab ] && grep -q 'comment=cloudconfig' /etc/fstab 2>/dev/null; then
            verify_warn "cloud-init tagged entries remain in /etc/fstab"
        fi
    fi
    if [ "$REMOVE_MACHINE_ID" -eq 1 ]; then
        if [ -e /etc/machine-id ]; then
            verify_machine_id=$(tr -d '\r\n' < /etc/machine-id 2>/dev/null || printf '')
            case $verify_machine_id in ''|uninitialized) ;;
                *) verify_warn "machine-id still contains an initialized value" ;;
            esac
        elif [ -d /run/systemd/system ] || have systemctl; then
            verify_warn "systemd machine-id marker is missing instead of uninitialized"
        fi
    fi
    if [ "$REMOVE_RANDOM_SEED" -eq 1 ] && [ -e /var/lib/systemd/random-seed ]; then
        verify_warn "saved random seed remains"
    fi
    if [ "$REMOVE_NETWORK_LEASES" -eq 1 ]; then
        for verify_lease_dir in /var/lib/dhcp /var/lib/dhcp3 /var/lib/dhclient \
            /var/lib/dhcpcd /var/lib/NetworkManager /var/lib/systemd/network \
            /run/NetworkManager /run/systemd/netif/leases; do
            verify_no_matching_files "$verify_lease_dir" \
                \( -name '*.lease' -o -name '*.leases' \)
        done
    fi
    if [ "$REMOVE_SSH_HOST_KEYS" -eq 1 ]; then
        verify_ssh_key=$(find /etc/ssh -maxdepth 1 -type f -name 'ssh_host_*' -print -quit 2>/dev/null || printf '')
        [ -z "$verify_ssh_key" ] || verify_warn "SSH host key remains: $verify_ssh_key"
    fi
    if [ "$REMOVE_KNOWN_HOSTS" -eq 1 ]; then
        for verify_system_known in /etc/ssh/ssh_known_hosts /etc/ssh/ssh_known_hosts.old \
            /etc/ssh/ssh_known_hosts2 /etc/ssh/ssh_known_hosts2.old; do
            [ ! -s "$verify_system_known" ] ||
                verify_warn "system-wide SSH client history remains: $verify_system_known"
        done
        if [ -d /etc/ssh/ssh_known_hosts.d ]; then
            verify_system_known=$(find /etc/ssh/ssh_known_hosts.d -xdev -mindepth 1 \
                \( -type f -o -type l \) -print -quit 2>/dev/null || printf '')
            [ -z "$verify_system_known" ] ||
                verify_warn "system-wide SSH client history remains: $verify_system_known"
        fi
    fi
    if [ -n "$CUSTOM_PATH_FILE" ]; then
        while IFS= read -r verify_custom || [ -n "$verify_custom" ]; do
            case $verify_custom in ''|'#'*) continue ;; esac
            if [ -d "$verify_custom" ]; then
                verify_custom_entry=$(find "$verify_custom" -xdev -mindepth 1 -print -quit 2>/dev/null || printf '')
                [ -z "$verify_custom_entry" ] ||
                    verify_warn "custom cleanup directory is not empty: $verify_custom"
            elif [ -e "$verify_custom" ]; then
                verify_warn "custom cleanup file still exists: $verify_custom"
            fi
        done < "$CUSTOM_PATH_FILE"
    fi
    if have loginctl; then
        verify_session=$(loginctl list-sessions --no-legend 2>/dev/null |
            awk 'NF {print $1; exit}')
        [ -z "$verify_session" ] || verify_warn "login session remains: $verify_session"
    fi

    if have systemctl; then
        for verify_unit in $STANDARD_CLEANUP_UNITS; do
            if systemctl is-active --quiet "$verify_unit"; then
                verify_warn "log-writing service is active during verification: $verify_unit"
            fi
        done
    fi

    if [ "$WIPE_SWAP" -eq 1 ] && have swapon; then
        verify_swap=$(swapon --noheadings --raw --output NAME 2>/dev/null |
            awk '$1 !~ /^\/dev\/(zram|ram)/ {print; exit}')
        [ -z "$verify_swap" ] || verify_warn "disk swap remains active after wipe: $verify_swap"
    fi
    if [ "$ZERO_FREE_SPACE" -eq 1 ] && have findmnt; then
        verify_uncovered=$(findmnt -n -o TARGET,SOURCE,FSTYPE,OPTIONS |
            awk '$2 ~ /^\/dev\// && $4 !~ /(^|,)ro(,|$)/ && $3 !~ /^(ext2|ext3|ext4|xfs)$/ {print $1 " (" $3 ")"; exit}')
        [ -z "$verify_uncovered" ] ||
            verify_warn "writable block filesystem was outside zero-fill support: $verify_uncovered"
    fi

    if [ "$VERIFY_WARNINGS" -eq 0 ]; then
        verify_emit '[CXT-SystemPrep][verify] PASS: no checked residuals found'
    else
        verify_emit "[CXT-SystemPrep][verify] completed with $VERIFY_WARNINGS warning(s); cleanup continues"
    fi
}

if [ "$REMOVE_SSH_HOST_KEYS" -eq 1 ]; then
    log "removing SSH server host keys"
    rm -f -- /etc/ssh/ssh_host_* 2>/dev/null || :
fi

if [ "$WIPE_SWAP" -eq 1 ]; then
    SWAP_LIST_FILE=$STATE_DIR/active-swap-targets
    swapon --noheadings --raw --output NAME > "$SWAP_LIST_FILE" 2>/dev/null || :
    if [ -s "$SWAP_LIST_FILE" ]; then
        log "zeroing active disk swap; ensure available RAM can hold the workload"
        while IFS= read -r swap_path; do
            [ -n "$swap_path" ] || continue
            case $swap_path in
                /dev/zram*|/dev/ram*) continue ;;
                /dev/*|/*) ;;
                *) die "unsafe swap path: $swap_path" ;;
            esac
            [ -b "$swap_path" ] || [ -f "$swap_path" ] ||
                die "swap target is not a block device or regular file: $swap_path"
            swap_uuid=$(blkid -s UUID -o value "$swap_path" 2>/dev/null || printf '')
            swap_label=$(blkid -s LABEL -o value "$swap_path" 2>/dev/null || printf '')
            swapoff "$swap_path" || die "could not disable swap: $swap_path"
            printf '%s\n' "$swap_path" >> "$DISABLED_SWAP_TARGETS"
            if [ -b "$swap_path" ]; then
                swap_size=$(blockdev --getsize64 "$swap_path" 2>/dev/null || printf 0)
            else
                swap_size=$(wc -c < "$swap_path")
            fi
            case $swap_size in ''|0|*[!0-9]*) die "could not determine swap size: $swap_path" ;; esac
            block_size=1048576
            full_blocks=$((swap_size / block_size))
            remainder=$((swap_size % block_size))
            if [ "$full_blocks" -gt 0 ]; then
                dd if=/dev/zero of="$swap_path" bs=1M count="$full_blocks" \
                    conv=notrunc 2>/dev/null || die "could not zero swap target: $swap_path"
            fi
            if [ "$remainder" -gt 0 ]; then
                dd if=/dev/zero of="$swap_path" bs=1 count="$remainder" \
                    seek=$((full_blocks * block_size)) conv=notrunc 2>/dev/null ||
                    die "could not finish zeroing swap target: $swap_path"
            fi
            set --
            [ -n "$swap_label" ] && set -- "$@" -L "$swap_label"
            [ -n "$swap_uuid" ] && set -- "$@" -U "$swap_uuid"
            mkswap "$@" "$swap_path" >/dev/null || die "could not recreate swap: $swap_path"
        done < "$SWAP_LIST_FILE"
    fi
fi

# Existing binary-accounting files were truncated in place so their distro-specific
# sparse layout, ownership, mode, ACLs, and labels remain intact. Missing files stay
# absent and will be created by the owning package/service with native metadata.
if have restorecon; then
    restorecon -RF /var/log /etc/machine-id >/dev/null 2>&1 || :
fi

if [ "$ZERO_FREE_SPACE" -eq 1 ]; then
    log "zero-filling free space; an out-of-space result for each temporary file is expected"
    ZERO_MOUNT_LIST=$STATE_DIR/zero-mounts
    findmnt -n -t ext2,ext3,ext4,xfs -o TARGET,FSTYPE,OPTIONS > "$ZERO_MOUNT_LIST"
    while IFS=' ' read -r mount_point mount_fstype mount_options; do
        case ,$mount_options, in *,ro,*) continue ;; esac
        case $mount_point in *\\*) warn "zero-fill skipped for escaped mount path: $mount_point"; continue ;; esac
        [ -d "$mount_point" ] || continue
        zero_file=$mount_point/.cxt-systemprep-zero-fill.tmp
        ACTIVE_ZERO_FILE=$zero_file
        log "zero-filling $mount_point ($mount_fstype)"
        rm -f -- "$zero_file" 2>/dev/null || :
        free_kb=$(df -Pk "$mount_point" 2>/dev/null | awk 'END {print $4}' || printf unknown)
        case $free_kb in
            0) log "skipping $mount_point because no allocatable blocks remain" ;;
            *[!0-9]*|'') die "could not determine free space for $mount_point" ;;
            *)
                : > "$zero_file" || die "could not create zero-fill file on $mount_point"
                dd if=/dev/zero of="$zero_file" bs=16M 2>/dev/null || :
                [ -s "$zero_file" ] || die "zero-fill made no progress on $mount_point"
                remaining_kb=$(df -Pk "$mount_point" 2>/dev/null | awk 'END {print $4}' || printf unknown)
                case $remaining_kb in
                    *[!0-9]*|'') die "could not verify remaining free space for $mount_point" ;;
                    *)
                        [ "$remaining_kb" -le 16384 ] ||
                            die "zero-fill stopped early on $mount_point; ${remaining_kb} KiB remains"
                        ;;
                esac
                ;;
        esac
        sync
        rm -f -- "$zero_file" || die "could not remove zero-fill file from $mount_point"
        ACTIVE_ZERO_FILE=
        sync
    done < "$ZERO_MOUNT_LIST"
fi

# Sessions and daemons may have written fresh accounting/lease state during a long
# zero-fill. Repeat the small identity-sensitive cleanup immediately before shutdown.
for accounting_file in /var/log/wtmp /var/log/btmp /var/log/lastlog; do
    if [ -f "$accounting_file" ] && [ ! -L "$accounting_file" ]; then
        : > "$accounting_file"
    fi
done
rm -f -- /run/utmp /var/run/utmp 2>/dev/null || :
if [ "$REMOVE_RANDOM_SEED" -eq 1 ]; then
    rm -f -- /var/lib/systemd/random-seed 2>/dev/null || :
fi
if [ "$REMOVE_NETWORK_LEASES" -eq 1 ]; then
    log "stopping network lease writers before final lease removal"
    for unit in $NETWORK_LEASE_UNITS; do
        stop_unit "$unit"
        runtime_mask_unit "$unit"
    done
    for unit in $NETWORK_LEASE_UNITS; do
        systemctl is-active --quiet "$unit" 2>/dev/null &&
            die "network lease writer is still active after stop and runtime mask: $unit"
    done
    rm -f -- \
        /var/lib/dhcp/*.lease /var/lib/dhcp/*.leases \
        /var/lib/dhcp3/*.lease /var/lib/dhcp3/*.leases \
        /var/lib/dhclient/*.lease /var/lib/dhclient/*.leases \
        /var/lib/dhcpcd/*.lease /var/lib/dhcpcd/*.leases \
        /var/lib/NetworkManager/*.lease /var/lib/NetworkManager/*.leases \
        /var/lib/systemd/network/*.lease /var/lib/systemd/network/*.leases \
        /run/NetworkManager/*.lease /run/NetworkManager/*.leases \
        2>/dev/null || :
    purge_directory_contents /run/systemd/netif/leases
fi

if find_open_log_writer; then
    die "a process reopened a cleaned log path before finalization: $OPEN_LOG_WRITER"
fi

cleanup_runtime_payload_success() {
    case $RUNTIME_DIR in
        /run/cxt-systemprep.*) ;;
        *) die "refusing to clean an unexpected runtime directory: $RUNTIME_DIR" ;;
    esac
    rm -f -- "$RUNTIME_DIR/custom-paths.list" "$RUNTIME_DIR/custom-services.list" 2>/dev/null || :
    if [ -f "$SCRIPT_PATH" ] && [ ! -L "$SCRIPT_PATH" ]; then
        rm -f -- "$SCRIPT_PATH" || die "could not remove runtime script: $SCRIPT_PATH"
    else
        warn "runtime script was not a regular file at cleanup time: $SCRIPT_PATH"
    fi
    cleanup_state_dir
    if [ "$VERIFY" -eq 1 ]; then
        chmod 600 "$VERIFY_LOG" 2>/dev/null || :
        log "retaining only the requested verification report in $RUNTIME_DIR"
    elif ! rmdir "$RUNTIME_DIR" 2>/dev/null; then
        warn "unexpected entries remain in private runtime directory: $RUNTIME_DIR"
    fi
}

# Stop journald only when shutdown or reboot follows immediately. With no power action,
# keep it running so the operator can reconnect for testing and inspection.
if [ "$ACTION" = none ]; then
    if have journalctl; then
        journalctl --rotate >/dev/null 2>&1 || :
        journalctl --vacuum-time=1s --vacuum-size=1K >/dev/null 2>&1 || :
    fi
    purge_non_directories /var/log/audit
    if [ "$VERIFY" -eq 1 ]; then
        run_verification
    fi
    restore_runtime_state
    sync
    warn "no power action selected; restored services may create new logs and transient state after this point"
    cleanup_runtime_payload_success
    trap - EXIT HUP INT TERM
    log "sanitization completed; final action: none"
    warn "cleanup completed without reboot or poweroff"
    exit 0
fi

# A detached systemd service normally writes stdout to journald; redirect first so
# closing the journal stream cannot abort the final shutdown phase with SIGPIPE.
log "entering final silent phase; the system will $ACTION when complete"
exec >/dev/null 2>&1
FINAL_JOURNAL_STOPPED=1
systemctl stop systemd-journald.service systemd-journald.socket \
    systemd-journald-dev-log.socket systemd-journald-audit.socket \
    >/dev/null 2>&1 || :
for unit in \
    systemd-journald.service systemd-journald.socket \
    systemd-journald-dev-log.socket systemd-journald-audit.socket; do
    runtime_mask_unit "$unit"
done
for unit in \
    systemd-journald.service systemd-journald.socket \
    systemd-journald-dev-log.socket systemd-journald-audit.socket; do
    systemctl is-active --quiet "$unit" 2>/dev/null &&
        die "systemd journal unit is still active in the final phase: $unit"
done
purge_non_directories /var/log/journal
purge_non_directories /run/log/journal
find /var/log/journal /run/log/journal -xdev -mindepth 1 -depth -type d \
    -empty -delete 2>/dev/null || :
purge_non_directories /var/log/audit
if [ "$VERIFY" -eq 1 ]; then
    run_verification
fi
sync

case $ACTION in
    poweroff)
        POWER_ACTION_IN_PROGRESS=1
        if ! systemctl poweroff --no-wall; then
            POWER_ACTION_IN_PROGRESS=0
            die "systemd rejected the poweroff request"
        fi
        ;;
    reboot)
        POWER_ACTION_IN_PROGRESS=1
        if ! systemctl reboot --no-wall; then
            POWER_ACTION_IN_PROGRESS=0
            die "systemd rejected the reboot request"
        fi
        ;;
esac

# systemctl normally hands control to the shutdown transaction. If it returns before
# PID 1 terminates this service, remove the remaining tmpfs payload as well.
cleanup_runtime_payload_success
trap - EXIT HUP INT TERM
exit 0
