# 为发行版使用的命令名提供交互式别名。
if (( ! $+commands[bat] && $+commands[batcat] && ! $+aliases[bat] )); then
    alias bat=batcat
fi
if (( ! $+commands[fd] && $+commands[fdfind] && ! $+aliases[fd] )); then
    alias fd=fdfind
fi
