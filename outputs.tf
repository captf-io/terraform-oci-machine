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

# Contract outputs of the machine role, in contract order:
# https://captf.io/docs/module-author/contract/v1alpha1/machine.html#outputs
# and common.md "Outputs" (health).

output "provider_id" {
  description = "oci://<instance OCID>, exactly what the OCI cloud controller manager writes to Node.spec.providerID (ProviderName() + \"://\" + InstanceID; providerPrefix in https://github.com/oracle/oci-cloud-controller-manager/blob/v1.36.0/pkg/cloudprovider/providers/oci/ccm.go)."
  value       = try("oci://${oci_core_instance.node_instance[0].id}", null)
}

output "addresses" {
  description = "The primary VNIC's private IP (InternalIP) and public IP when it has one (ExternalIP), as the OCI cloud controller manager reports them (extractNodeAddresses in pkg/cloudprovider/providers/oci/instances.go)."
  value = concat(
    [for ip in compact([try(oci_core_instance.node_instance[0].private_ip, "")]) : { type = "InternalIP", address = ip }],
    [for ip in compact([try(oci_core_instance.node_instance[0].public_ip, "")]) : { type = "ExternalIP", address = ip }],
  )
}

output "failure_domain" {
  description = "The failure domain the instance is in: the requested one, or the one picked from machine_name."
  value       = local.failure_domain
}

output "interruptible" {
  description = "Whether the instance runs on preemptible capacity."
  value       = try(length(oci_core_instance.node_instance[0].preemptible_instance_config) > 0, var.preemptible)
}

output "health" {
  description = "Machine health from the instance's lifecycle state (common.md \"Outputs\")."
  value = {
    state   = local.health_reading.state
    healthy = local.health_reading.healthy
    message = local.health_message
    reasons = local.health_reading.healthy ? [] : [local.health_reading.reason]
  }
}
