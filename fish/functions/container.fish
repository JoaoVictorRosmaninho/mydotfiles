function container 
    command aws ecs execute-command \
    --cluster $argv[1] \
    --task $argv[2] \
    --container $argv[3] \
    --interactive \
    --command "/bin/bash"
end
