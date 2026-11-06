#!/bin/bash

resolve_target_user() {
    if [ "$(id -u)" -ne 0 ] || [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = root ]; then
        printf '%s\n' '请由普通用户运行 sudo ./bootstrap.sh。' >&2
        return 1
    fi
    TARGET_USER=$SUDO_USER
    if [ "$OS" = macos ]; then
        TARGET_HOME=$(dscl . -read "/Users/$TARGET_USER" NFSHomeDirectory | sed 's/^NFSHomeDirectory: //')
    else
        TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    fi
    if [ -z "$TARGET_HOME" ] || [ ! -d "$TARGET_HOME" ]; then
        printf '%s\n' "无法读取 $TARGET_USER 的主目录。" >&2
        return 1
    fi
    USER_PATH="$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$TARGET_HOME/.config}/personal-bootstrap"
    STATE_DIR="${XDG_STATE_HOME:-$TARGET_HOME/.local/state}/personal-bootstrap"
    USER_ENV=()
    local name
    for name in XDG_CONFIG_HOME XDG_STATE_HOME ZDOTDIR ZSH ZSH_CUSTOM; do
        [ -z "${!name}" ] || USER_ENV+=("$name=${!name}")
    done
}

as_user() {
    sudo -H -u "$TARGET_USER" env PATH="$USER_PATH" "${USER_ENV[@]}" "$@"
}

user_command() {
    # shellcheck disable=SC2016 # 参数由目标用户的 sh 展开。
    as_user /bin/sh -c 'command -v "$1"' sh "$1"
}

confirm() {
    local answer
    printf '%s [y/N] ' "$1" >&2
    IFS= read -r answer || return 1
    case "$answer" in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}
