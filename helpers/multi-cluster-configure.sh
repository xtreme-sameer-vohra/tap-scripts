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

# Get the directory of the script
script_dir="$(dirname "$(readlink -f "$0")")"

# Assign leases to TAP SM profiles
VIEW_CLUSTER_LEASE_ID=$(sed '1q;d' "$leases")
BUILD_CLUSTER_LEASE_ID=$(sed '2q;d' "$leases")
RUN_CLUSTER_LEASE_ID=$(sed '3q;d' "$leases")

export VIEW_KUBECONFIG=/tmp/kube-config-$VIEW_CLUSTER_LEASE_ID.yaml
export BUILD_KUBECONFIG=/tmp/kube-config-$BUILD_CLUSTER_LEASE_ID.yaml
export RUN_KUBECONFIG=/tmp/kube-config-$RUN_CLUSTER_LEASE_ID.yaml

export VIEW_TAP_VALUES=/tmp/tap-values-$VIEW_CLUSTER_LEASE_ID.yaml
export BUILD_TAP_VALUES=/tmp/tap-values-$BUILD_CLUSTER_LEASE_ID.yaml
export RUN_TAP_VALUES=/tmp/tap-values-$RUN_CLUSTER_LEASE_ID.yaml

# On Build Cluster
#yq eval '.profile = "build"' $BUILD_TAP_VALUES --inplace
KUBECONFIG=$BUILD_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $BUILD_TAP_VALUES

KUBECONFIG=$BUILD_KUBECONFIG kubectl create -f $script_dir/tap-resources/tap-gui-viewer-service-account-rbac.yaml
KUBECONFIG=$BUILD_KUBECONFIG kubectl apply -f $script_dir/tap-resources/tap-gui-viewer-secret.yaml

KUBECONFIG=$BUILD_KUBECONFIG kubectl label namespaces my-apps apps.tanzu.vmware.com/tap-ns=""

# Test & Scan pipeline
KUBECONFIG=$BUILD_KUBECONFIG kubectl apply -f $script_dir/tap-resources/scan-policy.yaml --namespace my-apps
KUBECONFIG=$BUILD_KUBECONFIG kubectl apply -f $script_dir/tap-resources/tekton-pipeline.yaml
sed -i '' '/grype:/,/^\s*[^# ]/ s/registry-credentials/registries-credentials/' $BUILD_TAP_VALUES
KUBECONFIG=$BUILD_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $BUILD_TAP_VALUES

CLUSTER_URL=$(KUBECONFIG=$BUILD_KUBECONFIG kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(KUBECONFIG=$BUILD_KUBECONFIG kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_TOKEN=$(KUBECONFIG=$BUILD_KUBECONFIG kubectl -n tap-gui get secret tap-gui-viewer -o=json \
| jq -r '.data["token"]' \
| base64 --decode)

# On View Cluster
yq eval '.profile = "view"' $VIEW_TAP_VALUES --inplace
CLUSTER_URL=$CLUSTER_URL CLUSTER_TOKEN=$CLUSTER_TOKEN CLUSTER_NAME=$CLUSTER_NAME yq eval '.tap_gui.app_config.kubernetes = {"serviceLocatorMethod":{"type":"multiTenant"},"clusterLocatorMethods":[{"type":"config","clusters":[{"url":env(CLUSTER_URL),"name":env(CLUSTER_NAME),"authProvider":"serviceAccount","serviceAccountToken":env(CLUSTER_TOKEN),"skipTLSVerify":true,"skipMetricsLookup":true}]}]}'  $VIEW_TAP_VALUES --inplace
KUBECONFIG=$VIEW_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $VIEW_TAP_VALUES

# On Run Cluster
BUILD_IMAGE_REGISTRY=$(yq .shared.image_registry.project_path $BUILD_TAP_VALUES)
BUILD_IMAGE_REGISTRY=$BUILD_IMAGE_REGISTRY yq eval '.shared.image_registry.project_path = env(BUILD_IMAGE_REGISTRY)' $RUN_TAP_VALUES --inplace
KUBECONFIG=$RUN_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $RUN_TAP_VALUES
KUBECONFIG=$RUN_KUBECONFIG kubectl delete secret registry-credentials -n tap-install
KUBECONFIG=$BUILD_KUBECONFIG kubectl get secret registry-credentials -n tap-install -oyaml | KUBECONFIG=$RUN_KUBECONFIG kubectl apply -f -

yq eval '.profile = "run"' $RUN_TAP_VALUES --inplace
KUBECONFIG=$RUN_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $RUN_TAP_VALUES

KUBECONFIG=$RUN_KUBECONFIG kubectl label namespaces my-apps apps.tanzu.vmware.com/tap-ns=""

KUBECONFIG=$RUN_KUBECONFIG kubectl create -f $script_dir/tap-resources/tap-gui-viewer-service-account-rbac.yaml
KUBECONFIG=$RUN_KUBECONFIG kubectl apply -f $script_dir/tap-resources/tap-gui-viewer-secret.yaml

CLUSTER_URL=$(KUBECONFIG=$RUN_KUBECONFIG kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_NAME=$(KUBECONFIG=$RUN_KUBECONFIG kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_TOKEN=$(KUBECONFIG=$RUN_KUBECONFIG kubectl -n tap-gui get secret tap-gui-viewer -o=json \
| jq -r '.data["token"]' \
| base64 --decode)

# On View Cluster
CLUSTER_URL=$CLUSTER_URL CLUSTER_TOKEN=$CLUSTER_TOKEN CLUSTER_NAME=$CLUSTER_NAME yq eval '.tap_gui.app_config.kubernetes.clusterLocatorMethods.[0].clusters += {"url":env(CLUSTER_URL),"name":env(CLUSTER_NAME),"authProvider":"serviceAccount","serviceAccountToken":env(CLUSTER_TOKEN),"skipTLSVerify":true,"skipMetricsLookup":true}'  $VIEW_TAP_VALUES --inplace
KUBECONFIG=$VIEW_KUBECONFIG tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file $VIEW_TAP_VALUES

TAP_GUI_URL=$(cat /tmp/shepherd-lease-$VIEW_CLUSTER_LEASE_ID.json | jq -r .output.tap_gui_url)
echo "✅ TAP GUI is available at $TAP_GUI_URL"