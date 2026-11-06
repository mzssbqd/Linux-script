#!/bin/sh
# 模拟官方安装器的输入约定；不联网，只复制测试框架。
[ "$CHSH:$RUNZSH:$KEEP_ZSHRC" = no:no:yes ] || exit 2
[ "$1:$2" = --unattended:--keep-zshrc ] || exit 2
mkdir -p "$ZSH/custom/plugins" "$ZDOTDIR" || exit 1
cp "$PB_TEST_OMZ_SOURCE/oh-my-zsh.sh" "$ZSH/" || exit 1
cp -R "$PB_TEST_OMZ_SOURCE/plugins" "$ZSH/" || exit 1
printf 'installer-template\n' >"$ZDOTDIR/.zshrc"
printf 'omz-install\n' >>"$PB_TEST_CALLS"
