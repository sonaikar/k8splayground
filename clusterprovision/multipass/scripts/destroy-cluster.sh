#!/bin/bash
set -e

# Cluster configuration (must match create-cluster.sh)
LB_NAME="lb-node"
MASTER_NAMES=("k8s-master-1" "k8s-master-2" "k8s-master-3")
WORKER_NAMES=("k8s-worker-1" "k8s-worker-2")

ALL_VMS=("${LB_NAME}" "${MASTER_NAMES[@]}" "${WORKER_NAMES[@]}")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

delete_vm() {
    local vm_name=$1
    
    if multipass info "${vm_name}" &>/dev/null; then
        log_info "Deleting ${vm_name}..."
        multipass delete "${vm_name}"
    else
        log_warn "${vm_name} does not exist, skipping..."
    fi
}

main() {
    local force=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [-f|--force]"
                echo "  -f, --force    Skip confirmation prompt"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Confirmation
    if [ "$force" = false ]; then
        echo ""
        log_warn "This will delete the following VMs:"
        for vm in "${ALL_VMS[@]}"; do
            echo "  - ${vm}"
        done
        echo ""
        read -p "Are you sure you want to destroy the cluster? (y/N) " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi
    
    log_info "Destroying HA Kubernetes cluster..."
    echo ""
    
    # Delete all VMs
    for vm in "${ALL_VMS[@]}"; do
        delete_vm "${vm}"
    done
    
    # Purge deleted VMs
    log_info "Purging deleted VMs..."
    multipass purge
    
    # Clean up kubeconfig and temp files
    if [ -f "${SCRIPT_DIR}/../kubeconfig" ]; then
        log_info "Removing kubeconfig..."
        rm -f "${SCRIPT_DIR}/../kubeconfig"
    fi
    
    rm -f "${SCRIPT_DIR}/.join-command" "${SCRIPT_DIR}/.cert-key"
    
    echo ""
    log_info "=========================================="
    log_info "Cluster destroyed successfully!"
    log_info "=========================================="
    
    # Show remaining VMs
    echo ""
    log_info "Remaining Multipass VMs:"
    multipass list
}

main "$@"
