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

### Network Access

EKS clusters sit in a private network behind Twingate VPN.

Errors like the following indicate that the current device is not connected to
the VPN:

```text
E0617 18:34:16.859056   65323 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://04E4BEF23C0A171C284CF39155E53F75.gr7.us-west-2.eks.amazonaws.com/api?timeo
ut=32s\": dial tcp 10.13.126.213:443: connect: connection refused"
```

### Cloud Access

EKS clusters require a valid AWS SSO session.

Errors like the following indicate that AWS SSO session has expired:

```text
aws: [ERROR]: The SSO session associated with this profile has expired or is otherwise invalid. To refresh this SSO session run aws sso login with the corresponding profile.
E0617 18:31:54.939030   64334 memcache.go:265] "Unhandled Error" err="couldn't get current server API group list: Get \"https://04E4BEF23C0A171C284CF39155E53F75.gr7.us-west-2.eks.amazonaws.com/api?timeo
ut=32s\": getting credentials: exec: executable aws failed with exit code 255"
Unable to connect to the server: getting credentials: exec: executable aws failed with exit code 255
```

To renew or authenticate to AWS SSO, run: `aws sso login`

### Discover Available Contexts

```sh
# List all available contexts (clusters)
$ kubectl config get-contexts

# Show current active context
$ kubectl config current-context
```

### Switch Context

Explicitly set the context via `--context` flag:

```sh
kubectl --context="<KUBE_CONTEXT>" ...
```

### Add an EKS Cluster

If a cluster is not in `~/.kube/config`, add it via the aws CLI. Use the account
ID from the ARN to determine the `--profile` (see aws-cli skill).

```sh
$ aws eks update-kubeconfig \
    --name <cluster-name> \
    --region <region> \
    --profile <account-id-or-alias> \
    --alias <cluster-name>
```

### Switch Namespace

Explicitly set the namespace via `--namespace` flag:

```sh
# pass --namespace / -n inline
$ kubectl --context="<KUBE_CONTEXT>" --namespace="<KUBE_NAMESPACE>" get pods
```

## Common Patterns

See `references/patterns.md` for kubectl and Helm examples by resource type:
Contexts, Pods, Deployments, Services, ConfigMaps, Secrets, Nodes, Resource
Usage, Events, JSON/YAML output, Helm, and Mutations.
