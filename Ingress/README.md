# What is the Ingress Controller?
The Ingress controller is an application that runs in a cluster and configures an HTTP load balancer according to Ingress resources. The load balancer can be a software load balancer running in the cluster or a hardware or cloud load balancer running externally. Different load balancers require different Ingress controller implementations.

In the case of NGINX, the Ingress controller is deployed in a pod along with the load balancer.

## NGINX Ingress Controller
NGINX Ingress controller works with both NGINX and NGINX Plus and supports the standard Ingress features - content-based routing and TLS/SSL termination.

Additionally, several NGINX and NGINX Plus features are available as extensions to the Ingress resource via annotations and the ConfigMap resource. In addition to HTTP, NGINX Ingress controller supports load balancing Websocket, gRPC, TCP and UDP applications. See ConfigMap and Annotations docs to learn more about the supported features and customization options.



http://foo.bar.com/bar -> service1
http://bar.bar.com/foo -> service2
http://foo.bar.com/foo -> service2


http://cetbiz.com/ -> cetbizService 
http://amazon.com/ -> amazonService -> pods 

DNS -> 
  cetbiz.com  A   10.0.0.10 
  amazon.com  A   10.0.0.10 

HA proxy ->  10.0.0.10 -> Ingress 
Load Balancer ->  Ingress 
