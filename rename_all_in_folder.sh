#!/bin/bash
GEMINI_API_KEY=""

# Configuration
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/api_responses.log"
NO_ITEM_STRING="NO_ITEM_FOUND_IN_IMAGE"

# Variables you will need to adjust for your program to run correctly.
GEMINI_PROMPT="Analyze the image and tell me the **exact full name of the perfume** in the image. If you cannot find the perfume in the image, respond with '$NO_ITEM_STRING'."
IMAGE_PREPEND="Shop-for-"
IMAGE_APPEND="-perfume-fragrance-online-and-in-nebraska"

GEMINI_API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"

# Log Directory
if [ ! -d "$LOG_DIR" ]; then 
  mkdir -p "$LOG_DIR"
fi

# Counter to track requests
counter=0

# Start logging
echo "Starting image processing - $(date)" >> $LOG_FILE

# Process each image
for dir in */; do
  for file in *; do
    echo "The Filename: ${file}";

    # Ensure the file exists and is a valid image
    [ -f "$file" ] || continue

    echo "Processing: ${file}" >> "${LOG_FILE}" 

    # Convert image to base64
    BASE64_IMAGE=$(base64 -i "$file")

    # Send request using multipart form-data
    RESPONSE=$(curl -s -X POST "$GEMINI_API_URL" \
      -H "x-goog-api-key: $GEMINI_API_KEY" \
      -H "Content-Type: application/json" \
      -d '{
          "contents": [
            {
              "parts": [
                {
                  "text": "'"$GEMINI_PROMPT"'"
                },
                {
                  "inlineData": {
                    "mimeType": "image/webp",
                    "data": "'"$BASE64_IMAGE"'"
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "temperature": 0.0,
            "topP": 0.1,
            "maxOutputTokens": 300
          }
        }')
    
    # Log the raw API response
    echo "AI API Response for $file: $RESPONSE" >> "${LOG_FILE}" 

    # Extract the response text and handle potential errors
    ITEM_NAME=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text' 2>/dev/null)

    if [[ "$ITEM_NAME" == "$NO_PRODUCT_STRING" ]]; then
      echo "No prompt item detected in: $file" | tee -a "${LOG_FILE}" 
    fi

    # Check if the response is valid
    if [[ -z "$ITEM_NAME" || "$ITEM_NAME" == "null" ]]; then
        echo "Error: No valid response from API for $file" | tee -a "${LOG_FILE}";

        # Increment the counter
        ((counter++))

        # Throttle every 15 requests (to avoid hitting the rate limit)
        if ((counter % 15 == 0)); then
          echo "Sleeping for 60 seconds to avoid API rate limit..."
          sleep 60
        fi

        continue;
    fi

    EXT="${file##*.}"  # Get file extension

    # Rename the file if a product name is detected
    if [[ "$ITEM_NAME" != "$NO_PRODUCT_STRING" ]]; then
        SAFE_NAME=$(echo "$ITEM_NAME" | tr ' /' '-' | tr ' ' '-' |  tr -d '"' | tr -cd '[:alnum:]_-') # Sanitize filename
        NEW_NAME="${ITEM_IMAGE_PREPEND}${SAFE_NAME}${IMAGE_APPEND}.$EXT"

        # Rename the file if it's different
        if [ "$file" != "$NEW_NAME" ]; then
            mv "$file" "$NEW_NAME"
            echo "Renamed: $file -> $NEW_NAME" | tee -a "${LOG_FILE}" 
        fi
    fi

    # Increment the counter
    ((counter++))

    # Throttle every 15 requests (to avoid hitting the rate limit)
    if ((counter % 15 == 0)); then
      echo "Sleeping for 60 seconds to avoid API rate limit..."
      sleep 60
    fi
  done;
done

echo "Processing complete! Log file: $LOG_FILE"