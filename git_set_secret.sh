#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Source the config file to load variables
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/config.cfg"

# Read the GitHub token from the file
GIT_USER_NAME=$GIT_MASTER_USER_NAME
GIT_USER_TOKEN=$(cat "$GIT_MASTER_USER_TOKEN_PATH")

# GitHub API URL
GITHUB_API_URL="https://api.github.com"

# Function to get the public key for a repository
get_public_key() {
    local GIT_REPO_NAME=$1

    curl -s -H "Authorization: Bearer $GIT_USER_TOKEN" \
        -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
        "$GITHUB_API_URL/repos/$GIT_USER_NAME/$GIT_REPO_NAME/actions/secrets/public-key"
}

# Function to format the public key into PEM format
format_public_key() {
    local PUBLIC_KEY=$1
    echo "-----BEGIN PUBLIC KEY-----"
    echo "$PUBLIC_KEY" | sed 's/.\{64\}/&\n/g'
    echo "-----END PUBLIC KEY-----"
}

# Function to encrypt the secret value using the public key
encrypt_secret() {
    local SECRET_VALUE=$1
    local PUBLIC_KEY=$2

    # Create a temporary file for the public key
    PUB_KEY_FILE=$(mktemp)
    echo "$PUBLIC_KEY" | base64 --decode > "$PUB_KEY_FILE"

    # Encrypt and encode
    ENCRYPTED_SECRET=$(echo -n "$SECRET_VALUE" | openssl pkeyutl -encrypt -pubin -inkey "$PUB_KEY_FILE" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 | base64 -w 0)

    # Clean up
    rm -f "$PUB_KEY_FILE"

    echo "$ENCRYPTED_SECRET"
}

# Function to set a secret on a GitHub repository
set_github_secret() {
    local GIT_REPO_NAME=$1
    local GIT_SECRET_NAME=$2
    local ENCRYPTED_SECRET=$3
    local KEY_ID=$4


    # Get the public key
    PUBLIC_KEY_RESPONSE=$(get_public_key "$REPO")
    PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r .key)
    KEY_ID=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r .key_id)

    # Encrypt the secret
    ENCRYPTED_SECRET=$(encrypt_secret "$SECRET_VALUE" "$PUBLIC_KEY")

    # Prepare the payload
    PAYLOAD=$(jq -n \
                  --arg enc_value "$ENCRYPTED_SECRET" \
                  --arg key_id "$KEY_ID" \
                  '{"encrypted_value": $enc_value, "key_id": $key_id}')

    echo "Payload prepared:"
    echo "$PAYLOAD" | jq .

    # URL encode the secret name
    ENCODED_SECRET_NAME=$(printf %s "$SECRET_NAME" | jq -sRr @uri)

    # Set the secret
    RESPONSE=$(curl -s -X PUT \
        -H "Authorization: token $GIT_USER_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "$GITHUB_API_URL/repos/$GIT_USER_NAME/$REPO/actions/secrets/$ENCODED_SECRET_NAME" \
        -d "$PAYLOAD" \
        -w "\nStatus Code: %{http_code}")

    echo "API Response for $SECRET_NAME:"
    echo "$RESPONSE"

    # RESPONSE=$(curl -s -X PUT \
    #     -H "Authorization: token $GIT_USER_TOKEN" \
    #     -H "Accept: application/vnd.github.v3+json" \
    #     "$FULL_URL" \
    #     -d "{\"encrypted_value\":\"$SECRET_VALUE\",\"visibility\":\"all\"}" \
    #     -w "\nStatus Code: %{http_code}")

    # echo "API Response:"
    # echo "$RESPONSE"

    # if [[ "$RESPONSE" == *"Status Code: 204"* ]]; then
    #     echo "Secret successfully set."
    # else
    #     echo "Failed to set secret. Please check the response for more details."
    # fi
}

# Process each entry in GIT_REPO_SECRET_LIST
for GIT_REPO_SECRET in "${GIT_REPO_SECRET_LIST[@]}"; do
    IFS=',' read -r GIT_REPO_NAME SECRET_DIR <<< "$GIT_REPO_SECRET"
    echo "Processing repository: $GIT_REPO_NAME, directory: $SECRET_DIR"
    
    # # Get the public key for the repository
    # PUB_KEY_RESPONSE=$(get_public_key "$GIT_REPO_NAME")
    # PUB_KEY=$(echo "$PUB_KEY_RESPONSE" | jq -r .key)
    # KEY_ID=$(echo "$PUB_KEY_RESPONSE" | jq -r .key_id)

    # if [[ -z "$PUB_KEY" || -z "$KEY_ID" ]]; then
    #     echo "Failed to retrieve public key for repository $GIT_REPO_NAME. Response: $PUB_KEY_RESPONSE"
    #     continue
    # fi

    # Loop through all CSV files in the directory
    for SECRET_CSV_FILE in "$SECRET_DIR"/*.csv; do
        if [ -f "$SECRET_CSV_FILE" ]; then
            # Extract the file name without extension to use as secret name
            secret_name=$(basename "$SECRET_CSV_FILE" .csv)

            # Read the CSV file content and base64 encode it
            secret_value=$(cat "$SECRET_CSV_FILE")
            
            # Get the public key to encrypt the secret
            response=$(curl -s -H "Authorization: token $GIT_USER_TOKEN" \
                            "$GITHUB_API_URL/repos/$GIT_USER_NAME/$GIT_REPO_NAME/actions/secrets/public-key")
            
            key_id=$(echo "$response" | jq -r '.key_id')
            public_key=$(echo "$response" | jq -r '.key')

            # Decode the public key from base64 and store in a temporary file
            echo "$public_key" | base64 -d > public_key.pem

            # Encrypt the secret value using the public key
            encrypted_value=$(echo -n "$secret_value" | openssl rsautl -encrypt -inkey public_key.pem -pubin | base64 | tr -d '\n')
            
            # Clean up the temporary file
            rm public_key.pem

            echo $encrypted_value

            # # Create or update the secret
            # curl -X PUT -H "Authorization: token $GIT_USER_TOKEN" \
            #     -H "Content-Type: application/json" \
            #     -d "{\"encrypted_value\":\"$encrypted_value\",\"key_id\":\"$key_id\"}" \
            #     "$GITHUB_API_URL/repos/$GIT_USER_NAME/$GIT_REPO_NAME/actions/secrets/$secret_name"
            
            # echo "Stored secret: $secret_name"
        fi
    done
done

# # Process secret CSV files
# for SECRET_CSV_FILE in "$GIT_REPO_SECRET_LIST"/*.csv
# do
#     if echo "$SECRET_CSV_FILE" | grep -E '^([A-Za-z0-9+/=]|[\t\n\f\r ])*$' >/dev/null; then
#         SECRET_CSV_FILE_ENCODED=$(cat "$SECRET_CSV_FILE")
#         echo "The data is base64 (encoded) data."
#     else
#         SECRET_CSV_FILE_ENCODED=$(cat "$SECRET_CSV_FILE" | base64 -w 0)
#         echo "The data is encoded from csv data to base64 encoded data."
#     fi

#     SECRET_CSV_FILE_NAME="$(basename $SECRET_CSV_FILE)"
#     SECRET_CSV_FILE_PURE_NAME="${SECRET_CSV_FILE_NAME%.*}"
    
#     gh secret set "$SECRET_CSV_FILE_PURE_NAME"_ENCODED --repo "$GIT_USER_NAME/$GIT_REPO_NAME" --body "$SECRET_CSV_FILE_ENCODED"
# done