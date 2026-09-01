function awsp --description "Mostra ou troca o perfil AWS ativo"
    set -l profiles (_aws_profiles)

    if test (count $profiles) -eq 0
        echo "awsp: nenhum perfil em ~/.aws/credentials" >&2
        return 1
    end

    # sem argumento: seletor interativo (fzf) ou lista
    if test (count $argv) -eq 0
        if type -q fzf
            set -l rows
            for p in $profiles
                set -a rows (printf '%s\t%s' $p (_aws_region_of $p))
            end
            set -l chosen (printf '%s\n' $rows | fzf --height=~40% --reverse \
                --prompt='perfil AWS > ' \
                --header='enter = usar   esc = cancelar' \
                --query="" | cut -f1)
            test -n "$chosen"; or return 0
            _awsp_use $chosen
            return
        else
            _awsp_list $profiles
            return 0
        end
    end

    switch $argv[1]
        case -h --help
            echo "uso:"
            echo "  awsp                seletor interativo (fzf)"
            echo "  awsp <perfil>       troca de perfil (aceita trecho do nome, ex: awsp flow)"
            echo "  awsp -l, --list     lista os perfis"
            echo "  awsp -, off         limpa AWS_PROFILE do shell atual"
            return 0
        case -l --list
            _awsp_list $profiles
            return 0
        case - off none
            set -q AWS_PROFILE; and set -e AWS_PROFILE
            set -e __aws_profile_default
            echo "perfil AWS limpo neste shell"
            return 0
    end

    set -l query $argv[1]

    # 1) nome exato
    if contains -- $query $profiles
        _awsp_use $query
        return
    end

    # 2) trecho do nome (case-insensitive)
    set -l hits (printf '%s\n' $profiles | string match -ei -- $query)
    switch (count $hits)
        case 1
            _awsp_use $hits[1]
        case 0
            echo "awsp: nenhum perfil casa com '$query'" >&2
            _awsp_list $profiles >&2
            return 1
        case '*'
            echo "awsp: '$query' é ambíguo — casa com: $hits" >&2
            return 1
    end
end

function _awsp_use --argument-names profile --description "Ativa um perfil AWS no shell atual"
    set -gx AWS_PROFILE $profile
    # essas variáveis sobrescreveriam a região do perfil
    set -q AWS_REGION; and set -e AWS_REGION
    set -q AWS_DEFAULT_REGION; and set -e AWS_DEFAULT_REGION
    # lembra a escolha para os próximos shells
    set -U __aws_profile_default $profile

    set_color green
    echo -n "AWS_PROFILE = $profile"
    set_color normal
    echo " ("(_aws_region_of $profile)")"
end

function _awsp_list --description "Lista perfis marcando o ativo"
    for p in $argv
        set -l region (_aws_region_of $p)
        if test "$p" = "$AWS_PROFILE"
            set_color green
            echo "* $p ($region)"
            set_color normal
        else
            echo "  $p ($region)"
        end
    end
end
