# EKS Cluster Upgrade: 1.33 → 1.34

## Prerequisites

- `kubectl` configured and connected to the cluster
- `aws` CLI with valid credentials (`AWS_PROFILE=ssonaikar`)
- `kubent` installed for deprecated API detection
- `cilium` CLI installed (if Cilium CNI is in use)
- Cluster in healthy state before starting

## Upgrade Order (must follow this sequence)

```text
1. Pre-upgrade checks
2. Control plane (API server, etcd, scheduler)
3. Core addons (coredns, kube-proxy, vpc-cni, aws-ebs-csi-driver)
4. Cilium CNI (if installed)
5. Node group (worker nodes)
6. Post-upgrade verification
7. Update Terraform state
```

> EKS supports 1 minor version skew between control plane and nodes — nodes on 1.33 with control plane on 1.34 is safe temporarily during the upgrade window.

---

## Phase 1 — Pre-upgrade Checks

### Verify 1.34 is available

```bash
aws eks describe-addon-versions \
  --kubernetes-version 1.34 \
  --region us-east-1 \
  --query "addons[0].addonName" \
  --output text
```

Expected: returns any addon name (e.g. `snapshot-controller`) confirming 1.34 is supported.

### Check cluster health

```bash
kubectl get nodes
kubectl get pods -A | grep -Ev "Running|Completed"
```

All nodes must be `Ready` and no pods in `CrashLoopBackOff` or `Error` state before proceeding.

### Detect deprecated/removed APIs

```bash
# Install kubent
brew install kubent

# Scan cluster for APIs removed in 1.34
kubent

# Also scan Helm charts and manifests
brew install FairwindsOps/tap/pluto
pluto detect-all-in-cluster
```

Resolve any reported deprecated APIs before upgrading.

### Check addon compatibility with 1.34

```bash
aws eks describe-addon-versions \
  --kubernetes-version 1.34 \
  --region us-east-1 \
  --query "addons[].{name:addonName, version:addonVersions[0].addonVersion}" \
  --output table
```

### Check Cilium compatibility with 1.34

```bash
cilium version
helm show chart cilium/cilium | grep kubeVersion
```

Refer to [Cilium Kubernetes compatibility matrix](https://docs.cilium.io/en/stable/network/kubernetes/compatibility/) to confirm support.

---

## Phase 2 — Upgrade Control Plane

```bash
aws eks update-cluster-version \
  --name ssonaikar-eks-cluster \
  --kubernetes-version 1.34 \
  --region us-east-1
```

Monitor progress (takes ~15 minutes):

```bash
watch -n 30 "aws eks describe-cluster \
  --name ssonaikar-eks-cluster \
  --query 'cluster.{status:status, version:version}' \
  --output table \
  --region us-east-1"
```

Wait for `status: ACTIVE` and `version: 1.34` before proceeding to the next phase.

---

## Phase 3 — Upgrade Core Addons

```bash
for ADDON in coredns kube-proxy vpc-cni aws-ebs-csi-driver; do
  LATEST=$(aws eks describe-addon-versions \
    --kubernetes-version 1.34 \
    --addon-name $ADDON \
    --query "addons[0].addonVersions[0].addonVersion" \
    --output text \
    --region us-east-1)
  echo "Upgrading $ADDON to $LATEST..."

  aws eks update-addon \
    --cluster-name ssonaikar-eks-cluster \
    --addon-name $ADDON \
    --addon-version $LATEST \
    --resolve-conflicts OVERWRITE \
    --region us-east-1
done
```

Verify all addons are active:

```bash
aws eks list-addons \
  --cluster-name ssonaikar-eks-cluster \
  --region us-east-1

aws eks describe-addon \
  --cluster-name ssonaikar-eks-cluster \
  --addon-name coredns \
  --query "addon.status" \
  --region us-east-1
```

---

## Phase 4 — Upgrade Cilium (if installed)

Skip this phase if Cilium is not installed.

```bash
# Check current installed version
helm list -n kube-system | grep cilium

# Get latest compatible version
helm repo update
helm search repo cilium/cilium --versions | head -5

# Upgrade preserving existing values
helm upgrade cilium cilium/cilium \
  --namespace kube-system \
  --reuse-values \
  --version <latest-compatible-version>

# Verify Cilium health
cilium status
kubectl get pods -n kube-system | grep cilium
```

---

## Phase 5 — Upgrade Node Group

This performs a rolling replacement of all worker nodes (one at a time).

```bash
aws eks update-nodegroup-version \
  --cluster-name ssonaikar-eks-cluster \
  --nodegroup-name workers-20260524135722551300000013 \
  --region us-east-1
```

Monitor rollout:

```bash
watch -n 30 "aws eks describe-nodegroup \
  --cluster-name ssonaikar-eks-cluster \
  --nodegroup-name workers-20260524135722551300000013 \
  --query 'nodegroup.{status:status, version:releaseVersion}' \
  --output table \
  --region us-east-1"
```

Wait for `status: ACTIVE` before proceeding.

---

## Phase 6 — Post-upgrade Verification

```bash
# Control plane version
kubectl version

# All nodes on 1.34 and Ready
kubectl get nodes

# No unhealthy pods
kubectl get pods -A | grep -Ev "Running|Completed"

# Cilium healthy (if installed)
cilium status
kubectl exec -n kube-system ds/cilium -- cilium endpoint list

# EBS CSI controller running
kubectl get pods -n kube-system | grep ebs
```

---

## Phase 7 — Update Terraform State

Update `terraform.tfvars` to reflect the new version:

```hcl
cluster_version = "1.34"
```

Then sync Terraform state:

```bash
terraform apply
```

This ensures future `terraform plan` doesn't show a version drift.

---

## Rollback

EKS does **not support downgrading** the control plane version. If issues arise:

- Rollback individual addons to previous versions via `aws eks update-addon --addon-version <previous>`
- Rollback Cilium via `helm rollback cilium -n kube-system`
- For node group issues: terminate new nodes and let ASG replace with previous AMI version (requires re-running node group upgrade to previous version)

**Always take note of current addon versions before upgrading.**

```bash
# Save current addon versions before upgrade
aws eks list-addons \
  --cluster-name ssonaikar-eks-cluster \
  --region us-east-1 \
  --output json > addon-versions-pre-upgrade.json
```
