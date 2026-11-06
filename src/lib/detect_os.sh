#!/bin/bash

detect_os() {
    local system release_file
    system=${1:-$(uname -s)}
    release_file=${2:-/etc/os-release}
    case "$system" in
        Darwin)
            OS=macos
            OS_VERSION=$(sw_vers -productVersion)
            PACKAGE_MANAGER=brew
            ;;
        Linux)
            # os-release 是操作系统提供的标准信息文件。
            # shellcheck source=/dev/null
            source "$release_file" || return 1
            case "$ID" in
                ubuntu | debian) OS=$ID ;;
                *)
                    printf '不支持的 Linux 发行版：%s\n' "$ID" >&2
                    return 1
                    ;;
            esac
            OS_VERSION=$VERSION_ID
            PACKAGE_MANAGER=apt
            ;;
        *)
            printf '不支持的系统：%s\n' "$system" >&2
            return 1
            ;;
    esac
    case "${3:-$(uname -m)}" in
        x86_64 | amd64) ARCH=x86_64 ;;
        arm64 | aarch64) ARCH=arm64 ;;
        *)
            printf '%s\n' '只支持 x86_64 和 ARM64。' >&2
            return 1
            ;;
    esac
}
