complete -c awsp -f
complete -c awsp -a '(_aws_profiles)' -d 'perfil AWS'
complete -c awsp -s l -l list -d 'lista os perfis'
complete -c awsp -s h -l help -d 'ajuda'
complete -c awsp -a 'off' -d 'limpa AWS_PROFILE'
