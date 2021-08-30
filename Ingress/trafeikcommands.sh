Reference:  https://github.com/traefik/traefik-helm-chart

Commands:
helm repo add traefik https://helm.traefik.io/traefik
helm repo update
helm install traefik traefik/traefik

To connect with dashboard: (You need to be kube-system namespace)
kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000
