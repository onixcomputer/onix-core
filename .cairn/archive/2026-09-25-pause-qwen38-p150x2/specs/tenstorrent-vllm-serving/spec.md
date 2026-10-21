# Tenstorrent Qwen Serving Specification Delta

## MODIFIED Requirements

### Requirement: Qwen3.8-27B owns the P150x2 mesh

r[onix.tenstorrent.p150x2_qwen.deployment] The `britton-desktop` deployment MUST define the pinned Qwen3.8-27B package as `qwen38-p150x2.service`, MUST use physical devices 0 and 1 as one `1x2` mesh, and MUST serve only on loopback port 8000. While the operator keeps the P150 devices paused, the unit MUST be masked, so that neither boot, a deployment, nor another unit's `Wants=` starts it.

#### Scenario: The paused service stays down

- GIVEN the unit is masked on `britton-desktop`
- WHEN the host boots, a deployment activates, or a unit that wants it starts
- THEN `qwen38-p150x2.service` MUST NOT start
- AND no process MUST hold either P150 device for it

#### Scenario: A required model or device path is absent

- GIVEN the model snapshot or either device node is absent
- WHEN systemd evaluates the service conditions
- THEN the service does not start
- AND systemd records the failed condition without selecting another model service
