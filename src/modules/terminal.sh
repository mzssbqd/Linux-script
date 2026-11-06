#!/bin/bash

run_terminal() {
    log_info '开始 Terminal：终端工具'
    local tool
    for tool in bat glow fzf ripgrep fd zoxide btop bw; do
        ensure_package "$tool" || continue
    done
}
