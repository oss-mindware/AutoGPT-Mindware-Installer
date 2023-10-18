#!/bin/bash

set -e  # If a command fails, stop the script

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker could not be found."
    echo "Please install Docker and then re-run this script."
    exit 1
fi

# Set up necessary variables
ROOT_DIR=$(pwd)
PARENT_DIR=$(dirname "$ROOT_DIR")
WORKDIR="../AutoGPT"
ENV_FILE=".env"
AI_SETTINGS_FILE="ai_settings.yaml"
PLUGINS_CONFIG_FILE="plugins_config.yaml"
DOCKER_COMPOSE_FILE="docker-compose.yml"
PLUGINS_DIR="plugins"

# Create directory for AutoGPT and navigate into it, if it doesn't exist
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Create necessary files if they don't exist
touch "$ENV_FILE"
touch "$AI_SETTINGS_FILE"

# Function to ask for API keys
ask_for_api_key() {
    local key_name="$1"
    local prompt_msg="$2"
    echo "$prompt_msg"
    read -r api_key
    echo "${key_name}=${api_key}" >> "$ENV_FILE"
}

# Ask the user for their OPENAI_API_KEY and write the response to the .env file
ask_for_api_key "OPENAI_API_KEY" "Please enter your OpenAI API key:"

# Ask the user for their MINDWARE_API_KEY and write the response to the .env file
ask_for_api_key "MINDWARE_API_KEY" "Please enter your Mindware API key:"

# Create plugins_config.yaml file if it doesn't exist
if [ ! -f "$PLUGINS_CONFIG_FILE" ]; then
    YAML_CONTENT="MindwarePlugin:\n  config: {}\n  enabled: true\n"
    echo -e "$YAML_CONTENT" > "$PLUGINS_CONFIG_FILE"
fi

# Create docker-compose.yml file if it doesn't exist
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    DOCKER_COMPOSE_CONTENT="version: \"3.9\"
services:
  auto-gpt:
    image: significantgravitas/auto-gpt
    env_file:
      - .env
    profiles: [\"exclude-from-up\"]
    volumes:
      - ./auto_gpt_workspace:/app/auto_gpt_workspace
      - ./data:/app/data
      - ./logs:/app/logs
      - ./plugins:/app/plugins
      - type: bind
        source: ./ai_settings.yaml
        target: /app/ai_settings.yaml
      - type: bind
        source: ./plugins_config.yaml
        target: /app/plugins_config.yaml"
    echo "$DOCKER_COMPOSE_CONTENT" > "$DOCKER_COMPOSE_FILE"
fi

# Pull the necessary Docker image
docker pull significantgravitas/auto-gpt

# Create directory for plugins if it doesn't exist and navigate into it
mkdir -p "$PLUGINS_DIR"
cd "$PLUGINS_DIR"

# Pull the latest Mindware repository, zip it, and clean up
if [ ! -d "AutoGPT-Mindware" ]; then
    git clone https://github.com/open-mindware/AutoGPT-Mindware.git
    zip -r ./AutoGPT-Mindware.zip ./AutoGPT-Mindware
    rm -rf ./AutoGPT-Mindware
fi

# Clean up installer and navigate to AutoGPT directory
cd "$PARENT_DIR" && rm -rf ./AutoGPT-Mindware-Installer && cd ./AutoGPT

# Run the Docker container
docker compose run --rm auto-gpt --install-plugin-deps