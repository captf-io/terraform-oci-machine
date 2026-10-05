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

# Machine health from the instance's lifecycle state (CONVENTIONS.md
# section 10). States:
# https://docs.oracle.com/en-us/iaas/api/#/en/iaas/latest/Instance/
locals {
  # OCI instance lifecycle state -> contract health (common.md "Outputs").
  health_by_state = {
    PROVISIONING = { state = "pending", healthy = false, reason = "InstanceProvisioning" }
    STARTING     = { state = "pending", healthy = false, reason = "InstanceStarting" }
    RUNNING      = { state = "running", healthy = true, reason = null }
    # Live migration to another host; the instance keeps running.
    MOVING = { state = "running", healthy = true, reason = null }
    # A custom image is being taken; the instance is not serving meanwhile.
    CREATING_IMAGE = { state = "unknown", healthy = false, reason = "InstanceCreatingImage" }
    STOPPING       = { state = "stopped", healthy = false, reason = "InstanceStopping" }
    STOPPED        = { state = "stopped", healthy = false, reason = "InstanceStopped" }
    TERMINATING    = { state = "terminated", healthy = false, reason = "InstanceNotFound" }
    TERMINATED     = { state = "terminated", healthy = false, reason = "InstanceNotFound" }
  }

  # try(): the provider drops a TERMINATED instance from state on read, and
  # an out-of-band termination leaves no instance at all (node_instance.tf).
  instance_state = try(upper(oci_core_instance.node_instance[0].state), null)
  health_reading = (
    local.instance_state == null ? { state = "terminated", healthy = false, reason = "InstanceNotFound" } :
    lookup(local.health_by_state, local.instance_state, { state = "unknown", healthy = false, reason = "UnknownState" })
  )
  health_message = local.instance_state == null ? "instance not found" : "instance is ${local.instance_state}"
}
