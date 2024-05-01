# tap-scripts
Scripts for creating Tanzu Application Platform environments using Shepherd

# Full Profile Single Cluster
```
./single-cluster-testing-scanning.sh
```
Create a single cluster full profile TAP install with Testing and Scanning Supply Chain and a sample workload.

# Multi Cluster TAP Install
```
./multi-cluster-tap.sh
```
Create a multi-cluster View, Full and Run Profile TAP environment with sample workloads.


# Pre-requisites
- shepherd cli
- yq cli
- jq cli
- tanzu cli
- kubectl cli