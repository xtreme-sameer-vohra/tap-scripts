#!/bin/sh

LEASE_DURATION="120h" # 5days
SHEPHERD_NAMESPACE=vsameer

echo "⚙️ Creating Shepherd Lease"
shepherd create lease --template gke-tap@2.1 \
	--template-namespace official-tap \
	--duration $LEASE_DURATION \
	--namespace $SHEPHERD_NAMESPACE \
	--template-argument '{"k8s_version":"1.27","tap_version":"1.9.1-rc.1","region":"us-west2","cluster_essentials_version":"1.6.1"}'


shepherd get lease --last-lease -j > /tmp/shepherd-lease.json
lease_id=$(cat /tmp/shepherd-lease.json | jq -r '.id')
mv  /tmp/shepherd-lease.json /tmp/shepherd-lease-$lease_id.json

echo "🔗 Kubeconfig (/tmp/kube-config-$lease_id.yaml) exported for use with Kubectl and Tanzu CLI"
cat /tmp/shepherd-lease-$lease_id.json | jq -r .output.kubeconfig > /tmp/kube-config-$lease_id.yaml
export KUBECONFIG=/tmp/$lease_id-kube-config.yaml

echo "🏷️ Labeling the 'my-apps' for Namespace Provisioner"
kubectl label namespaces my-apps apps.tanzu.vmware.com/tap-ns=""

kubectl apply -f helpers/tap-resources/scan-policy.yaml --namespace my-apps
echo "📄 YAML file scan-policy.yaml applied."

kubectl apply -f helpers/tap-resources/tekton-pipeline.yaml
echo "📄 YAML file tekton-pipeline.yaml applied."

# Step 9: Obtain and save the tap-values.yaml file
echo "📃 Obtaining the tap-values.yaml file..."
tanzu package installed get tap --values-file-output /tmp/tap-values-$lease_id.yaml -n tap-install
echo "📁 /tmp/tap-values-$lease_id.yaml file obtained."

# Step 10: Modify tap-values.yaml
echo "🛠️ Modifying tap-values.yaml..."
sed -i '' '/grype:/,/^\s*[^# ]/ s/registry-credentials/registries-credentials/' /tmp/tap-values-$lease_id.yaml
echo "✅ tap-values.yaml file modified."

# Step 11: Apply the changes with tanzu
echo "🔄 Applying changes with tanzu package installed update..."
tanzu package installed update tap -p tap.tanzu.vmware.com -n tap-install --values-file /tmp/tap-values-$lease_id.yaml
echo "✅ Changes applied."

# Step 12: Create the tanzu-java-web-app workload
echo "🚀 Creating the tanzu-java-web-app workload..."
tanzu apps workload create my-java-app \
	--git-repo https://github.com/xtreme-sameer-vohra/tanzu-java-web-app  \
	--git-branch xtreme-sameer-vohra-patch-1 \
	--type web \
	--label app.kubernetes.io/part-of=my-java-app \
	--label apps.tanzu.vmware.com/has-tests=true \
	--yes \
	--namespace my-apps

echo "✅ tanzu-java-web-app workload created."

tap_gui_url=$(cat /tmp/shepherd-lease-$lease_id.json | jq -r .output.tap_gui_url)
echo "✅ TAP GUI is available at $tap_gui_url"