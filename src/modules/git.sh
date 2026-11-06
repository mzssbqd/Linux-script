#!/bin/bash

run_git() {
    if [ "$CONFIG_READY" != true ]; then
        record_failure 'Git 身份配置' '个人偏好目录不可用'
        return 1
    fi
    if ! load_preferences; then
        record_failure '个人偏好' '读取失败，请检查 preferences.conf'
        return 1
    fi
    if [ "$CONFIGURE_GIT" != true ]; then
        log_info 'Git 身份配置未启用，沿用原设置。'
        return 0
    fi
    if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
        record_failure 'Git 身份配置' '用户名和邮箱需要同时填写'
        return 1
    fi
    if ! tool_available git; then
        record_failure 'Git 身份配置' 'Git 不可用'
        return 1
    fi
    if run_logged as_user git config --global user.name "$GIT_USER_NAME" &&
        run_logged as_user git config --global user.email "$GIT_USER_EMAIL"; then
        record_done 'Git 身份配置'
    else
        record_failure 'Git 身份配置' '写入失败'
    fi
}
