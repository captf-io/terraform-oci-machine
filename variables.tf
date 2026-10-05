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

# User variables of the machine role, alphabetical. Set them through
# TerraformMachineTemplate spec.template.spec.variables:
# https://captf.io/docs/user-guide/variables.html. The defaults describe the
# shape the image's io.captf.capacity label advertises (Makefile
# MACHINE_CAPACITY); change both together.

variable "additional_nsg_ids" {
  description = "OCIDs of extra network security groups for the VNIC, after the cluster's control-plane or worker NSG. At most 4: a VNIC holds 5."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = length(var.additional_nsg_ids) <= 4 && alltrue([for id in var.additional_nsg_ids : startswith(id, "ocid1.networksecuritygroup.")])
    error_message = "additional_nsg_ids holds at most 4 network security group OCIDs (ocid1.networksecuritygroup.…): a VNIC holds 5 and the cluster's NSG is always one."
  }
}

variable "additional_tags" {
  description = "Extra OCI free-form tags for the instance and its VNIC. At most 4: OCI allows 10 free-form tags per resource and captf_tags takes 6."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = length(var.additional_tags) <= 4
    error_message = "additional_tags holds at most 4 entries: OCI allows 10 free-form tags per resource and the 6 captf tags are always set."
  }
  validation {
    condition     = alltrue([for k, v in var.additional_tags : can(regex("^[!-~]{1,100}$", k)) && !strcontains(k, ".") && length(v) <= 256])
    error_message = "additional_tags keys must be 1-100 printable ASCII characters without periods or spaces, and values at most 256 characters (OCI tag limits)."
  }
  validation {
    condition     = alltrue([for k in keys(var.additional_tags) : !startswith(lower(k), "captf_io/")])
    error_message = "additional_tags keys must not start with captf_io/: that prefix holds the captf tags, and OCI tag keys are case-insensitive."
  }
}

variable "boot_volume_kms_key_id" {
  description = "OCID of a Vault key that encrypts the boot volume. Null uses Oracle-managed keys; OCI encrypts every volume at rest either way."
  type        = string
  default     = null

  validation {
    condition     = var.boot_volume_kms_key_id == null || startswith(coalesce(var.boot_volume_kms_key_id, "-"), "ocid1.key.")
    error_message = "boot_volume_kms_key_id must be a Vault key OCID (ocid1.key.…)."
  }
}

variable "boot_volume_size_gib" {
  description = "Boot volume size in GiB (OCI's \"GB\"). 100 by default: room for images and logs beyond the 50 GiB minimum."
  type        = number
  default     = 100
  nullable    = false

  validation {
    condition     = var.boot_volume_size_gib >= 50 && var.boot_volume_size_gib <= 32768 && floor(var.boot_volume_size_gib) == var.boot_volume_size_gib
    error_message = "boot_volume_size_gib must be a whole number from 50 to 32768 (OCI boot volume limits)."
  }
}

variable "external_cluster_exports" {
  description = "The cluster exports to use when the TerraformCluster is externally managed (captf_cluster_outputs is {}): the same object the OCI cluster module exports, schema captf.io/oci-cluster/v1."
  type        = any
  default     = null

  validation {
    condition     = var.external_cluster_exports == null || try(var.external_cluster_exports.schema, null) == "captf.io/oci-cluster/v1"
    error_message = "external_cluster_exports must follow schema captf.io/oci-cluster/v1 (README \"Exports\"), with schema = \"captf.io/oci-cluster/v1\"."
  }
}

variable "ignore_defined_tags" {
  description = "Defined tags (\"<namespace>.<key>\") that tenancy tag defaults add and Terraform should not manage, on top of Oracle-Tags.CreatedBy and Oracle-Tags.CreatedOn, which are always ignored."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = length(var.ignore_defined_tags) <= 98 && alltrue([for t in var.ignore_defined_tags : can(regex("^[^. ]+\\.[^. ]+$", t))])
    error_message = "ignore_defined_tags holds at most 98 entries of the form <namespace>.<key> (the provider allows 100; two are Oracle-Tags)."
  }
}

variable "image_id" {
  description = "OCID of the node image in the cluster's region: an image with the container runtime, kubelet and kubeadm (or RKE2) of the Machine's version, such as one built by image-builder. Required: images are regional and the module cannot guess one."
  type        = string
  default     = null

  validation {
    condition     = var.image_id != null && startswith(coalesce(var.image_id, "-"), "ocid1.image.")
    error_message = "image_id is required: set spec.template.spec.variables.image_id on the TerraformMachineTemplate to an image OCID (ocid1.image.…)."
  }
}

variable "memory_gib" {
  description = "Memory of a flexible shape in GiB (OCI's \"GB\"). 16 by default, with ocpus 2 (4 vCPUs): the 4 vCPU / 16 GiB node the image's capacity label advertises. Ignored for fixed shapes."
  type        = number
  default     = 16
  nullable    = false

  validation {
    condition     = var.memory_gib >= 1
    error_message = "memory_gib must be at least 1."
  }
}

variable "ocpus" {
  description = "OCPUs of a flexible shape (one OCPU is two vCPUs on x86). 2 by default; see memory_gib. Ignored for fixed shapes."
  type        = number
  default     = 2
  nullable    = false

  validation {
    condition     = var.ocpus >= 1
    error_message = "ocpus must be at least 1."
  }
}

variable "preemptible" {
  description = "Run on preemptible capacity, which OCI may reclaim at any time (the Machine is then interruptible). Workers only; off by default."
  type        = bool
  default     = false
  nullable    = false
}

variable "public_ip" {
  description = "Give the instance a public IP. Off by default: nodes stay private and reach the internet through the VCN's NAT gateway. Needs a public subnet."
  type        = bool
  default     = false
  nullable    = false
}

variable "pv_encryption_in_transit" {
  description = "Encrypt the paravirtualized boot volume traffic between the instance and the storage servers. On by default; turn it off only for images without paravirtualized attachments."
  type        = bool
  default     = true
  nullable    = false
}

variable "shape" {
  description = "OCI compute shape. VM.Standard.E5.Flex by default: current-generation AMD x86 with flexible OCPUs and memory (ocpus, memory_gib)."
  type        = string
  default     = "VM.Standard.E5.Flex"
  nullable    = false

  validation {
    condition     = can(regex("^(VM|BM)\\.[A-Za-z0-9.]+$", var.shape))
    error_message = "shape must be an OCI compute shape name such as VM.Standard.E5.Flex."
  }
}

variable "ssh_authorized_keys" {
  description = "SSH public keys for the image's default user. Empty by default: no SSH access, and the cluster's NSGs admit SSH only from ssh_allowed_cidrs."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for k in var.ssh_authorized_keys : can(regex("^(ssh-|ecdsa-|sk-)", k))])
    error_message = "ssh_authorized_keys must hold OpenSSH public keys (ssh-ed25519 …, ssh-rsa …, ecdsa-sha2-… or sk-…)."
  }
}

variable "subnet_id" {
  description = "OCID of the subnet for the instance. Null uses the cluster's control-plane or worker subnet from exports."
  type        = string
  default     = null

  validation {
    condition     = var.subnet_id == null || startswith(coalesce(var.subnet_id, "-"), "ocid1.subnet.")
    error_message = "subnet_id must be a subnet OCID (ocid1.subnet.…)."
  }
}
