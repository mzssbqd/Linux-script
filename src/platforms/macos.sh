#!/bin/bash

find_brew() {
    local candidate
    case "$ARCH" in
        arm64) candidate=/opt/homebrew/bin/brew ;;
        x86_64) candidate=/usr/local/bin/brew ;;
    esac
    if [ -x "$candidate" ]; then
        BREW_BIN=$candidate
        return 0
    fi
    BREW_BIN=$(user_command brew)
}

platform_prepare() {
    local installer prefix
    if ! find_brew; then
        if ! confirm '未找到 Homebrew，是否使用官方安装程序安装？'; then
            record_failure Homebrew '未同意安装，初始化停止'
            return 1
        fi
        if ! installer=$(as_user mktemp -t personal-bootstrap); then
            record_failure Homebrew '无法创建安装程序临时文件'
            return 1
        fi
        if ! run_logged as_user curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
            record_failure Homebrew '下载安装程序失败'
            as_user rm -f "$installer"
            return 1
        fi
        if ! run_logged as_user /bin/bash "$installer"; then
            record_failure Homebrew '官方安装程序执行失败'
            as_user rm -f "$installer"
            return 1
        fi
        as_user rm -f "$installer"
        if ! find_brew; then
            record_failure Homebrew '安装后仍未找到 brew'
            return 1
        fi
        record_done Homebrew
    else
        record_existing Homebrew
    fi
    if ! prefix=$(as_user "$BREW_BIN" --prefix); then
        record_failure Homebrew '无法读取安装路径'
        return 1
    fi
    USER_PATH="$prefix/bin:$prefix/sbin:$USER_PATH"
}

platform_package_available() {
    as_user "$BREW_BIN" info --formula "$1" >>"$LOG_FILE" 2>&1
}

platform_install() {
    as_user "$BREW_BIN" install --formula "$1"
}
