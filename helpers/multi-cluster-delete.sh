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

cat $leases | xargs -I lease_id shepherd delete lease lease_id 