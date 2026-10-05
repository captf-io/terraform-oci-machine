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

# Where the instance goes. The requested failure domain is honoured exactly
# (machine.md "failure_domain (input)"); without one the module picks
# deterministically, the sha256 of machine_name over the sorted names
# (CONVENTIONS.md section 11), so a re-render never moves the machine.
locals {
  failure_domain_names = sort(keys(local.cluster_failure_domains))
  # No failure domains at all is an exports problem the precondition on
  # node_instance.tf reports.
  failure_domain = var.failure_domain != null ? var.failure_domain : (
    length(local.failure_domain_names) == 0 ? null :
    local.failure_domain_names[parseint(substr(sha256(var.machine_name), 0, 8), 16) % length(local.failure_domain_names)]
  )
  placement = try(local.cluster_failure_domains[local.failure_domain], null)

  availability_domain = try(local.placement.availability_domain, null)
  # Absent in availability-domain mode: OCI picks the fault domain.
  fault_domain = try(local.placement.fault_domain, null)
}
