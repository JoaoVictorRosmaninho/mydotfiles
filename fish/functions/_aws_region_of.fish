function _aws_region_of --argument-names profile --description "Região configurada para um perfil AWS"
    set -l cfg $AWS_CONFIG_FILE
    test -n "$cfg"; or set cfg $HOME/.aws/config
    test -f $cfg; or return 1

    awk -v want="$profile" '
        /^\[/ {
            cur = $0
            sub(/^\[[[:space:]]*(profile[[:space:]]+)?/, "", cur)
            sub(/[[:space:]]*\][[:space:]]*$/, "", cur)
            next
        }
        cur == want && /^[[:space:]]*region[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, "")
            print
            exit
        }
    ' $cfg
end
