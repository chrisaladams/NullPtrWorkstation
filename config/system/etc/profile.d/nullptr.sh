# nullptr Workstation environment
export GBDK_HOME=/opt/gbdk
case ":$PATH:" in *:/opt/gbdk/bin:*) ;; *) PATH="$PATH:/opt/gbdk/bin" ;; esac
export EDITOR=nvim VISUAL=nvim
export PATH
