#!/bin/bash
# Personal Bootstrap：以 sudo 启动，用户环境归属于发起 sudo 的用户。
set -o pipefail

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
    cat <<'EOF'
Personal Bootstrap — 个人终端初始化

用法：sudo ./bootstrap.sh
      ./bootstrap.sh --help

支持 macOS、Ubuntu、Debian；按 Base → Terminal → Shell → 可选 Git 配置执行。
安装失败会在最后汇总。用户配置安装到发起 sudo 的用户目录。
EOF
}

main() {
    if [ "$#" -gt 0 ]; then
        if [ "$#" -eq 1 ] && [ "$1" = --help ]; then
            usage
            return 0
        fi
        usage >&2
        return 2
    fi

    local file
    for file in common detect_os logger package_manager config_manager; do
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/src/lib/$file.sh" || return 1
    done
    detect_os || return 1
    resolve_target_user || return 1
    init_logger || return 1
    log_info "系统：$OS $OS_VERSION / ${ARCH}；目标用户：$TARGET_USER"

    if ! prepare_package_manager; then
        print_summary
        return 1
    fi
    for file in base terminal shell git; do
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/src/modules/$file.sh" || return 1
    done

    run_base
    run_terminal
    # 模块已经记录未完成项；入口继续执行，最后按汇总决定退出状态。
    run_shell || :
    run_git || :
    print_summary
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
