function gc --wraps='git checkout' --description 'alias gs=git checkout'
    git checkout $argv
end
