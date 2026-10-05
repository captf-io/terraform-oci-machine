# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The node: one compute instance, immutable like the Machine it backs. Its
# display name is machine_name, the first key the OCI cloud controller
# manager looks a node up by (GetInstanceByNodeName in
# https://github.com/oracle/oci-cloud-controller-manager/blob/v1.36.0/pkg/oci/client/compute.go).
# A change to user_data or ssh_authorized_keys replaces it (the provider's
# CustomizeDiff), which is what an immutable machine wants. count = 1 on
# purpose: the provider drops a TERMINATED instance from state on read
# (ReadResource in internal/tfresource/crud_helpers.go), and only a counted
# resource then reads as an empty list that try() turns into "terminated".
resource "oci_core_instance" "node_instance" {
  count = 1

  availability_domain = local.availability_domain
  compartment_id      = local.compartment_id
  # Lets the cluster's (control-plane) or an operator-managed dynamic group
  # match this node; null rather than {} when there is none.
  defined_tags                        = length(local.node_defined_tags) > 0 ? local.node_defined_tags : null
  display_name                        = var.machine_name
  fault_domain                        = local.fault_domain
  freeform_tags                       = local.tags
  is_pv_encryption_in_transit_enabled = var.pv_encryption_in_transit
  metadata                            = local.metadata
  # Terminating a node deletes its disk; nothing on it outlives the Machine.
  preserve_boot_volume = false
  shape                = var.shape

  create_vnic_details {
    # A string in the provider, which defaults it to "true": always set.
    assign_public_ip = tostring(var.public_ip)
    display_name     = var.machine_name
    freeform_tags    = local.tags
    nsg_ids          = compact(concat([local.node_nsg_id], var.additional_nsg_ids))
    subnet_id        = var.subnet_id != null ? var.subnet_id : local.node_subnet_id
  }

  # Instance metadata v1 off: v2 requires an "Authorization: Bearer Oracle"
  # header and rejects forwarded requests, which blunts request forgery:
  # https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/gettingmetadata.htm
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  dynamic "preemptible_instance_config" {
    for_each = var.preemptible ? [true] : []

    content {
      preemption_action {
        preserve_boot_volume = false
        type                 = "TERMINATE"
      }
    }
  }

  # Flexible shapes take OCPUs and memory; fixed shapes refuse them.
  dynamic "shape_config" {
    for_each = endswith(var.shape, ".Flex") ? [true] : []

    content {
      memory_in_gbs = var.memory_gib
      ocpus         = var.ocpus
    }
  }

  source_details {
    boot_volume_size_in_gbs = tostring(var.boot_volume_size_gib)
    kms_key_id              = var.boot_volume_kms_key_id
    source_id               = var.image_id
    source_type             = "image"
  }

  lifecycle {
    precondition {
      condition     = local.exports != null
      error_message = "The TerraformCluster is externally managed (captf_cluster_outputs is {}): set spec.variables.external_cluster_exports on the TerraformMachineTemplate to the cluster's exports (README \"Exports\")."
    }
    precondition {
      condition     = local.placement != null
      error_message = "failure_domain ${coalesce(var.failure_domain, "(none)")} is not one of the cluster's failure domains: ${join(", ", local.failure_domain_names)}."
    }
    precondition {
      condition     = !(var.bootstrap_format == "ignition" && nonsensitive(startswith(var.bootstrap_data, "H4sI")))
      error_message = "bootstrap_data is gzipped Ignition, which this module refuses: Ignition is not known to decompress its user-data config on OCI. Turn off compression in the bootstrap provider (CAPRKE2 gzipUserData)."
    }
    precondition {
      condition     = !(var.preemptible && var.control_plane)
      error_message = "preemptible is for workers only: OCI may reclaim a preemptible instance at any time, which a control-plane member must not risk."
    }
    precondition {
      condition     = local.metadata_bytes <= local.metadata_limit_bytes
      error_message = "The instance metadata (bootstrap data plus SSH keys) is ${local.metadata_bytes} bytes; OCI accepts ${local.metadata_limit_bytes}. Shrink the bootstrap configuration (fewer or smaller files), or gzip it in the bootstrap provider (CAPRKE2 gzipUserData)."
    }
    precondition {
      condition     = length(local.tags) <= 10
      error_message = "OCI allows 10 free-form tags per resource; captf_tags and additional_tags together hold ${length(local.tags)}. Remove entries from additional_tags."
    }
  }
}
