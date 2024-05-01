#!/bin/sh

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

LEASE_DURATION="120h" # 5days
SHEPHERD_NAMESPACE=vsameer

for i in {1..3}
do
    echo "⚙️ Creating Shepherd Lease"
    output=$(shepherd create lease --template gke-tap@2.1 \
      --template-namespace official-tap \
      --duration $LEASE_DURATION \
      --namespace $SHEPHERD_NAMESPACE \
      --json \
      --template-argument '{"k8s_version":"1.27","tap_version":"1.9.1-rc.1","region":"us-west2","cluster_essentials_version":"1.6.1"}')

    # Extract the lease ID using jq
    lease_id=$(echo $output | jq -r '.id')
    echo "Cluster $i Shepherd Lease ID: $lease_id"
    echo $lease_id >> $leases
done

elapsed_duration=0
max_duration=6000 # 1 Hour
while true; do
	LEASE_STATES=$(cat $leases | xargs -I lease_id shepherd get lease lease_id -j | jq .status | grep --invert-match LEASED)
	# Check if all leases are ready
	if [ -z "$LEASE_STATES" ]
    then
        echo "All leases are ready"
        break
    else
        echo "⏳ Waiting for the all leases to be ready... (this may take a few minutes)"
	    sleep 60
        elapsed_duration=$((elapsed_duration + 60))
		# Check if the maximum waiting time has been exceeded
		if [ $elapsed_duration -ge $max_duration ]; then
			echo "❌ Timed out waiting for Shepherd Leases being in LEASED state."
			exit 1
		fi
    fi
done
