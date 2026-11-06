#!/usr/bin/env bats
load helpers

setup() {
    setup_project
    prepare_config
}

@test "backup_original_zshrc_and_keep_reruns_unchanged" {
    local rc="$TARGET_HOME/.zshrc"
    printf 'export MY_SETTING=hello\nalias mine="echo custom"\n' >"$rc"
    cp "$rc" "$BATS_TEST_TMPDIR/original"
    update_zshrc "$rc"
    cmp "$BATS_TEST_TMPDIR/original" "$CONFIG_DIR"/backups/zshrc-*
    cp "$rc" "$BATS_TEST_TMPDIR/first"
    update_zshrc "$rc"
    cmp "$rc" "$BATS_TEST_TMPDIR/first"
    [ "$(grep -c '^# BEGIN Personal Bootstrap$' "$rc")" -eq 1 ]
    [ "$(find "$CONFIG_DIR/backups" -type f | wc -l | tr -d ' ')" -eq 1 ]
}

@test "create_new_zshrc_without_backup" {
    update_zshrc "$TARGET_HOME/.zshrc"
    [ -s "$TARGET_HOME/.zshrc" ]
    [ -z "$(find "$CONFIG_DIR/backups" -type f)" ]
    run zsh -n "$TARGET_HOME/.zshrc"
    [ "$status" -eq 0 ]
}

@test "support_spaces_and_preserve_symlinks" {
    create_omz_fixture
    deploy_zsh_files
    mkdir -p "$TARGET_HOME/dotfiles"
    printf 'export USER_CONFIG_KEPT=yes\n' >"$TARGET_HOME/dotfiles/zshrc"
    ln -s "$TARGET_HOME/dotfiles/zshrc" "$TARGET_HOME/.zshrc"
    update_zshrc "$TARGET_HOME/.zshrc"
    [ -L "$TARGET_HOME/.zshrc" ]
    run as_user zsh -fic 'source "$HOME/.zshrc"; print -r -- "$USER_CONFIG_KEPT:$omz_loads"'
    [ "$status" -eq 0 ]
    [[ "$output" == *'yes:1'* ]]
}

@test "preserve_preferences_and_read_literal_values" {
    printf 'CONFIGURE_GIT=true\nGIT_USER_NAME=$(touch /should-not-exist)\nGIT_USER_EMAIL=alice@example.test\n' >"$CONFIG_DIR/preferences.conf"
    prepare_config
    load_preferences
    [ "$CONFIGURE_GIT" = true ]
    [ "$GIT_USER_NAME" = '$(touch /should-not-exist)' ]
}

@test "configure_git_only_when_enabled" {
    CONFIG_READY=true
    printf 'CONFIGURE_GIT=false\nGIT_USER_NAME=\nGIT_USER_EMAIL=\n' >"$CONFIG_DIR/preferences.conf"
    as_user git config --global core.editor vim
    run_git
    run as_user git config --global user.name
    [ "$status" -ne 0 ]
    printf 'CONFIGURE_GIT=true\nGIT_USER_NAME=Alice Example\nGIT_USER_EMAIL=alice@example.test\n' >"$CONFIG_DIR/preferences.conf"
    run_git
    [ "$(as_user git config --global user.name)" = 'Alice Example' ]
    [ "$(as_user git config --global core.editor)" = vim ]
}

@test "reject_incomplete_git_identity" {
    CONFIG_READY=true
    printf 'CONFIGURE_GIT=true\nGIT_USER_NAME=Alice\nGIT_USER_EMAIL=\n' >"$CONFIG_DIR/preferences.conf"
    run_git || true
    [ "${#INCOMPLETE[@]}" -eq 1 ]
    run as_user git config --global user.name
    [ "$status" -ne 0 ]
}

@test "load_existing_framework_once_and_keep_theme" {
    create_omz_fixture
    deploy_zsh_files
    cat >"$TARGET_HOME/.zshrc" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
plugins=(git)
ZSH_THEME=my-theme
source "$ZSH/oh-my-zsh.sh"
EOF
    update_zshrc "$TARGET_HOME/.zshrc"
    run as_user zsh -fic 'source "$HOME/.zshrc"; source "$HOME/.config/personal-bootstrap/zsh/init.zsh"; print -r -- "$omz_loads:$git_loads:$ZSH_THEME:${+functions[_zsh_highlight]}"'
    [ "$status" -eq 0 ]
    [[ "$output" == *'1:1:my-theme:1'* ]]
}

@test "preserve_existing_command_aliases" {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/sh\nexit 0\n' >"$BATS_TEST_TMPDIR/bin/fdfind"
    chmod +x "$BATS_TEST_TMPDIR/bin/fdfind"
    run zsh -fic 'path=("$1" /usr/bin /bin); source "$2"; print -r -- $aliases[fd]; alias fd="echo mine"; source "$2"; print -r -- $aliases[fd]' zsh "$BATS_TEST_TMPDIR/bin" "$PROJECT_ROOT/config/zsh/aliases.zsh"
    [ "$status" -eq 0 ]
    [ "$output" = $'fdfind\necho mine' ]
}

@test "change_login_shell_only_with_consent_and_for_target_user" {
    ZSH_BIN=/bin/zsh
    getent() { printf 'test:x:1000:1000::%s:/bin/bash\n' "$TARGET_HOME"; }
    chsh() { printf '%s\n' "$*" >"$BATS_TEST_TMPDIR/chsh-call"; }
    confirm() { return 1; }
    change_default_shell
    [ ! -e "$BATS_TEST_TMPDIR/chsh-call" ]
    confirm() { return 0; }
    change_default_shell
    [ "$(cat "$BATS_TEST_TMPDIR/chsh-call")" = '-s /bin/zsh bootstrap-test' ]
}

@test "new_zsh_can_find_cli_installed_in_user_local_bin" {
    create_omz_fixture
    deploy_zsh_files
    mkdir -p "$TARGET_HOME/.local/bin"
    printf '#!/bin/sh\nprintf "test-bw\\n"\n' >"$TARGET_HOME/.local/bin/bw"
    chmod +x "$TARGET_HOME/.local/bin/bw"
    run as_user zsh -fic 'source "$HOME/.config/personal-bootstrap/zsh/init.zsh"; bw --version'
    [ "$status" -eq 0 ]
    [ "$output" = test-bw ]
}
