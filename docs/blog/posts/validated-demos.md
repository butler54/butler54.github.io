---
draft: false
date: 2023-10-30
categories:
  - validated-patterns
  - gitops
  - openshift
  - demos
---

# Validated patterns for demos

Upon joining [Red Hat](https://www.redhat.com) as a Chief Architect I've been lucky enough to find some time to deep-dive into our products and upstream. One of the fun challenges that I faced straight away is our demo OpenShift environments, for many reasons, are emphemeral.

In ephemeral environments GitOps is essential to quickly get to a consistent environment. Enter validated patterns.

<!-- more -->

At a high level validated patterns gitops based reference architectures for multiple OpenShift clusters running across multiple environments (both on prem and in the cloud).

The core [`multicloud-gitops`](https://validatedpatterns.io/patterns/multicloud-gitops/) provides:

- Multicluster management using Red Hat Advanced Cluster Manager,
- A hub-and-spoke approach to secrets management with [upstream Vault Project](https://www.vaultproject.io/),
- A single point for managing both operators and argo applications,
- Hooks for the procedural steps you just can't get rid of (such as unsealing vault).

The result from an operationl perspective once I have a cluster the only steps I care about are:

1. Cloning a pattern repo - `git clone git@github.com/butler54/validated-patterns-demos`,
1. Logging into the cluster - `oc login --token=sha256~*** --server=https://URL:PORT`,
1. Setup required secrets using the [secret-template](https://validatedpatterns.io/patterns/multicloud-gitops/mcg-getting-started/), if required;
1. `./pattern.sh make install`.

??? info "Podman and bootstrapping on mac os"
    To run the bootstrap scripts validated patterns presumes that you are using `podman`.
    Using [brew](https://brew.sh/):

    ```bash
    brew install podman
    podman machine init
    podman machine start
    ```

All I have to do is wait and the environment will roll itself out automatically. Using [OpenShift GitOps](https://docs.openshift.com/gitops/latest/understanding_openshift_gitops/about-redhat-openshift-gitops.html) ([Argo CD](https://argo-cd.readthedocs.io/en/stable/)) the deployment rollout can easily be monitored and triaged for errors.

When developing [my own pattern](https://github.com/butler54/validated-patterns-demos) or your own the best way to start is to fork from the [`multicloud-gitops`](https://github.com/validatedpatterns/multicloud-gitops) repository.

The validated-patterns operator has a few nice features such as branch based deployments but the setup has two features that I found to be essential for demo / development environments

- Safe by default secrets loading;
- Environmental overrides.

## Safe by default secrets loading

While in production environments enterprises typically take great care with secrets, in early stage development it is not uncommon for developers to be manipulating secrets from their laptops.
A nice feature of validated patterns sit that the secrets bootstrapping when calling `./pattern.sh make install` and `./pattern.sh make load-secrets` *explicitly does not look in the cloned source repo*.

Instead it looks for files in a users [home directory](https://github.com/validatedpatterns/common/tree/main/ansible/roles/vault_utils#values-secret-file-format) which is highly unlikely to be managed by git.
The result is that the template helps decrease the risk of developers committing secrets - as there is no reason to have the secrets in the repository at any point in time.

## Environmental overrides

The `values.yaml` files provides the high level abstraction of what needs to be deployed onto a cluster. For example `values-hub.yaml` example below deploys ACM, OpenShift pipelines ([Tekton](https://tekton.dev/)) and a pipelines Helm chart that contains Tekton pipeline definitions.

```yaml
clusterGroup:
  name: hub
  isHubCluster: true

  namespaces:
    - open-cluster-management
    - vault
    - golang-external-secrets
    - devops
  # Operator subscriptions
  subscriptions:
    acm:
      name: advanced-cluster-management
      namespace: open-cluster-management
      channel: release-2.8

    openshift-pipelines:
      name: openshift-pipelines-operator-rh
      namespace: openshift-operators
  # OCP project
  projects:
    - hub
    - devops

  # defining the path to an argoCD application (e.g. helm / Kustomize)
  applications:
    acm:
      name: acm
      namespace: open-cluster-management
      project: hub
      path: common/acm
      ignoreDifferences:
        - group: internal.open-cluster-management.io
          kind: ManagedClusterInfo
          jsonPointers:
            - /spec/loggingCA


    pipelines:
      name: pipelines
      namespace: devops
      project: devops
      path: charts/all/pipelines
      ignoreDifferences:
        - kind: ServiceAccount
          jsonPointers:
            - /imagePullSecrets
            - /secrets
  sharedValueFiles:
    - /overrides/values-{{ $.Values.global.clusterPlatform }}.yaml
    - /overrides/values-{{ $.Values.global.clusterPlatform }}-{{ $.Values.global.clusterVersion
      }}.yaml
```

In the case of my pipelines it requests a `storageclass` by name in the pipelines Helm chart. `storageclasses` typically have different names across different cloud providers which means we need provider specific overrides.
The validated patterns operator provides a framework where a combination of `clusterGroup`, cloud provider and OpenShift version. This gives you value files of the format:

- `values-global.yaml` default applies everywhere,
- `values-hub.yaml` hub for your 'hub' RHACM cluster,
- `sharedValueFiles`, defined in `values-hub.yaml` where you can define a list override files which can be based on global variables such as:
  - `clusterGroup`
  - `clusterPlatform` e.g. AWS, Azure, IBMCloud
  - `clusterVersion` e.g. 4.13

??? info "clusterGroup"
    `clusterGroup` is a label used together with RHACM particularly for clusters beyond the first.
    Applying:

    `oc label managedclusters.cluster.open-cluster-management.io/<your-cluster> clusterGroup=<managed-cluster-group>`

    will result in the correct `clusterGroup` payload being applied ot a given cluster.

In this case my pipelines Helm chart presumes that the storageclass is defined in `{{ .Values.cloudProvider.storageClass }}` so to setup for both IBM Cloud and AWS using the `sharedValuesFiles` defined in the example yaml file above I created two files to contain the overrides:

!!! info "`overrides/values-AWS.yaml`"
    ```yaml
    cloudProvider:
      storageClass: gp3-csi
    ```

!!! info "`overrides/values-IBMCloud.yaml`"
    ```yaml
    cloudProvider:
      storageClass: ibmc-vpc-block-10iops-tier
    ```

These override any values in the Helm chart's default `Values.yaml` file.

## Wrap up

Validated patterns, together with Helm, Argo CD, and RHACM. Provides a powerful tool to achieve consistency across multiple clusters and clouds.

This blog was written based on [this version](https://github.com/butler54/validated-patterns-demos/tree/validated-demos-blog) of my validated-demos repo.

Thanks to [@beekhof](https://github.com/beekhof) and [@day0hero](https://github.com/day0hero) who spent a considerable amount of time teaching me (and others) about validated patterns.
