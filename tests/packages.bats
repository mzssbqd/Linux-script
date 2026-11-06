#!/usr/bin/env bats
load helpers

setup() {
    setup_project
}

@test "map_packages_separately_from_commands" {
    [ "$(package_name fd)" = fd-find ]
    [ "$(package_name ssh)" = openssh-client ]
    [ "$(package_name bw)" = bitwarden-cli ]
    [ "$(package_name node)" = nodejs ]
    [ "$(package_name npm)" = npm ]
    user_command() { [ "$1" = fdfind ] && printf '/usr/bin/fdfind\n'; }
    [ "$(tool_command fd)" = /usr/bin/fdfind ]
    PACKAGE_MANAGER=brew
    [ "$(package_name fd)" = fd ]
    [ "$(package_name ssh)" = openssh ]
    [ "$(package_name bw)" = bitwarden-cli ]
    [ "$(package_name node)" = node ]
    [ "$(package_name npm)" = node ]
}

@test "skip_installed_tools" {
    tool_available() { return 0; }
    platform_install() { touch "$BATS_TEST_TMPDIR/should-not-install"; }
    ensure_package git
    [ ! -e "$BATS_TEST_TMPDIR/should-not-install" ]
    [ "${#EXISTING[@]}" -eq 1 ]
}

@test "report_unavailable_packages_without_installing" {
    tool_available() { return 1; }
    platform_package_available() { return 1; }
    platform_install() { touch "$BATS_TEST_TMPDIR/should-not-install"; }
    ensure_package glow || true
    [ ! -e "$BATS_TEST_TMPDIR/should-not-install" ]
    [ "${#INCOMPLETE[@]}" -eq 1 ]
    [[ ${INCOMPLETE[0]} == *glow* ]]
}

@test "continue_after_one_install_fails_without_retry" {
    tool_available() { [ -f "$BATS_TEST_TMPDIR/installed-$1" ]; }
    platform_package_available() { return 0; }
    platform_install() {
        printf '%s\n' "$1" >>"$BATS_TEST_TMPDIR/attempts"
        [ "$1" != glow ] || return 42
        local name=$1
        [ "$name" != fd-find ] || name=fd
        [ "$name" != bitwarden-cli ] || name=bw
        touch "$BATS_TEST_TMPDIR/installed-$name"
    }
    run_terminal
    [ -f "$BATS_TEST_TMPDIR/installed-btop" ]
    [ "$(grep -c '^glow$' "$BATS_TEST_TMPDIR/attempts")" -eq 1 ]
    [ "${#INCOMPLETE[@]}" -eq 1 ]
    [ "${#COMPLETED[@]}" -eq 7 ]
    run print_summary
    [ "$status" -ne 0 ]
}

@test "verify_tool_after_successful_install_command" {
    tool_available() { return 1; }
    platform_package_available() { return 0; }
    platform_install() { return 0; }
    ensure_package jq || true
    [ "${#COMPLETED[@]}" -eq 0 ]
    [ "${#INCOMPLETE[@]}" -eq 1 ]
}

@test "apt_uses_current_sources_and_reports_update_failure" {
    source "$PROJECT_ROOT/src/platforms/apt.sh"
    apt-cache() { printf '  Candidate: (none)\n'; }
    run platform_package_available glow
    [ "$status" -eq 1 ]
    apt-cache() { printf '  Candidate: 1.2.3\n'; }
    platform_package_available jq
    apt-get() {
        printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/apt-calls"
        return 100
    }
    platform_prepare || true
    [ "$(cat "$BATS_TEST_TMPDIR/apt-calls")" = update ]
    [ "${#INCOMPLETE[@]}" -eq 1 ]
}

@test "brew_runs_as_target_user" {
    source "$PROJECT_ROOT/src/platforms/macos.sh"
    OS=macos
    BREW_BIN=/example/brew
    as_user() { printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/user-calls"; }
    platform_package_available jq
    platform_install jq
    [ "$(cat "$BATS_TEST_TMPDIR/user-calls")" = $'/example/brew info --formula jq\n/example/brew install --formula jq' ]
}

@test "bitwarden_uses_user_npm_install_on_both_linux_architectures" {
    source "$PROJECT_ROOT/src/platforms/apt.sh"
    as_user() { printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/npm-calls"; }
    apt-get() { return 99; }
    for ARCH in x86_64 arm64; do
        platform_package_available bitwarden-cli
        platform_install bitwarden-cli
    done
    [ "$(wc -l <"$BATS_TEST_TMPDIR/npm-calls" | tr -d ' ')" -eq 2 ]
    [ "$(head -1 "$BATS_TEST_TMPDIR/npm-calls")" = "npm install --global --prefix $TARGET_HOME/.local --engine-strict @bitwarden/cli" ]
}

@test "bitwarden_npm_failure_is_reported_without_retry_or_login" {
    source "$PROJECT_ROOT/src/platforms/apt.sh"
    tool_available() { return 1; }
    as_user() {
        printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/npm-calls"
        return 1
    }
    ensure_package bw || true
    [ "${#INCOMPLETE[@]}" -eq 1 ]
    [ "${#COMPLETED[@]}" -eq 0 ]
    [ "$(wc -l <"$BATS_TEST_TMPDIR/npm-calls" | tr -d ' ')" -eq 1 ]
    [[ ${INCOMPLETE[0]} == "bw："* ]]
}

@test "declining_homebrew_stops_without_download" {
    source "$PROJECT_ROOT/src/platforms/macos.sh"
    find_brew() { return 1; }
    confirm() { return 1; }
    as_user() { touch "$BATS_TEST_TMPDIR/unexpected-operation"; }
    platform_prepare || true
    [ ! -e "$BATS_TEST_TMPDIR/unexpected-operation" ]
    [ "${#INCOMPLETE[@]}" -eq 1 ]
}

@test "homebrew_install_requires_consent_and_updates_user_path" {
    source "$PROJECT_ROOT/src/platforms/macos.sh"
    OS=macos
    export PB_TEST_BREW_READY="$BATS_TEST_TMPDIR/brew-ready"
    find_brew() {
        [ -f "$PB_TEST_BREW_READY" ] || return 1
        BREW_BIN=/example/brew
    }
    confirm() { printf 'confirmed\n' >>"$BATS_TEST_TMPDIR/brew-calls"; }
    as_user() {
        printf '%s\n' "$1" >>"$BATS_TEST_TMPDIR/brew-calls"
        case "$1" in
            mktemp) mktemp "$BATS_TEST_TMPDIR/brew-install.XXXXXX" ;;
            curl) printf 'touch "$PB_TEST_BREW_READY"\n' >"${@: -1}" ;;
            /example/brew) printf '/example\n' ;;
            *) "$@" ;;
        esac
    }
    platform_prepare
    [ "$(head -1 "$BATS_TEST_TMPDIR/brew-calls")" = confirmed ]
    [ -f "$PB_TEST_BREW_READY" ]
    [ "$BREW_BIN" = /example/brew ]
    [[ "$USER_PATH" == /example/bin:/example/sbin:* ]]
    [ "${#COMPLETED[@]}" -eq 1 ]
}

@test "logged_command_preserves_failure_status" {
    run run_logged sh -c 'echo expected-failure; exit 7'
    [ "$status" -eq 7 ]
    grep -q expected-failure "$LOG_FILE"
}
