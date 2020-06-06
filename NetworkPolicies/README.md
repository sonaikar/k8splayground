### A network policy is a specification of how groups of pods are allowed to communicate with each other and other network endpoints.

### NetworkPolicy resources use labels to select pods and define rules which specify what traffic is allowed to the selected pods.


### Network policies are implemented by the network plugin. To use network policies, you must be using a networking solution which supports NetworkPolicy. Creating a NetworkPolicy resource without a controller that implements it will have no effect.


### By default, pods are non-isolated; they accept traffic from any source.


### Pods become isolated by having a NetworkPolicy that selects them. Once there is any NetworkPolicy in a namespace selecting a particular pod, that pod will reject any connections that are not allowed by any NetworkPolicy. (Other pods in the namespace that are not selected by any NetworkPolicy will continue to accept all traffic.)

### Network policies do not conflict; they are additive. If any policy or policies select a pod, the pod is restricted to what is allowed by the union of those policies’ ingress/egress rules. Thus, order of evaluation does not affect the policy result.


### Kubernetes doesn’t have a “deny” action but you can achieve the same effect with a regular (allow) policy that specifies policyTypes=Ingress but omits the actual ingress definition. This is interpreted as “no ingress allowed”:
This policy selects all pods in the namespace as the source and leaves ingress undefined which means — no inbound traffic allowed.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### 
### Are Policies Defined for Pods or Services?
When a pod accesses another pod in Kubernetes it usually does so through a service — a virtual load-balancer which forwards traffic to the pods that implement the service. You may be tempted to think that network policies control access to services but this is not the case. Kubernetes network policies are applied to the pod ports, not to the service ports.

For example, if a service is listening on port 80 but forwarding traffic to its pods on port 8080, you need to specify 8080 in the network policy.

This design is sub-optimal because it means that you need to update network policies when someone changes the internal workings of a service (which ports the pods are listening on).

There is apparently a solution for this which is using named ports instead of hard-coded port numbers:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default.allow-hello
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: hello
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          run: curl
    ports:
    - port: my-http
```

### Do I Need To Define Both Ingress And Egress?
The short answer is Yes — in order to allow pod A to talk to pod B you need to allow pod A to create an outbound connection through an egress policy and pod B to accept an inbound connection through an ingress policy.


## https://medium.com/@ahmetensar/kubernetes-network-plugins-abfd7a1d7cac