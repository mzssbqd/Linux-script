#!/bin/bash

platform_prepare() {
    if run_logged apt-get update; then
        record_done 'APT 软件索引'
        return 0
    fi
    record_failure 'APT 软件索引' '更新失败，初始化停止'
    return 1
}

platform_package_available() {
    if [ "$1" = bitwarden-cli ]; then
        return 0 # 使用官方 npm 包，支持 x86_64 和 ARM64。
    fi
    local candidate
    candidate=$(LC_ALL=C apt-cache policy "$1" | awk '/Candidate:/ {print $2; exit}')
    [ -n "$candidate" ] && [ "$candidate" != '(none)' ]
}

platform_install() {
    if [ "$1" = bitwarden-cli ]; then
        as_user npm install --global --prefix "$TARGET_HOME/.local" --engine-strict @bitwarden/cli
        return
    fi
    apt-get install -y "$1"
}
