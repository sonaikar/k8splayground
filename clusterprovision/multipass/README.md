# Multipass HA Kubernetes Cluster

Automated provisioning of a highly available Kubernetes cluster using Multipass VMs.

## Architecture

```text
                    ┌─────────────────┐
                    │   HAProxy LB    │
                    │  10.0.0.150     │
                    │    :6443        │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  k8s-master-1   │ │  k8s-master-2   │ │  k8s-master-3   │
│  10.0.0.151     │ │  10.0.0.152     │ │  10.0.0.153     │
│  Control Plane  │ │  Control Plane  │ │  Control Plane  │
└─────────────────┘ └─────────────────┘ └─────────────────┘
         │                   │                   │
         └───────────────────┴───────────────────┘
                             │
         ┌───────────────────┴───────────────────┐
         │                                       │
         ▼                                       ▼
┌─────────────────┐                     ┌─────────────────┐
│  k8s-worker-1   │                     │  k8s-worker-2   │
│  10.0.0.156     │                     │  10.0.0.157     │
│     Worker      │                     │     Worker      │
└─────────────────┘                     └─────────────────┘
```

## Components

| Node | IP | Resources | Role |
| ------ | ----- | ----------- | ------ |
| lb-node | 10.0.0.150 | 1 CPU, 1GB RAM | HAProxy load balancer |
| k8s-master-1 | 10.0.0.151 | 2 CPU, 4GB RAM, 30GB disk | Control plane |
| k8s-master-2 | 10.0.0.152 | 2 CPU, 4GB RAM, 30GB disk | Control plane |
| k8s-master-3 | 10.0.0.153 | 2 CPU, 4GB RAM, 30GB disk | Control plane |
| k8s-worker-1 | 10.0.0.156 | 2 CPU, 4GB RAM, 30GB disk | Worker |
| k8s-worker-2 | 10.0.0.157 | 2 CPU, 4GB RAM, 30GB disk | Worker |

**Total Resources Required:** ~14GB RAM, 10 CPUs, 150GB disk

## Prerequisites

- [Multipass](https://multipass.run/) installed
- macOS with bridged network support (uses `en0` interface)
- Sufficient system resources

## Quick Start

### Create Cluster

```bash
cd clusterprovision/multipass
chmod +x scripts/*.sh
./scripts/create-cluster.sh
```

### Check Status

```bash
./scripts/status-cluster.sh
```

### Use kubectl

```bash
export KUBECONFIG=$(pwd)/kubeconfig
kubectl get nodes
```

### Destroy Cluster

```bash
./scripts/destroy-cluster.sh

# Skip confirmation prompt
./scripts/destroy-cluster.sh --force
```

## Directory Structure

```text
multipass/
├── README.md                    # This file
├── ha-cluster-provision.md      # Manual provisioning docs
├── kubeconfig                   # Generated after cluster creation
├── cloud-init/
│   ├── lb-node.yaml            # HAProxy cloud-init config
│   └── k8s-node.yaml           # Kubernetes node cloud-init config
└── scripts/
    ├── create-cluster.sh       # Create the full cluster
    ├── destroy-cluster.sh      # Tear down the cluster
    └── status-cluster.sh       # Check cluster status
```

## Configuration

Edit the variables at the top of `scripts/create-cluster.sh` to customize:

- **NETWORK_INTERFACE**: Network interface for bridged networking (default: `en0`)
- **POD_CIDR**: Pod network CIDR (default: `10.244.0.0/16`)
- **IP addresses**: Modify `*_IP` and `*_IPS` arrays
- **Resource allocation**: Adjust CPU, memory, disk in launch commands

## Networking

- Uses manual/bridged networking on `en0`
- Static IPs configured via netplan
- HAProxy load balances API server traffic across all masters

## CNI

Calico v3.31.4 is installed by default. To use a different CNI, modify the `init_first_master()` function in `create-cluster.sh`.

## Troubleshooting

### Check cloud-init logs

```bash
multipass exec k8s-master-1 -- cat /var/log/cloud-init-output.log
```

### Check HAProxy status

```bash
multipass exec lb-node -- systemctl status haproxy
# Or visit http://10.0.0.150:1936 for stats
```

### SSH into a node

```bash
multipass shell k8s-master-1
```

### View cluster events

```bash
kubectl get events -A --sort-by='.lastTimestamp'
```
