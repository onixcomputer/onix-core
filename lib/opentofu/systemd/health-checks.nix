# SystemD Health Check Strategies
# Extensible health check logic for different service types
{ lib }:

rec {
  # Health check strategy interface
  healthCheckStrategies = {
    # Keycloak-specific health checks with comprehensive OIDC readiness verification
    keycloak = {
      description = "Keycloak OIDC authentication service";
      maxAttempts = 90; # 3 minutes total
      sleepInterval = 2; # seconds between attempts

      phases = [
        {
          name = "startup";
          description = "Startup probe";
          url = "http://localhost:9000/management/health/started";
          required = true;
        }
        {
          name = "readiness";
          description = "Readiness probe";
          url = "http://localhost:9000/management/health/ready";
          required = true;
        }
        {
          name = "oidc";
          description = "OIDC endpoints";
          url = "http://localhost:8080/realms/master/protocol/openid-connect/certs";
          required = true;
        }
      ];

      # Additional stabilization wait after all probes pass
      stabilizationWait = 10;
    };

    # Garage S3-compatible storage health checks
    garage = {
      description = "Garage S3-compatible storage";
      maxAttempts = 30; # 1 minute total
      sleepInterval = 2;

      phases = [
        {
          name = "health";
          description = "Health endpoint";
          url = "http://127.0.0.1:3903/health";
          required = true;
        }
        {
          name = "api";
          description = "S3 API endpoint";
          url = "http://127.0.0.1:3900/";
          required = false; # S3 endpoint may return 403 but still be functional
        }
      ];

      stabilizationWait = 5;
    };

    # Generic health check for services with basic HTTP endpoints
    generic = {
      description = "Generic HTTP service";
      maxAttempts = 30; # 1 minute total
      sleepInterval = 2;

      phases = [
        {
          name = "basic";
          description = "Basic service readiness";
          url = null; # No URL-based checks, just systemd service status
          required = true;
        }
      ];

      stabilizationWait = 5;
    };
  };

  # Generate health check script for a specific service
  generateHealthChecks =
    serviceName:
    let
      strategy =
        if builtins.hasAttr serviceName healthCheckStrategies then
          healthCheckStrategies.${serviceName}
        else
          healthCheckStrategies.generic;

      # Generate script for a single health check phase
      generatePhaseCheck = phase: ''
        echo "Checking ${phase.description}..."
        ${
          if phase.url != null then
            ''
              if curl -sf ${phase.url} >/dev/null 2>&1; then
                echo "✓ ${phase.description} passed"
                PHASE_${lib.toUpper phase.name}_PASSED=1
              else
                echo "✗ ${phase.description} failed (attempt $i/${toString strategy.maxAttempts})"
                ${
                  if phase.required then
                    "PHASE_${lib.toUpper phase.name}_PASSED=0"
                  else
                    "PHASE_${lib.toUpper phase.name}_PASSED=1"
                }
              fi
            ''
          else
            ''
              # No URL check - assume passed for systemd-only verification
              echo "✓ ${phase.description} passed (systemd-based)"
              PHASE_${lib.toUpper phase.name}_PASSED=1
            ''
        }
      '';

      # Generate all phase checks and success validation
      phaseChecks = lib.concatStringsSep "\n" (map generatePhaseCheck strategy.phases);

      # Generate success condition check
      successConditions = lib.concatStringsSep " && " (
        map (phase: "[ \"$PHASE_${lib.toUpper phase.name}_PASSED\" = \"1\" ]") (
          builtins.filter (p: p.required) strategy.phases
        )
      );

    in
    ''
      echo "=== ${serviceName} Readiness Verification ==="
      echo "Strategy: ${strategy.description}"
      echo "Timestamp: $(date -Iseconds)"

      # Phase 1: Wait for systemd service to be active
      echo "Phase 1: Waiting for systemd service..."
      for i in {1..60}; do
        if systemctl is-active ${serviceName}.service >/dev/null 2>&1; then
          echo "✓ ${serviceName} systemd service is active"
          break
        fi
        [ "$i" -eq 60 ] && {
          echo "ERROR: ${serviceName} service failed to start"
          echo "Service status:"
          systemctl status ${serviceName}.service --no-pager || true
          exit 1
        }
        echo "Waiting for ${serviceName} service... (attempt $i/60)"
        sleep 2
      done

      # Phase 2: Service-specific health checks
      ${
        if strategy.phases != [ ] && (builtins.any (p: p.url != null) strategy.phases) then
          ''
            echo "Phase 2: Service-specific health verification..."

            for i in $(seq 1 ${toString strategy.maxAttempts}); do
              # Initialize phase status variables
              ${lib.concatStringsSep "\n" (
                map (phase: "PHASE_${lib.toUpper phase.name}_PASSED=0") strategy.phases
              )}

              ${phaseChecks}

              # Check if all required phases passed
              if ${successConditions}; then
                echo "✓ All required health checks passed"
                echo "✓ ${serviceName} is fully ready for terraform operations"
                break
              fi

              [ "$i" -eq ${toString strategy.maxAttempts} ] && {
                echo "ERROR: ${serviceName} health checks failed after $((${toString strategy.maxAttempts} * ${toString strategy.sleepInterval})) seconds"
                echo "Service status:"
                systemctl status ${serviceName}.service --no-pager || true
                exit 1
              }

              sleep ${toString strategy.sleepInterval}
            done
          ''
        else
          ''
            echo "Phase 2: Using basic service readiness wait..."
            sleep ${toString strategy.stabilizationWait}
          ''
      }

      # Phase 3: Stabilization wait if configured
      ${
        if strategy.stabilizationWait > 0 then
          ''
            echo "Phase 3: Service stabilization wait (${toString strategy.stabilizationWait}s)..."
            sleep ${toString strategy.stabilizationWait}
          ''
        else
          ""
      }

      echo "=== ${serviceName} Ready for Terraform Operations ==="
    '';

  # Register a new health check strategy
  registerHealthCheckStrategy =
    serviceName: strategy: healthCheckStrategies // { ${serviceName} = strategy; };

  # Get available health check strategies
  getAvailableStrategies = builtins.attrNames healthCheckStrategies;

  # Validate a health check strategy configuration
  validateHealthCheckStrategy =
    strategy:
    let
      requiredFields = [
        "description"
        "maxAttempts"
        "sleepInterval"
        "phases"
        "stabilizationWait"
      ];
      missingFields = builtins.filter (field: !builtins.hasAttr field strategy) requiredFields;
    in
    if missingFields == [ ] then
      strategy
    else
      throw "validateHealthCheckStrategy: Missing required fields: ${lib.concatStringsSep ", " missingFields}";
}
