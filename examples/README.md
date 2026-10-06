# Examples

Manifests that use the OCI module images (built by [module-images](https://github.com/captf-io/module-images)), written for
`clusterctl generate yaml --from <file>`: `${VARIABLE}` is substituted from
the environment, `${VARIABLE:=default}` falls back to the default.

| File | What it creates | Variables |
| --- | --- | --- |
| [`identity.yaml`](identity.yaml) | The credentials Secret (placeholder values; the PEM key is a file key) and the `TerraformClusterIdentity` that lets `NAMESPACE` use it | `NAMESPACE`, optional `OCI_IDENTITY_NAME`, `OCI_IDENTITY_NAMESPACE`, `OCI_TENANCY_OCID`, `OCI_USER_OCID`, `OCI_FINGERPRINT` |
| [`cluster-kubeadm.yaml`](cluster-kubeadm.yaml) | A `Cluster` on a `TerraformCluster`, a three-node `KubeadmControlPlane`, a `MachineDeployment` of workers, a `MachinePool` of workers on a `TerraformMachinePool` with a node label, and MachineHealthChecks for workers and the control plane | `CLUSTER_NAME`, `KUBERNETES_VERSION`, `OCI_COMPARTMENT_ID`, `OCI_REGION`, `OCI_CONTROL_PLANE_SUBNET_ID`, `OCI_WORKER_SUBNET_ID`, `OCI_IMAGE_ID`, `OCI_NODE_TAG_NAMESPACE`, `OCI_NODE_TAG_KEY` |

The manifests pin every image to a release, `v0.1.0-opentofu`: change the
tag to the release you deploy (`vX.Y.Z-opentofu` or `vX.Y.Z-terraform`), or
to a digest. The moving tags (`opentofu`, `terraform`) are
for trying things out, never for anything you keep. The quick start in the
[archived oci-modules README](https://github.com/captf-io/oci-modules#using-it) walks through them in order.
