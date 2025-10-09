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

# Disable shared history across tmux sessions
setopt no_share_history
setopt append_history
setopt inc_append_history

# Separate history per tmux PANE (not just window)
if [[ -n "$TMUX_PANE" ]]; then
    export HISTFILE="$HOME/.zsh_history_tmux_${TMUX_PANE:1}"
fi
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

set -g mouse off
set -g set-clipboard external
set -ga terminal-overrides ',*:Ms=\\E]52;c;%p2%s\\7'
set -g base-index 1
setw -g pane-base-index 1
set -g history-limit 1000000
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
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'brooth/far.vim'
call plug#end()

" --- Sensible basics ---
set number
set norelativenumber
set hidden
set ignorecase smartcase
set mouse=a

" --- Color scheme settings ---
set background=dark
if &term =~ '256color'
    set t_Co=256
endif

" Use default vim colors - no fancy themes
colorscheme default

" --- Terminal settings ---
" Enable alternate screen buffer (restore screen on exit)
set t_ti=\e[?1049h
set t_te=\e[?1049l

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

" \fr: find and replace across files (far.vim)
nnoremap \fr :Far
" \fi: find and replace case insensitive
nnoremap \fi :Far -i

" Configure far.vim to use ripgrep
let g:far#source = 'rg'

" In FAR buffer: press R (shift+r) to execute all replacements
autocmd FileType far nnoremap <buffer> R :Fardo<CR>
" In FAR buffer: press U (shift+u) to undo replacements
autocmd FileType far nnoremap <buffer> U :Farundo<CR>

" Simple workflow: use 'x' to exclude items you DON'T want to replace, then 'R' to replace included ones

" :vs already exists; add :hs for horizontal split
command! -nargs=? -complete=file Hs split <args>

" Quickfix nav (optional)
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprevious<CR>

set clipboard=unnamedplus

" --- CoC.nvim settings ---
" Use tab for trigger completion with characters ahead and navigate
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
inoremap <silent><expr> <c-space> coc#refresh()

" GoTo code navigation
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

" \fm: format current buffer
nmap <silent> \fm <Plug>(coc-format)
" \fs: format selected range (visual mode)
xmap <silent> \fs <Plug>(coc-format-selected)

" --- CoC settings - MINIMAL highlighting ---
" Disable CoC visual pollution
let g:coc_default_semantic_highlight_groups = 0
autocmd VimEnter * call coc#config('semanticTokens.enable', v:false)
autocmd VimEnter * call coc#config('codeLens.enable', v:false)
autocmd VimEnter * call coc#config('inlayHint.enable', v:false)
autocmd VimEnter * call coc#config('documentHighlight.enable', v:false)
autocmd VimEnter * call coc#config('colors.enable', v:false)
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
# 6) Create Claude Code wrapper script
###############################################################################
banner "Creating Claude Code wrapper for tmux isolation..."
cat > "${HOME}/claude-wrapper.sh" <<'WRAPPER'
#!/bin/bash
# Run Claude Code with proper terminal isolation in tmux
# This prevents output from bleeding into other panes

if [[ -n "${TMUX:-}" ]]; then
    # In tmux: disable alternate screen and force normal terminal behavior
    export TERM=screen-256color
    tput rmcup 2>/dev/null || true
    exec claude "$@"
else
    # Outside tmux: run normally
    exec claude "$@"
fi
WRAPPER
chmod +x "${HOME}/claude-wrapper.sh"

###############################################################################
# 7) Install CoC language servers
###############################################################################
banner "Installing CoC language servers..."
# Wait a moment for CoC to initialize, then install common language servers
sleep 2
if command -v nvim >/dev/null 2>&1; then
  nvim --headless +"CocInstall -sync coc-prettier coc-pyright coc-java coc-tsserver coc-json coc-css coc-html" +qall || true
elif command -v vim >/dev/null 2>&1; then
  vim +"CocInstall -sync coc-prettier coc-pyright coc-java coc-tsserver coc-json coc-css coc-html" +qall || true
fi

###############################################################################
# 8) Done
###############################################################################
banner "All set! Next steps:"
echo " - Start a new shell (or run: source ~/.zshrc) to auto-attach tmux."
echo " - Inside tmux, reload config anytime with: Ctrl-a then r"
echo " - In Vim: \\nt toggles NERDTree, \\ff searches files, \\fb text search, \\fr find/replace, \\fm formats code."
echo " - CoC LSP features: gd (go to definition), gr (references), K (docs)."
echo " - Claude Code wrapper created at ~/claude-wrapper.sh (prevents output bleeding in tmux)"
