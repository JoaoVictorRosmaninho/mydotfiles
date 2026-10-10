function init_ssh_agent --wraps='eval (ssh-agent -c)' --description 'alias init_ssh_agent=eval (ssh-agent -c)'
    eval (ssh-agent -c) $argv 2&>/dev/null
    ssh-add ~/.ssh/id_ed25519 2&>/dev/null
end
