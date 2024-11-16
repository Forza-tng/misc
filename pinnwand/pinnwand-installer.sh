#!/bin/bash

# Variables
USER="pinnwand"
HOME_DIR="/home/${USER}"
VENV_DIR="${HOME_DIR}/venv"
SRC_DIR="${HOME_DIR}/src"
PINNWAND_SRC="${SRC_DIR}/pinnwand"
USE_LOCAL_SRC="false"	 # Set to "true" to skip Git updates
REPO_URL="https://github.com/supakeen/pinnwand.git"
# Set to a specific tag (e.g., v1.6.0) or use "master" for the latest branch. Leave empty for automatic selection of latest release.
# GIT_REF="v1.6.0"

get_latest_tag_remote() {
	latest_tag=$(git ls-remote --tags "$REPO_URL" v\* | awk -F'/' '{print $3}' | sort -V | tail -n 1)
	echo "$latest_tag"
}

# Ensure the script is run as the specified user
if [ "$(whoami)" != "$USER" ]; then
	echo "This script must be run as the '$USER' user."
	echo "Try 'sudo -u $USER $0'"
	exit 1
fi

# Check if the source directory exists
if [ ! -d "$SRC_DIR" ]; then
	echo "Source directory '$SRC_DIR' does not exist. Please create it and try again."
	exit 1
fi

# Update or use the existing repository
if [ "$USE_LOCAL_SRC" = "true" ]; then
		echo "USE_LOCAL_SRC is set. Skipping Git updates and using the local source as is."
		if [ ! -d "$PINNWAND_SRC" ]; then
			echo "Pinnwand source directory not found."
		fi
else
	# Detect the latest tag if GIT_REF is not set
	GIT_REF="${GIT_REF:-}"
	
	if [ -z "$GIT_REF" ]; then
		echo "GIT_REF is not set. Detecting the latest tag from remote..."
		GIT_REF=$(get_latest_tag_remote)
		[ -z "$GIT_REF" ] && { echo "Failed to determine the latest tag."; exit 1; }
		echo "Using the latest tag: $GIT_REF"
	fi

	if [ ! -d "$PINNWAND_SRC" ]; then
		echo "Pinnwand source directory not found. Cloning the repository..."
		git clone "$REPO_URL" "$PINNWAND_SRC" || { echo "Failed to clone repository."; exit 1; }
	else
		echo "Pinnwand source directory found. Cleaning and updating from Git..."
		pushd "$PINNWAND_SRC" > /dev/null || { echo "Failed to navigate to $PINNWAND_SRC."; exit 1; }

		# Clean untracked files and directories first
		git clean -q -fd || { echo "Failed to clean untracked files."; exit 1; }

		# Reset the repository to ensure a clean state
		git fetch -q --all || { echo "Failed to fetch updates from repository."; exit 1; }
		git reset -q --hard "$GIT_REF" || { echo "Failed to reset to $GIT_REF."; exit 1; }
	
		popd > /dev/null
	fi
fi

echo "Source preparation complete."

exit
# Check if the virtual environment exists and is valid; create it if necessary
if [ ! -d "$VENV_DIR" ]; then
	echo "Virtual environment not found. Creating it now..."
	python3 -m venv "$VENV_DIR" || { echo "Failed to create virtual environment."; exit 1; }
elif [ ! -f "${VENV_DIR}/bin/activate" ]; then
	echo "Virtual environment directory exists but is invalid. Recreating it..."
	python3 -m venv "$VENV_DIR" || { echo "Failed to recreate virtual environment."; exit 1; }
fi

# Ensure pip is upgraded
echo "Upgrading pip..."
"${VENV_DIR}/bin/pip" install --upgrade pip || { echo "Failed to upgrade pip."; exit 1; }

# Install or upgrade Pinnwand from the source
echo "Installing/Upgrading Pinnwand from source..."
"${VENV_DIR}/bin/pip" install -v "$PINNWAND_SRC" || { echo "Failed to install Pinnwand."; exit 1; }

# Return to the original directory
popd || { echo "Failed to return to original directory."; exit 1; }

echo "Pinnwand installation/upgrade process completed successfully."