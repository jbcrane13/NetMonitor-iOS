#!/bin/bash
# testflight-post-upload.sh
#
# After xcodebuild -exportArchive uploads a build, this script:
#   1. Waits for ASC to finish processing the build
#   2. Sets export compliance (no encryption)
#   3. Adds the build to internal test groups (Alphas + Internal Testers)
#
# Usage: ./testflight-post-upload.sh <build_number>
# Requires: python3 with PyJWT, ASC API key at ~/.private_keys/AuthKey_P554KPNJ92.p8

set -uo pipefail

BUILD_NUMBER="${1:?Usage: $0 <build_number>}"
APP_ID="6759060947"
# Internal groups to auto-add builds to.
# Note: "Alphas" (f633e96b) has hasAccessToAllBuilds=true, so it auto-gets every build.
GROUP_IDS=(
    "70fa9ed5-71cd-4228-ba85-561a28d51476"   # Internal Testers
)
KEY_ID="P554KPNJ92"
ISSUER_ID="39686cf7-40f9-45b0-820e-fc971c77adbf"
KEY_PATH="$HOME/.private_keys/AuthKey_${KEY_ID}.p8"

MAX_WAIT=300  # 5 minutes max wait for processing
POLL_INTERVAL=15

generate_token() {
    python3 -c "
import jwt, time
with open('${KEY_PATH}') as f: key = f.read()
now = int(time.time())
print(jwt.encode({'iss': '${ISSUER_ID}', 'iat': now, 'exp': now + 1200, 'aud': 'appstoreconnect-v1'}, key, algorithm='ES256', headers={'kid': '${KEY_ID}'}))
"
}

api() {
    local method="$1" url="$2" data="${3:-}"
    local token
    token=$(generate_token)
    if [ -n "$data" ]; then
        curl -s --max-time 30 -X "$method" \
            -H "Authorization: Bearer $token" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$url"
    else
        curl -s --max-time 30 -X "$method" \
            -H "Authorization: Bearer $token" \
            "$url"
    fi
}

echo "⏳ Waiting for build $BUILD_NUMBER to finish processing..."

elapsed=0
BUILD_ID=""
while [ $elapsed -lt $MAX_WAIT ]; do
    response=$(api GET "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=${APP_ID}&filter[version]=${BUILD_NUMBER}&fields[builds]=version,processingState,usesNonExemptEncryption")

    state=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['attributes']['processingState'] if d['data'] else 'NOT_FOUND')" 2>/dev/null || echo "ERROR")
    BUILD_ID=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['id'] if d['data'] else '')" 2>/dev/null || echo "")

    if [ "$state" = "VALID" ]; then
        echo "✅ Build $BUILD_NUMBER processed successfully (ID: $BUILD_ID)"
        break
    elif [ "$state" = "INVALID" ]; then
        echo "❌ Build $BUILD_NUMBER is INVALID — check App Store Connect for details"
        exit 1
    elif [ "$state" = "NOT_FOUND" ]; then
        echo "   Build not found yet... (${elapsed}s)"
    else
        echo "   Processing: $state (${elapsed}s)"
    fi

    sleep $POLL_INTERVAL
    elapsed=$((elapsed + POLL_INTERVAL))
done

if [ -z "$BUILD_ID" ]; then
    echo "❌ Timed out waiting for build $BUILD_NUMBER to process"
    exit 1
fi

# Set export compliance — no non-exempt encryption
echo "📋 Setting export compliance (no encryption)..."
uses_encryption=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'][0]['attributes'].get('usesNonExemptEncryption', 'None'))" 2>/dev/null || echo "None")

if [ "$uses_encryption" = "None" ] || [ "$uses_encryption" = "null" ]; then
    compliance_response=$(api PATCH "https://api.appstoreconnect.apple.com/v1/builds/$BUILD_ID" '{
        "data": {
            "type": "builds",
            "id": "'"$BUILD_ID"'",
            "attributes": {
                "usesNonExemptEncryption": false
            }
        }
    }')
    echo "✅ Export compliance set"
else
    echo "✅ Export compliance already set (usesNonExemptEncryption=$uses_encryption)"
fi

# Add to internal test groups
for group_id in "${GROUP_IDS[@]}"; do
    group_name=$(api GET "https://api.appstoreconnect.apple.com/v1/betaGroups/$group_id?fields[betaGroups]=name" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['attributes']['name'])" 2>/dev/null || echo "$group_id")

    echo "📱 Adding build to group: $group_name..."
    add_response=$(api POST "https://api.appstoreconnect.apple.com/v1/betaGroups/$group_id/relationships/builds" '{
        "data": [
            {
                "type": "builds",
                "id": "'"$BUILD_ID"'"
            }
        ]
    }')

    # POST returns 204 No Content on success (empty body)
    if [ -z "$add_response" ]; then
        echo "✅ Added to $group_name"
    else
        # Check if it's an error
        error=$(echo "$add_response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('errors', [{}])[0].get('detail', ''))" 2>/dev/null || echo "")
        if [ -n "$error" ]; then
            echo "⚠️  $group_name: $error"
        else
            echo "✅ Added to $group_name"
        fi
    fi
done

echo ""
echo "🚀 Build $BUILD_NUMBER is live on TestFlight!"
