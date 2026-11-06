# 由 .zshrc 接入；仅在交互终端中加载一次。
[[ -o interactive ]] || return
[[ -n ${_PERSONAL_BOOTSTRAP_LOADED:-} ]] && return
typeset -g _PERSONAL_BOOTSTRAP_LOADED=1
typeset -g _PERSONAL_BOOTSTRAP_CONFIG=${${(%):-%N}:A:h}
source "$_PERSONAL_BOOTSTRAP_CONFIG/paths.zsh"

# Mac 已有欢迎画入口时沿用原配置，避免重复显示。
if ! grep -Eq '^[^#]*source[[:space:]].*mzssbqd-banner\.zsh' "${ZDOTDIR:-$HOME}/.zshrc" 2>/dev/null; then
    source "$_PERSONAL_BOOTSTRAP_CONFIG/mzssbqd-banner.zsh"
fi

# 用户目录中的 CLI（例如通过 npm 安装的 bw）。
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || path=("$HOME/.local/bin" $path)

if [[ -n $PERSONAL_BOOTSTRAP_BREW && -x $PERSONAL_BOOTSTRAP_BREW ]]; then
    eval "$("$PERSONAL_BOOTSTRAP_BREW" shellenv)"
fi

export ZSH=${ZSH:-$PERSONAL_BOOTSTRAP_OMZ}
ZSH_CUSTOM=${ZSH_CUSTOM:-$PERSONAL_BOOTSTRAP_CUSTOM}
if (( ! $+functions[omz] )) && [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
    typeset -ga plugins
    (( $+commands[git] && ! ${plugins[(Ie)git]} )) && plugins+=(git)
    (( $+commands[fzf] && ! ${plugins[(Ie)fzf]} )) && plugins+=(fzf)
    ZSH_THEME=${ZSH_THEME-robbyrussell}
    source "$ZSH/oh-my-zsh.sh"
fi

source "$_PERSONAL_BOOTSTRAP_CONFIG/aliases.zsh"
if (( $+commands[zoxide] && ! $+functions[__zoxide_z] )); then
    eval "$(zoxide init zsh)"
fi
# 插件文件最后处理语法高亮。
source "$_PERSONAL_BOOTSTRAP_CONFIG/plugins.zsh"
