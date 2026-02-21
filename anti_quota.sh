#!/bin/bash

# anti_quota.sh
# Finds the Google Antigravity language_server process, extracts the CSRF token,
# finds the connection port, and queries the user status / quota info.

DUMP_JSON=0
for arg in "$@"; do
    case $arg in
        -h|--help)
        echo "Usage: anti_quota.sh [OPTIONS]"
        echo ""
        echo "Queries the Antigravity Language Server for user quota and status."
        echo ""
        echo "Options:"
        echo "  -h, --help           Show this help message and exit"
        echo "  -j, --json, --raw    Dump the raw JSON response instead of the formatted summary"
        exit 0
        ;;
        -j|--json|--raw)
        DUMP_JSON=1
        shift
        ;;
    esac
done

# 1. Find the language server process IDs
PIDS=$(pgrep -f "language_server")

if [ -z "$PIDS" ]; then
    echo "Error: Antigravity language_server process not found."
    exit 1
fi

for PID in $PIDS; do
    # Get the full command line for this PID
    CMD=$(ps -p "$PID" -o args=)
    
    # 2. Extract CSRF token using GNU grep
    CSRF_TOKEN=$(echo "$CMD" | grep -oP -- '--csrf_token[=\s]\K([a-zA-Z0-9\-]+)')
    
    # Fallback to sed if grep -oP fails (e.g., on macOS)
    if [ -z "$CSRF_TOKEN" ]; then
        CSRF_TOKEN=$(echo "$CMD" | sed -n 's/.*--csrf_token[= ]\([a-zA-Z0-9\-]\+\).*/\1/p')
    fi

    if [ -z "$CSRF_TOKEN" ]; then
        continue # Skip if no CSRF token found in args
    fi

    # 3. Find listening TCP ports for this PID
    # Try using ss first
    PORTS=$(ss -tlnp 2>/dev/null | grep "pid=$PID," | awk '{print $4}' | awk -F: '{print $NF}' | sort -u)
    
    # Fallback to lsof if ss output is empty
    if [ -z "$PORTS" ]; then
        PORTS=$(lsof -nP -a -iTCP -sTCP:LISTEN -p "$PID" 2>/dev/null | grep -i listen | awk '{print $9}' | awk -F: '{print $NF}' | sort -u)
    fi
    
    # 4. Test each listening port
    for PORT in $PORTS; do
        # We query the GetUserStatus gRPC-web endpoint using JSON
        RESPONSE=$(curl -s -k -m 2 -X POST "https://127.0.0.1:$PORT/exa.language_server_pb.LanguageServerService/GetUserStatus" \
            -H "Content-Type: application/json" \
            -H "Connect-Protocol-Version: 1" \
            -H "X-Codeium-Csrf-Token: $CSRF_TOKEN" \
            -d '{"metadata":{"ideName":"antigravity","extensionName":"antigravity","locale":"en"}}')
        
        # Check if the response contains 'userStatus' which indicates success
        if echo "$RESPONSE" | grep -q 'userStatus'; then
            if [ "$DUMP_JSON" -eq 1 ]; then
                if command -v jq &>/dev/null; then
                    echo "$RESPONSE" | jq .
                elif command -v python3 &>/dev/null; then
                    echo "$RESPONSE" | python3 -m json.tool
                else
                    echo "$RESPONSE"
                fi
                exit 0
            fi

            echo "Successfully found Antigravity Language Server!"
            echo "PID: $PID | Port: $PORT"
            echo "----------------------------------------"
            
            # Extract and display specific fields using awk
            echo "$RESPONSE" | awk '
            BEGIN {
                GREEN = "\033[32m"
                YELLOW = "\033[33m"
                RED = "\033[31m"
                RESET = "\033[0m"
            }
            {
                tier = "Unknown"
                if (match($0, /"userTier":\{[^}]*"name":"[^"]+"/)) {
                    t = substr($0, RSTART, RLENGTH)
                    match(t, /"name":"[^"]+"/)
                    tier = substr(t, RSTART+8, RLENGTH-9)
                }
                
                pc = "N/A"
                if (match($0, /"availablePromptCredits":[0-9]+/)) {
                    pc = substr($0, RSTART+25, RLENGTH-25)
                }
                
                fc = "N/A"
                if (match($0, /"availableFlowCredits":[0-9]+/)) {
                    fc = substr($0, RSTART+23, RLENGTH-23)
                }
                
                print "=== Quota Summary ==="
                print "Tier: " tier
                print "Prompt Credits: " pc
                print "Flow Credits: " fc
                print "\nModels:"
                
                # Split by model label
                n = split($0, arr, /\{"label":"/)
                for (i=2; i<=n; i++) {
                    end_quote = index(arr[i], "\"")
                    name = substr(arr[i], 1, end_quote-1)
                    
                    rem = "Unlimited"
                    reset_str = ""
                    color = GREEN
                    
                    if (match(arr[i], /"remainingFraction":[0-9.]+/)) {
                        val = substr(arr[i], RSTART+20, RLENGTH-20)
                        rem_val = int(val * 100)
                        rem = rem_val "%"
                        
                        if (rem_val < 25) {
                            color = RED
                        } else if (rem_val < 50) {
                            color = YELLOW
                        }
                        
                        if (rem_val < 100 && match(arr[i], /"resetTime":"[^"]+"/)) {
                            t = substr(arr[i], RSTART, RLENGTH)
                            match(t, /"resetTime":"[^"]+"/)
                            utc_time = substr(t, RSTART+13, RLENGTH-14)
                            cmd = "date -d \"" utc_time "\" +\"%Y-%m-%d %H:%M:%S\""
                            cmd | getline local_time
                            close(cmd)
                            reset_str = " (Resets: " local_time ")"
                        }
                    }
                    print " - " name ": " color rem RESET reset_str
                }
            }'
            exit 0
        fi
    done
done

echo "Failed to query quota. Process was found but no valid port responded."
exit 1
