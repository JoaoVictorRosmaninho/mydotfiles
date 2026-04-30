if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Adicione isso ao seu ~/.config/fish/config.fish se não tiver um gerenciador de sessão
if status is-login
    dbus-run-session startplasma-wayland
end

# Se o DBus não estiver no ambiente, tenta buscar de uma sessão já rodando
if not set -q DBUS_SESSION_BUS_ADDRESS
    set -gx DBUS_SESSION_BUS_ADDRESS (pgrep -u $USER -n dbus-daemon | xargs -I{} cat /proc/{}/environ | tr '\0' '\n' | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
end

set -gx CHROME_EXECUTABLE_FLAGS "--password-store=basic"

set -g fish_user_paths $fish_user_paths ~/.local/bin
set -g fish_user_paths $fish_user_paths ~/.local/bin/code

# go path
set -g fish_user_paths $fish_user_paths ~/go/bin
# starship init
starship init fish | source

# SSH agent init function call
init_ssh_agent

#Zoxide
zoxide init fish --cmd cd | source
