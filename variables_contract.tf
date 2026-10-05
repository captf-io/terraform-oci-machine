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

# Contract inputs of the machine role, in contract order and with the
# contract's types: https://captf.io/docs/module-author/contract/v1alpha1/common.html
# and https://captf.io/docs/module-author/contract/v1alpha1/machine.html.

# Read only by its own validation, which is the point of it.
# tflint-ignore: terraform_unused_declarations
variable "captf_contract" {
  description = "Contract version the controller generated the root module for. Always \"v1alpha1\"."
  type        = string

  validation {
    condition     = var.captf_contract == "v1alpha1"
    error_message = "captf_contract must be \"v1alpha1\": this module implements contract v1alpha1 only."
  }
}

# The instance is named after machine_name; the cluster's names come from
# exports.
# tflint-ignore: terraform_unused_declarations
variable "captf_cluster" {
  description = "The owning CAPI Cluster: name and namespace."
  type = object({
    name      = string
    namespace = string
  })
}

# The instance is named after the CAPI Machine, which the cloud controller
# manager matches nodes against, not after the TerraformMachine.
# tflint-ignore: terraform_unused_declarations
variable "captf_object" {
  description = "The TerraformMachine being reconciled: kind, name and namespace."
  type = object({
    kind      = string
    name      = string
    namespace = string
  })
}

variable "captf_cluster_outputs" {
  description = "The cluster role's exports (schema captf.io/oci-cluster/v1), or {} for an externally managed TerraformCluster (then external_cluster_exports applies)."
  type        = any

  validation {
    condition     = try(length(var.captf_cluster_outputs), 0) == 0 || try(var.captf_cluster_outputs.schema, null) == "captf.io/oci-cluster/v1"
    error_message = "captf_cluster_outputs must be the exports of the OCI cluster module (schema captf.io/oci-cluster/v1): the TerraformCluster runs a different or incompatible cluster module."
  }
}

variable "captf_tags" {
  description = "Fixed tags the controller sets (captf.io/cluster, namespace, kind, name, managed-by, template). Applied to every taggable resource as OCI free-form tags."
  type        = map(string)
}

variable "machine_name" {
  description = "Name of the owning CAPI Machine. The instance's display name: the OCI cloud controller manager looks nodes up by it."
  type        = string
}

variable "bootstrap_data" {
  description = "Base64 of the bootstrap Secret's value; passed unchanged as the instance's user_data, which OCI takes base64-encoded."
  type        = string
  sensitive   = true
}

variable "bootstrap_format" {
  description = "Format of the bootstrap payload: cloud-config or ignition. Both are passed through unchanged."
  type        = string

  validation {
    condition     = contains(["cloud-config", "ignition"], var.bootstrap_format)
    error_message = "bootstrap_format must be cloud-config or ignition."
  }
}

variable "failure_domain" {
  description = "Machine.spec.failureDomain: a failure domain name from the cluster's exports. Null lets the module pick one deterministically from machine_name."
  type        = string
  default     = null
}

# The image decides the Kubernetes version; nothing here depends on it.
# tflint-ignore: terraform_unused_declarations
variable "kubernetes_version" {
  description = "Machine.spec.version. Not used: image_id carries the Kubernetes version."
  type        = string
  default     = null
}

variable "control_plane" {
  description = "Whether the Machine is a control-plane machine: it then registers in the API load balancer's backend sets and joins the control-plane NSG."
  type        = bool
}
