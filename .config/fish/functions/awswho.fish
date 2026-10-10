function awswho --description "Mostra qual conta AWS está ativa (sts get-caller-identity)"
    if not set -q AWS_PROFILE
        echo "awswho: AWS_PROFILE não está definido (use awsp)" >&2
        return 1
    end

    set -l region (_aws_region_of $AWS_PROFILE)
    test -n "$region"; or set region "-"

    set -l out (command aws sts get-caller-identity --output json 2>&1)
    if test $status -ne 0
        echo "awswho: falha ao consultar a AWS com o perfil '$AWS_PROFILE'" >&2
        printf '%s\n' $out >&2
        return 1
    end

    printf '%s\n' $out | jq -r --arg p "$AWS_PROFILE" --arg r "$region" \
        '"perfil : \($p)\nregião : \($r)\nconta  : \(.Account)\narn    : \(.Arn)"'
end
