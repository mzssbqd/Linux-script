# 已有 Oh My Zsh 时，只补充本项目需要而尚未启用的内置插件。
if (( $+commands[git] && ! ${plugins[(Ie)git]} )) && [[ -f "$ZSH/plugins/git/git.plugin.zsh" ]]; then
    source "$ZSH/plugins/git/git.plugin.zsh"
    plugins+=(git)
fi
if (( $+commands[fzf] && ! ${plugins[(Ie)fzf]} )) && [[ -f "$ZSH/plugins/fzf/fzf.plugin.zsh" ]]; then
    source "$ZSH/plugins/fzf/fzf.plugin.zsh"
    plugins+=(fzf)
fi

if (( ! $+functions[_zsh_autosuggest_start] )) && [[ -f "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if (( ! $+functions[_zsh_highlight] )) && [[ -f "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
