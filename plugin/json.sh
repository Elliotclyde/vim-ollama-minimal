#!/bin/bash

# JSON parser state machine
STATE="START"
DEPTH=0
IN_STRING=false
ESCAPE=false
KEY=""
RESPONSE_VALUE=""
FOUND_RESPONSE=false

while IFS= read -r -n1 CHAR; do
    case "$STATE" in
        "START")
            if [[ "$CHAR" == "{" ]]; then
                STATE="IN_TOP_OBJECT"
                DEPTH=1
            fi
            ;;
        "IN_TOP_OBJECT")
            if ! $IN_STRING; then
                if [[ "$CHAR" == "\"" ]]; then
                    IN_STRING=true
                    KEY=""
                elif [[ "$CHAR" == "}" ]]; then
                    DEPTH=$((DEPTH - 1))
                    if (( DEPTH == 0 )); then
                        STATE="END"
                    fi
                elif [[ "$CHAR" == "{" ]]; then
                    DEPTH=$((DEPTH + 1))
                fi
            else
                if $ESCAPE; then
                    ESCAPE=false
                elif [[ "$CHAR" == "\\" ]]; then
                    ESCAPE=true
                elif [[ "$CHAR" == "\"" ]]; then
                    IN_STRING=false
                    if [[ "$KEY" == "response" && $DEPTH == 1 ]]; then
                        STATE="FIND_RESPONSE_VALUE"
                    fi
                else
                    KEY+="$CHAR"
                fi
            fi
            ;;
        "FIND_RESPONSE_VALUE")
            if ! $IN_STRING; then
                if [[ "$CHAR" == ":" ]]; then
                    continue
                elif [[ "$CHAR" == "\"" ]]; then
                    IN_STRING=true
                    RESPONSE_VALUE=""
                    FOUND_RESPONSE=true
                    STATE="READ_RESPONSE_VALUE"
                else
                    # Not a string value, ignore
                    STATE="IN_TOP_OBJECT"
                fi
            fi
            ;;
        "READ_RESPONSE_VALUE")
            if $ESCAPE; then
                RESPONSE_VALUE+="\\$CHAR"
                ESCAPE=false
            elif [[ "$CHAR" == "\\" ]]; then
                ESCAPE=true
            elif [[ "$CHAR" == "\"" ]]; then
                IN_STRING=false
                STATE="END"
                break
            else
                RESPONSE_VALUE+="$CHAR"
            fi
            ;;
        "END")
            break
            ;;
    esac
done

if $FOUND_RESPONSE; then
    echo -n "$RESPONSE_VALUE"
else
    echo "Error: 'response' key not found in top-level object" >&2
    exit 1
fi
