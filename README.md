# kubernetes-upgrade

The intent of this project is to automate an upgrade of a bare-metal Kubernetes cluster.

I use a single Bash script, `upgrade.sh`, to perform upgrades of my personal cluster and making it available for anyone else looking to automate upgrades.

## Requirements

1. `kubectl` installed on the host you call the `upgrade.sh` script from.
2. Passwordless ssh access to the control plane and worker nodes to upgrade.

Note that you should only upgrade one minor version at a time so if you're upgrading from an exceptionally older version
of Kubernetes to the latest version you may have to go through more than one iteration. The script doesn't handle this for you.

## Usage

1. Update the `TARGET_MAJOR_MINOR_VERSION` in the `upgrade.sh` script to something like `1.19`.
2. Update the values for `MASTER_NODE` and the `WORKER_NODES` array in the `upgrade.sh` script.

## References

* [Upgrading kubeadm clusters | Kubernetes](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
