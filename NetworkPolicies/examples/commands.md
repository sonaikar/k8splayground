kubectl get namespaces --show-labels


kubectl apply -f middleware-netpol.yml; 
kubectl apply -f database-netpol.yml

kubectl create deployment nginx --image=ewoutp/docker-nginx-curl -n web

kubectl create deployment nginx --image=ewoutp/docker-nginx-curl -n middleware

kubectl create deployment nginx --image=ewoutp/docker-nginx-curl -n database

kubectl get deployment --all-namespaces|grep nginx


Let’s list the pods first to get their IP.
kubectl get pod --all-namespaces -o wide|grep nginx

Now let’s kubectl exec on the web pod to check if it can connect with the middleware pod.

kubectl exec -it nginx-f67f7854c-ldsbb -n web -- curl 10.52.0.4

Let us try connecting to the database pod from the middleware pod.
kubectl exec -it nginx-f67f7854c-ldsbb -n web -- curl 10.52.0.3


What would happen if we try to connect to the database pod from the middleware pod?
kubectl exec -it nginx-f67f7854c-5l2zx -n middleware -- curl 10.52.0.3

How about middleware to the web pod?
kubectl exec -it nginx-f67f7854c-5l2zx -n middleware -- curl 10.52.0.5

Let us now try database to middleware.
kubectl exec -it nginx-f67f7854c-5l2zx -n middleware -- curl 10.52.0.4

What about the database to the web pod?
kubectl exec -it nginx-f67f7854c-5l2zx -n middleware -- curl 10.52.0.5


Let’s check if intra-namespace communication is present or not. For that, we will fire another set of NGINX deployments called NGINX-1.

kubectl create deployment nginx-1 --image=ewoutp/docker-nginx-curl -n web
kubectl create deployment nginx-1 --image=ewoutp/docker-nginx-curl -n middleware
kubectl create deployment nginx-1 --image=ewoutp/docker-nginx-curl -n database

kubectl get deployment --all-namespaces|grep nginx-1

Let’s try NGINX to NGINX-1 on the web namespace.
kubectl exec -it nginx-1-cd6cf6cc7-r6nj4 -n web -- curl 10.52.2.5

What about middleware to middleware?
kubectl exec -it nginx-1-cd6cf6cc7-27ztk -n middleware -- curl 10.52.0.4

That works as well. And database to the database pod?
kubectl exec -it nginx-1-cd6cf6cc7-xz8lf -n database -- curl 10.52.0.3

Let’s now expose the applications through services and see how they behave.
kubectl expose deployment nginx --port 80 -n web
kubectl expose deployment nginx --port 80 -n middleware
kubectl expose deployment nginx --port 80 -n database
kubectl get svc --all-namespaces|grep nginx


Now let’s do a curl from web to middleware and check what happens.
kubectl exec -it nginx-f67f7854c-ldsbb -n web -- curl nginx.middleware 
 
 
From middleware to the database pod?
kubectl exec -it nginx-f67f7854c-5l2zx -n middleware -- curl nginx.database

And it works as expected. What about curl from the web to the database pod with services?

kubectl exec -it nginx-f67f7854c-ldsbb -n web -- curl nginx.database
^Ccommand terminated with exit code 130





beta.kubernetes.io/arch=amd64,
beta.kubernetes.io/instance-type=t2.medium,
beta.kubernetes.io/os=linux,
failure-domain.beta.kubernetes.io/region=us-east-1,
failure-domain.beta.kubernetes.io/zone=us-east-1c,
kops.k8s.io/instancegroup=master-us-east-1c,
kubernetes.io/arch=amd64,
kubernetes.io/hostname=ip-172-20-105-229.ec2.internal,
kubernetes.io/os=linux,
kubernetes.io/role=master,
node-role.kubernetes.io/master=


beta.kubernetes.io/arch=amd64,
beta.kubernetes.io/instance-type=t2.medium,
beta.kubernetes.io/os=linux,
failure-domain.beta.kubernetes.io/region=us-east-1,
failure-domain.beta.kubernetes.io/zone=us-east-1a,
kops.k8s.io/instancegroup=nodes,
kubernetes.io/arch=amd64,
kubernetes.io/hostname=ip-172-20-36-66.ec2.internal,
kubernetes.io/os=linux,
kubernetes.io/role=node,
node-role.kubernetes.io/node=



 