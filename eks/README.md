# EKS Cluster — Terraform

Creates a production-ready EKS cluster with:
- Dedicated VPC with public/private subnets across 3 AZs
- Managed node group with auto-scaling
- Core addons: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver

## Prerequisites

- Terraform >= 1.5.0
- AWS CLI installed and configured
- AWS IAM user with EKS/EC2/VPC/IAM permissions

## Usage

### 1. Create tfvars file
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS credentials and desired config
```

### 2. Initialize Terraform
```bash
terraform init
```

### 3. Preview changes
```bash
terraform plan
```

### 4. Apply
```bash
terraform apply
```

### 5. Configure kubectl
```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
kubectl get nodes
```

## Installing Cilium CNI (Overlay Mode)

Cilium overlay replaces the default VPC CNI, increasing pod density from ~15 to 110 pods/node on `t4g.medium`.

### 1. Get cluster endpoint

```bash
CLUSTER_ENDPOINT=$(aws eks describe-cluster \
  --name <cluster_name> \
  --query "cluster.endpoint" \
  --output text)
```

### 2. Install Cilium via Helm

```bash
helm repo add cilium https://helm.cilium.io/
helm repo update

helm install cilium cilium/cilium \
  --namespace kube-system \
  --set eni.enabled=false \
  --set ipam.mode=cluster-pool \
  --set ipam.operator.clusterPoolIPv4PodCIDRList="100.64.0.0/10" \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set kubeProxyReplacement=false \
  --set k8sServiceHost=${CLUSTER_ENDPOINT#https://} \
  --set k8sServicePort=443
```

> Note: `tunnel` flag was removed in Cilium v1.15. Use `routingMode=tunnel` + `tunnelProtocol=vxlan` instead.

### 3. Disable VPC CNI (aws-node)

```bash
kubectl patch daemonset aws-node \
  -n kube-system \
  --type='json' \
  -p='[{"op":"replace","path":"/spec/template/spec/nodeSelector","value":{"non-existing":"true"}}]'
```

### 4. Replace all nodes (required for Cilium to take effect)

```bash
aws eks update-nodegroup-version \
  --cluster-name <cluster_name> \
  --nodegroup-name <nodegroup_name> \
  --force
```

### 5. Verify Cilium is running

```bash
# Install Cilium CLI
brew install cilium-cli

cilium status
cilium connectivity test

# Pod IPs should now be from 100.64.0.0/10 (not VPC subnet)
kubectl get pods -A -o wide
```

### VPC CNI vs Cilium Overlay

| | VPC CNI (default) | Cilium Overlay |
|--|-----------------|----------------|
| Pod IP range | VPC subnet IPs | `100.64.x.x` (cluster pool) |
| Max pods (t4g.medium) | ~15 | 110 |
| L7 NetworkPolicy | No | Yes |
| Tunnel overhead | None | VXLAN ~5% |

## Destroy cluster
```bash
terraform destroy
```

## Files

| File | Purpose |
|------|---------|
| `providers.tf` | AWS and Kubernetes provider config |
| `variables.tf` | All input variable definitions |
| `main.tf` | VPC and EKS module resources |
| `outputs.tf` | Cluster endpoint, kubectl command, etc. |
| `terraform.tfvars.example` | Example values — copy to terraform.tfvars |
| `.gitignore` | Prevents secrets and state from being committed |
