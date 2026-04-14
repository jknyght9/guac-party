#!/bin/bash

# Define the snapshot parameters
SNAPSHOT_NAME="base"
SNAPSHOT_DESC="base-state"
JSON_FILE="ranges.json"

# 1. Source the environment variables safely
if [ -f ./.env ]; then
    set -a            # Automatically export all variables defined
    source ./.env     # Read the file
    set +a            # Turn auto-export back off
else
    echo "Error: .env file not found in the current directory."
    exit 1
fi

# Ensure the base URL ends cleanly with /api2/json so we don't get double paths
BASE_URL="${PVE_API_URL%/}"
if [[ "$BASE_URL" != *"/api2/json" ]]; then
    BASE_URL="$BASE_URL/api2/json"
fi

# 2. Pull the data and write the file
echo "Pulling Terraform state and updating $JSON_FILE..."
./docker/terraform.sh -chdir=03-range-build output -json workshop_range_allocations | tee $JSON_FILE > /dev/null
echo "----------------------------------------"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Run 'sudo apt install jq' first."
    exit 1
fi

echo "Starting Proxmox API snapshots..."

# 3. Parse JSON and fire API requests
jq -r 'to_entries[] | .value.target_node as $node | .value.vms[] | "\($node) \(.vm_id)"' $JSON_FILE | while read -r node vmid; do
    
    echo "Tasking node: $node -> Snapshotting VM: $vmid via API"
    
    # Fire the POST request to the Proxmox API
    # -k ignores self-signed cert warnings
    # -s hides the download progress bar
    # --data-urlencode safely handles spaces in the description
    curl -s -k -X POST "$BASE_URL/nodes/$node/qemu/$vmid/snapshot" \
        -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
        -d "snapname=$SNAPSHOT_NAME" \
        --data-urlencode "description=$SNAPSHOT_DESC" \
        -d "vmstate=1" \
        -o /dev/null # We toss the JSON response to keep the terminal clean
    sleep 1 # Hopefully don't overload the disk
done

echo "----------------------------------------"
echo "API calls complete! All ranges successfully snapshotted."