function gs --wraps='git checkout' --wraps='git status' --description 'alias gs=git status'
    git status $argv
end
