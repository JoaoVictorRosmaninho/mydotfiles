# Define o perfil AWS inicial de cada shell novo: o último escolhido com `awsp`.
# Shells já abertos mantêm o perfil deles — troque com `awsp <nome>`.
if not set -q AWS_PROFILE
    if set -q __aws_profile_default
        set -gx AWS_PROFILE $__aws_profile_default
    else
        set -gx AWS_PROFILE pit
    end
end
