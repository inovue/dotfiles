function rm_git_submodule() {
    if [ -z "$1" ]; then
        echo "Usage: rm_git_submodule <submodule-path>"
        return 1
    fi
    local submodule_path=$1

    echo "Deinitializing submodule '$submodule_path'..."
    git submodule deinit -f "$submodule_path"

    echo "Removing submodule '$submodule_path'..."
    git rm -f "$submodule_path"

    echo "Removing submodule '$submodule_path'..."
    rm -rf ".git/modules/$submodule_path"
    
    echo "Submodule '$submodule_path' removed successfully."
}
