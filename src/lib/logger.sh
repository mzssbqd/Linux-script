#!/bin/bash

COMPLETED=()
EXISTING=()
INCOMPLETE=()

init_logger() {
    local directory old_logs i
    if [ "$OS" = macos ]; then
        directory="$TARGET_HOME/Library/Logs/Personal-Bootstrap"
    else
        directory="$STATE_DIR/logs"
    fi
    LOG_FILE="$directory/bootstrap-$(date +%Y%m%d-%H%M%S)-$$.log"
    as_user mkdir -p "$directory" && as_user touch "$LOG_FILE" || return 1
    old_logs=("$directory"/bootstrap-*.log)
    # 文件名按时间排序；只清理本工具的旧日志，保留最近十次。
    for ((i = 0; i < ${#old_logs[@]} - 10; i++)); do
        as_user rm -- "${old_logs[$i]}" || return 1
    done
}

log_info() {
    printf '%s\n' "$*" | tee -a "$LOG_FILE"
}

record_done() {
    COMPLETED+=("$1")
    log_info "[已完成] $1"
}

record_existing() {
    EXISTING+=("$1")
    log_info "[已存在] $1"
}

record_failure() {
    INCOMPLETE+=("$1：$2")
    log_info "[未完成] $1：$2"
}

run_logged() {
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

print_summary() {
    log_info ""
    log_info "初始化结果：已完成 ${#COMPLETED[@]}，已存在 ${#EXISTING[@]}，未完成 ${#INCOMPLETE[@]}。"
    local item
    for item in "${INCOMPLETE[@]}"; do
        log_info "  - $item"
    done
    log_info "日志：$LOG_FILE"
    log_info '配置生效请新开终端；未完成的项目可自行处理后再次运行。'
    [ "${#INCOMPLETE[@]}" -eq 0 ]
}
