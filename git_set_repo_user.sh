#!/bin/bash

# Source the config file to load variables
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.cfg"

# Read the GitHub token from the file
GIT_USER_NAME=$GIT_MASTER_USER_NAME
GIT_USER_TOKEN=$(cat "$GIT_MASTER_USER_TOKEN_PATH")

# GitHub API URL
GITHUB_API_URL="https://api.github.com"

# Function to create an SSH key pair
create_ssh_key() {
    local GIT_REPO_NAME=$1
    local LOCAL_KEY_DIR=$2
    local LOCAL_KEY_NAME=$3
    local SSH_KEY_PATH="$HOME/.ssh/$LOCAL_KEY_NAME"

    # Ensure the .ssh directory exists
    mkdir -p "$HOME/.ssh"

    if [ -f "$SSH_KEY_PATH" ]; then
        echo "SSH key $SSH_KEY_PATH already exists."
    else
        ssh-keygen -t rsa -b 4096 -C "$LOCAL_KEY_NAME" -f "$SSH_KEY_PATH" -N ""
        echo "SSH key $SSH_KEY_PATH created."
    fi

    cp "$SSH_KEY_PATH" "$LOCAL_KEY_DIR"
    cp "$SSH_KEY_PATH.pub" "$LOCAL_KEY_DIR"
}

# Function to add deploy key to a GitHub repository
add_deploy_key() {
    local GIT_REPO_NAME=$1
    local LOCAL_KEY_DIR=$2
    local LOCAL_KEY_NAME=$3
    local SSH_KEY_PATH="$HOME/.ssh/$LOCAL_KEY_NAME"
    local READ_ONLY=${4:-true}

    PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

    curl -s -X POST -H "Authorization: token $GIT_USER_TOKEN" -H "Accept: application/vnd.github.v3+json" \
    -d "{\"title\":\"$LOCAL_KEY_NAME\",\"key\":\"$PUBLIC_KEY\",\"read_only\":$READ_ONLY}" \
    "$GITHUB_API_URL/repos/$GIT_USER_NAME/$GIT_REPO_NAME/keys"

    if [ $? -eq 0 ]; then
        echo "Deploy key $LOCAL_KEY_NAME added to $GIT_REPO_NAME."
    else
        echo "Failed to add deploy key $LOCAL_KEY_NAME to $GIT_REPO_NAME."
    fi
}

for git_repo_user_info in "${GIT_REPO_USER_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME LOCAL_KEY_DIR LOCAL_KEY_NAME <<< "$git_repo_user_info"
    echo "Creating ssh key \"$LOCAL_KEY_NAME\" for \"$GIT_REPO_NAME\""
    create_ssh_key "$GIT_REPO_NAME" "$LOCAL_KEY_DIR" "$LOCAL_KEY_NAME"
    echo "Adding deploy key \"$LOCAL_KEY_NAME\" to repository \"$GIT_REPO_NAME\""
    add_deploy_key "$GIT_REPO_NAME" "$LOCAL_KEY_DIR" "$LOCAL_KEY_NAME"
done