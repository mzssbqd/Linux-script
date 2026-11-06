#!/usr/bin/env bats
load helpers

setup() {
    setup_project
    create_omz_fixture
    export PB_TEST_OMZ_SOURCE="$BATS_TEST_TMPDIR/omz-source"
    export PB_TEST_CALLS="$BATS_TEST_TMPDIR/calls"
    mv "$OMZ_DIR" "$PB_TEST_OMZ_SOURCE"
    tool_available() { [ -f "$BATS_TEST_TMPDIR/installed-$1" ]; }
    platform_package_available() { return 0; }
    platform_install() {
        printf 'package:%s\n' "$1" >>"$PB_TEST_CALLS"
        local name=$1
        case "$name" in
            fd-find) name=fd ;;
            openssh-client) name=ssh ;;
            bitwarden-cli) name=bw ;;
            nodejs) name=node ;;
        esac
        touch "$BATS_TEST_TMPDIR/installed-$name"
    }
    as_user() {
        if [ "$1" = curl ]; then
            cp "$PROJECT_ROOT/tests/fixtures/omz-install.sh" "${@: -1}"
        elif [ "$1:$2" = git:clone ]; then
            local destination="${@: -1}"
            local name=${destination##*/}
            printf 'plugin:%s\n' "$name" >>"$PB_TEST_CALLS"
            mkdir -p "$(dirname "$destination")"
            cp -R "$PB_TEST_OMZ_SOURCE/custom/plugins/$name" "$destination"
        else
            env HOME="$TARGET_HOME" XDG_CONFIG_HOME="$TARGET_HOME/.config" XDG_STATE_HOME="$TARGET_HOME/.local/state" "$@"
        fi
    }
    getent() { printf 'test:x:1000:1000::%s:/bin/bash\n' "$TARGET_HOME"; }
    confirm() { return 1; }
}

@test "initialize_then_rerun_without_reinstalling" {
    printf 'export ORIGINAL_SETTING=kept\n' >"$TARGET_HOME/.zshrc"
    run_base
    run_terminal
    run_shell
    run_git
    print_summary
    [ "${#INCOMPLETE[@]}" -eq 0 ]
    [ "$(grep -c '^package:' "$PB_TEST_CALLS")" -eq 20 ]
    grep -q '^package:bitwarden-cli$' "$PB_TEST_CALLS"
    grep -q '^package:nodejs$' "$PB_TEST_CALLS"
    grep -q '^package:npm$' "$PB_TEST_CALLS"
    [ "$(grep -c '^omz-install$' "$PB_TEST_CALLS")" -eq 1 ]
    [ "$(grep -c '^plugin:' "$PB_TEST_CALLS")" -eq 2 ]
    cp "$PB_TEST_CALLS" "$BATS_TEST_TMPDIR/first-calls"
    cp "$TARGET_HOME/.zshrc" "$BATS_TEST_TMPDIR/first-zshrc"
    run_base
    run_terminal
    run_shell
    run_git
    print_summary
    cmp "$PB_TEST_CALLS" "$BATS_TEST_TMPDIR/first-calls"
    cmp "$TARGET_HOME/.zshrc" "$BATS_TEST_TMPDIR/first-zshrc"
    [ "$(find "$CONFIG_DIR/backups" -type f | wc -l | tr -d ' ')" -eq 1 ]
    run as_user zsh -fic 'source "$HOME/.zshrc"; print -r -- "$ORIGINAL_SETTING:$omz_loads:${+functions[_zsh_highlight]}"'
    [ "$status" -eq 0 ]
    [[ "$output" == *'kept:1:1'* ]]
}

@test "missing_git_skips_framework_but_keeps_terminal_tools" {
    platform_package_available() { [ "$1" != git ]; }
    run_base
    run_terminal
    run_shell || true
    [ -f "$BATS_TEST_TMPDIR/installed-btop" ]
    [ ! -e "$OMZ_DIR/oh-my-zsh.sh" ]
    [ ! -e "$TARGET_HOME/.zshrc" ]
    [ "${#INCOMPLETE[@]}" -eq 2 ]
}

@test "respect_zdotdir_from_user_zshenv" {
    mkdir -p "$TARGET_HOME/custom zsh"
    printf 'export ZDOTDIR="$HOME/custom zsh"\n' >"$TARGET_HOME/.zshenv"
    printf 'export CUSTOM_ZSH=yes\n' >"$TARGET_HOME/custom zsh/.zshrc"
    printf 'do-not-touch\n' >"$TARGET_HOME/.zshrc"
    run_base
    run_shell
    [ "$(cat "$TARGET_HOME/.zshrc")" = do-not-touch ]
    grep -q '^# BEGIN Personal Bootstrap$' "$TARGET_HOME/custom zsh/.zshrc"
    run as_user zsh -ic 'print -r -- "$CUSTOM_ZSH:$omz_loads"'
    [ "$status" -eq 0 ]
    [[ "$output" == *'yes:1'* ]]
}

@test "continue_after_plugin_failure" {
    run_base
    touch "$BATS_TEST_TMPDIR/installed-zsh"
    install_plugin() {
        if [ "$1" = zsh-autosuggestions ]; then
            record_failure "$1" '测试下载失败'
            return 1
        fi
        mkdir -p "$OMZ_CUSTOM_DIR/plugins/$1"
        cp "$PB_TEST_OMZ_SOURCE/custom/plugins/$1/$1.zsh" "$OMZ_CUSTOM_DIR/plugins/$1/"
    }
    run_shell
    [ -f "$OMZ_CUSTOM_DIR/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]
    grep -q '^# BEGIN Personal Bootstrap$' "$TARGET_HOME/.zshrc"
    [ "${#INCOMPLETE[@]}" -eq 1 ]
}
