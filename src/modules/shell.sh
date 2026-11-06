#!/bin/bash

install_omz() {
    local installer
    if [ -f "$OMZ_DIR/oh-my-zsh.sh" ]; then
        record_existing 'Oh My Zsh'
        return 0
    fi
    if ! tool_available git || ! tool_available curl; then
        record_failure 'Oh My Zsh' '缺少 Git 或 curl，跳过安装'
        return 1
    fi
    if ! installer=$(as_user mktemp "$CONFIG_DIR/.omz-install.XXXXXX"); then
        record_failure 'Oh My Zsh' '无法创建安装程序临时文件'
        return 1
    fi
    if ! run_logged as_user curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer"; then
        record_failure 'Oh My Zsh' '下载安装程序失败'
        as_user rm -f "$installer"
        return 1
    fi
    # 使用临时 ZDOTDIR 接收安装器模板；真实 .zshrc 仅由配置模块接入。
    local installer_dotdir
    if ! installer_dotdir=$(as_user mktemp -d "$CONFIG_DIR/.omz-dotdir.XXXXXX"); then
        as_user rm -f "$installer"
        record_failure 'Oh My Zsh' '无法创建安装程序临时目录'
        return 1
    fi
    if run_logged as_user env ZSH="$OMZ_DIR" ZDOTDIR="$installer_dotdir" CHSH=no RUNZSH=no KEEP_ZSHRC=yes \
        sh "$installer" --unattended --keep-zshrc; then
        as_user rm -rf "$installer" "$installer_dotdir"
        record_done 'Oh My Zsh'
        return 0
    fi
    as_user rm -rf "$installer" "$installer_dotdir"
    record_failure 'Oh My Zsh' '官方安装程序执行失败'
    return 1
}

install_plugin() {
    local name repository directory
    name=$1
    repository=$2
    directory="$OMZ_CUSTOM_DIR/plugins/$name"
    if [ -f "$directory/$name.zsh" ]; then
        record_existing "$name"
        return 0
    fi
    if ! tool_available git; then
        record_failure "$name" '缺少 Git，跳过下载'
        return 1
    fi
    if run_logged as_user git clone --depth=1 "$repository" "$directory"; then
        record_done "$name"
        return 0
    fi
    record_failure "$name" '下载失败'
    return 1
}

change_default_shell() {
    local current_shell
    if [ "$OS" = macos ]; then
        current_shell=$(dscl . -read "/Users/$TARGET_USER" UserShell | sed 's/^UserShell: //')
    else
        current_shell=$(getent passwd "$TARGET_USER" | cut -d: -f7)
    fi
    if [ "$current_shell" = "$ZSH_BIN" ]; then
        record_existing '默认 Shell：Zsh'
        return 0
    fi
    if ! confirm "是否将 $TARGET_USER 的默认 Shell 设置为 $ZSH_BIN？"; then
        log_info '保留原默认 Shell；可以手动运行 zsh。'
        return 0
    fi
    if run_logged chsh -s "$ZSH_BIN" "$TARGET_USER"; then
        record_done '默认 Shell：Zsh'
    else
        record_failure '默认 Shell' '切换失败，可自行设置'
    fi
}

run_shell() {
    log_info '开始 Shell：Zsh 与插件'
    ensure_package zsh || return 1
    if [ "$CONFIG_READY" != true ]; then
        record_failure 'Zsh 配置' '个人配置目录未准备好，跳过'
        return 1
    fi
    ZSH_BIN=$(tool_command zsh)
    # 只读取 .zshenv 确定 ZDOTDIR，不执行原 .zshrc。
    local dotdir
    # shellcheck disable=SC2016 # 路径由目标用户的 Zsh 展开。
    if ! dotdir=$(as_user "$ZSH_BIN" -c 'printf "%s" "${ZDOTDIR:-$HOME}"'); then
        record_failure 'Zsh 配置' '读取 ZDOTDIR 失败'
        return 1
    fi
    OMZ_DIR=${ZSH:-$TARGET_HOME/.oh-my-zsh}
    OMZ_CUSTOM_DIR=${ZSH_CUSTOM:-$OMZ_DIR/custom}
    install_omz || return 1
    local plugin
    for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        install_plugin "$plugin" "https://github.com/zsh-users/$plugin.git" || continue
    done
    if run_logged deploy_zsh_files && run_logged update_zshrc "$dotdir/.zshrc"; then
        record_done 'Zsh 配置'
        change_default_shell
    else
        record_failure 'Zsh 配置' '同步模板、备份或接入配置失败'
    fi
}
