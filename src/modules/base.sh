#!/bin/bash

run_base() {
    log_info '开始 Base：基础工具'
    local tool
    for tool in git curl wget ca-certificates unzip tree jq less ssh node npm; do
        ensure_package "$tool" || continue
    done
    if run_logged prepare_config; then
        CONFIG_READY=true
        record_done '个人配置目录'
    else
        record_failure '个人配置目录' '创建目录或复制偏好模板失败'
    fi
}
