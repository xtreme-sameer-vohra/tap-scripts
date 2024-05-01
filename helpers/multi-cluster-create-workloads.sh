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

NUMBER_OF_WORKLOADS=10
# Assign leases to TAP SM profiles
BUILD_CLUSTER_LEASE_ID=$(sed '2q;d' "$leases")
RUN_CLUSTER_LEASE_ID=$(sed '3q;d' "$leases")

export BUILD_KUBECONFIG=/tmp/kube-config-$BUILD_CLUSTER_LEASE_ID.yaml
export RUN_KUBECONFIG=/tmp/kube-config-$RUN_CLUSTER_LEASE_ID.yaml

export BUILD_TAP_VALUES=/tmp/tap-values-$BUILD_CLUSTER_LEASE_ID.yaml
export RUN_TAP_VALUES=/tmp/tap-values-$RUN_CLUSTER_LEASE_ID.yaml

for ((i = 1; i <= NUMBER_OF_WORKLOADS; i++)); do
    KUBECONFIG=$BUILD_KUBECONFIG tanzu apps workload create my-java-app-$i \
	--git-repo https://github.com/xtreme-sameer-vohra/tanzu-java-web-app  \
	--git-branch xtreme-sameer-vohra-patch-1 \
	--type web \
	--label app.kubernetes.io/part-of=my-java-app \
	--label apps.tanzu.vmware.com/has-tests=true \
	--yes \
	--namespace my-apps
done

elapsed_duration=0
max_duration=600 # 10 mins
while true; do
	READY_WORKLOADS=$(KUBECONFIG=$BUILD_KUBECONFIG tanzu apps workload list -n my-apps | grep "Ready" | wc -l)
	NUMBER_OF_READY_WORKLOADS=$((READY_WORKLOADS))
	if [ "$NUMBER_OF_WORKLOADS" == "$NUMBER_OF_READY_WORKLOADS" ]; then
        echo "All Workloads on Build Cluster are ready"
        break
    else
        echo "⏳ Waiting for all the Workloads to be ready."
	    sleep 30
        elapsed_duration=$((elapsed_duration + 30))
		# Check if the maximum waiting time has been exceeded
		if [ $elapsed_duration -ge $max_duration ]; then
			echo "❌ Timed out waiting for Workloads to be ready"
			exit 1
		fi
    fi
done

# Copy Deliverables From Build to Run
for ((i = 1; i <= NUMBER_OF_WORKLOADS; i++)); do
    KUBECONFIG=$BUILD_KUBECONFIG kubectl get deliverable my-java-app-$i -n my-apps -oyaml | yq - e | yq 'del(.status, .metadata.generation, .metadata.ownerReferences, .metadata.resourceVersion, .metadata.uid)' > /tmp/deliverable-my-java-app-$i.yaml

    KUBECONFIG=$RUN_KUBECONFIG kubectl apply -f /tmp/deliverable-my-java-app-$i.yaml
done
echo "Workload Deliverables applied to Run Cluster"