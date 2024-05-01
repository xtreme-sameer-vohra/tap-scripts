#!/bin/sh

mkdir -p leases
leases=$(mktemp ./leases/leases.XXXX)
echo "Leases are stored in $leases"

./helpers/multi-cluster-create.sh $leases
./helpers/create-state-files.sh $leases
./helpers/multi-cluster-configure.sh $leases
./helpers/multi-cluster-create-workloads.sh $leases
