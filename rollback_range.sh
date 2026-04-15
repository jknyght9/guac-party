#!/bin/bash

# 1. Check for the range ID argument
if [ -z "$1" ]; then
    echo "Error: No range ID provided."
    echo "Usage: $0 <range_id>"
    echo "Example: $0 21"
    exit 1
fi

RANGE_ID="range-$1"
SNAPSHOT_NAME="base"
JSON_FILE="ranges.json"

# 2. Source the environment variables safely
if [ -f ./.env ]; then
    set -a
    source ./.env
    set +a
else
    echo "Error: .env file not found in the current directory."
    exit 1
fi

# Ensure the base URL ends cleanly with /api2/json
BASE_URL="${PVE_API_URL%/}"
if [[ "$BASE_URL" != *"/api2/json" ]]; then
    BASE_URL="$BASE_URL/api2/json"
fi

# 3. Pull the data and write the file
echo "Pulling Terraform state and updating $JSON_FILE..."
./docker/terraform.sh -chdir=03-range-build output -json workshop_range_allocations | tee $JSON_FILE > /dev/null
echo "----------------------------------------"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Run 'sudo apt install jq' first."
    exit 1
fi

echo "Searching for $RANGE_ID in configuration..."

# 4. Extract data specifically for the requested range using jq
# --arg passes the bash variable securely into jq
# select(. != null) ensures it fails gracefully if the range doesn't exist
VM_DATA=$(jq -r --arg rname "$RANGE_ID" '.[$rname] | select(. != null) | .target_node as $node | .vms[] | "\($node) \(.vm_id)"' "$JSON_FILE")

if [ -z "$VM_DATA" ]; then
    echo "Error: $RANGE_ID not found in $JSON_FILE or contains no VMs."
    exit 1
fi

echo "Starting Proxmox API rollbacks for $RANGE_ID..."

# 5. Parse the extracted data and fire API requests
echo "$VM_DATA" | while read -r node vmid; do
    
    echo "Tasking node: $node -> Rolling back VM: $vmid to snapshot '$SNAPSHOT_NAME'"
    
    curl -s -k -X POST "$BASE_URL/nodes/$node/qemu/$vmid/snapshot/$SNAPSHOT_NAME/rollback" \
        -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
        -o /dev/null
    
done

echo "----------------------------------------"
echo "API calls complete! $RANGE_ID is rolling back."