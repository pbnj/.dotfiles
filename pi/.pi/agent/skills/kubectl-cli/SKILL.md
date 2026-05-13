---
name: kubectl-cli
description:
  "Use when interacting with Kubernetes clusters, pods, deployments, services,
  namespaces, helm releases, or any k8s resource. Triggers on kubectl, helm,
  k8s, pod, deployment, namespace, etc."
compatibility:
  "Requires kubectl (https://kubernetes.io/docs/tasks/tools/), helm
  (https://helm.sh/docs/intro/install/), kubectx/kubens
  (https://github.com/ahmetb/kubectx), and aws CLI v2 for EKS clusters. Cluster
  auth via ~/.kube/config or `aws eks update-kubeconfig`."
metadata:
  author: Peter Benjamin
  version: 0.1.0
---

# kubectl CLI Skill

A skill for inspecting and managing Kubernetes clusters using `kubectl`, `helm`,
`kubectx`, and `kubens`.

## Safety: Read vs. Mutation Commands

Read commands (`get`, `describe`, `logs`, `top`, `explain`, `diff`, `version`,
`config view`, `helm list/get/status/history`) are safe to run freely — they
only retrieve information and have no side effects. Mutation commands (`apply`,
`create`, `delete`, `patch`, `edit`, `rollout`, `scale`,
`helm install/upgrade/rollback/uninstall`) and interactive commands (`exec`,
`port-forward`) change or access live cluster state in ways that can be
difficult to reverse. Before running any of these, show the user the full
command and wait for explicit approval. When in doubt, ask.

## Authentication

### Discover Available Contexts

```sh
# List all available contexts (clusters)
$ kubectl config get-contexts

# Show current active context
$ kubectl config current-context
```

### Switch Context / Namespace with kubectx/kubens

```sh
# List and switch contexts (clusters)
kubectx              # list all contexts
kubectx <name>       # switch to context

# List and switch namespaces
kubens               # list all namespaces
kubens <name>        # switch active namespace
```

### Switch Context (kubectl native)

```sh
# Using kubectl
$ kubectl config use-context <context-name>
```

### Add an EKS Cluster

If a cluster is not in `~/.kube/config`, add it via the aws CLI. Use the account
ID from the ARN to determine the `--profile` (see aws-cli skill).

```sh
$ aws eks update-kubeconfig \
    --name <cluster-name> \
    --region <region> \
    --profile <account-id-or-alias>
```

### Switch Namespace

```sh
# pass --namespace / -n inline
$ kubectl get pods -n <namespace>
```

---

## Common Patterns

See `references/patterns.md` for kubectl and Helm examples by resource type:
Contexts, Pods, Deployments, Services, ConfigMaps, Secrets, Nodes, Resource
Usage, Events, JSON/YAML output, Helm, and Mutations.
