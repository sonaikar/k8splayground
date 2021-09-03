The RBAC API declares four kinds of Kubernetes object: Role, ClusterRole, RoleBinding and ClusterRoleBinding. 

An RBAC Role or ClusterRole contains rules that represent a set of permissions. Permissions are purely additive (there are no "deny" rules).

A Role always sets permissions within a particular namespace; when you create a Role, you have to specify the namespace it belongs in.

ClusterRole, by contrast, is a non-namespaced resource. The resources have different names (Role and ClusterRole) because a Kubernetes object always has to be either namespaced or not namespaced; it can't be both.

https://docs.bitnami.com/tutorials/configure-rbac-in-your-kubernetes-cluster/



clusterrole --> Cluster level access:   admin                 
role --> Namespace level access:    User/Developer     


Role: ->  UserAccess
Access to example namespace 

venkat and prakash 

RoleBinding -> 
 RoleName: - UserAccess
 Bind to Subject:- venkat (ssl certificate, token)

ClusterRole: -> AdminAccess
ClusterRoleBinding -> 
  ClusterRoleName:  AdminAccess
  Subject:  prakash

REST API: 
Kubectl get namespace  ->   get request 
https://kcluster.cetbiz.com/api/namesapace?get 


venkat -> example namespace (Readonly access)

get
list
watch


Maintainance: 
Get
list
watch
update
patch



get  
list 
watch
create
update
patch
delete
deletecollection


ClusterReadOnly  <-  Group, User
NamespaceReadOnly
NamespaceEdit
ClusterEdit
ClusterReadWrite
ClusterReadOnly 


NamespaceReadOnly
-> configmaps 

LDAP/ActiveDirectory  (System admin/Windows admin)
->  LDAP 

Add User to LDAP group. 

Oauth2 -> Google (authentication) gmailid, github, gitlab, keycloack 

User John -> 2019 
User -> k8s -> john 
John left 2020 (subbatical) -> 2021 (temporary disable)

LDAP/AD :  john account disbled 
->  Printer
->  network 
->  machines
->  k8s cluster
->  artifactory 


User: 
group/person -- venkat/prakash 
ServiceAccount (virtual user)

SystemAccount - 
Backup system -> ServiceAccount (backup)

ServiceAccount (backup/databaseadmin)
pod (application requires access to database )












