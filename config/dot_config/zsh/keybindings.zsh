# plugin固有のkeybind (history-substring-search) は plugins.toml の hooks.post にある
bindkey -e # Use Emacs key bindings
bindkey "^[[Z" reverse-menu-complete
WORDCHARS='*?_-.[]~&;!#$%^(){}<>'
