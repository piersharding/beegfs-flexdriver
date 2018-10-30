# CSI-Flex beegfs driver
This is an example implementation of a simulated BeeGFS storage driver for Kubernetes, based on the CSI driver interface.  In reality, this driver does not do anything BeeGFS specific as it just bind mounts the already mounted storage into the container (analogous to the hostPath CSI driver).

This could easily be modified to:
```mount -t beegfs beegfs_nodev /mnt/my/beegfs/share -ocfgFile=/etc/beegfs/client-xxx.conf``` but this is likely to be highly inefficient as it will mean many PFS mount points multiplied especially by the number of bound containers.  Better to mount the BeeGFS share once and reuse...

# BeeGFS

The default config for the test defined in Makefile expects the root of the BeeGFS share to be mounted at /mnt/beegfs .  An example of deploying a test NeeGFS cluster using Ansible is described here - https://github.com/piersharding/p3-appliances/tree/k8s-testing/k8s/playbooks/roles/beegfs .

# Requirements

The following feature gates and runtime config have to be enabled to deploy the driver

```
FEATURE_GATES=CSIPersistentVolume=true,MountPropagation=true
RUNTIME_CONFIG="storage.k8s.io/v1alpha1=true"
```

Mountprogpation requires support for privileged containers. So, make sure privileged containers are enabled in the cluster.

An example of this with (minikube)[https://github.com/kubernetes/minikube/releases] - tested with v0.30.0 is:
```
sudo -E minikube start --vm-driver=none --extra-config="apiserver.runtime-config=settings.k8s.io/v1alpha1=true" --extra-config="apiserver.runtime-config=storage.k8s.io/v1alpha1=true" --feature-gates="DevicePlugins=true,TaintBasedEvictions=true,CSIPersistentVolume=true,MountPropagation=true"
```

If using minikube (as above with --vm-driver=none), then you need to simulate BeeGFS by creating the directory eg: ```sudo mkdir /mnt/beegfs```

# Configuration

* must set BEEGFS_ROOT and beegfs-mount-dir to corresponding mount point for node local BeeGFS - if using ```make launch```, then this can be done via the make BEEGFS_ROOT variable 
* must set volumeHandle volumeAttributes.share appropriately

# Building

* All the build has been encapsulated in ```make```
* must build the flexadapter first
* setup your values (DOCKER_USER, DOCKER_PASSWORD, REG_EMAIL, REGISTRY_NAME, DOCKER_IMAGE - see Makefile for examples) in your own PrivateRules.mak file
* ```make all``` and then ```make launch```
* adjust the resource descriptors for configuration and repos etc.

# Example Nginx application

Launch NGiNX using a persistent volume located in /mnt/beegfs :

```make test```
