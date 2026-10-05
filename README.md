<h1 align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="72" height="72" alt="CAPTF"></a>
  <br>
  terraform-oci-machine
</h1>

<p align="center">The CAPTF machine module for Oracle Cloud</p>

<p align="center">
  <a href="https://github.com/captf-io/terraform-oci-machine/actions/workflows/ci.yml"><img
    src="https://img.shields.io/github/actions/workflow/status/captf-io/terraform-oci-machine/ci.yml?branch=main&amp;label=build&amp;labelColor=161B3A&amp;style=flat-square"
    alt="build"></a>
  <a href="https://captf.io/docs/module-author/contract/index.html"><img
    src="https://img.shields.io/static/v1?label=contract&amp;message=v1alpha1&amp;color=A974FF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="contract v1alpha1"></a>
  <a href="https://captf.io/docs/"><img
    src="https://img.shields.io/static/v1?label=docs&amp;message=captf.io&amp;color=5B8CFF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="docs captf.io"></a>
  <a href="https://github.com/captf-io/terraform-oci-machine/blob/main/LICENSE.md"><img
    src="https://img.shields.io/static/v1?label=license&amp;message=Apache-2.0&amp;color=FFD84D&amp;labelColor=161B3A&amp;style=flat-square"
    alt="license Apache-2.0"></a>
</p>

> [!NOTE]
> **Pre-release.** CAPTF is `v1alpha1`: its API and its
> [module contract](https://captf.io/docs/module-author/contract/index.html)
> may still change between releases.

The CAPTF Oracle Cloud (OCI) machine module: the Terraform/OpenTofu root module
behind `TerraformMachine`, implementing the
[machine role](https://captf.io/docs/module-author/contract/v1alpha1/machine.html)
of the module contract. It creates one compute instance per
`TerraformMachine`, placed in the Machine's failure domain, on the cluster's
subnet and network security group, and, for a control-plane machine,
registered in the API load balancer.

The module image is `ghcr.io/captf-io/oci-machine`, published from
[oci-modules](https://github.com/captf-io/oci-modules). Design decisions are
in [DESIGN.md](https://github.com/captf-io/terraform-oci-machine/blob/main/DESIGN.md).

## Using it

CAPTF runs this module from the module image `ghcr.io/captf-io/oci-machine`: set
the image on a `TerraformMachine`'s `spec.source.image` (through a
`TerraformMachineTemplate`), and the controller renders every input. The module
is also published to the Terraform Registry as `captf-io/machine/oci` and can be
called directly:

```hcl
module "machine" {
  source  = "captf-io/machine/oci"
  version = "~> 0.1"

  # The contract inputs the controller would render (captf_contract,
  # captf_cluster, captf_object, captf_tags, ...; see Inputs), and any
  # user variables.
}
```

Called directly, the module is a CAPTF root module first:

- it configures its own `provider "oci"` block, so the calling
  module cannot use `count`, `for_each` or `depends_on` on it, and the
  provider takes its credentials from the environment (see Identity
  Secret);
- its providers are pinned to exact versions (`versions.tf`), which the
  calling configuration has to accept;
- you set the `captf_*` inputs yourself.

## What it creates

| Resource | Address | When |
| --- | --- | --- |
| Compute instance and its boot volume | `oci_core_instance.node_instance` | always |
| Backend in each API backend set (`kube-apiserver`, and `rke2-supervisor` with RKE2) | `oci_network_load_balancer_backend.api_backends` | `control_plane` and a module-owned endpoint |

The instance:

- is named `machine_name`, the first key the OCI cloud controller manager
  looks a node up by;
- runs `image_id` on `shape` (`VM.Standard.E5.Flex`, 2 OCPUs, 16 GB by
  default) with a 100 GiB boot volume, encrypted at rest (with
  `boot_volume_kms_key_id` when set) and in transit;
- has no public IP and no SSH key unless asked, and instance metadata v1
  off;
- carries `user_data = bootstrap_data` unchanged, since OCI takes it base64
  encoded: cloud-config, Ignition and gzipped payloads alike;
- deletes its boot volume when it terminates;
- carries the cluster's defined tag, if it has one: the control-plane value
  on a control-plane machine (the only one the cluster's dynamic group
  matches), the worker value otherwise.

A control-plane machine registers in every backend set of the cluster's API
load balancer, in its own state: destroying the machine deregisters it. The
backend is created once the instance is RUNNING, a network load balancer
work request that typically completes within a minute or two, and the
backend takes traffic once its TCP health check passes: inside the minutes
`kubeadm init` and `join` take, but not verified against a fast init
(DESIGN.md "Unverified" 8).

## Prerequisites

- A cluster made by the OCI cluster module (its `exports`), or
  `external_cluster_exports` for an externally managed `TerraformCluster`.
- **An image** in the cluster's region with the container runtime, the
  kubelet and kubeadm (or RKE2) of the Machine's version, and cloud-init (or
  Ignition): for example one built with
  [image-builder](https://image-builder.sigs.k8s.io/capi/providers/oci.html). The
  module does not install anything at boot. Instance metadata v1 is off, so
  the image's cloud-init (or Ignition) must read metadata v2, with the
  `Authorization: Bearer Oracle` header, as current cloud-init does.
- **The kubelet's provider ID.** Set
  `provider-id: oci://{{ v1.instance_id }}` and `cloud-provider: external`
  in the bootstrap configuration's `kubeletExtraArgs`, as
  [`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-oci-machine/blob/main/examples/cluster-kubeadm.yaml) does:
  cloud-init's Oracle datasource sets `instance_id` to the instance OCID, so
  the Node carries exactly this module's `provider_id` from its first
  registration, with or without the cloud controller manager.
- **Quotas** for the shape's OCPUs and memory and for boot volumes.
- **Permissions** of the identity's user:

  ```text
  Allow group <group> to manage instance-family in compartment <compartment>
  Allow group <group> to use volume-family in compartment <compartment>
  Allow group <group> to use virtual-network-family in compartment <network compartment>
  Allow group <group> to use network-load-balancers in compartment <compartment>
  # node_identity.defined_tag on the cluster:
  Allow group <group> to use tag-namespaces in tenancy
  # boot_volume_kms_key_id:
  Allow service blockstorage to use keys in compartment <vault compartment>
  ```

## Inputs

Contract inputs used: `captf_cluster_outputs` (or `external_cluster_exports`),
`captf_tags`, `machine_name`, `bootstrap_data`, `failure_domain`,
`control_plane`. `captf_contract` and `bootstrap_format` are validated (both
formats pass through); `captf_cluster`, `captf_object` and
`kubernetes_version` are declared and unused: the image carries the version.

User variables (`spec.template.spec.variables` on the
`TerraformMachineTemplate`):

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `image_id` | `string` | required | Image OCID in the cluster's region. |
| `shape` | `string` | `VM.Standard.E5.Flex` | Compute shape. |
| `ocpus` | `number` | `2` | OCPUs of a flexible shape. |
| `memory_gib` | `number` | `16` | Memory of a flexible shape. |
| `boot_volume_size_gib` | `number` | `100` | Boot volume size, 50 to 32768. |
| `boot_volume_kms_key_id` | `string` | `null` | Vault key for the boot volume. |
| `pv_encryption_in_transit` | `bool` | `true` | Encrypt boot volume traffic in transit. |
| `preemptible` | `bool` | `false` | Preemptible capacity; workers only. |
| `public_ip` | `bool` | `false` | A public IP on the VNIC. |
| `ssh_authorized_keys` | `list(string)` | `[]` | SSH public keys. |
| `subnet_id` | `string` | the cluster's subnet for the role | Subnet of the VNIC. |
| `additional_nsg_ids` | `list(string)` | `[]` | Extra NSGs, at most 4. |
| `external_cluster_exports` | `any` | `null` | Exports for an externally managed cluster. |
| `ignore_defined_tags` | `list(string)` | `[]` | Tag-default keys to ignore. |
| `additional_tags` | `map(string)` | `{}` | Extra free-form tags; at most 4. |

The image's `io.captf.capacity` (`{"cpu":"4","memory":"16Gi"}`) and
`io.captf.node-info` (`amd64`, `linux`) labels describe the default shape,
for Cluster Autoscaler scale-from-zero. A template that changes the shape
should use an image built with matching `MACHINE_CAPACITY` and
`MACHINE_ARCH` (see the [oci-modules Makefile](https://github.com/captf-io/oci-modules/blob/main/Makefile)).

## Outputs

| Name | Value |
| --- | --- |
| `provider_id` | `oci://<instance OCID>`, the cloud controller manager's format: `ProviderName() + "://" + InstanceID` ([`ccm.go`](https://github.com/oracle/oci-cloud-controller-manager/blob/v1.36.0/pkg/cloudprovider/providers/oci/ccm.go) `providerPrefix`). |
| `addresses` | `InternalIP` (the primary private IP) and `ExternalIP` (the public IP, when there is one), as the cloud controller manager reports them ([`instances.go`](https://github.com/oracle/oci-cloud-controller-manager/blob/v1.36.0/pkg/cloudprovider/providers/oci/instances.go) `extractNodeAddresses`). |
| `failure_domain` | The requested failure domain, or the one picked from `machine_name` (below). |
| `interruptible` | `true` for a preemptible instance. |
| `health` | From the instance's lifecycle state (below). |

**Placement.** A requested failure domain must be one of the cluster's; the
instance goes to its availability domain and, in fault-domain mode, its
fault domain. Without one, the module picks
`sorted(names)[sha256(machine_name) mod n]`, so a re-render never moves the
machine.

## Exports

The machine role exports nothing; it reads the cluster's `exports`
([terraform-oci-cluster README](https://github.com/captf-io/terraform-oci-cluster/blob/main/README.md#exports)).

## Identity Secret

The cluster's identity, unless the template sets its own `identityRef`. See
the [oci-modules README](https://github.com/captf-io/oci-modules#using-it). The region comes from the
cluster's exports.

## Bootstrap

`metadata.user_data` is `bootstrap_data` unchanged, since OCI takes user
data base64-encoded: cloud-config (CABPK's Jinja header included), Ignition
and a gzipped cloud-config alike; cloud-init decompresses gzip. Gzipped
Ignition fails a precondition.

- **Size.** Instance metadata (user data plus SSH keys) may
  hold 32,000 bytes; a precondition stops a larger payload. A kubeadm
  control-plane payload with its certificates is well under that, but every
  extra file counts.
- **Secrecy.** The user data, which on a control-plane machine
  holds the cluster's CA keys, stays readable from the instance's metadata
  service and through the OCI API to principals that may read the instance:
  the cluster's dynamic group grants that to control-plane instances only
  (see [terraform-oci-cluster README](https://github.com/captf-io/terraform-oci-cluster/blob/main/README.md#limitations)). This falls
  short of the control-plane checklist's "keep key material out of readable
  instance metadata"; staging it in OCI Vault is not implemented.

## Tags

The instance and its VNIC carry `captf_tags` as free-form tags, `.` and space
mapped to `_` (`captf_io/cluster`), plus at most four `additional_tags`. The
instance also carries the cluster's node defined tag, when it has one.
Network load balancer backends are not taggable.

## Health

| Instance state | `health.state` | `healthy` | `reasons` |
| --- | --- | --- | --- |
| `PROVISIONING`, `STARTING` | `pending` | `false` | `InstanceProvisioning`, `InstanceStarting` |
| `RUNNING`, `MOVING` (live migration) | `running` | `true` | `[]` |
| `CREATING_IMAGE` | `unknown` | `false` | `InstanceCreatingImage` |
| `STOPPING`, `STOPPED` | `stopped` | `false` | `InstanceStopping`, `InstanceStopped` |
| `TERMINATING`, `TERMINATED` | `terminated` | `false` | `InstanceNotFound` |
| gone from state (the provider drops a `TERMINATED` instance on read; terminated out of band) | `terminated` | `false` | `InstanceNotFound` |
| anything else | `unknown` | `false` | `UnknownState` |

`health.message` names the OCI state.

## Limitations

- **Immutable.** A change to the bootstrap data or SSH keys replaces the
  instance, as an immutable Machine expects; CAPI rolls Machines through a
  new template instead.
- **Preemptible capacity** is rejected for control-plane machines.
- **Bootstrap secrecy:** the control-plane payload stays in instance
  metadata (see "Bootstrap").

## Exceptions

- `tfcapi-lint module --strict` passes without allowed warnings.
- `display_name` is `machine_name` rather than a hashed name
  (CONVENTIONS.md section 6): the cloud controller manager matches nodes by
  it.
- The control-plane payload is not staged in a store (CONVENTIONS.md
  section 13): it goes into instance metadata, as "Bootstrap" documents.
  OCI Vault secrets read by the instance principal could serve as the
  store; that is not implemented.

## Examples

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: TerraformMachineTemplate
metadata:
  name: demo-md-0
spec:
  template:
    spec:
      source:
        image: ghcr.io/captf-io/oci-machine:v0.1.0-opentofu
      variables:
        image_id: ocid1.image.oc1.iad.<id>
        boot_volume_size_gib: 200
        ssh_authorized_keys:
        - ssh-ed25519 AAAA… operator@example.com
```

The complete cluster is in
[`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-oci-machine/blob/main/examples/cluster-kubeadm.yaml).

## Developing

The host needs `make`, `podman` (or `docker` with `ENGINE=docker`), `jq` and
Go; every other tool runs in a container pinned by digest. `make verify` is
the gate. Override variables on the command line, for example
`make validate RUNTIMES=opentofu`.

| Target | What it does |
| --- | --- |
| `make fmt` | Format the module with `terraform fmt` and `tofu fmt`, in place. |
| `make fmt-check` | Fail on any file either formatter would change. |
| `make validate` | `init` and `validate` on both runtimes and on their floors (Terraform 1.5.7, OpenTofu 1.6.3). |
| `make unit-test` | `terraform test` and `tofu test` with mocked providers. |
| `make tflint` | `tflint` with the Terraform ruleset (preset all) and the cloud ruleset. |
| `make tfcapi-lint` | `tfcapi-lint module --strict`; skips when the linter is unavailable. |
| `make scan` | `trivy config` over the repository (HCL, workflows). |
| `make check-conventions` | `hack/check-layout.sh` (CONVENTIONS.md sections 2 and 4) and `hack/check-tags.sh` (section 7). |
| `make shellcheck` | `shellcheck` over `hack/` and every shell template, rendered with placeholders. |
| `make check-headers` | Fail on any source file without the Apache-2.0 license header. |
| `make fix-headers` | Add the license header to every source file missing it. |
| `make verify` | All of the above, in parallel groups: static checks, then one group per runtime. |
| `make clean` | Remove `build/`; keeps `.cache/` and `.tools/`. |

`tfcapi-lint` is built from the provider repository, found through
`PROVIDER_DIR` (default `../cluster-api-provider-terraform`). The repository
holds the code only: the module images are built and published from
[oci-modules](https://github.com/captf-io/oci-modules).

<br>
<p align="center">
  <img
    src="https://captf.io/assets/readme/divider.svg"
    width="100%" height="4" alt="">
</p>
<p align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="40" height="40" alt="CAPTF"></a>
  <br>
  <a href="https://captf.io/docs/"
    ><b>Documentation</b></a> ·
  <a href="https://captf.io/docs/getting-started/quick-start.html"
    ><b>Quick start</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/CONTRIBUTING.md"
    ><b>Contributing</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/SECURITY.md"
    ><b>Security</b></a>
  <br>
  <sub>Built for
    <a href="https://cluster-api.sigs.k8s.io/">Cluster API</a>.
    <a href="https://github.com/captf-io/terraform-oci-machine/blob/main/LICENSE.md"
    >Apache 2.0</a>.</sub>
</p>
