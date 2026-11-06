#!/bin/bash
# shellcheck disable=SC2016,SC2329
# 测试写入的 Shell 片段在子进程中展开；辅助函数由 Bats 调用。
set -o pipefail

setup_project() {
    PROJECT_ROOT=$(cd "$BATS_TEST_DIRNAME/.." && pwd)
    TARGET_USER=bootstrap-test
    TARGET_HOME="$BATS_TEST_TMPDIR/user home"
    CONFIG_DIR="$TARGET_HOME/.config/personal-bootstrap"
    STATE_DIR="$TARGET_HOME/.local/state/personal-bootstrap"
    USER_PATH=$PATH
    USER_ENV=()
    OS=ubuntu
    OS_VERSION=24.04
    ARCH=arm64
    PACKAGE_MANAGER=apt
    unset ZSH ZSH_CUSTOM ZDOTDIR
    mkdir -p "$TARGET_HOME"
    local file
    for file in common detect_os logger package_manager config_manager; do
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/src/lib/$file.sh"
    done
    for file in base terminal shell git; do
        # shellcheck source=/dev/null
        source "$PROJECT_ROOT/src/modules/$file.sh"
    done
    # 隔离实际用户目录；测试不会调用系统 sudo 或安装软件。
    as_user() {
        env HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" XDG_STATE_HOME="$TARGET_HOME/.local/state" "$@"
    }
    init_logger
}

create_omz_fixture() {
    OMZ_DIR="$TARGET_HOME/.oh-my-zsh"
    OMZ_CUSTOM_DIR="$OMZ_DIR/custom"
    mkdir -p "$OMZ_DIR/plugins/git" "$OMZ_DIR/plugins/fzf" \
        "$OMZ_CUSTOM_DIR/plugins/zsh-autosuggestions" "$OMZ_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
    cat >"$OMZ_DIR/oh-my-zsh.sh" <<'EOF'
typeset -gi omz_loads=$(( ${omz_loads:-0} + 1 ))
omz() { :; }
for plugin in $plugins; do
    [[ ! -f "$ZSH/plugins/$plugin/$plugin.plugin.zsh" ]] || source "$ZSH/plugins/$plugin/$plugin.plugin.zsh"
done
EOF
    printf 'typeset -gi git_loads=$(( ${git_loads:-0} + 1 ))\n' >"$OMZ_DIR/plugins/git/git.plugin.zsh"
    printf 'typeset -gi fzf_loads=$(( ${fzf_loads:-0} + 1 ))\n' >"$OMZ_DIR/plugins/fzf/fzf.plugin.zsh"
    printf '_zsh_autosuggest_start() { :; }\n' >"$OMZ_CUSTOM_DIR/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
    printf '_zsh_highlight() { :; }\n' >"$OMZ_CUSTOM_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
}
