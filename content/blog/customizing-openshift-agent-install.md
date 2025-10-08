---
title: "Customizing Red Hat OpenShift agent installs for repeatable cluster builds on bare metal"
description: "Red Hat OpenShift provides lots of different install mechanisms to cater to different use cases. I've been using [validated patterns](https://validatedpatterns.io/patterns/) extensively for building reference architectures and test systems. One challenge has been how to get repeatable build processes on bare metal. This blog describes how I've done this in one our technology labs."
author: "Chris Butler"
date: 2025-10-08
draft: false
categories:
  - OpenShift
  - Installer
  - Red Hat
  - Kubernetes

---

# Customizing Red Hat OpenShift agent installs for repeatable cluster builds on bare metal

Red Hat OpenShift provides lots of different install mechanisms to cater to different use cases. 
I've been using [validated patterns](https://validatedpatterns.io/patterns/) extensively for building reference architectures and test systems. One challenge has been how to get repeatable build processes on bare metal. This blog describes how I've done this in one our technology labs.

<!-- more -->


Like many organizations the easiest place for me to test at Red Hat is in the cloud.
Our [demo platform](https://demo.redhat.com/) ([GitHub](https://github.com/rhpds)) makes it incredibly easy to provision environments. 
While developing the [confidential containers validated pattern](https://github.com/validatedpatterns/coco-pattern) I quickly started [using (and templating)](https://github.com/validatedpatterns/coco-pattern/tree/main/rhdp) `openshift-installer` CLI do 'IPI' installs - the installer configures everything it needs to deploy OpenShift clusters to just big enough for what I needed.

In the cloud this is perfect. My demo environments get blown away completely and the cloud scrubs the infrastructure clean.

On bare metal, unfortunately, the experience can be a little different.

The [agent install](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/installing_an_on-premise_cluster_with_the_agent-based_installer/index) provides the simplest process for bare metal installs:

1. Configure the installer.
2. Build an iso.
3. Mount the iso on all hosts.
4. Wait for the installer to finish and collect credentials.

This is approachable across many environments as virtually all enterprise hardware can boot an iso hosted remotely. 
This is particularly true for testing on Single Node OpenShift (SNO) as it's only one ISO to mount.

The challenge I faced is the agent installer was not enough to give me a clean slate for storage.

In SNO the simplest method for providing storage is the [LVM storage operator](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/storage/persistent-storage-using-local-storage).
LVM storage operator, to me,  makes the most sense as PVCs function as you would expect in the cloud and a developer doesn't need to know about the underlying hardware (beyond total capacity).

The downside to LVM is the underlying LVM partitions need to be cleaned up if you do any kind of reinstall.
Imagine you re-install OpenShift on the SNO system and then install LVM storage operator:

- The LVM storage operator will see the old `physical volume` `volume group` and `logical volumes`
- As you formatted a disk to install OpenShift it likely will put the LVM operator in a failed state
- The result is a whole load of messing around as `root` on the SNO system to clean up the system into a stable state.

Why does this happen? The agent-installer is inherently conservative and won't jump in and format all the disks. Understandably it's a good idea that this functionality has to be explicitly and deliberately enabled.

The way in which we can do this is to customize the ignition files used by OpenShift.
The ignition configuration below allows us to wipe all the disks.

```json
{
  "ignition": {
    "version": "3.2.0"
  },
  "storage": {
    "disks": [
      {
        "device": "/dev/nvme0n1",
        "wipeTable": true
      },
      {
        "device": "/dev/nvme1n1",
        "wipeTable": true
      },
      {
        "device": "/dev/nvme2n1",
        "wipeTable": true
      },
      {
        "device": "/dev/nvme3n1",
        "wipeTable": true
      },
      {
        "device": "/dev/nvme4n1",
        "wipeTable": true
      }
    ]
  }
}
```

This, with the correct device names, will wipe all the partition tables ensuring LVM Operator will behave as expected.

The question is how to provide it to the OpenShift installer. One approach is to use the 'any platform' install process and [host the ignition configuration](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/installing_on_any_platform/installing-platform-agnostic#installation-user-infra-generate-k8s-manifest-ignition_installing-platform-agnostic).

The other simpler quick hack is to realize that the agent iso embeds its own ignition information and it is really easy to customize.

## Customizing the agent installer iso
`coreos-installer` is available on RHEL, CentOS Stream, and Fedora. It provides tooling to manipulate the installer ISOs safely.

Assuming I already have my `agent-config.yaml`, `install-config.yaml` and the ignition fragment above `wipe-disks.ign`:
```bash
ls -h 
agent-config.yaml       install-config.yaml     wipe-disks.ign
```

The first step is to run the standard agent iso generator: `openshift-install --dir $(pwd) agent create image`. This will produce the standard `agent.x86_64.iso` image. This image already has a pre-configured ignition file in it.

`coreos-installer` can be used to extract the ignition file: `coreos-installer iso ignition show agent.x86_64.iso > base.ign`.

Once we have this it's easy to merge the files together with `jq` and create a new iso which provides just the customization you need:

```bash
coreos-installer iso ignition show agent.x86_64.iso > base.ign

jq -s '.[0] * .[1]' base.ign wipe-disks.ign > combined.ign

coreos-installer iso ignition embed -i ./combined.ign -f -o sno.iso agent.x86_64.iso
```
Note that the `-f` force command is needed to override the base ignition. Now you have a new ISO that ensures you clean out your system, allowing stable and repeatable installs. What's even better is that the ISO is reusable in the environment going forward.






