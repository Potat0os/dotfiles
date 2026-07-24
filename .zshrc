# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="bira"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-completions
    zsh-history-substring-search
    zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# Check archlinux plugin commands here
# https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/archlinux

# Set-up icons for files/directories in terminal using lsd
alias lt='ls --tree'
alias trash='trash-put'
alias msbah='fastfetch'
alias yt='yt-dlp'
alias ytmp3='yt -x --audio-format mp3'
alias sudokms='shutdown -h now'

# Canceled command so you dont shoot your self in the foot
#alias sudo rm='echo "Are you retarted ? use trash"; false'
alias rm='echo "Use trash instead"; false'

# Set-up FZF key bindings (CTRL R for fuzzy history finder)
source <(fzf --zsh)

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory

#eval "$(starship init zsh)"
#--- yazi ---
function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d '' cwd < "$tmp"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
        trash-put -f -- "$tmp"
}

eval "$(zoxide init zsh)"

# Created by `pipx` on 2025-10-12 14:27:52
export PATH="$PATH:/home/potato/.local/bin"
