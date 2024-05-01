#!/bin/bash

# Check if the leases file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <leases file>"
    exit 1
fi

leases="$1"

# Check if the input file exists
if [ ! -f "$leases" ]; then
    echo "Leases file '$leases' does not exist."
    exit 1
fi

# Save the state files
while IFS= read -r lease_id; do
    echo "Saving State Files for Shepherd Lease $lease_id"
    shepherd get lease $lease_id --json > /tmp/shepherd-lease-$lease_id.json
    cat /tmp/shepherd-lease-$lease_id.json | jq -r .output.kubeconfig > /tmp/kube-config-$lease_id.yaml
    KUBECONFIG=/tmp/kube-config-$lease_id.yaml tanzu package installed get tap --values-file-output /tmp/tap-values-$lease_id.yaml -n tap-install
done < "$leases"