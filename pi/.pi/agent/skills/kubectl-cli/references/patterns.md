# kubectl & Helm Patterns by Resource

## Contexts & Namespaces

```sh
# List all namespaces
kubectl get namespaces

# Describe a namespace
kubectl describe namespace <namespace>
```

## Pods

```sh
# List pods in a namespace
kubectl get pods -n <namespace>

# Wide output (includes node, IP)
kubectl get pods -n <namespace> -o wide

# Describe a pod (events, resource limits, mounts)
kubectl describe pod <pod-name> -n <namespace>

# Stream logs (last 100 lines)
kubectl logs <pod-name> -n <namespace> --tail=100

# Follow live logs
kubectl logs <pod-name> -n <namespace> -f

# Logs from a specific container in a multi-container pod
kubectl logs <pod-name> -c <container-name> -n <namespace>

# Logs from previous (crashed) container
kubectl logs <pod-name> -n <namespace> --previous

# Filter pods by label
kubectl get pods -n <namespace> -l app=<app-name>
```

## Deployments & ReplicaSets

```sh
# List deployments
kubectl get deployments -n <namespace>

# Describe a deployment
kubectl describe deployment <name> -n <namespace>

# Check rollout status
kubectl rollout status deployment/<name> -n <namespace>

# View rollout history
kubectl rollout history deployment/<name> -n <namespace>

# List ReplicaSets
kubectl get replicasets -n <namespace>
```

## Services & Endpoints

```sh
# List services
kubectl get services -n <namespace>

# Describe a service
kubectl describe service <name> -n <namespace>

# List endpoints
kubectl get endpoints <name> -n <namespace>
```

## ConfigMaps & Secrets

```sh
# List ConfigMaps
kubectl get configmaps -n <namespace>

# View a ConfigMap
kubectl get configmap <name> -n <namespace> -o yaml

# List Secrets (names only — do not print values without approval)
kubectl get secrets -n <namespace>

# Describe a Secret (shows metadata, not values)
kubectl describe secret <name> -n <namespace>
```

## Nodes

```sh
# List nodes with status
kubectl get nodes -o wide

# Describe a node (taints, allocatable resources, conditions)
kubectl describe node <node-name>

# List pods on a specific node
kubectl get pods --all-namespaces --field-selector spec.nodeName=<node-name>
```

## Resource Usage

```sh
# Node CPU/memory usage (requires metrics-server)
kubectl top nodes

# Pod CPU/memory usage
kubectl top pods -n <namespace>

# Pod CPU/memory sorted by CPU
kubectl top pods -n <namespace> --sort-by=cpu
```

## Events

```sh
# Events in a namespace (great for debugging)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Events for a specific resource
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# Watch events live
kubectl get events -n <namespace> -w
```

## All Resources (Broad View)

```sh
# All resources in a namespace
kubectl get all -n <namespace>

# All resources across all namespaces
kubectl get all --all-namespaces
```

## JSON/YAML Output & Querying

```sh
# Output as YAML
kubectl get <resource> <name> -n <namespace> -o yaml

# JSONPath query (e.g. get container image)
kubectl get pod <name> -n <namespace> \
    -o jsonpath='{.spec.containers[*].image}'

# Custom columns
kubectl get pods -n <namespace> \
    -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
```

## Helm

```sh
# List all releases across all namespaces
helm list --all-namespaces

# List releases in a namespace
helm list -n <namespace>

# Get release details
helm get all <release-name> -n <namespace>

# Get values used for a release
helm get values <release-name> -n <namespace>

# Release status
helm status <release-name> -n <namespace>

# Release history
helm history <release-name> -n <namespace>

# Show rendered manifests (dry-run, no cluster changes)
helm template <release-name> <chart> -f values.yaml
```

## Mutations (Require Explicit Approval)

These commands modify cluster state. Always show the full command to the user
and wait for approval before executing.

```sh
# Apply a manifest
kubectl apply -f <file.yaml> -n <namespace>

# Delete a resource
kubectl delete <resource> <name> -n <namespace>

# Scale a deployment
kubectl scale deployment/<name> --replicas=<n> -n <namespace>

# Rollback a deployment
kubectl rollout undo deployment/<name> -n <namespace>

# Patch a resource
kubectl patch <resource> <name> -n <namespace> --patch '<json-patch>'

# Exec into a container (interactive access — always requires approval)
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Port-forward (always requires approval)
kubectl port-forward <pod-name> <local-port>:<pod-port> -n <namespace>

# Helm install / upgrade / rollback / uninstall
helm upgrade --install <release> <chart> -f values.yaml -n <namespace>
helm rollback <release> <revision> -n <namespace>
helm uninstall <release> -n <namespace>
```
