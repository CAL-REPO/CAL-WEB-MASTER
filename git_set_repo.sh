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
    gh repo create "$GIT_USER_NAME/$GIT_REPO_NAME" --${IS_PUBLIC:+"public"}${IS_PUBLIC:+"private"} --confirm
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
for git_repo_info in "${GIT_REPO_BRANCH_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME GIT_REPO_REMOTE_NAME GIT_BRANCH_NAME LOCAL_DIR <<< "$git_repo_info"
    echo "Initializing local repository for $GIT_REPO_NAME in $LOCAL_DIR with branch $GIT_BRANCH_NAME"
    initialize_local_repo "$GIT_REPO_NAME" "$GIT_REPO_REMOTE_NAME" "$GIT_BRANCH_NAME" "$LOCAL_DIR"
done


# # Function to pull, merge, and push a specific subtree branch
# pull_merge_push_subtree_branch() {
#     local BRANCH_NAME=$1
#     local DIRECTORY=$2
#     local GIT_REPO_REMOTE_NAME=$3

#     # Ensure directory exists
#     mkdir -p "$DIRECTORY"

#     # Fetch latest updates from remote
#     git fetch $GIT_REPO_REMOTE_NAME

#     # Check if branch exists remotely
#     if git ls-remote --exit-code --heads $GIT_REPO_REMOTE_NAME $BRANCH_NAME; then
#         git checkout $BRANCH_NAME
#         # Try pulling the latest changes from the remote subtree
#         if ! git subtree pull --prefix="$DIRECTORY" $GIT_REPO_REMOTE_NAME $BRANCH_NAME -m "Merge changes from $BRANCH_NAME into $DIRECTORY"; then
#             echo "Conflict detected while merging changes from $BRANCH_NAME into $DIRECTORY. Please resolve conflicts manually."
#             exit 1
#         fi
#     else
#         # Branch does not exist remotely, create it
#         git checkout -b $BRANCH_NAME
#         git subtree push --prefix="$DIRECTORY" $GIT_REPO_REMOTE_NAME $BRANCH_NAME
#     fi

#     # Check for changes in the directory
#     if [ -n "$(git status --porcelain "$DIRECTORY")" ]; then
#         # Add and commit changes in the directory
#         git add "$DIRECTORY"
#         git commit -m "Update directory $DIRECTORY in branch $BRANCH_NAME"
#     else
#         echo "No changes to commit in directory $DIRECTORY for branch $BRANCH_NAME."
#     fi

#     # Push the subtree to the remote repository
#     git subtree push --prefix="$DIRECTORY" $GIT_REPO_REMOTE_NAME $BRANCH_NAME
# }

# # Copy pre-push script into .git/hooks directory
# cp "$SCRIPT_DIR/pre-push" ".git/hooks/pre-push"
# chmod +x ".git/hooks/pre-push"

# # Configure Git to use HTTPS with the personal access token
# configure_git_remote_https "$GIT_USER_NAME" "$GIT_USER_TOKEN" "$GIT_REPO_NAME"