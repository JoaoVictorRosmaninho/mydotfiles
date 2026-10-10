function container 

    echo "Connecting to container $argv[3] in task $argv[2] on cluster $argv[1] in region $argv[4]..."

    command aws ecs execute-command \
    --cluster $argv[1] \
    --task $argv[2] \
    --container $argv[3] \
    --interactive \
    --command "/bin/bash" \
    --region $argv[4]
end
