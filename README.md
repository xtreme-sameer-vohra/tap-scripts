# tap-scripts
Scripts for creating Tanzu Application Platform environments using Shepherd



# Multi Cluster TAP Install
```
./multi-cluster-tap.sh
```
Creates a Multi Cluster TAP environment with;
- A View profile cluster
- A Full profile cluster (This also serves as the Build cluster)
- A Run profile cluster
- 10 sample workloads deployed to the Full profile and Run profile clusters
- TAP GUI on View cluster configured to observe the Full and Run clusters.
- Testing and Scanning SupplyChain configured on Full profile cluster.

## Configuration
The script above can be run as-is.

However, its recommended you create your own Shepherd namespace and replace the default value in `multi-cluster-create.sh`. 

The Shepherd lease time defaults to 5 days and can be adjusted in `multi-cluster-create.sh` by setting `LEASE_DURATION`.

## Cleanup
```
./helpers/multi-cluster-delete.sh leases/PATH_TO_LEASES
```
# Full Profile Single Cluster
```
./single-cluster-testing-scanning.sh
```
Create a single cluster full profile TAP install with Testing and Scanning Supply Chain and a sample workload.

# Pre-requisites
- shepherd cli
- yq cli
- jq cli
- tanzu cli
- kubectl cli

# Issues
## TAP GUI Supply Chain UI permissions error for Run cluster
Error: Authentication Error: It seems you don't have permissions to list workloads on the namespace. Clusters that are affected: some-named-cluster
Re-running multi-cluster-configure.sh should resolve the issue

```
./helpers/multi-cluster-configure.sh leases/PATH_TO_LEASES
```