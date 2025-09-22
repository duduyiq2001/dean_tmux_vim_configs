#!/usr/bin/env bash
set -euo pipefail

banner() { echo -e "\n==> $1"; }
backup() { local f="$1"; [[ -f "$f" ]] && cp -a "$f" "${f}.bak.$(date +%Y%m%d-%H%M%S)"; }

###############################################################################
# 1) Install prerequisites (tmux, ripgrep, vim, curl, git)
###############################################################################
banner "Installing packages (tmux, ripgrep, vim, curl, git, fzf)..."
if command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y tmux ripgrep vim curl git fzf
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y tmux ripgrep vim curl git fzf
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --noconfirm tmux ripgrep vim curl git fzf
elif command -v zypper >/dev/null 2>&1; then
  sudo zypper install -y tmux ripgrep vim curl git fzf
elif command -v brew >/dev/null 2>&1; then
  brew install tmux ripgrep vim git fzf
else
  echo "Could not detect a supported package manager. Please install tmux, ripgrep, vim, curl, git, and fzf manually."
fi

###############################################################################
# 2) zsh: auto-attach/create tmux session
###############################################################################
banner "Configuring zsh to auto-attach tmux..."
ZSHRC="${HOME}/.zshrc"
AUTO_BLOCK_START="# >>> tmux autostart (added by setup_tmux_vim.sh) >>>"
AUTO_BLOCK_END="# <<< tmux autostart (added by setup_tmux_vim.sh) <<<"
mkdir -p "$(dirname "$ZSHRC")"
if ! grep -qF "$AUTO_BLOCK_START" "$ZSHRC" 2>/dev/null; then
  backup "$ZSHRC"
  cat >> "$ZSHRC" <<'ZRC'
# >>> tmux autostart (added by setup_tmux_vim.sh) >>>
# Attach to or create a 'main' tmux session for interactive shells
if [[ $- == *i* ]] && command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]]; then
  tmux new -A -s main
fi
# <<< tmux autostart (added by setup_tmux_vim.sh) <<<
ZRC
fi

###############################################################################
# 3) tmux configuration with your keybinds
###############################################################################
banner "Writing ~/.tmux.conf..."
TMUXCONF="${HOME}/.tmux.conf"
backup "$TMUXCONF"
cat > "$TMUXCONF" <<'TMUXCONF'
##### Prefix & basics
unbind C-b
set -g prefix C-a
bind C-a send-prefix

set -g mouse on
set -g set-clipboard external
set -ga terminal-overrides ',*:Ms=\\E]52;c;%p2%s\\7'
set -g base-index 1
setw -g pane-base-index 1
set -g history-limit 100000
setw -g mode-keys vi
set -g status-keys vi
set -s escape-time 0
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:RGB"

##### Splits 
bind | split-window -h -c "#{pane_current_path}"
bind % split-window -v -c "#{pane_current_path}"

##### Move between panes (arrow keys)
bind -r Left  select-pane -L
bind -r Right select-pane -R
bind -r Up    select-pane -U
bind -r Down  select-pane -D

##### Resize panes (Prefix + w/a/s/d)
bind -r a resize-pane -L 5
bind -r d resize-pane -R 5
bind -r w resize-pane -U 5
bind -r s resize-pane -D 5

##### Zoom toggle on + / -
bind + resize-pane -Z
bind - resize-pane -Z

##### Handy extras
bind c new-window -c "#{pane_current_path}"
bind q display-panes
bind x kill-pane
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"
TMUXCONF

###############################################################################
# 4) Vim config: NERDTree, /nt, /ff, :hs, ripgrep-backed search
###############################################################################
banner "Installing vim-plug (plugin manager)..."
# Vim
curl -fsSLo "${HOME}/.vim/autoload/plug.vim" --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
# Neovim (optional, if you use it)
curl -fsSLo "${HOME}/.local/share/nvim/site/autoload/plug.vim" --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

VIMRC="${HOME}/.vimrc"
backup "$VIMRC"
cat > "$VIMRC" <<'VIMRC'
" --- Plugins (vim-plug) ---
call plug#begin('~/.vim/plugged')
Plug 'preservim/nerdtree'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
call plug#end()

" --- Sensible basics ---
set number
set relativenumber
set hidden
set ignorecase smartcase
set termguicolors
set mouse=a

" --- File search backend (prefer ripgrep) ---
if executable('rg')
  set grepprg=rg\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
elseif executable('ag')
  set grepprg=ag\ --vimgrep\ --smart-case
  set grepformat=%f:%l:%c:%m
else
  set grepprg=grep\ -R\ --line-number\ --column\ --binary-files=without-match\ --exclude-dir=.git
  set grepformat=%f:%l:%m
endif

" --- Your mappings/commands ---
" \nt: toggle NERDTree
nnoremap <silent> \nt :NERDTreeToggle<CR>

" \ff: fuzzy file finder popup
nnoremap <silent> \ff :CtrlP<CR>

" \fb: fuzzy text search in files (browse)
nnoremap <silent> \fb :Rg<CR>

" :vs already exists; add :hs for horizontal split
command! -nargs=? -complete=file Hs split <args>

" Quickfix nav (optional)
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprevious<CR>
VIMRC

# Neovim mirrors ~/.vimrc if Neovim is present
if command -v nvim >/dev/null 2>&1; then
  banner "Writing Neovim config to ~/.config/nvim/init.vim..."
  mkdir -p "${HOME}/.config/nvim"
  backup "${HOME}/.config/nvim/init.vim"
  cat > "${HOME}/.config/nvim/init.vim" <<'NVIM'
" Load the same config as Vim
if filereadable(expand("~/.vimrc"))
  execute 'source ~/.vimrc'
endif
NVIM
fi

###############################################################################
# 5) Install Vim plugins non-interactively
###############################################################################
banner "Installing Vim plugins..."
if command -v nvim >/dev/null 2>&1; then
  nvim --headless +PlugInstall +qall || true
elif command -v vim >/dev/null 2>&1; then
  vim +PlugInstall +qall || true
fi

###############################################################################
# 6) Done
###############################################################################
banner "All set! Next steps:"
echo " - Start a new shell (or run: source ~/.zshrc) to auto-attach tmux."
echo " - Inside tmux, reload config anytime with: Ctrl-a then r"
echo " - In Vim: /nt toggles NERDTree, /ff searches files, :hs splits horizontally."
