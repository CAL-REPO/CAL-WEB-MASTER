#!/bin/bash

# Source the config file to load variables
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.cfg"

# Function to check if a repository already exists
repository_exists() {
    local GIT_REPO_NAME=$1
    if gh repo view "$GIT_USER_NAME/$GIT_REPO_NAME" > /dev/null 2>&1; then
        return 0 # Repository exists
    else
        return 1 # Repository does not exist
    fi
}

# Function to delete a repository
delete_repository() {
    local GIT_REPO_NAME=$1
    gh repo delete "$GIT_USER_NAME/$GIT_REPO_NAME" --confirm
}

# Function to delete local .git directory
delete_local_git_directory() {
    local LOCAL_DIR=$1
    if [ -d "$LOCAL_DIR/.git" ]; then
        echo "Deleting .git directory in $LOCAL_DIR"
        rm -rf "$LOCAL_DIR/.git"
    else
        echo "No .git directory found in $LOCAL_DIR. Skipping."
    fi
}

# Main script to delete repositories
for git_repo in "${GIT_REPOSITORIES[@]}"; do
    IFS=',' read -r GIT_REPO_NAME IS_PUBLIC <<< "$git_repo"
    echo "Checking if repository $GIT_REPO_NAME exists..."
    if repository_exists "$GIT_REPO_NAME"; then
        echo "Deleting repository: $GIT_REPO_NAME"
        delete_repository "$GIT_REPO_NAME"
    else
        echo "Repository $GIT_REPO_NAME does not exist. Skipping deletion."
    fi
done

# Delete local .git directories for specified branches
for repo_info in "${GIT_REPO_BRANCH_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME GIT_REPO_REMOTE_NAME GIT_BRANCH_NAME LOCAL_DIR <<< "$repo_info"
    echo "Deleting local .git directory for $GIT_REPO_NAME in $LOCAL_DIR"
    delete_local_git_directory "$LOCAL_DIR"
done

echo "All specified repositories have been processed."
