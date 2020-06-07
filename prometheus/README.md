NAME: prom
LAST DEPLOYED: Sun Jun  7 13:35:48 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

Watch the Prometheus Operator Deployment status using the command:

    kubectl get deploy -w --namespace default -l app.kubernetes.io/name=prometheus-operator-operator,app.kubernetes.io/instance=prom

Watch the Prometheus StatefulSet status using the command:

    kubectl get sts -w --namespace default -l app.kubernetes.io/name=prometheus-operator-prometheus,app.kubernetes.io/instance=prom

Prometheus can be accessed via port "9090" on the following DNS name from within your cluster:

    prom-prometheus-operator-prometheus.default.svc.cluster.local

To access Prometheus from outside the cluster execute the following commands:

    echo "Prometheus URL: http://127.0.0.1:9090/"
    kubectl port-forward --namespace default svc/prom-prometheus-operator-prometheus 9090:9090

Watch the Alertmanager StatefulSet status using the command:

    kubectl get sts -w --namespace default -l app.kubernetes.io/name=prometheus-operator-alertmanager,app.kubernetes.io/instance=prom

Alertmanager can be accessed via port "9093" on the following DNS name from within your cluster:

    prom-prometheus-operator-alertmanager.default.svc.cluster.local

To access Alertmanager from outside the cluster execute the following commands:

    echo "Alertmanager URL: http://127.0.0.1:9093/"
    kubectl port-forward --namespace default svc/prom-prometheus-operator-alertmanager 9093:9093
    
    
#######
NAME: grafana
LAST DEPLOYED: Sun Jun  7 14:13:01 2020
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
** Please be patient while the chart is being deployed **

1. Get the application URL by running these commands:
    echo "Browse to http://127.0.0.1:8080"
    kubectl port-forward svc/grafana 8080:3000 &

2. Get the admin credentials:

    echo "User: admin"
    echo "Password: $(kubectl get secret grafana-admin --namespace default -o jsonpath="{.data.GF_SECURITY_ADMIN_PASSWORD}" | base64 --decode)"
