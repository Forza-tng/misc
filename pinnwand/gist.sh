#!/bin/bash

# Base URL of the Pinnwand instance
PINNWAND_BASE_URL="https://gist.tnonline.net/api/v1"
PASTE_URL="${PINNWAND_BASE_URL}/paste"
LEXER_URL="${PINNWAND_BASE_URL}/lexer"

# Default options
expiry="1day"
lexer="text"

# Function to show help information
show_help() {
	local s
	s=$(basename "$0")
	cat <<END
Usage: $s [options] [file1 file2 ...]

Options:
  -e, --expiry <expiry>   Set the expiry time for the paste (e.g., 1day, 1hour).
                          Default is '1day' if not specified.
  -l, --lexer <lexer>     Specify the lexer to use for syntax highlighting.
                          Default is 'text' if not specified.
  --lexers                List all available lexers in 'name : description' format.
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

	if [[ -f "$input" ]]; then
		# If input is a file, check directly with file command
		[[ "$(file --mime-encoding -b -L "$input")" == "binary" ]]
	else
		# If input is from stdin, use grep to check for binary content
		grep -qI . <<< "$input"
		return $?  # Return 0 for text, non-zero for binary
	fi
}

# Function to post content to Pinnwand
post_to_pinnwand() {
	local expiry="$1"
	local lexer="$2"
	shift 2
	local files=("$@")
	
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
		# If no files were provided, read from stdin
		stdin_content=$(cat | jq -Rs .)  # Read and JSON-encode stdin content
		# Check if stdin content is binary
		if is_binary "$stdin_content"; then
			echo "Error: Input from stdin is binary. Only text content is allowed."
			exit 1
		fi
		files_json+="{\"name\":\"stdin\",\"lexer\":\"$lexer\",\"content\":$stdin_content},"
	fi

	# Remove trailing comma and close array
	files_json="${files_json%,}]"

	response=$(curl -s -X POST "$PASTE_URL" \
		-H "Content-Type: application/json" \
		-d '{"expiry":"'"$expiry"'","files":'"$files_json"'}' )


	# Extract link and removal URLs from the response
	link=$(echo "$response" | jq -r '.link')
	removal=$(echo "$response" | jq -r '.removal')

	# Check if the response contains a URL
	if [[ "$response" == null ]]; then
		echo "Error: Could not create paste"
		exit 1
	else
		echo "Paste URL:   $link"
		echo "Removal URL: $removal"
	fi
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
			expiry="$2"
			shift 2
			;;
		-l|--lexer)
			lexer="$2"
			shift 2
			;;
		--lexers)
			list_lexers
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
