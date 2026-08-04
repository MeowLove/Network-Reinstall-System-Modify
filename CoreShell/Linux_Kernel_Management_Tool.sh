#!/usr/bin/env bash
# Linux Kernel Management Tool - Enhanced
# Version 3.1.8
#
# Supported families:
#   - Debian / Ubuntu
#   - RHEL-compatible family (official channel)
#   - ELRepo channel only on validated Enterprise Linux variants
#
# Upgrade channels:
#   Debian: official, backports
#   Ubuntu: official, hwe
#   RHEL:   official, elrepo-lt, elrepo-ml
#
# Source inspiration:
#   https://github.com/MeowLove/Network-Reinstall-System-Modify/blob/master/CoreShell/Linux_Kernel_Management_Tool.sh

set -Eeuo pipefail
IFS=$'\n\t'

PROGRAM_NAME="Linux Kernel Management Tool - Enhanced"
PROGRAM_VERSION="3.1.8"

COMMAND="menu"
CHANNEL=""
KEEP_OLD_KERNELS="1"
ASSUME_YES="0"
DRY_RUN="0"
AUTOREMOVE="0"

OS_FAMILY=""
OS_ID=""
OS_ID_LIKE=""
OS_NAME=""
OS_VERSION=""
OS_CODENAME=""
ELREPO_SUPPORTED="0"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

print_command() {
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
}

pause_screen() {
    if [[ -t 0 ]]; then
        printf '\n按 Enter 返回菜单...'
        read -r _
    fi
}

confirm() {
    local prompt="$1"
    local answer=""

    if [[ "${ASSUME_YES}" == "1" ]]; then
        return 0
    fi

    read -r -p "${prompt} [y/N]: " answer
    [[ "${answer}" == "y" || "${answer}" == "Y" || "${answer}" == "yes" || "${answer}" == "YES" ]]
}

require_root() {
    [[ "${EUID}" -eq 0 ]] || die "请使用 root 运行此脚本。"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "缺少命令：$1"
}

acquire_package_lock() {
    case "${COMMAND}" in
        menu|upgrade|clean|repair|clean-cache)
            require_command flock
            mkdir -p /run/lock
            exec 9>/run/lock/linux-kernel-management-tool.lock
            flock -n 9 || die "检测到另一个内核管理或软件包操作正在运行。"
            ;;
    esac
}

parse_nonnegative_integer() {
    [[ "$1" =~ ^[0-9]+$ ]] || die "参数必须是非负整数：$1"
}

parse_args() {
    local command_set=0

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            menu|status|list|upgrade|clean|boot|repair|clean-cache|diagnose)
                if [[ "${command_set}" -eq 1 ]]; then
                    die "只能指定一个操作命令。"
                fi
                COMMAND="$1"
                command_set=1
                ;;
            --channel)
                [[ "$#" -ge 2 ]] || die "--channel 缺少参数。"
                CHANNEL="$2"
                shift
                ;;
            --channel=*)
                CHANNEL="${1#*=}"
                ;;
            --keep-old)
                [[ "$#" -ge 2 ]] || die "--keep-old 缺少参数。"
                KEEP_OLD_KERNELS="$2"
                shift
                ;;
            --keep-old=*)
                KEEP_OLD_KERNELS="${1#*=}"
                ;;
            --dry-run)
                DRY_RUN="1"
                ;;
            --autoremove)
                AUTOREMOVE="1"
                ;;
            --yes|-y)
                ASSUME_YES="1"
                ;;
            --help|-h|help)
                usage
                exit 0
                ;;
            --version)
                echo "${PROGRAM_NAME} ${PROGRAM_VERSION}"
                exit 0
                ;;
            *)
                die "未知参数：$1。使用 --help 查看帮助。"
                ;;
        esac
        shift
    done

    parse_nonnegative_integer "${KEEP_OLD_KERNELS}"
}

detect_os() {
    [[ -r /etc/os-release ]] || die "无法读取 /etc/os-release。"
    # shellcheck disable=SC1091
    . /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
    OS_VERSION="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"

    case " ${OS_ID} ${OS_ID_LIKE} " in
        *debian*|*ubuntu*) OS_FAMILY="apt" ;;
        *rhel*|*fedora*|*centos*) OS_FAMILY="rhel" ;;
        *) die "当前发行版暂不支持：${OS_NAME}" ;;
    esac

    case "${OS_ID}" in
        rhel|rocky|almalinux|ol|oraclelinux)
            ELREPO_SUPPORTED="1"
            ;;
        fedora|centos)
            ELREPO_SUPPORTED="0"
            ;;
        *)
            ELREPO_SUPPORTED="0"
            ;;
    esac
}

check_path_free_space() {
    local path="$1"
    local minimum_kb="$2"
    local label="$3"
    local free_kb

    [[ -e "${path}" ]] || return 0
    free_kb="$(df -Pk "${path}" | awk 'NR == 2 {print $4}')"

    if [[ "${free_kb}" =~ ^[0-9]+$ ]] && [[ "${free_kb}" -lt "${minimum_kb}" ]]; then
        warn "${label} 可用空间不足，内核安装或 initramfs 生成可能失败。"
        df -h "${path}"
        return 1
    fi
}

check_space_for_kernel_update() {
    local failed=0

    check_path_free_space / 262144 "根分区" || failed=1

    if mountpoint -q /boot 2>/dev/null; then
        check_path_free_space /boot 131072 "/boot 分区" || failed=1
    fi

    if mountpoint -q /boot/efi 2>/dev/null; then
        check_path_free_space /boot/efi 16384 "/boot/efi 分区" || failed=1
    fi

    if [[ "${failed}" -eq 1 ]]; then
        confirm "检测到启动相关分区空间偏低，仍要继续？" || return 1
    fi
}

update_apt_bootloader() {
    if command -v update-grub >/dev/null 2>&1; then
        update-grub
    elif command -v update-grub2 >/dev/null 2>&1; then
        update-grub2
    else
        warn "未找到 update-grub/update-grub2；请手动确认 bootloader 配置。"
    fi
}

apt_current_kernel_package() {
    printf 'linux-image-%s\n' "$(uname -r)"
}

apt_tracking_package() {
    local kernel
    kernel="$(uname -r)"

    if [[ "${OS_ID}" == "debian" ]]; then
        case "${kernel}" in
            *-cloud-amd64) printf '%s\n' 'linux-image-cloud-amd64' ;;
            *-cloud-arm64) printf '%s\n' 'linux-image-cloud-arm64' ;;
            *-amd64)       printf '%s\n' 'linux-image-amd64' ;;
            *-arm64)       printf '%s\n' 'linux-image-arm64' ;;
            *)             printf '%s\n' '' ;;
        esac
        return
    fi

    if [[ "${OS_ID}" == "ubuntu" ]]; then
        case "${kernel}" in
            *-generic)
                local hwe_generic
                hwe_generic="$(ubuntu_hwe_tracking_package || true)"
                if [[ -n "${hwe_generic}" ]] && apt_package_installed "${hwe_generic}"; then
                    printf '%s\n' "${hwe_generic}"
                else
                    printf '%s\n' 'linux-generic'
                fi
                ;;
            *-virtual)
                local hwe_virtual
                hwe_virtual="$(ubuntu_hwe_tracking_package || true)"
                if [[ -n "${hwe_virtual}" ]] && apt_package_installed "${hwe_virtual}"; then
                    printf '%s\n' "${hwe_virtual}"
                else
                    printf '%s\n' 'linux-virtual'
                fi
                ;;
            *-aws)      printf '%s\n' 'linux-aws' ;;
            *-azure)    printf '%s\n' 'linux-azure' ;;
            *-gcp)      printf '%s\n' 'linux-gcp' ;;
            *-oracle)   printf '%s\n' 'linux-oracle' ;;
            *-kvm)      printf '%s\n' 'linux-kvm' ;;
            *-raspi)    printf '%s\n' 'linux-raspi' ;;
            *)          printf '%s\n' '' ;;
        esac
        return
    fi

    printf '%s\n' ''
}

ubuntu_hwe_tracking_package() {
    local kernel
    kernel="$(uname -r)"

    [[ "${OS_ID}" == "ubuntu" ]] || return 1
    [[ "${OS_VERSION}" =~ ^[0-9]+\.[0-9]+$ ]] || return 1

    case "${kernel}" in
        *-generic) printf 'linux-generic-hwe-%s\n' "${OS_VERSION}" ;;
        *-virtual) printf 'linux-virtual-hwe-%s\n' "${OS_VERSION}" ;;
        *)         return 1 ;;
    esac
}

apt_kernel_flavor() {
    case "$(uname -r)" in
        *-cloud-amd64) printf '%s\n' 'cloud-amd64' ;;
        *-cloud-arm64) printf '%s\n' 'cloud-arm64' ;;
        *-amd64)       printf '%s\n' 'amd64' ;;
        *-arm64)       printf '%s\n' 'arm64' ;;
        *-generic)     printf '%s\n' 'generic' ;;
        *-virtual)     printf '%s\n' 'virtual' ;;
        *-lowlatency)  printf '%s\n' 'lowlatency' ;;
        *-aws)         printf '%s\n' 'aws' ;;
        *-azure)       printf '%s\n' 'azure' ;;
        *-gcp)         printf '%s\n' 'gcp' ;;
        *-oracle)      printf '%s\n' 'oracle' ;;
        *-kvm)         printf '%s\n' 'kvm' ;;
        *-oem)         printf '%s\n' 'oem' ;;
        *-raspi)       printf '%s\n' 'raspi' ;;
        *)              printf '%s\n' '' ;;
    esac
}

apt_kernel_package_matches_flavor() {
    local package="$1"
    local requested_flavor="$2"

    case "${requested_flavor}" in
        amd64)
            [[ "${package}" == *-amd64 && "${package}" != *-cloud-amd64 ]]
            ;;
        arm64)
            [[ "${package}" == *-arm64 && "${package}" != *-cloud-arm64 ]]
            ;;
        *)
            [[ "${package}" == *-"${requested_flavor}" ]]
            ;;
    esac
}

apt_kernel_release_matches_flavor() {
    local release="$1"
    local requested_flavor="$2"

    apt_kernel_package_matches_flavor \
        "linux-image-${release}" "${requested_flavor}"
}

apt_boot_file_owned_by_installed_package() {
    local path="$1"
    local owner_line owner

    while IFS= read -r owner_line; do
        # dpkg-query -S uses ": " as the separator; the package name itself
        # can contain a colon for its architecture qualifier.
        owner="${owner_line%%: *}"
        [[ -n "${owner}" ]] || continue
        apt_package_installed "${owner}" && return 0
    done < <(dpkg-query -S "${path}" 2>/dev/null || true)

    return 1
}

apt_orphaned_boot_files() {
    local requested_flavor="$1"
    local current_release path filename release

    current_release="$(uname -r)"

    while IFS= read -r -d '' path; do
        filename="${path##*/}"
        case "${filename}" in
            vmlinuz-*)    release="${filename#vmlinuz-}" ;;
            initrd.img-*) release="${filename#initrd.img-}" ;;
            *)            continue ;;
        esac

        [[ "${release}" == "${current_release}" ]] && continue
        apt_kernel_release_matches_flavor \
            "${release}" "${requested_flavor}" || continue
        apt_boot_file_owned_by_installed_package "${path}" && continue
        printf '%s\n' "${path}"
    done < <(
        find /boot -maxdepth 1 -type f \
            \( -name 'vmlinuz-*' -o -name 'initrd.img-*' \) -print0 2>/dev/null
    )
}

apt_kernel_component_packages() {
    local release="$1"
    local status package package_name

    while IFS=$'\t' read -r status package; do
        [[ "${status:0:2}" == "ii" ]] || continue
        package_name="${package%:*}"
        case "${package_name}" in
            "linux-base-${release}"|\
            "linux-binary-${release}"|\
            "linux-modules-${release}"|\
            "linux-modules-extra-${release}")
                printf '%s\n' "${package}"
                ;;
        esac
    done < <(
        dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\n' \
            "linux-base-${release}" \
            "linux-binary-${release}" \
            "linux-modules-${release}" \
            "linux-modules-extra-${release}" 2>/dev/null || true
    )
}

apt_orphaned_kernel_component_packages() {
    local requested_flavor="$1"
    local current_release status package package_name release

    current_release="$(uname -r)"

    while IFS=$'\t' read -r status package; do
        [[ "${status:0:2}" == "ii" ]] || continue
        package_name="${package%:*}"
        case "${package_name}" in
            linux-base-*)          release="${package_name#linux-base-}" ;;
            linux-binary-*)        release="${package_name#linux-binary-}" ;;
            linux-modules-extra-*) release="${package_name#linux-modules-extra-}" ;;
            linux-modules-*)       release="${package_name#linux-modules-}" ;;
            *)                     continue ;;
        esac

        [[ "${release}" == "${current_release}" ]] && continue
        apt_kernel_release_matches_flavor \
            "${release}" "${requested_flavor}" || continue
        apt_package_installed "linux-image-${release}" && continue
        printf '%s\n' "${package}"
    done < <(
        dpkg-query -W -f='${db:Status-Abbrev}\t${binary:Package}\n' \
            'linux-base-*' 'linux-binary-*' 'linux-modules-*' 2>/dev/null || true
    ) | sort -u
}

apt_installed_kernel_rows() {
    local requested_flavor="${1:-}"
    local status package version

    # Parse dpkg-query fields directly. ${db:Status-Abbrev} is a three-character
    # field (desired action/current state/error flag); only "ii" is installed.
    while IFS=$'\t' read -r status package version; do
        [[ "${status:0:2}" == "ii" ]] || continue
        [[ "${package}" =~ ^linux-image-[0-9] ]] || continue
        if [[ -n "${requested_flavor}" ]]; then
            apt_kernel_package_matches_flavor "${package}" "${requested_flavor}" || continue
        fi
        printf '%s\t%s\n' "${package}" "${version}"
    done < <(
        dpkg-query -W \
            -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n' \
            'linux-image-[0-9]*' 2>/dev/null
    ) | sort -t $'\t' -k2,2V
}
apt_package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q '^install ok installed$'
}

ensure_apt_tracking_package() {
    local meta
    meta="$(apt_tracking_package)"

    if [[ -z "${meta}" ]]; then
        warn "无法根据当前内核自动判断跟踪软件包。"
        return 0
    fi

    if [[ "${DRY_RUN}" == "1" ]]; then
        if apt_package_installed "${meta}"; then
            info "跟踪软件包已安装：${meta}"
        else
            warn "实际执行时将安装跟踪软件包：${meta}"
            print_command apt-get install -y --install-recommends "${meta}"
        fi
        return 0
    fi

    info "确保内核跟踪软件包已安装并设为手动安装：${meta}"
    apt-get install -y --install-recommends "${meta}"
    apt-mark manual "${meta}" >/dev/null
}

rhel_running_kernel_owner() {
    local release owner
    release="$(uname -r)"

    owner="$(rpm -q --whatprovides "kernel-uname-r = ${release}" --qf '%{NAME}\n' 2>/dev/null | head -n 1 || true)"
    if [[ -n "${owner}" ]]; then
        printf '%s\n' "${owner}"
        return 0
    fi

    if [[ -e "/boot/vmlinuz-${release}" ]]; then
        rpm -qf "/boot/vmlinuz-${release}" --qf '%{NAME}\n' 2>/dev/null | head -n 1 || true
        return 0
    fi

    if [[ -e "/lib/modules/${release}/vmlinuz" ]]; then
        rpm -qf "/lib/modules/${release}/vmlinuz" --qf '%{NAME}\n' 2>/dev/null | head -n 1 || true
    fi
}

rhel_tracking_package() {
    local owner
    owner="$(rhel_running_kernel_owner)"

    case "${owner}" in
        kernel-ml|kernel-ml-core|kernel-ml-modules*) printf '%s\n' 'kernel-ml' ;;
        kernel-lt|kernel-lt-core|kernel-lt-modules*) printf '%s\n' 'kernel-lt' ;;
        kernel-uek|kernel-uek-core|kernel-uek-modules*|kernel-uek-firmware) printf '%s\n' 'kernel-uek' ;;
        *) printf '%s\n' 'kernel' ;;
    esac
}

show_status() {
    echo
    echo "========================================"
    echo "${PROGRAM_NAME} ${PROGRAM_VERSION}"
    echo "系统：${OS_NAME}"
    echo "发行版：${OS_ID} ${OS_VERSION}"
    echo "当前运行内核：$(uname -r)"
    echo "架构：$(uname -m)"
    echo "========================================"

    echo
    echo "磁盘空间："
    df -h /
    if mountpoint -q /boot 2>/dev/null; then
        df -h /boot
    fi
    if mountpoint -q /boot/efi 2>/dev/null; then
        df -h /boot/efi
    fi

    echo
    if [[ "${OS_FAMILY}" == "apt" ]]; then
        echo "当前内核包：$(apt_current_kernel_package)"
        echo "跟踪软件包：$(apt_tracking_package)"
        if [[ -e /var/run/reboot-required ]]; then
            warn "系统提示需要重启。"
            [[ -r /var/run/reboot-required.pkgs ]] && cat /var/run/reboot-required.pkgs
        else
            echo "重启状态：当前未检测到 reboot-required 标记。"
        fi
    else
        echo "当前内核所属包：$(rhel_running_kernel_owner)"
        echo "跟踪软件包：$(rhel_tracking_package)"
        if command -v grubby >/dev/null 2>&1; then
            echo "默认启动内核：$(grubby --default-kernel 2>/dev/null || echo unknown)"
        fi
    fi
}

list_kernels_apt() {
    local current_pkg meta pkg version
    current_pkg="$(apt_current_kernel_package)"
    meta="$(apt_tracking_package)"

    echo
    echo "已安装的实际内核包："
    while IFS=$'\t' read -r pkg version; do
        [[ -n "${pkg}" ]] || continue
        if [[ "${pkg}" == "${current_pkg}" ]]; then
            printf '  [当前] %-55s %s\n' "${pkg}" "${version}"
        else
            printf '  [其他] %-55s %s\n' "${pkg}" "${version}"
        fi
    done < <(apt_installed_kernel_rows)

    echo
    echo "已安装的内核跟踪/元软件包："
    while IFS=$'\t' read -r status package version; do
        [[ "${status:0:2}" == "ii" ]] || continue
        [[ "${package}" =~ ^linux-image-[0-9] ]] && continue
        printf '  %s %s\n' "${package}" "${version}"
    done < <(
        dpkg-query -W \
            -f='${db:Status-Abbrev}\t${binary:Package}\t${Version}\n' \
            'linux-image*' 'linux-generic*' 'linux-virtual*' 'linux-aws*' \
            'linux-azure*' 'linux-gcp*' 'linux-oracle*' 2>/dev/null
    ) | sort -u || true
    echo
    echo "当前建议跟踪包：${meta:-未知}"

    echo
    echo "/boot 内核文件："
    find /boot -maxdepth 1 -type f \
        \( -name 'vmlinuz-*' -o -name 'initrd.img-*' \) \
        -printf '  %f\n' 2>/dev/null | sort -V || true
}

list_kernels_rhel() {
    echo
    echo "当前运行内核：$(uname -r)"
    echo "已安装的内核包："
    rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |
        grep -E '^(kernel|kernel-core|kernel-lt|kernel-lt-core|kernel-ml|kernel-ml-core|kernel-uek|kernel-uek-core)-[0-9]' |
        sort -V || true

    if command -v grubby >/dev/null 2>&1; then
        echo
        echo "GRUB 内核条目："
        grubby --info=ALL | grep -E '^(index=|kernel=|title=)' || true
    fi
}

list_kernels() {
    if [[ "${OS_FAMILY}" == "apt" ]]; then
        list_kernels_apt
    else
        list_kernels_rhel
    fi
}

apt_upgrade_official() {
    local meta
    meta="$(apt_tracking_package)"
    [[ -n "${meta}" ]] || die "无法确定当前内核对应的官方跟踪软件包。"

    check_space_for_kernel_update || return 0

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command apt-get update
        print_command apt-get -s install "${meta}"
        return 0
    fi

    apt-get update
    apt-get install -y --install-recommends "${meta}"
    apt-mark manual "${meta}" >/dev/null
    update_apt_bootloader
}

backports_configured() {
    local suite="$1"
    local source_file

    while IFS= read -r source_file; do
        [[ -n "${source_file}" ]] || continue
        if grep -qiE '^Enabled:[[:space:]]*no' "${source_file}"; then
            continue
        fi
        return 0
    done < <(
        grep -RslE "(^deb[[:space:]].*[[:space:]]${suite}([[:space:]]|$)|^Suites:[[:space:]]*${suite}([[:space:]]|$))" \
            /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
    )

    return 1
}

configure_debian_backports() {
    local suite file backup
    [[ "${OS_ID}" == "debian" ]] || die "Backports 通道仅适用于 Debian。"
    [[ -n "${OS_CODENAME}" ]] || die "无法识别 Debian 代号。"

    suite="${OS_CODENAME}-backports"
    file="/etc/apt/sources.list.d/${suite}.sources"

    if backports_configured "${suite}"; then
        info "已经检测到启用的 ${suite} 源。"
        return 0
    fi

    warn "系统尚未检测到启用的 Debian ${suite} 官方仓库。"
    if [[ "${DRY_RUN}" == "1" ]]; then
        echo "[DRY-RUN] 将创建或更新 ${file}："
        cat <<EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: ${suite}
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
        return 0
    fi

    if [[ -e "${file}" ]]; then
        backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        warn "目标源文件已存在但未被识别为启用的 Backports：${file}"
        confirm "是否先备份为 ${backup} 并更新它？" || die "用户取消更新 Backports 源。"
        cp -a "${file}" "${backup}"
    else
        confirm "是否添加 Debian 官方 ${suite} 仓库？" || die "用户取消添加 Backports。"
    fi

    cat > "${file}" <<EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: ${suite}
Components: main
Enabled: yes
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
}

apt_backports_version() {
    local meta="$1"
    local suite="$2"

    # apt-cache policy does not print the suite on the Candidate line itself;
    # it prints a version table followed by repository source lines. Associate
    # each source line with the version immediately preceding it instead of
    # grepping the whole output for the suite name.
    apt-cache policy "${meta}" | awk -v suite="${suite}" '
        /^[[:space:]]+\*\*\*[[:space:]]+/ { version=$2; next }
        /^[[:space:]]+[0-9][^[:space:]]*[[:space:]]+[0-9]+([[:space:]]|$)/ { version=$1; next }
        index($0, suite) > 0 && version != "" { print version; exit }
    '
}

apt_upgrade_backports() {
    local suite meta backports_version simulation
    [[ "${OS_ID}" == "debian" ]] || die "--channel backports 仅适用于 Debian。"

    meta="$(apt_tracking_package)"
    [[ -n "${meta}" ]] || die "无法确定 Debian 内核跟踪软件包。"
    suite="${OS_CODENAME}-backports"

    check_space_for_kernel_update || return 0
    configure_debian_backports

    if [[ "${DRY_RUN}" == "1" ]]; then
        if backports_configured "${suite}"; then
            info "已检测到启用的 ${suite} 源，开始执行只读的 APT 事务预演。"
            apt-cache policy "${meta}"
            apt-get -s install -t "${suite}" "${meta}"
        else
            print_command apt-get update
            print_command apt-cache policy "${meta}"
            print_command apt-get -s install -t "${suite}" "${meta}"
            warn "Backports 源尚未真正写入系统；以上命令仅供正式执行时参考。"
        fi
        return 0
    fi

    apt-get update
    if ! apt-cache show "${meta}" >/dev/null 2>&1; then
        die "仓库中找不到软件包：${meta}"
    fi

    backports_version="$(apt_backports_version "${meta}" "${suite}")"
    if [[ -z "${backports_version}" ]]; then
        die "APT 索引中没有检测到 ${meta} 的 ${suite} 版本；请检查源配置和 apt-cache policy 输出。"
    fi
    info "检测到 ${meta} 的 ${suite} 版本：${backports_version}"

    # -t is the authoritative selection mechanism. A normal apt-cache
    # Candidate may still point at stable/security because Backports normally
    # has a lower default pin priority; this simulation verifies that the
    # target release can actually resolve before making changes.
    if ! simulation="$(apt-get -s install -t "${suite}" "${meta}" 2>&1)"; then
        printf '%s\n' "${simulation}" >&2
        die "无法解析 ${suite} 目标发行版的安装事务；已停止。"
    fi
    printf '%s\n' "${simulation}"

    apt-get install -y --install-recommends -t "${suite}" "${meta}"
    apt-mark manual "${meta}" >/dev/null
    update_apt_bootloader
}
apt_upgrade_hwe() {
    local meta
    [[ "${OS_ID}" == "ubuntu" ]] || die "--channel hwe 仅适用于 Ubuntu。"
    meta="$(ubuntu_hwe_tracking_package || true)"
    [[ -n "${meta}" ]] || die "当前 Ubuntu 内核类型不适合自动切换到 HWE；仅自动支持 generic/virtual。"

    check_space_for_kernel_update || return 0

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command apt-get update
        print_command apt-get -s install "${meta}"
        return 0
    fi

    apt-get update
    apt-cache show "${meta}" >/dev/null 2>&1 || die "官方仓库中不存在 HWE 软件包：${meta}"
    apt-get install -y --install-recommends "${meta}"
    apt-mark manual "${meta}" >/dev/null
    update_apt_bootloader
}

elrepo_secure_boot_check() {
    if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        die "Secure Boot 已启用。ELRepo kernel-lt/kernel-ml 未使用 Secure Boot key 签名，拒绝安装和设为默认启动项。请先在固件或云平台中禁用 Secure Boot。"
    fi
}

install_elrepo_release() {
    local major release_url key_url expected_fingerprint tmp_key actual_fingerprint
    require_command dnf
    require_command rpm
    require_command curl

    [[ "${ELREPO_SUPPORTED}" == "1" ]] || die "${OS_NAME} 不在脚本允许的 ELRepo 自动安装范围内。"

    if rpm -q elrepo-release >/dev/null 2>&1; then
        info "ELRepo release 软件包已经安装。"
        return 0
    fi

    major="${OS_VERSION%%.*}"
    [[ "${major}" =~ ^[0-9]+$ ]] || die "无法识别 Enterprise Linux 主版本：${OS_VERSION}"

    # ELRepo 的当前签名密钥是 v2；旧 key 仅用于安装 2025 年 1 月以前发布的包。
    key_url="https://www.elrepo.org/RPM-GPG-KEY-v2-elrepo.org"
    expected_fingerprint="B8A755874DA240C9DAC4E71551600989EAA31D4A"

    release_url="https://www.elrepo.org/elrepo-release-${major}.el${major}.elrepo.noarch.rpm"

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command curl --fail --location "${key_url}"
        echo "[DRY-RUN] 将验证 ELRepo GPG fingerprint：${expected_fingerprint}"
        print_command dnf install -y "${release_url}"
        return 0
    fi

    confirm "需要安装并验证 ELRepo release 软件包，是否继续？" || die "用户取消安装 ELRepo。"

    require_command gpg
    tmp_key="$(mktemp /tmp/elrepo-key.XXXXXX)"
    trap 'rm -f "${tmp_key:-}"' RETURN

    curl --fail --location --proto '=https' --tlsv1.2 \
        --output "${tmp_key}" "${key_url}"

    actual_fingerprint="$(gpg --show-keys --with-colons "${tmp_key}" 2>/dev/null |
        awk -F: '$1 == "fpr" {print toupper($10); exit}')"

    [[ "${actual_fingerprint}" == "${expected_fingerprint}" ]] ||
        die "ELRepo GPG key fingerprint 不匹配。期望 ${expected_fingerprint}，实际 ${actual_fingerprint:-unknown}。"

    rpm --import "${tmp_key}"
    dnf install -y "${release_url}"

    rm -f "${tmp_key}"
    trap - RETURN
}

find_elrepo_kernel_path() {
    local flavor="$1"
    local core_package latest_package path

    core_package="${flavor}-core"
    latest_package="$(rpm -q --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' \
        "${core_package}" 2>/dev/null | sort -V | tail -n 1 || true)"

    if [[ -n "${latest_package}" ]]; then
        path="$(rpm -ql "${latest_package}" 2>/dev/null | grep -E '^/boot/vmlinuz-' | head -n 1 || true)"
        if [[ -n "${path}" ]]; then
            printf '%s\n' "${path}"
            return 0
        fi
    fi

    find /boot -maxdepth 1 -type f -name 'vmlinuz-*elrepo*' -print 2>/dev/null |
        sort -V | tail -n 1
}

rhel_upgrade_official() {
    local tracking
    require_command dnf
    tracking="$(rhel_tracking_package)"
    check_space_for_kernel_update || return 0

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command dnf upgrade --assumeno "${tracking}"
        dnf upgrade --assumeno "${tracking}" || true
        return 0
    fi
    dnf upgrade -y "${tracking}"
}

rhel_upgrade_elrepo() {
    local flavor="$1"
    local kernel_path

    [[ "${flavor}" == "kernel-lt" || "${flavor}" == "kernel-ml" ]] || die "无效 ELRepo 内核类型：${flavor}"

    check_space_for_kernel_update || return 0
    elrepo_secure_boot_check
    install_elrepo_release

    info "检查 ELRepo elrepo-kernel 仓库中的 ${flavor}..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command dnf --disablerepo='*' --enablerepo=elrepo-kernel list available "${flavor}"
        print_command dnf --enablerepo=elrepo-kernel install -y "${flavor}"
        return 0
    fi

    dnf --disablerepo='*' --enablerepo=elrepo-kernel makecache
    dnf --disablerepo='*' --enablerepo=elrepo-kernel list --showduplicates "${flavor}" || true
    dnf --enablerepo=elrepo-kernel install -y "${flavor}"

    kernel_path="$(find_elrepo_kernel_path "${flavor}")"
    if [[ -n "${kernel_path}" ]] && command -v grubby >/dev/null 2>&1; then
        info "把新安装的 ELRepo 内核设为默认启动项：${kernel_path}"
        grubby --set-default "${kernel_path}"
        echo "默认启动内核：$(grubby --default-kernel)"
    else
        warn "未能自动确定 ELRepo 内核路径，请使用 boot 功能检查默认启动项。"
    fi
}

upgrade_kernel() {
    local selected_channel="${CHANNEL:-official}"

    if [[ "${DRY_RUN}" != "1" ]]; then
        confirm "将使用 ${selected_channel} 通道安装或升级内核，是否继续？" || return 0
    fi

    case "${OS_FAMILY}:${selected_channel}" in
        apt:official)      apt_upgrade_official ;;
        apt:backports)     apt_upgrade_backports ;;
        apt:hwe)           apt_upgrade_hwe ;;
        rhel:official)     rhel_upgrade_official ;;
        rhel:elrepo-lt)
            [[ "${ELREPO_SUPPORTED}" == "1" ]] || die "${OS_NAME} 不支持 ELRepo 内核通道。"
            rhel_upgrade_elrepo kernel-lt
            ;;
        rhel:elrepo-ml)
            [[ "${ELREPO_SUPPORTED}" == "1" ]] || die "${OS_NAME} 不支持 ELRepo 内核通道。"
            rhel_upgrade_elrepo kernel-ml
            ;;
        *)
            die "当前系统 ${OS_ID} 不支持内核通道：${selected_channel}"
            ;;
    esac

    echo
    echo "内核安装/更新操作完成。"
    echo "当前仍运行：$(uname -r)"
    echo "新内核需要重启后才会生效。"
    list_kernels
}

clean_kernels_apt() {
    local current_pkg meta backup_packages row pkg
    local -a kernel_rows=()
    local -a installed_packages=()
    local -a protected_packages=()
    local -a packages_to_remove=()
    local -a packages_to_purge=()
    local -a component_packages=()
    local -a orphaned_boot_files=()

    current_pkg="$(apt_current_kernel_package)"
    meta="$(apt_tracking_package)"
    local current_flavor
    current_flavor="$(apt_kernel_flavor)"

    [[ -n "${current_flavor}" ]] || die "无法识别当前 Debian/Ubuntu 内核 flavor，为避免混合清理已停止。"

    ensure_apt_tracking_package

    mapfile -t kernel_rows < <(apt_installed_kernel_rows "${current_flavor}")
    [[ "${#kernel_rows[@]}" -gt 0 ]] || die "没有发现已安装的实际内核包。"

    for row in "${kernel_rows[@]}"; do
        pkg="${row%%$'\t'*}"
        # A tracking/meta package such as linux-image-cloud-amd64 is not an
        # actual versioned kernel and must never enter the cleanup set.
        [[ "${pkg}" =~ ^linux-image-[0-9] ]] || continue
        [[ "${pkg}" == "${meta}" ]] && continue
        installed_packages+=("${pkg}")
    done

    local current_found=0
    for pkg in "${installed_packages[@]}"; do
        if [[ "${pkg}" == "${current_pkg}" ]]; then
            current_found=1
            break
        fi
    done
    [[ "${current_found}" -eq 1 ]] || die "无法确认当前内核包 ${current_pkg}，为避免误删已停止。"

    local latest_index latest_pkg
    latest_index=$((${#kernel_rows[@]} - 1))
    latest_pkg="${kernel_rows[$latest_index]%%$'\t'*}"

    if [[ "${latest_pkg}" != "${current_pkg}" ]]; then
        warn "检测到已安装但尚未启动的新内核：${latest_pkg}"
        warn "当前仍运行：${current_pkg}"
        warn "请先重启进入最新内核，确认正常后再清理。"
        return 0
    fi

    backup_packages=""
    if [[ "${KEEP_OLD_KERNELS}" -gt 0 ]]; then
        local kept=0
        local i
        for ((i=${#kernel_rows[@]}-1; i>=0; i--)); do
            pkg="${kernel_rows[$i]%%$'\t'*}"
            [[ "${pkg}" == "${current_pkg}" ]] && continue
            if [[ "${kept}" -lt "${KEEP_OLD_KERNELS}" ]]; then
                [[ -n "${backup_packages}" ]] && backup_packages+=$'\n'
                backup_packages+="${pkg}"
                kept=$((kept + 1))
            fi
        done
    fi

    for pkg in "${installed_packages[@]}"; do
        [[ "${pkg}" == "${current_pkg}" ]] && continue
        if [[ -n "${backup_packages}" ]] && grep -Fxq "${pkg}" <<< "${backup_packages}"; then
            continue
        fi
        packages_to_remove+=("${pkg}")
    done

    echo "当前内核：${current_pkg}"
    echo "跟踪软件包：${meta:-未知}"
    echo "额外保留旧内核数量：${KEEP_OLD_KERNELS}"

    if [[ -n "${backup_packages}" ]]; then
        echo "保留的回退内核："
        while IFS= read -r pkg; do
            [[ -n "${pkg}" ]] && echo "  ${pkg}"
        done <<< "${backup_packages}"
    fi

    packages_to_purge=("${packages_to_remove[@]}")
    for pkg in "${packages_to_remove[@]}"; do
        mapfile -t component_packages < <(
            apt_kernel_component_packages "${pkg#linux-image-}"
        )
        packages_to_purge+=("${component_packages[@]}")
    done

    if [[ "${#packages_to_purge[@]}" -eq 0 ]]; then
        mapfile -t component_packages < <(
            apt_orphaned_kernel_component_packages "${current_flavor}"
        )
        packages_to_purge=("${component_packages[@]}")
    fi

    if [[ "${#packages_to_purge[@]}" -eq 0 ]]; then
        echo "没有需要删除的旧内核。"

        mapfile -t orphaned_boot_files < <(apt_orphaned_boot_files "${current_flavor}")
        [[ "${#orphaned_boot_files[@]}" -gt 0 ]] || return 0

        echo "将清理未由已安装内核包管理的旧 /boot 文件："
        printf '  %s\n' "${orphaned_boot_files[@]}"

        if [[ "${DRY_RUN}" == "1" ]]; then
            print_command rm -f -- "${orphaned_boot_files[@]}"
            return 0
        fi

        confirm "确认删除以上残留启动文件并刷新 GRUB？" || {
            echo "操作已取消。"
            return 0
        }

        rm -f -- "${orphaned_boot_files[@]}"
        update_apt_bootloader
        dpkg --audit
        apt-get check
        return 0
    fi

    echo "将删除："
    printf '  %s\n' "${packages_to_purge[@]}"

    if [[ "${DRY_RUN}" == "1" ]]; then
        print_command apt-get -s purge "${packages_to_purge[@]}"
        apt-get -s purge "${packages_to_purge[@]}" || true
        if [[ "${AUTOREMOVE}" == "1" ]]; then
            print_command apt-get -s autoremove --purge
            apt-get -s autoremove --purge || true
        fi
        return 0
    fi

    confirm "确认删除以上旧内核？" || {
        echo "操作已取消。"
        return 0
    }

    protected_packages+=("${current_pkg}")
    [[ -n "${meta}" ]] && protected_packages+=("${meta}")
    if [[ -n "${backup_packages}" ]]; then
        while IFS= read -r pkg; do
            [[ -n "${pkg}" ]] && protected_packages+=("${pkg}")
        done <<< "${backup_packages}"
    fi

    apt-mark manual "${protected_packages[@]}" >/dev/null
    apt-get purge -y "${packages_to_purge[@]}"

    if [[ "${AUTOREMOVE}" == "1" ]]; then
        echo "以下是全局 autoremove 的模拟事务："
        apt-get -s autoremove --purge || true
        if confirm "是否执行上述全局 autoremove？"; then
            apt-get autoremove --purge -y
        else
            echo "已跳过全局 autoremove。"
        fi
    fi

    mapfile -t orphaned_boot_files < <(apt_orphaned_boot_files "${current_flavor}")
    if [[ "${#orphaned_boot_files[@]}" -gt 0 ]]; then
        echo "清理未由已安装内核包管理的旧 /boot 文件："
        printf '  %s\n' "${orphaned_boot_files[@]}"
        rm -f -- "${orphaned_boot_files[@]}"
    fi

    apt-get clean
    update-initramfs -u -k all
    update_apt_bootloader
    dpkg --audit
    apt-get check
    df -h /
}

rhel_installed_kernel_rows() {
    rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}.%{ARCH}\t%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' |
        awk -F '\t' '
            $1 ~ /^(kernel|kernel-core|kernel-modules|kernel-modules-core|kernel-modules-extra|kernel-uki-virt|kernel-lt|kernel-lt-core|kernel-lt-modules|kernel-lt-modules-core|kernel-lt-modules-extra|kernel-ml|kernel-ml-core|kernel-ml-modules|kernel-ml-modules-core|kernel-ml-modules-extra|kernel-uek|kernel-uek-core|kernel-uek-modules|kernel-uek-modules-core|kernel-uek-modules-extra|kernel-uek-firmware)$/
            {
                print $1 "\t" $2 "\t" $3
            }
        ' |
        sort -t $'\t' -k2,2V -k1,1
}

clean_kernels_rhel() {
    local current_release backup_releases row package_name release nevra
    local -a kernel_rows=()
    local -a installed_releases=()
    local -a packages_to_remove=()

    require_command dnf
    require_command rpm

    current_release="$(uname -r)"
    mapfile -t kernel_rows < <(rhel_installed_kernel_rows)
    [[ "${#kernel_rows[@]}" -gt 0 ]] || die "没有发现已安装的 RHEL 内核软件包。"

    mapfile -t installed_releases < <(
        printf '%s\n' "${kernel_rows[@]}" |
            cut -f2 |
            sort -Vu
    )

    local current_found=0
    for release in "${installed_releases[@]}"; do
        if [[ "${release}" == "${current_release}" ]]; then
            current_found=1
            break
        fi
    done
    [[ "${current_found}" -eq 1 ]] || die "无法在 RPM 数据库中确认当前内核 ${current_release}，停止清理。"

    local latest_index latest_release
    latest_index=$((${#installed_releases[@]} - 1))
    latest_release="${installed_releases[$latest_index]}"

    if [[ "${latest_release}" != "${current_release}" ]]; then
        warn "检测到已安装但尚未启动的更新内核：${latest_release}"
        warn "当前仍运行：${current_release}"
        warn "请先重启进入最新内核，确认正常后再清理。"
        return 0
    fi

    backup_releases=""
    if [[ "${KEEP_OLD_KERNELS}" -gt 0 ]]; then
        local kept=0
        local i
        for ((i=${#installed_releases[@]}-1; i>=0; i--)); do
            release="${installed_releases[$i]}"
            [[ "${release}" == "${current_release}" ]] && continue

            if [[ "${kept}" -lt "${KEEP_OLD_KERNELS}" ]]; then
                [[ -n "${backup_releases}" ]] && backup_releases+=$'\n'
                backup_releases+="${release}"
                kept=$((kept + 1))
            fi
        done
    fi

    for row in "${kernel_rows[@]}"; do
        package_name="${row%%$'\t'*}"
        row="${row#*$'\t'}"
        release="${row%%$'\t'*}"
        nevra="${row#*$'\t'}"

        [[ "${release}" == "${current_release}" ]] && continue
        if [[ -n "${backup_releases}" ]] && grep -Fxq "${release}" <<< "${backup_releases}"; then
            continue
        fi
        packages_to_remove+=("${nevra}")
    done

    echo "当前运行内核：${current_release}"
    echo "额外保留旧内核数量：${KEEP_OLD_KERNELS}"

    if [[ -n "${backup_releases}" ]]; then
        echo "保留的回退内核 release："
        while IFS= read -r release; do
            [[ -n "${release}" ]] && echo "  ${release}"
        done <<< "${backup_releases}"
    fi

    if [[ "${#packages_to_remove[@]}" -eq 0 ]]; then
        echo "没有需要删除的旧内核。"
        return 0
    fi

    echo "将通过 DNF 删除以下精确软件包："
    printf '  %s\n' "${packages_to_remove[@]}"
    echo "当前内核 release ${current_release} 不会被删除。"

    print_command dnf remove --assumeno \
        --setopt=clean_requirements_on_remove=False \
        "${packages_to_remove[@]}"
    dnf remove --assumeno \
        --setopt=clean_requirements_on_remove=False \
        "${packages_to_remove[@]}" || true

    if [[ "${DRY_RUN}" == "1" ]]; then
        return 0
    fi

    confirm "确认删除以上非运行内核软件包？" || {
        echo "操作已取消。"
        return 0
    }

    dnf remove -y \
        --setopt=clean_requirements_on_remove=False \
        "${packages_to_remove[@]}"

    echo "RHEL 内核清理完成。"
    list_kernels_rhel
}

clean_kernels() {
    if [[ "${OS_FAMILY}" == "apt" ]]; then
        clean_kernels_apt
    else
        clean_kernels_rhel
    fi
}

show_boot_default() {
    echo
    if [[ "${OS_FAMILY}" == "rhel" ]]; then
        require_command grubby
        echo "当前默认启动内核："
        grubby --default-kernel
        echo
        grubby --info=ALL | grep -E '^(index=|kernel=|title=)' || true
        return 0
    fi

    echo "/etc/default/grub 中的默认设置："
    grep -E '^(GRUB_DEFAULT|GRUB_SAVEDEFAULT)=' /etc/default/grub 2>/dev/null || true

    if command -v grub-editenv >/dev/null 2>&1; then
        echo
        echo "GRUB 环境变量："
        grub-editenv list 2>/dev/null || true
    fi

    echo
    echo "GRUB 菜单中的 Linux 内核条目："
    grep -E "^[[:space:]]*menuentry '.*Linux" /boot/grub/grub.cfg 2>/dev/null |
        sed -E "s/^[[:space:]]*menuentry '([^']+)'.*/  \1/" || true
}

repair_tracking_package() {
    if [[ "${DRY_RUN}" != "1" ]]; then
        confirm "将修复并标记内核跟踪软件包，是否继续？" || return 0
    fi

    if [[ "${OS_FAMILY}" == "apt" ]]; then
        if [[ "${DRY_RUN}" == "1" ]]; then
            ensure_apt_tracking_package
            return 0
        fi
        apt-get update
        ensure_apt_tracking_package
        dpkg -l 'linux-image*' 'linux-generic*' 'linux-virtual*' 2>/dev/null |
            awk '$1 == "ii" {print}' || true
        return 0
    fi

    local tracking
    tracking="$(rhel_tracking_package)"
    echo "当前内核跟踪包：${tracking}"

    if [[ "${DRY_RUN}" == "1" ]]; then
        if [[ "${tracking}" == kernel-lt || "${tracking}" == kernel-ml ]]; then
            print_command dnf --enablerepo=elrepo-kernel install -y "${tracking}"
        else
            print_command dnf install -y kernel
        fi
        return 0
    fi

    if [[ "${tracking}" == kernel-lt || "${tracking}" == kernel-ml ]]; then
        install_elrepo_release
        dnf --enablerepo=elrepo-kernel install -y "${tracking}"
    else
        dnf install -y kernel
    fi
}

clean_package_cache() {
    if [[ "${DRY_RUN}" != "1" ]]; then
        confirm "将清理软件包缓存，是否继续？" || return 0
    fi

    if [[ "${OS_FAMILY}" == "apt" ]]; then
        if [[ "${DRY_RUN}" == "1" ]]; then
            print_command apt-get clean
            print_command apt-get autoclean
        else
            apt-get clean
            apt-get autoclean
        fi
    else
        require_command dnf
        if [[ "${DRY_RUN}" == "1" ]]; then
            print_command dnf clean packages
        else
            dnf clean packages
        fi
    fi
    df -h /
}

run_diagnostics() {
    echo "===== 基本信息 ====="
    uname -a
    cat /etc/os-release

    echo
    echo "===== 磁盘 ====="
    df -h
    lsblk -f 2>/dev/null || true

    echo
    echo "===== 当前和已安装内核 ====="
    list_kernels

    echo
    echo "===== 引导配置 ====="
    show_boot_default

    echo
    echo "===== 软件包检查 ====="
    if [[ "${OS_FAMILY}" == "apt" ]]; then
        dpkg --audit
        apt-get check
    else
        dnf check || true
        rpm -Va --nofiles --nodigest 2>/dev/null || true
    fi
}

select_upgrade_channel_interactive() {
    local choice

    echo
    if [[ "${OS_FAMILY}" == "rhel" ]]; then
        if [[ "${ELREPO_SUPPORTED}" == "1" ]]; then
            cat <<EOF
可用内核通道：
  1. official   - 当前发行版官方稳定内核
  2. elrepo-lt  - ELRepo Long Term Support 内核
  3. elrepo-ml  - ELRepo Mainline Stable 内核
EOF
            read -r -p "请选择 [1-3]: " choice
            case "${choice}" in
                1) CHANNEL="official" ;;
                2) CHANNEL="elrepo-lt" ;;
                3) CHANNEL="elrepo-ml" ;;
                *) warn "无效选择。"; return 1 ;;
            esac
        else
            echo "当前发行版仅支持 official 通道；ELRepo 通道已禁用。"
            CHANNEL="official"
        fi
        return 0
    fi

    if [[ "${OS_ID}" == "debian" ]]; then
        cat <<EOF
可用内核通道：
  1. official   - Debian 当前发行版官方稳定内核
  2. backports  - Debian 官方 Backports 更新内核
EOF
        read -r -p "请选择 [1-2]: " choice
        case "${choice}" in
            1) CHANNEL="official" ;;
            2) CHANNEL="backports" ;;
            *) warn "无效选择。"; return 1 ;;
        esac
        return 0
    fi

    if [[ "${OS_ID}" == "ubuntu" ]]; then
        local hwe_meta
        hwe_meta="$(ubuntu_hwe_tracking_package || true)"
        cat <<EOF
可用内核通道：
  1. official   - 当前 Ubuntu 官方内核跟踪包
EOF
        if [[ -n "${hwe_meta}" ]]; then
            echo "  2. hwe        - Ubuntu 官方 HWE 内核（${hwe_meta}）"
        else
            echo "  2. hwe        - 当前 flavor 不支持自动 HWE，选择后将拒绝执行"
        fi
        read -r -p "请选择 [1-2]: " choice
        case "${choice}" in
            1) CHANNEL="official" ;;
            2) CHANNEL="hwe" ;;
            *) warn "无效选择。"; return 1 ;;
        esac
    fi
}

configure_clean_interactive() {
    local value answer

    read -r -p "额外保留几个旧内核？[默认 ${KEEP_OLD_KERNELS}]: " value
    if [[ -n "${value}" ]]; then
        parse_nonnegative_integer "${value}"
        KEEP_OLD_KERNELS="${value}"
    fi

    read -r -p "是否只预演、不执行删除？[y/N]: " answer
    if [[ "${answer}" == "y" || "${answer}" == "Y" ]]; then
        DRY_RUN="1"
    fi
}

show_menu() {
    clear 2>/dev/null || true
    cat <<EOF

============================================
${PROGRAM_NAME} ${PROGRAM_VERSION}
系统：${OS_NAME}
当前内核：$(uname -r)
============================================
1. 查看系统和当前内核状态
2. 查看已安装内核
3. 选择通道安装/升级内核
4. 安全清理旧内核
5. 查看默认启动内核和 GRUB 条目
6. 修复/保护内核跟踪软件包
7. 清理软件包缓存
8. 运行完整诊断
0. 退出
============================================

EOF
}

menu_loop() {
    local choice
    while true; do
        show_menu
        read -r -p "请选择 [0-8]: " choice

        case "${choice}" in
            1) show_status; pause_screen ;;
            2) list_kernels; pause_screen ;;
            3)
                CHANNEL=""
                select_upgrade_channel_interactive && upgrade_kernel
                pause_screen
                ;;
            4)
                DRY_RUN="0"
                AUTOREMOVE="0"
                configure_clean_interactive
                clean_kernels
                pause_screen
                ;;
            5) show_boot_default; pause_screen ;;
            6) repair_tracking_package; pause_screen ;;
            7) clean_package_cache; pause_screen ;;
            8) run_diagnostics; pause_screen ;;
            0) exit 0 ;;
            *) warn "无效选项：${choice}"; sleep 1 ;;
        esac
    done
}

usage() {
    cat <<EOF
${PROGRAM_NAME} ${PROGRAM_VERSION}

用法：
  $0 [命令] [后缀参数]

命令：
  menu             打开交互式菜单（默认）
  status           查看状态
  list             列出内核
  upgrade          安装/升级内核
  clean            安全清理旧内核
  boot             查看默认启动内核和 GRUB 条目
  repair           修复/保护内核跟踪软件包
  clean-cache      清理软件包缓存
  diagnose         运行完整诊断

通用后缀参数：
  --dry-run                仅预演，不执行修改
  --autoremove             清理旧内核后额外执行全局 autoremove（默认关闭）
  --yes, -y                跳过人工确认
  --keep-old N             清理时额外保留 N 个旧内核
  --keep-old=N             同上
  --channel NAME           选择内核升级通道
  --channel=NAME           同上

内核通道：
  Debian: official, backports
  Ubuntu: official, hwe
  RHEL:   official, elrepo-lt, elrepo-ml

示例：
  $0 clean --keep-old 0 --dry-run
  $0 clean --keep-old=1 --yes
  $0 upgrade --channel official
  $0 upgrade --channel backports --dry-run
  $0 upgrade --channel elrepo-lt
  $0 upgrade --channel elrepo-ml --yes
EOF
}

main() {
    parse_args "$@"
    require_root
    detect_os
    acquire_package_lock

    case "${COMMAND}" in
        menu)        menu_loop ;;
        status)      show_status ;;
        list)        list_kernels ;;
        upgrade)     upgrade_kernel ;;
        clean)       clean_kernels ;;
        boot)        show_boot_default ;;
        repair)      repair_tracking_package ;;
        clean-cache) clean_package_cache ;;
        diagnose)    run_diagnostics ;;
        *)           die "未实现的命令：${COMMAND}" ;;
    esac
}

main "$@"
