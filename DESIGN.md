# Design: terraform-oci-machine

Why these modules look the way they do. Each decision names the evidence it
rests on; anything not yet checked against a real tenancy is listed under
"Unverified" and must be confirmed on the first reviewed apply.

Pins: `oracle/oci` 9.8.0. Runtimes: Terraform >= 1.5, OpenTofu >= 1.6.
Conventions: [CONVENTIONS.md](CONVENTIONS.md). Contract:
<https://captf.io/docs/module-author/contract/v1alpha1/>.

Provider facts below were read from the 9.8.0 sources
(`internal/service/<service>/*_resource.go`, `internal/provider/provider.go`,
`internal/tfresource/retry.go`) and `providers schema -json` of the pinned
provider; "ForceNew" means the attribute forces a replacement there.

The decision and "Unverified" numbers are the same in every terraform-oci-*
repository (they follow the cloud's original DESIGN.md), so a citation such as
"decision 6" means the same thing everywhere. A section that only concerns
another role is a one-line pointer under its original number.

## Scope

- One role, `machine`: one compute instance per `TerraformMachine`.. The other roles are in
  [terraform-oci-cluster](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md) and
  [terraform-oci-machinepool](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md).
- Cluster exports consumed (schema `captf.io/oci-cluster/v1`, defined in
  the [cluster repository's DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#exports-captfiooci-clusterv1)):
  `region`, `compartment_id`, `control_plane_subnet_id`, `worker_subnet_id`,
  `control_plane_nsg_id`, `worker_nsg_id`, `failure_domains`,
  `node_defined_tags`, `control_plane_defined_tags` and `api`.

## Decisions

### 1. API Network Load Balancer

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#1-api-network-load-balancer). The machine role's part:

- Control-plane machines add themselves as backends
  (`oci_network_load_balancer_backend`, `target_id` = instance OCID) in
  their own state. OCI cannot register an instance before its OCID exists;
  the provider registers it seconds after RUNNING, well inside kubeadm's
  wait: the backend is a work request that typically completes in a minute
  or two, and takes traffic once its TCP health check passes
  (`is_fail_open` stays false). Concurrent backend changes on one NLB
  return 409; the provider retries 409 by default (`retry.go`, unless
  `disable_409_retry`).

### 2. Network security groups

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#2-network-security-groups).

### 3. Failure domains

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#3-failure-domains).

### 4. Node identity

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#4-node-identity).

### 5. Machine

- `oci_core_instance` with `count = 1`: the provider drops an instance in
  a deleted target state (TERMINATED) from state on read (`ReadResource` in
  `internal/tfresource/crud_helpers.go`), and only a counted resource then
  reads as an empty list, which `try()` turns into health `terminated`.
  `display_name = machine_name` (the CCM's first
  lookup key, `GetInstanceByNodeName` in `pkg/oci/client/compute.go`),
  placement from the failure domain's attributes, flexible shape
  (`VM.Standard.E5.Flex`, 2 OCPUs, 16 GB by default; `shape_config` only for
  `*.Flex` shapes), boot volume of 100 GiB and optional KMS key,
  `preserve_boot_volume = false`.
- Legacy IMDS endpoints disabled; in-transit encryption on; no public IP
  by default (`create_vnic_details.assign_public_ip` is a string attribute
  with `Default: "true"` in `core_instance_resource.go`, so it is always
  set); SSH keys only when given; no hostname label (the CCM falls back to
  VNIC lookups, and the kubelet registers its provider ID itself, below).
- `metadata.user_data = var.bootstrap_data` verbatim (base64; works for
  cloud-config, Ignition and gzip). `metadata` and `extended_metadata` may
  total 32,000 bytes; a precondition enforces it on
  `length(jsonencode(metadata))`. Changing `user_data` or
  `ssh_authorized_keys` replaces the instance (the resource's
  CustomizeDiff `ForceNewIfChange("metadata", …)`), which is fine for
  immutable machines.
- Gzipped Ignition fails a precondition (CONVENTIONS.md section 13):
  Ignition is not known to decompress its user-data config on OCI.
- The control-plane payload, with the cluster CA keys, stays in instance
  metadata: CONVENTIONS.md section 13 asks for staging in a store the
  instance identity can read, and OCI Vault secrets could be one, but that
  is not implemented; the README documents the exposure under "Bootstrap"
  and lists it under "Exceptions".
- Preemptible capacity for workers only (`preemption_action TERMINATE`);
  `interruptible` follows it.
- Failure domain null: `sorted(names)[sha256(machine_name) mod n]`.
- The kubelet sets `--provider-id=oci://{{ v1.instance_id }}` in the
  examples: CABPK's cloud-config is a Jinja template and cloud-init's
  Oracle datasource sets `instance-id` to the instance OCID
  (`DataSourceOracle.py`), so the Node carries the module's `provider_id`
  from its first registration, CCM or not.

### 6. Machine pool

Concerns the machinepool role: see [terraform-oci-machinepool DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md#6-machine-pool).

### 7. provider_id, addresses, health

- `oci://<instance-ocid>`: oci-cloud-controller-manager v1.36.0 implements
  Instances v1 and cloud-provider builds `ProviderName() + "://" +
  InstanceID` (`ccm.go` `providerPrefix = providerName + "://"`,
  `k8s.io/cloud-provider` `GetInstanceProviderID`).
- Addresses: InternalIP (private IP), ExternalIP when public; the same set
  the CCM reports for IPv4 (`extractNodeAddresses`, `instances.go`).
- Health from instance `state`: PROVISIONING, STARTING → pending; RUNNING,
  MOVING → running; CREATING_IMAGE → unknown; STOPPING, STOPPED → stopped;
  TERMINATING, TERMINATED → terminated; gone from state → terminated. The
  enum is `InstanceLifecycleStateEnum` in oci-go-sdk v65.126.1, the
  provider's SDK.

Cluster health: [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#7-provider_id-addresses-health); pool health: [terraform-oci-machinepool DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md#7-provider_id-addresses-health).

### 8. Subnet checks and teardown

Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#8-subnet-checks-and-teardown).

### 9. Tags


Free-form tag keys cannot contain periods or spaces, are case-insensitive,
and a resource carries at most 10 free-form tags
(<https://docs.oracle.com/en-us/iaas/Content/Tagging/Concepts/taggingoverview.htm>,
"Limits on Tags": keys printable ASCII without periods or spaces, at most
100 characters; values at most 256). Mapping: `.` and space to `_`
(`captf.io/cluster` → `captf_io/cluster`); values unchanged. The six captf
tags leave four slots, so `additional_tags` takes at most four entries, and
a precondition on each role's primary resource checks the total. Provider
blocks set `ignore_defined_tags = ["Oracle-Tags.CreatedBy",
"Oracle-Tags.CreatedOn"]` plus the user's `ignore_defined_tags`, so tenancy
tag defaults cause no drift. Not taggable: NSG rules, backend sets,
listeners and backends.

### 10. Credentials


Every provider argument falls back to `TF_VAR_<attr>` and then
`OCI_<ATTR>` (`MultiEnvDefaultFunc` with `tfVarName`/`ociVarName` in
`provider.go` 9.8.0); CAPTF drops `TF_VAR_*`, so the identity uses the
`OCI_*` forms:

```yaml
OCI_TENANCY_OCID: ocid1.tenancy.oc1..<id>
OCI_USER_OCID: ocid1.user.oc1..<id>
OCI_FINGERPRINT: "<aa:bb:...>"
OCI_PRIVATE_KEY_PATH: /var/run/captf/credentials/oci_api_key.pem
oci_api_key.pem: <PEM>
```

`OCI_PRIVATE_KEY` would take precedence over the path, so it is not used.
Config-file profiles read `$HOME/.oci/config`, and the runner sets `HOME`
to `/captf/work`, so profiles (and SecurityToken auth) are unusable. A
management cluster running on OCI can use `OCI_AUTH=InstancePrincipal`.
Modules set the region explicitly: `region` on the cluster, the exports'
region on machines and pools.


## Unverified

**1.** Whether OCI accepts empty free-form tag values (`captf.io/template`).

**2.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

**3.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

**4.** Concerns the machinepool role: see [terraform-oci-machinepool DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md#unverified).

**5.** Concerns the machinepool role: see [terraform-oci-machinepool DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md#unverified).

**6.** Concerns the machinepool role: see [terraform-oci-machinepool DESIGN.md](https://github.com/captf-io/terraform-oci-machinepool/blob/main/DESIGN.md#unverified).

**7.** Idempotency of `shape_config`, `source_details`, defined tags and the
autoscaling rules' read-back (first real apply must show an empty second
plan).

**8.** Backend registration timing (work request plus health-check rise)
against a fast `kubeadm init`.

**9.** In-transit encryption (`is_pv_encryption_in_transit_enabled`) on custom
images such as image-builder's.

**10.** Concerns the cluster role: see [terraform-oci-cluster DESIGN.md](https://github.com/captf-io/terraform-oci-cluster/blob/main/DESIGN.md#unverified).

## Rejected alternatives

- Config-file profiles (no `$HOME/.oci` in the Job).
- Gzipping uncompressed cloud-config in the module for more user-data
  headroom: the contract's pass-through rule is simpler, and a kubeadm
  control-plane payload fits the 32,000 bytes.
