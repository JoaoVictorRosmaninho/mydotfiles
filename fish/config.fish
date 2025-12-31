if status is-interactive
    # Commands to run in interactive sessions can go here
end

set -g fish_user_paths $fish_user_paths ~/.local/bin

# starship init
starship init fish | source

# SSH agent init function call
init_ssh_agent

#Zoxide
zoxide init fish --cmd cd | source
