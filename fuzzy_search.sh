#!/bin/bash

# Path to the file where suggestions will be stored
suggestions_file="$HOME/.fuzzy_search_suggestions.txt"

# Function to read suggestions from file
load_suggestions() {
    if [[ -f "$suggestions_file" ]]; then
        # Read suggestions from the file into an array
        mapfile -t items < "$suggestions_file"
    else
        # If no suggestions file exists, start with an empty list
        items=()
    fi
}

# Function to save suggestions to the file
save_suggestions() {
    # Save the suggestions array to the file
    printf "%s\n" "${items[@]}" > "$suggestions_file"
}

# Function to perform the filtering
fuzzy_find() {
    local query="$1"
    local filtered=()

    # Skip suggestions if the query is empty or just spaces
    if [[ -z "${query// /}" ]]; then
        # If the query is all spaces, return an empty suggestion
        echo -n ""
        return
    fi

    # Loop through items and match the query (case-insensitive matching)
    for item in "${items[@]}"; do
        if [[ "$item" =~ $query ]]; then
            filtered+=("$item")
        fi
    done

    # Return the first match
    echo -n "${filtered[0]}"
}

# Function to apply lowlight effect to the suggested part
apply_lowlight() {
    local query="$1"
    local suggestion="$2"

    # Check if there is a suggestion and it matches the query
    if [[ -n "$suggestion" && "$suggestion" != "$query" ]]; then
        # Apply lowlight effect (dim the part that is suggested)
        local suggestion_len=${#query}
        local rest_of_suggestion=${suggestion:$suggestion_len}

        # ANSI escape codes to dim text (lowlight)
        # '\e[2m' is for dimming the text
        # '\e[0m' resets formatting to normal
        echo -en "$query\e[2m$rest_of_suggestion\e[0m"
    else
        echo -n "$query"
    fi
}

# Function to handle user input with dynamic suggestions and autocomplete
interactive_search() {
    local query=""
    local suggested=""
    local input=""

    # Loop for dynamic input
    while true; do
        # Move the cursor to the beginning of the line and clear it after "Search: "
        tput sc  # Save cursor position
        tput el  # Clear the line from cursor to end
        echo -n "Search: "

        # Display the current query on the same line, followed by the suggestion
        suggested=$(fuzzy_find "$query")

        # Show the query and the lowlighted suggestion
        apply_lowlight "$query" "$suggested"

        # Read a single character of input for filtering
        IFS= read -r -s -n 1 input

        # Handle the Backspace key (ASCII value 127) and Shift + Backspace (ASCII value 8)
        if [[ "$input" == $'\x7f' || "$input" == $'\x08' ]]; then
            # Remove the last character from the query (fixing backspace issue)
            query="${query%${query: -1}}"
        # Handle the Enter key to select the current query
        elif [[ "$input" == "" ]]; then
            echo -e "\nYou selected: $query"
            break
        # Handle the Tab key for autocomplete (do not exit the script)
        elif [[ "$input" == $'\x09' ]]; then
            # Autocomplete the suggestion
            query="$suggested"
        else
            # Add the typed character to the query
            query="$query$input"
        fi

        tput rc  # Restore cursor position
    done

    # Check if the query already exists in the items list before adding
    if [[ ! " ${items[@]} " =~ " ${query} " ]]; then
        items+=("$query")
        save_suggestions  # Save the updated suggestions to the file
    fi

    # Return the final value of query when the function finishes
    echo "$query"
}

# Main script execution
load_suggestions  # Load existing suggestions from the file
interactive_search  # Run the interactive search
