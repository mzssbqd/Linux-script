#!/bin/bash

CONFIG_READY=false

prepare_config() {
    as_user mkdir -p "$CONFIG_DIR/zsh" "$CONFIG_DIR/backups" || return 1
    if [ ! -f "$CONFIG_DIR/preferences.conf" ]; then
        as_user cp "$PROJECT_ROOT/config/preferences.conf" "$CONFIG_DIR/preferences.conf" || return 1
    fi
}

load_preferences() {
    CONFIGURE_GIT=false
    GIT_USER_NAME=
    GIT_USER_EMAIL=
    local key value
    # 偏好文件只读取字面值，不作为 root 执行 Shell 代码。
    while IFS='=' read -r key value || [ -n "$key" ]; do
        case "$key" in
            '' | \#*) continue ;;
            CONFIGURE_GIT) CONFIGURE_GIT=$value ;;
            GIT_USER_NAME) GIT_USER_NAME=$value ;;
            GIT_USER_EMAIL) GIT_USER_EMAIL=$value ;;
            *)
                log_info "未知偏好项：$key"
                return 1
                ;;
        esac
    done <"$CONFIG_DIR/preferences.conf"
    case "$CONFIGURE_GIT" in
        true | false) return 0 ;;
        *)
            log_info 'CONFIGURE_GIT 只能是 true 或 false。'
            return 1
            ;;
    esac
}

deploy_zsh_files() {
    local file
    for file in init.zsh aliases.zsh plugins.zsh mzssbqd-banner.zsh; do
        if ! cmp -s "$PROJECT_ROOT/config/zsh/$file" "$CONFIG_DIR/zsh/$file"; then
            as_user cp "$PROJECT_ROOT/config/zsh/$file" "$CONFIG_DIR/zsh/$file" || return 1
        fi
    done
    # 记录本次确定的安装路径，供新开的 Zsh 使用。
    {
        printf 'typeset -g PERSONAL_BOOTSTRAP_BREW=%q\n' "${BREW_BIN:-}"
        printf 'typeset -g PERSONAL_BOOTSTRAP_OMZ=%q\n' "$OMZ_DIR"
        printf 'typeset -g PERSONAL_BOOTSTRAP_CUSTOM=%q\n' "$OMZ_CUSTOM_DIR"
    } | as_user tee "$CONFIG_DIR/zsh/paths.zsh" >/dev/null
}

update_zshrc() {
    local rc temporary entry input backup
    rc=$1
    as_user mkdir -p "$(dirname "$rc")" || return 1
    temporary=$(as_user mktemp "$CONFIG_DIR/.zshrc.XXXXXX") || return 1
    printf -v entry 'source %q' "$CONFIG_DIR/zsh/init.zsh"
    input=$rc
    [ -f "$input" ] || input=/dev/null
    # shellcheck disable=SC2016 # $0 属于 awk 表达式。
    if ! as_user env PB_ENTRY="$entry" awk '
        function block() {
            print "# BEGIN Personal Bootstrap"
            print ENVIRON["PB_ENTRY"]
            print "# END Personal Bootstrap"
        }
        $0 == "# BEGIN Personal Bootstrap" { block(); managed = 1; found = 1; next }
        $0 == "# END Personal Bootstrap" { managed = 0; next }
        !managed { print }
        END { if (!found) { if (NR > 0) print ""; block() } }
    ' "$input" | as_user tee "$temporary" >/dev/null; then
        as_user rm -f "$temporary"
        return 1
    fi
    if cmp -s "$temporary" "$rc"; then
        as_user rm -f "$temporary"
        return 0
    fi
    if [ -f "$rc" ]; then
        backup="$CONFIG_DIR/backups/zshrc-$(date +%Y%m%d-%H%M%S)-$$"
        as_user cp -p "$rc" "$backup" || return 1
        printf '原配置备份：%s\n' "$backup"
    fi
    # tee 保留已有文件的权限，并沿用已有符号链接。
    if ! as_user cat "$temporary" | as_user tee "$rc" >/dev/null; then
        as_user rm -f "$temporary"
        return 1
    fi
    as_user rm -f "$temporary"
}
