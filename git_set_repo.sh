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

# Function to create a repository
create_repository() {
    local GIT_REPO_NAME=$1
    local IS_PUBLIC=$2
    if [ "$IS_PUBLIC" = "true" ]; then
        gh repo create "$GIT_USER_NAME/$GIT_REPO_NAME" --public --confirm
    else
        gh repo create "$GIT_USER_NAME/$GIT_REPO_NAME" --private --confirm
    fi
}

# Function to initialize the local repository and create a branch
initialize_local_repo() {
    local GIT_REPO_NAME=$1
    local GIT_REPO_REMOTE_NAME=$2
    local GIT_BRANCH_NAME=$3
    local LOCAL_DIR=$4

    mkdir -p "$LOCAL_DIR"
    
    cd "$LOCAL_DIR" || exit

    if [ ! -d ".git" ]; then
        git init
    fi

    if ! git remote get-url $GIT_REPO_REMOTE_NAME > /dev/null 2>&1; then
        git remote add $GIT_REPO_REMOTE_NAME https://github.com/$GIT_USER_NAME/$GIT_REPO_NAME.git
    else
        git remote set-url $GIT_REPO_REMOTE_NAME https://github.com/$GIT_USER_NAME/$GIT_REPO_NAME.git
    fi

    git checkout -b "$GIT_BRANCH_NAME"

    if [ ! -f "README.md" ]; then
        echo "# $GIT_REPO_REMOTE_NAME" > README.md
        git add README.md
    else
        echo "README.md already exists in $LOCAL_DIR. Skipping initial commit."
        git add .
    fi

    git commit -m "Initial commit on $GIT_BRANCH_NAME"
    git push -u "$GIT_REPO_REMOTE_NAME" "$GIT_BRANCH_NAME"

    cd - || exit
}

# Main script to create repositories and set up branches
for git_repo in "${GIT_REPOSITORIES[@]}"; do
    IFS=',' read -r GIT_REPO_NAME IS_PUBLIC <<< "$git_repo"
    echo "Checking if repository $GIT_REPO_NAME exists..."
    if repository_exists "$GIT_REPO_NAME"; then
        echo "Repository $GIT_REPO_NAME already exists. Skipping creation."
    else
        echo "Creating repository: $GIT_REPO_NAME"
        create_repository "$GIT_REPO_NAME" "$IS_PUBLIC"
    fi
done

# Initialize local repositories with specified branches
for git_repo_detailed in "${GIT_REPO_DETAILED_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME GIT_REPO_REMOTE_NAME GIT_BRANCH_NAME LOCAL_DIR <<< "$git_repo_detailed"
    echo "Initializing local repository for $GIT_REPO_NAME in $LOCAL_DIR with branch $GIT_BRANCH_NAME"
    initialize_local_repo "$GIT_REPO_NAME" "$GIT_REPO_REMOTE_NAME" "$GIT_BRANCH_NAME" "$LOCAL_DIR"
done