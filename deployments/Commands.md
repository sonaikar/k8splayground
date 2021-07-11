# Deployment Rollout

1. Create a Deployment to rollout a ReplicaSet. The ReplicaSet creates Pods in the background. Check the status of the rollout to see if it succeeds or not.
2. Declare the new state of the Pods by updating the PodTemplateSpec of the Deployment. A new ReplicaSet is created and the Deployment manages moving the Pods from the old ReplicaSet to the new one at a controlled rate. Each new ReplicaSet updates the revision of the Deployment.
3. Rollback to an earlier Deployment revision if the current state of the Deployment is not stable. Each rollback updates the revision of the Deployment.
4. Scale up the Deployment to facilitate more load.
5. Pause the Deployment to apply multiple fixes to its PodTemplateSpec and then resume it to start a new rollout.
6. Use the status of the Deployment as an indicator that a rollout has stuck.
Clean up older ReplicaSets that you don't need anymore.
   
New in Kubernetes deployment: 

--record :  write the command executed in the resource annotation kubernetes.io/change-cause. The recorded change is useful for future introspection

Deployment status: 
```bash 
kubectl rollout status deployment/nginx-deployment
```

Updating deployment: 
```bash
kubectl --record deploy/webapplication set image deploy/webapplication webserver=nginx:1.20

kubectl set image deployment/webapplication webserver=nginx:1.18 --record

# Using kubectl edit:  It will open configuration in default editor.  
kubectl edit deploy/webapplication ()

```

Deployment ensures that only a certain number of Pods are down while they are being updated. By default, it ensures that at least 75% of the desired number of Pods are up (25% max unavailable).

Deployment also ensures that only a certain number of Pods are created above the desired number of Pods. By default, it ensures that at most 125% of the desired number of Pods are up (25% max surge).

For example, if you look at the above Deployment closely, you will see that it first created a new Pod, then deleted some old Pods, and created new ones. It does not kill old Pods until a sufficient number of new Pods have come up, and does not create new Pods until a sufficient number of old Pods have been killed. It makes sure that at least 2 Pods are available and that at max 4 Pods in total are available.

```bash
 # Events are shown with describe command
 kubectl describe deploy
 
```

## Rolling back deployment 
```bash

# Try a typo in image name
kubectl set image deployment.v1.apps/webapplication webserver=nginx:1.161 --record=true

# Note: The Deployment controller stops the bad rollout automatically, and stops scaling up the new ReplicaSet. This depends on the rollingUpdate parameters (maxUnavailable specifically) that you have specified. Kubernetes by default sets the value to 25%.
```

### To fix this deployment
```bash
kubectl rollout history deployment.v1.apps/webapplication

kubectl rollout history deploy/webapplication --revision=2

kubectl  rollout undo deploy/webapplication --revision=2
```

# Scaling deployment:
```bash
kubectl scale deployment/webapplication --replicas=10
```

# Pausing and Resuming deployment
```bash
#Pause
kubectl rollout pause deploy/webapplication 

#update image
kubectl set image deploy/webapplication webserver=nginx:1.16

# No rollout started
kubectl rollout history deployment.v1.apps/webapplication
kubectl get rs 

# You can make as many updates you wish 
kubectl set resources deployment.v1.apps/webapplicatoin -c=webserver --limits=cpu=200m,memory=128Mi

# Resueme rollout 
kubectl rollout resume deployment.v1.apps/webapplication

kubectl get rs -w

```

### Additional options 
```bash
# Replicaset history 
.spec.revisionHistoryLimit


# Restart policy
.spec.template.spec.restartPolicy = Always

# strategy
.spec.strategy.type 
 # can be "Recreate" or "RollingUpdate". "RollingUpdate" is the default value.
 
# All existing Pods are killed before new ones are created when .spec.strategy.type==Recreate. 
```

### Rolling update deployment 
```bash
.spec.strategy.type==RollingUpdate. 
#You can specify maxUnavailable and maxSurge to control the rolling update process.

.spec.strategy.rollingUpdate.maxUnavailable is an optional field that specifies the maximum number of Pods that can be unavailable during the update process. The value can be an absolute number (for example, 5) or a percentage of desired Pods (for example, 10%). The absolute number is calculated from percentage by rounding down. The value cannot be 0 
if .spec.strategy.rollingUpdate.maxSurge is 0. The default value is 25%


.spec.strategy.rollingUpdate.maxSurge is an optional field that specifies the maximum number of Pods that can be created over the desired number of Pods. The value can be an absolute number (for example, 5) or a percentage of desired Pods (for example, 10%). The value cannot be 0 if MaxUnavailable is 0. The absolute number is calculated from the percentage by rounding up. The default value is 25%.

```

### Progress Deadline Seconds

.spec.progressDeadlineSeconds is an optional field that specifies the number of seconds you want to wait for your Deployment to progress before the system reports back that the Deployment has failed progressing - surfaced as a condition with Type=Progressing, Status=False. and Reason=ProgressDeadlineExceeded in the status of the resource. The Deployment controller will keep retrying the Deployment. This defaults to 600. In the future, once automatic rollback will be implemented, the Deployment controller will roll back a Deployment as soon as it observes such a condition.
If specified, this field needs to be greater than .spec.minReadySeconds


Min Ready Seconds

.spec.minReadySeconds is an optional field that specifies the minimum number of seconds for which a newly created Pod should be ready without any of its containers crashing, for it to be considered available. This defaults to 0 (the Pod will be considered available as soon as it is ready).