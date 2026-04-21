#!/bin/bash

# Cluster configuration
LB_NAME="lb-node"
LB_IP="10.0.0.150"
MASTER_NAMES=("k8s-master-1" "k8s-master-2" "k8s-master-3")
WORKER_NAMES=("k8s-worker-1" "k8s-worker-2")

ALL_VMS=("${LB_NAME}" "${MASTER_NAMES[@]}" "${WORKER_NAMES[@]}")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBECONFIG_PATH="${SCRIPT_DIR}/../kubeconfig"

echo -e "${BLUE}=========================================="
echo -e "  Multipass HA Kubernetes Cluster Status"
echo -e "==========================================${NC}"
echo ""

echo -e "${YELLOW}VM Status:${NC}"
echo "-------------------------------------------"
for vm in "${ALL_VMS[@]}"; do
    if multipass info "${vm}" &>/dev/null; then
        state=$(multipass info "${vm}" --format csv | tail -1 | cut -d',' -f2)
        ipv4=$(multipass info "${vm}" --format csv | tail -1 | cut -d',' -f3)
        if [ "$state" = "Running" ]; then
            echo -e "  ${GREEN}●${NC} ${vm}: ${state} (${ipv4})"
        else
            echo -e "  ${RED}●${NC} ${vm}: ${state}"
        fi
    else
        echo -e "  ${RED}○${NC} ${vm}: Not found"
    fi
done

echo ""
echo -e "${YELLOW}HAProxy Status:${NC}"
echo "-------------------------------------------"
if multipass info "${LB_NAME}" &>/dev/null; then
    haproxy_status=$(multipass exec "${LB_NAME}" -- systemctl is-active haproxy 2>/dev/null || echo "unknown")
    if [ "$haproxy_status" = "active" ]; then
        echo -e "  ${GREEN}●${NC} HAProxy: running"
        echo -e "  Stats URL: http://${LB_IP}:1936"
    else
        echo -e "  ${RED}●${NC} HAProxy: ${haproxy_status}"
    fi
else
    echo -e "  ${RED}○${NC} Load balancer not running"
fi

echo ""
echo -e "${YELLOW}Kubernetes Status:${NC}"
echo "-------------------------------------------"
if [ -f "${KUBECONFIG_PATH}" ]; then
    export KUBECONFIG="${KUBECONFIG_PATH}"
    
    if kubectl cluster-info &>/dev/null; then
        echo -e "  ${GREEN}●${NC} API Server: reachable"
        echo ""
        echo "  Nodes:"
        kubectl get nodes -o wide 2>/dev/null | sed 's/^/    /'
        echo ""
        echo "  Control Plane Pods:"
        kubectl get pods -n kube-system -l tier=control-plane -o wide 2>/dev/null | sed 's/^/    /' || echo "    Unable to fetch control plane pods"
    else
        echo -e "  ${RED}●${NC} API Server: unreachable"
    fi
else
    echo -e "  ${YELLOW}○${NC} Kubeconfig not found at ${KUBECONFIG_PATH}"
    echo "    Run create-cluster.sh first or check if cluster exists"
fi

echo ""
echo -e "${BLUE}==========================================${NC}"
