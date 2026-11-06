#!/bin/bash

prepare_package_manager() {
    if [ "$PACKAGE_MANAGER" = brew ]; then
        # shellcheck source=../platforms/macos.sh
        source "$PROJECT_ROOT/src/platforms/macos.sh"
    else
        # shellcheck source=../platforms/apt.sh
        source "$PROJECT_ROOT/src/platforms/apt.sh"
    fi
    platform_prepare
}

package_name() {
    case "$1:$PACKAGE_MANAGER" in
        bw:brew | bw:apt) printf '%s\n' bitwarden-cli ;;
        node:apt) printf '%s\n' nodejs ;;
        npm:brew) printf '%s\n' node ;;
        fd:apt) printf '%s\n' fd-find ;;
        ssh:apt) printf '%s\n' openssh-client ;;
        ssh:brew) printf '%s\n' openssh ;;
        *) printf '%s\n' "$1" ;;
    esac
}

tool_command() {
    case "$1" in
        ripgrep) user_command rg ;;
        bat) user_command bat || user_command batcat ;;
        fd) user_command fd || user_command fdfind ;;
        *) user_command "$1" ;;
    esac
}

tool_available() {
    if [ "$1" = ca-certificates ]; then
        if [ "$OS" = macos ]; then
            return 0 # macOS 使用系统证书。
        fi
        [ "$(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null)" = 'install ok installed' ]
    else
        tool_command "$1" >/dev/null 2>&1
    fi
}

ensure_package() {
    local tool package
    tool=$1
    if tool_available "$tool"; then
        record_existing "$tool"
        return 0
    fi
    package=$(package_name "$tool")
    if ! platform_package_available "$package"; then
        record_failure "$tool" "当前平台的安装渠道未提供 $package"
        return 1
    fi
    log_info "安装 ${tool}（${package}）"
    if run_logged platform_install "$package"; then
        if tool_available "$tool"; then
            record_done "$tool"
            return 0
        fi
        record_failure "$tool" '安装命令结束，但所需工具仍不可用'
    else
        record_failure "$tool" '安装失败，详细输出见日志'
    fi
    return 1
}
