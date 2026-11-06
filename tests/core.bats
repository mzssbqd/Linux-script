#!/usr/bin/env bats
load helpers

setup() {
    setup_project
}

@test "help_and_unknown_options_do_not_install" {
    run /bin/bash "$PROJECT_ROOT/bootstrap.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *'sudo ./bootstrap.sh'* ]]
    run /bin/bash "$PROJECT_ROOT/bootstrap.sh" --module shell
    [ "$status" -eq 2 ]
}

@test "detect_ubuntu_debian_and_architectures" {
    printf 'ID=ubuntu\nVERSION_ID="24.04"\n' >"$BATS_TEST_TMPDIR/os-release"
    detect_os Linux "$BATS_TEST_TMPDIR/os-release" aarch64
    [ "$OS" = ubuntu ] && [ "$ARCH" = arm64 ] && [ "$PACKAGE_MANAGER" = apt ]
    printf 'ID=debian\nVERSION_ID="13"\n' >"$BATS_TEST_TMPDIR/os-release"
    detect_os Linux "$BATS_TEST_TMPDIR/os-release" x86_64
    [ "$OS" = debian ] && [ "$OS_VERSION" = 13 ] && [ "$ARCH" = x86_64 ]
}

@test "detect_macos_and_reject_unsupported_platforms" {
    sw_vers() { printf '15.0\n'; }
    detect_os Darwin /dev/null arm64
    [ "$OS" = macos ] && [ "$PACKAGE_MANAGER" = brew ]
    run detect_os FreeBSD /dev/null x86_64
    [ "$status" -ne 0 ]
    run detect_os Darwin /dev/null armv7l
    [ "$status" -ne 0 ]
    printf 'ID=fedora\nVERSION_ID=44\n' >"$BATS_TEST_TMPDIR/os-release"
    run detect_os Linux "$BATS_TEST_TMPDIR/os-release" x86_64
    [ "$status" -ne 0 ]
}

@test "resolve_home_of_sudo_user" {
    id() { printf '0\n'; }
    getent() { printf 'alice:x:1000:1000::%s:/bin/bash\n' "$TARGET_HOME"; }
    SUDO_USER=alice
    unset XDG_CONFIG_HOME XDG_STATE_HOME
    resolve_target_user
    [ "$TARGET_USER" = alice ]
    [ "$CONFIG_DIR" = "$TARGET_HOME/.config/personal-bootstrap" ]
    [ "$TARGET_HOME" != "$HOME" ]
}

@test "resolve_macos_home_and_log_directory" {
    OS=macos
    SUDO_USER=alice
    id() { printf '0\n'; }
    dscl() { printf 'NFSHomeDirectory: %s\n' "$TARGET_HOME"; }
    resolve_target_user
    [ "$TARGET_USER" = alice ]
    init_logger
    [[ "$LOG_FILE" == "$TARGET_HOME/Library/Logs/Personal-Bootstrap/"* ]]
    [ -f "$LOG_FILE" ]
}

@test "require_sudo_from_a_normal_user" {
    id() { printf '1000\n'; }
    SUDO_USER=alice
    run resolve_target_user
    [ "$status" -ne 0 ]
    id() { printf '0\n'; }
    unset SUDO_USER
    run resolve_target_user
    [ "$status" -ne 0 ]
}

@test "run_user_operations_with_target_identity" {
    source "$PROJECT_ROOT/src/lib/common.sh"
    USER_ENV=('ZDOTDIR=/custom/zsh')
    sudo() { printf '<%s>\n' "$@"; }
    run as_user git config --global user.name Alice
    [ "$status" -eq 0 ]
    [[ "$output" == *'<-H>'*'<-u>'*'<bootstrap-test>'* ]]
    [[ "$output" == *'<ZDOTDIR=/custom/zsh>'*'<git>'* ]]
}

@test "rotate_logs_and_report_failures" {
    local i
    for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
        touch "$STATE_DIR/logs/bootstrap-200001$i.log"
    done
    touch "$STATE_DIR/logs/notes.txt"
    init_logger
    [ "$(find "$STATE_DIR/logs" -name 'bootstrap-*.log' | wc -l | tr -d ' ')" -eq 10 ]
    [ -f "$STATE_DIR/logs/notes.txt" ]
    record_failure glow '软件源无包'
    run print_summary
    [ "$status" -eq 1 ]
    [[ "$output" == *'glow：软件源无包'* ]]
}
