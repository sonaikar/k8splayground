#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_INIT_DIR="${SCRIPT_DIR}/../cloud-init"

# Cluster configuration
LB_NAME="lb-node"
LB_IP="10.0.0.150"
MASTER_NAMES=("k8s-master-1" "k8s-master-2" "k8s-master-3")
MASTER_IPS=("10.0.0.151" "10.0.0.152" "10.0.0.153")
WORKER_NAMES=("k8s-worker-1" "k8s-worker-2")
WORKER_IPS=("10.0.0.156" "10.0.0.157")
NETWORK_INTERFACE="en0"
POD_CIDR="10.244.0.0/16"
LAUNCH_TIMEOUT="900"  # Timeout in seconds for VM launch (cloud-init can be slow)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

vm_exists() {
    local vm_name=$1
    multipass info "${vm_name}" &>/dev/null
}

configure_static_ip() {
    local vm_name=$1
    local ip_addr=$2
    
    log_info "Configuring static IP ${ip_addr} for ${vm_name}..."
    
    # Find the secondary interface (not enp0s1/default, not lo)
    local iface
    iface=$(multipass exec "${vm_name}" -- bash -c "ip -o link show | awk -F': ' '{print \$2}' | grep -v -E '^(lo|enp0s1)$' | head -1")
    
    if [ -z "${iface}" ]; then
        log_error "Could not detect secondary network interface on ${vm_name}"
        return 1
    fi
    
    log_info "Detected interface ${iface} on ${vm_name}"
    
    multipass exec "${vm_name}" -- sudo bash -c "cat << EOF > /etc/netplan/10-custom.yaml
network:
  version: 2
  ethernets:
    ${iface}:
      dhcp4: no
      addresses: [${ip_addr}/24]
EOF"
    multipass exec "${vm_name}" -- sudo chmod 600 /etc/netplan/10-custom.yaml
    multipass exec "${vm_name}" -- sudo netplan apply
}

wait_for_cloud_init() {
    local vm_name=$1
    log_info "Waiting for cloud-init to complete on ${vm_name}..."
    # cloud-init returns exit code 2 for "done with warnings" which is acceptable
    local status
    status=$(multipass exec "${vm_name}" -- cloud-init status --wait 2>&1) || true
    if echo "${status}" | grep -qE "status: (done|disabled)"; then
        log_info "Cloud-init completed on ${vm_name}"
        return 0
    elif echo "${status}" | grep -q "status: error"; then
        log_error "Cloud-init failed on ${vm_name}"
        multipass exec "${vm_name}" -- tail -50 /var/log/cloud-init-output.log
        return 1
    fi
}

launch_lb_node() {
    if vm_exists "${LB_NAME}"; then
        log_warn "${LB_NAME} already exists, skipping launch..."
        wait_for_cloud_init "${LB_NAME}"
        return 0
    fi
    
    log_info "Launching load balancer node..."
    multipass launch --name "${LB_NAME}" \
        --network "name=${NETWORK_INTERFACE},mode=manual" \
        --cpus 1 \
        --memory 1G \
        --timeout "${LAUNCH_TIMEOUT}" \
        --cloud-init "${CLOUD_INIT_DIR}/lb-node.yaml"
    
    configure_static_ip "${LB_NAME}" "${LB_IP}"
    wait_for_cloud_init "${LB_NAME}"
    log_info "Load balancer node ready at ${LB_IP}"
}

launch_master_nodes() {
    log_info "Launching master nodes..."
    
    for i in "${!MASTER_NAMES[@]}"; do
        local name="${MASTER_NAMES[$i]}"
        local ip="${MASTER_IPS[$i]}"
        
        if vm_exists "${name}"; then
            log_warn "${name} already exists, skipping launch..."
            continue
        fi
        
        log_info "Launching ${name}..."
        multipass launch --name "${name}" \
            --network "name=${NETWORK_INTERFACE},mode=manual" \
            --cpus 2 \
            --memory 4G \
            --disk 30G \
            --timeout "${LAUNCH_TIMEOUT}" \
            --cloud-init "${CLOUD_INIT_DIR}/k8s-node.yaml"
        
        configure_static_ip "${name}" "${ip}"
    done
    
    # Wait for cloud-init on all masters
    for name in "${MASTER_NAMES[@]}"; do
        wait_for_cloud_init "${name}"
    done
    
    log_info "All master nodes launched"
}

launch_worker_nodes() {
    log_info "Launching worker nodes..."
    
    for i in "${!WORKER_NAMES[@]}"; do
        local name="${WORKER_NAMES[$i]}"
        local ip="${WORKER_IPS[$i]}"
        
        if vm_exists "${name}"; then
            log_warn "${name} already exists, skipping launch..."
            continue
        fi
        
        log_info "Launching ${name}..."
        multipass launch --name "${name}" \
            --network "name=${NETWORK_INTERFACE},mode=manual" \
            --cpus 2 \
            --memory 4G \
            --disk 30G \
            --timeout "${LAUNCH_TIMEOUT}" \
            --cloud-init "${CLOUD_INIT_DIR}/k8s-node.yaml"
        
        configure_static_ip "${name}" "${ip}"
    done
    
    # Wait for cloud-init on all workers
    for name in "${WORKER_NAMES[@]}"; do
        wait_for_cloud_init "${name}"
    done
    
    log_info "All worker nodes launched"
}

init_first_master() {
    local master="${MASTER_NAMES[0]}"
    local master_ip="${MASTER_IPS[0]}"
    
    log_info "Initializing Kubernetes on ${master}..."
    
    # Generate certificate key for control plane join
    CERT_KEY=$(multipass exec "${master}" -- sudo kubeadm certs certificate-key)
    
    # Initialize the cluster
    multipass exec "${master}" -- sudo kubeadm init \
        --apiserver-advertise-address="${master_ip}" \
        --control-plane-endpoint "${LB_IP}:6443" \
        --pod-network-cidr="${POD_CIDR}" \
        --apiserver-cert-extra-sans "${LB_IP},${LB_NAME},${MASTER_NAMES[0]},${MASTER_NAMES[1]},${MASTER_NAMES[2]}" \
        --upload-certs \
        --certificate-key "${CERT_KEY}"
    
    # Setup kubectl for ubuntu user
    multipass exec "${master}" -- bash -c "mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    
    # Install Calico CNI
    log_info "Installing Calico CNI..."
    multipass exec "${master}" -- bash -c "curl -sO https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml && kubectl apply -f calico.yaml"
    
    # Get join commands
    log_info "Generating join commands..."
    
    # Control plane join command
    CONTROL_PLANE_JOIN=$(multipass exec "${master}" -- sudo kubeadm token create --print-join-command)
    
    # Store join info for other scripts
    echo "${CONTROL_PLANE_JOIN}" > "${SCRIPT_DIR}/.join-command"
    echo "${CERT_KEY}" > "${SCRIPT_DIR}/.cert-key"
    
    log_info "First master initialized successfully"
}

join_other_masters() {
    local join_cmd=$(cat "${SCRIPT_DIR}/.join-command")
    local cert_key=$(cat "${SCRIPT_DIR}/.cert-key")
    
    for i in 1 2; do
        local name="${MASTER_NAMES[$i]}"
        local ip="${MASTER_IPS[$i]}"
        
        log_info "Joining ${name} to control plane..."
        multipass exec "${name}" -- sudo ${join_cmd} \
            --control-plane \
            --certificate-key "${cert_key}" \
            --apiserver-advertise-address "${ip}"
        
        # Setup kubectl
        multipass exec "${name}" -- bash -c "mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config && sudo chown \$(id -u):\$(id -g) ~/.kube/config"
    done
    
    log_info "All masters joined to control plane"
}

join_workers() {
    local join_cmd=$(cat "${SCRIPT_DIR}/.join-command")
    
    for name in "${WORKER_NAMES[@]}"; do
        log_info "Joining ${name} as worker..."
        multipass exec "${name}" -- sudo ${join_cmd}
    done
    
    log_info "All workers joined to cluster"
}

copy_kubeconfig() {
    local master="${MASTER_NAMES[0]}"
    local kubeconfig_path="${SCRIPT_DIR}/../kubeconfig"
    
    log_info "Copying kubeconfig to ${kubeconfig_path}..."
    multipass exec "${master}" -- sudo cat /etc/kubernetes/admin.conf > "${kubeconfig_path}"
    
    # Update server address to use LB
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E "s|server: https://[^:]+:6443|server: https://${LB_IP}:6443|" "${kubeconfig_path}"
    else
        sed -i -E "s|server: https://[^:]+:6443|server: https://${LB_IP}:6443|" "${kubeconfig_path}"
    fi
    
    log_info "Kubeconfig saved. Use: export KUBECONFIG=${kubeconfig_path}"
}

wait_for_nodes_ready() {
    local master="${MASTER_NAMES[0]}"
    local expected_nodes=$((${#MASTER_NAMES[@]} + ${#WORKER_NAMES[@]}))
    
    log_info "Waiting for all nodes to be Ready..."
    
    for i in {1..60}; do
        ready_count=$(multipass exec "${master}" -- kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
        if [ "${ready_count}" -eq "${expected_nodes}" ]; then
            log_info "All ${expected_nodes} nodes are Ready!"
            multipass exec "${master}" -- kubectl get nodes
            return 0
        fi
        echo -n "."
        sleep 5
    done
    
    log_warn "Timeout waiting for nodes. Current status:"
    multipass exec "${master}" -- kubectl get nodes
}

cleanup_temp_files() {
    rm -f "${SCRIPT_DIR}/.join-command" "${SCRIPT_DIR}/.cert-key"
}

main() {
    log_info "Starting HA Kubernetes cluster creation..."
    echo ""
    
    # Phase 1: Launch all VMs
    launch_lb_node
    launch_master_nodes
    launch_worker_nodes
    
    echo ""
    log_info "All VMs launched. Starting Kubernetes setup..."
    echo ""
    
    # Phase 2: Initialize Kubernetes
    init_first_master
    join_other_masters
    join_workers
    
    # Phase 3: Finalize
    copy_kubeconfig
    wait_for_nodes_ready
    cleanup_temp_files
    
    echo ""
    log_info "=========================================="
    log_info "HA Kubernetes cluster created successfully!"
    log_info "=========================================="
    echo ""
    log_info "Load Balancer: ${LB_IP}"
    log_info "HAProxy Stats: http://${LB_IP}:1936"
    log_info "API Server:    https://${LB_IP}:6443"
    echo ""
    log_info "To use kubectl:"
    log_info "  export KUBECONFIG=${SCRIPT_DIR}/../kubeconfig"
    log_info "  kubectl get nodes"
}

main "$@"
