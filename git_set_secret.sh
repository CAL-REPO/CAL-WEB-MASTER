#!/bin/bash

# Source the config file to load variables
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.cfg"

# Main script to create repositories and set secrets
for GIT_REPO_SECRET in "${GIT_REPO_SECRET_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME GIT_SECRET_DIR <<< "$GIT_REPO_SECRET"
    echo "Processing repository: $GIT_REPO_NAME, directory: $GIT_SECRET_DIR"

    # Loop through all CSV files in the directory
    for GIT_SECRET_CSV in "$GIT_SECRET_DIR"/*.csv; do
        if [ -f "$GIT_SECRET_CSV" ]; then
            # Read and base64 encode the CSV file content
            GIT_SECRET_CSV_ENCODED=$(base64 -w 0 "$GIT_SECRET_CSV")
            GIT_SECRET_CSV_NAME=$(basename "$GIT_SECRET_CSV" .csv)_ENCODED
            # Set the secret using GitHub CLI
            echo "Setting secret $GIT_SECRET_CSV_NAME for repository $GIT_REPO_NAME"
            gh secret set "$GIT_SECRET_CSV_NAME" --repo "$GIT_USER_NAME/$GIT_REPO_NAME" --body "$GIT_SECRET_CSV_ENCODED"

            echo "Stored secret: $GIT_SECRET_CSV_NAME in repository: $GIT_REPO_NAME"
        else
            echo "No CSV files found in directory $GIT_SECRET_DIR."
        fi
    done
done