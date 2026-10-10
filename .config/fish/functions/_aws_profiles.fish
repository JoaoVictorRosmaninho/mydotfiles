function _aws_profiles --description "Lista os perfis configurados no AWS CLI"
    set -l cfg $AWS_CONFIG_FILE
    test -n "$cfg"; or set cfg $HOME/.aws/config
    set -l cred $AWS_SHARED_CREDENTIALS_FILE
    test -n "$cred"; or set cred $HOME/.aws/credentials

    begin
        if test -f $cfg
            string match -rg '^\[\s*profile\s+(.+?)\s*\]' <$cfg
            string match -rg '^\[\s*(default)\s*\]' <$cfg
        end
        if test -f $cred
            string match -rg '^\[\s*(.+?)\s*\]' <$cred
        end
    end | sort -u
end
