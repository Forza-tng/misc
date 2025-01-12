#!/bin/bash

###
# Paste to a Pinnwand pastebin service
#
# This script uploads text content from files or stdin to a Pinnwand
# pastebin instance. It supports specifying expiry times, lexers for
# syntax highlighting.
#
# Features:
# - Upload content from files or stdin
# - Specify expiry times and lexers for syntax highlighting
# - Supports autodetection (if enabled by the server) or explicit
#   lexer selection
#
# Dependencies:
# - curl: For sending HTTP requests to the Pinnwand API
# - jq:   For parsing JSON responses and encoding input
# - file: For binary file detection
#
# SPDX-License-Identifier: CC0-1.0
###

# Base URL of the Pinnwand instance
PINNWAND_BASE_URL="${PINNWAND_BASE_URL:-https://gist.tnonline.net/api/v1}"

PASTE_URL="${PINNWAND_BASE_URL}/paste"
LEXER_URL="${PINNWAND_BASE_URL}/lexer"

# Default options
expiry="1day"
lexer="autodetect"

# Function to show help information
show_help() {
	local s
	s=$(basename "$0")
	cat <<END
Usage: $s [options] [file1 file2 ...]

Options:
  -e, --expiry <expiry>   Set the expiry time for the paste (e.g., 1day,
                          1hour). Default is '1day' if not specified.
  --expiries              List valid expiry periods.
  -l, --lexer <lexer>     Specify the lexer to use for syntax highlighting.
                          Default is 'autodetect' if not specified.
  --lexers                List all available lexers in 'name : description'
                          format.
  -h, --help              Show this help message and exit.

Examples:
  $s -e 1hour -l python file1 file2
  $s --lexers
  dmesg | $s -l kmsg
END
	exit 0
}


# Function to check if a file or input is binary
is_binary() {
	local input="$1"

	# Use the `file` command to check if the input is binary
	[[ "$(file --mime-encoding -b -L "$input")" == "binary" ]]
}

# Function to post content to Pinnwand
post_to_pinnwand() {
	local expiry="$1"
	local lexer="$2"
	shift 2
	local files=("$@")

	# Create temporary files for payload and response
	tmp_payload=$(mktemp 2>/dev/null) || { echo "Error: Failed to create a temporary file for payload"; exit 1; }
	tmp_response=$(mktemp 2>/dev/null) || { echo "Error: Failed to create a temporary file for response"; rm -f "$tmp_payload"; exit 1; }
	tmp_status=$(mktemp 2>/dev/null) || { echo "Error: Failed to create a temporary file for status code"; rm -f "$tmp_payload" "$tmp_response"; exit 1; }
	tmp_stdin=$(mktemp 2>/dev/null) || { echo "Error: Failed to create a temporary file for stdin"; rm -f "$tmp_payload" "$tmp_response" "$tmp_status"; exit 1; }
	trap 'rm -f "$tmp_payload" "$tmp_response" "$tmp_status" "$tmp_stdin"' EXIT

	# Prepare files array for JSON
	files_json="["

	if [[ "${#files[@]}" -gt 0 ]]; then
		# Add each file to the JSON array
		for file in "${files[@]}"; do
			if [[ -f "$file" ]]; then
				# Check if the file is binary
				if is_binary "$file"; then
					echo "Error: $file is a binary file. Only text files are allowed."
					exit 1
				fi

				content=$(<"$file" jq -Rs .)  # Read and JSON-encode file content
				files_json+="{\"name\":\"$(basename "$file")\",\"lexer\":\"$lexer\",\"content\":$content},"
			else
				echo "File not found: $file"
				exit 1
			fi
		done
	else
		# Write stdin to a temp file
		cat > "$tmp_stdin"

		# Check if stdin content is binary
		if is_binary "$tmp_stdin"; then
			echo "Error: Input from stdin is binary. Only text content is allowed."
			exit 1
		fi

		# Read and JSON-encode stdin content
		stdin_content=$(<"$tmp_stdin" jq -Rs .)
		files_json+="{\"name\":\"stdin\",\"lexer\":\"$lexer\",\"content\":$stdin_content},"
	fi

	# Remove trailing comma and close array
	files_json="${files_json%,}]"

	echo '{"expiry":"'"$expiry"'","files":'"$files_json"'}' > "$tmp_payload"

	# Send the payload using curl and save the response and HTTP status separately
	curl -s -o "$tmp_response" -w "%{http_code}" -X POST "$PASTE_URL" \
		-H "Content-Type: application/json" --data @"$tmp_payload" > "$tmp_status"

	# Extract HTTP status code and response body
	http_code=$(<"$tmp_status")
	response_body=$(<"$tmp_response")

	# Ensure http_code is a valid number
	if ! [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
		echo "Error: Failed to parse HTTP status code. Raw response:"
		cat "$tmp_response"
		exit 1
	fi

	# Check if the HTTP status code indicates success
	if [[ "$http_code" -ne 200 ]]; then
		echo "Error: Failed to create paste (HTTP $http_code). Response body:"
		echo "$response_body"
		exit 1
	fi

	# Extract link and removal URLs from the response body
	link=$(echo "$response_body" | jq -r '.link')
	removal=$(echo "$response_body" | jq -r '.removal')

	# Check if the response contains valid URLs
	if [[ -z "$link" || "$link" == "null" ]]; then
		echo "Error: Could not create paste. API response:"
		echo "$response_body"
		exit 1
	else
		echo "Paste URL:   $link"
		echo "Removal URL: $removal"
	fi
}

# Function to fetch and list available expiry times
list_expiries() {
	local expiries

	# Fetch expiry options from the API
	expiries=$(curl -s "$PINNWAND_BASE_URL/expiry" | jq -r 'keys_unsorted | join(" ")' 2>/dev/null)

	if [[ -z "$expiries" ]]; then
		echo "Error: Unable to fetch valid expiry options from the server."
		exit 1
	fi

	echo "Valid expiry times: $expiries"
	exit 0
}

# Function to list available lexers
list_lexers() {
	curl -s "$LEXER_URL" | jq -r '.'
	exit 0
}

# Parse command line options
while [ "$#" -gt 0 ]; do
	case $1 in
		-e|--expiry)
			if [[ -z "$2" || "$2" == -* ]]; then
				echo "Error: The --expiry option requires a value."
				exit 1
			fi
			expiry="$2"
			shift 2
			;;
		-l|--lexer)
			if [[ -z "$2" || "$2" == -* ]]; then
				echo "Error: The --lexer option requires a value."
				exit 1
			fi
			lexer="$2"
			shift 2
			;;
		--lexers)
			list_lexers
			;;
		--expiries)
			list_expiries
			;;
		-h|--help)
			show_help
			;;
		*)
			break
			;;
	esac
done

# Remaining arguments are assumed to be files
files=("$@")

# Post content from provided files or stdin
post_to_pinnwand "$expiry" "$lexer" "${files[@]}"

