#!/bin/bash

# Source the config file to load variables
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.cfg"

# Function to create an SSH key pair
create_ssh_key() {
    local GIT_REPO_NAME=$1
    local LOCAL_KEY_DIR=$2
    local LOCAL_KEY_NAME=$3
    local SSH_KEY_PATH="$HOME/.ssh/$LOCAL_KEY_NAME"

    echo "Creating ssh key \"$LOCAL_KEY_NAME\" for \"$GIT_REPO_NAME\""

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

# Function to check if a deploy key already exists
deploy_key_exists() {
    local GIT_REPO_NAME=$1
    local PUBLIC_KEY=$2

    existing_keys=$(gh api repos/"$GIT_USER_NAME"/"$GIT_REPO_NAME"/keys --jq '.[] | select(.key == "'"$PUBLIC_KEY"'")')
    if [ -n "$existing_keys" ]; then
        return 0 # Deploy key exists
    else
        return 1 # Deploy key does not exist
    fi
}

# Function to add deploy key to a GitHub repository
add_deploy_key() {
    local GIT_REPO_NAME=$1
    local LOCAL_KEY_NAME=$2
    local SSH_KEY_PATH="$HOME/.ssh/$LOCAL_KEY_NAME"
    local READ_ONLY=${3:-true}

    echo "Adding deploy key \"$LOCAL_KEY_NAME\" to repository \"$GIT_REPO_NAME\""
    PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

    gh api -X POST -H "Accept: application/vnd.github.v3+json" \
    repos/"$GIT_USER_NAME"/"$GIT_REPO_NAME"/keys \
    -f title="$LOCAL_KEY_NAME" -f key="$PUBLIC_KEY" -f read_only="$READ_ONLY" &>/dev/null

    if [ $? -eq 0 ]; then
        echo "Deploy key $LOCAL_KEY_NAME added to $GIT_REPO_NAME."
    else
        echo "Failed to add deploy key $LOCAL_KEY_NAME to $GIT_REPO_NAME."
    fi
}

for GIT_REPO_USER in "${GIT_REPO_USER_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME LOCAL_KEY_DIR LOCAL_KEY_NAME <<< "$GIT_REPO_USER"
    create_ssh_key "$GIT_REPO_NAME" "$LOCAL_KEY_DIR" "$LOCAL_KEY_NAME"
    add_deploy_key "$GIT_REPO_NAME" "$LOCAL_KEY_NAME"
done