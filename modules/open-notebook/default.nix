{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "open-notebook";
    readme = "Open Notebook research workspace with automatic provider bootstrap";
    description = "Open Notebook plus SurrealDB, configured as a clan service";
    categories = [
      "AI/ML"
      "Knowledge"
    ];
  };

  roles.server = {
    description = "Open Notebook server";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            inputs,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.server);
            generatorName = "open-notebook-${instanceName}";

            inherit (settings)
              stateDir
              openNotebookImage
              surrealdbImage
              credentials
              defaultModels
              installLauncher
              ;

            dataDir = "${stateDir}/data";
            dbDir = "${stateDir}/surrealdb";
            envFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
            bootstrapFile = config.clan.core.vars.generators.${generatorName}.files."bootstrap-json".path;
            apiUrl = "http://127.0.0.1:5055";
            bootstrapJson = builtins.toJSON {
              inherit credentials defaultModels;
            };

            waitForSurreal = pkgs.writeShellApplication {
              name = "open-notebook-wait-for-surreal";
              runtimeInputs = [ pkgs.curl ];
              text = ''
                attempts=60
                while [ "$attempts" -gt 0 ]; do
                  if curl -fsS http://127.0.0.1:8000/health >/dev/null 2>&1; then
                    exit 0
                  fi
                  attempts=$((attempts - 1))
                  sleep 1
                done

                echo "Timed out waiting for SurrealDB on 127.0.0.1:8000" >&2
                exit 1
              '';
            };

            bootstrapScript = pkgs.writeShellApplication {
              name = "open-notebook-bootstrap";
              runtimeInputs = [ pkgs.python3 ];
              text = ''
                export OPEN_NOTEBOOK_API_URL=${lib.escapeShellArg apiUrl}
                export OPEN_NOTEBOOK_BOOTSTRAP_FILE=${lib.escapeShellArg bootstrapFile}

                python <<'PY'
                import json
                import time
                import urllib.parse
                import urllib.request
                from urllib.error import HTTPError, URLError

                api_url = OPEN_NOTEBOOK_API_URL = ${builtins.toJSON apiUrl}
                bootstrap_path = ${builtins.toJSON bootstrapFile}

                with open(bootstrap_path, "r", encoding="utf-8") as fh:
                    config = json.load(fh)


                def request(method, path, payload=None):
                    body = None if payload is None else json.dumps(payload).encode("utf-8")
                    req = urllib.request.Request(
                        api_url + path,
                        data=body,
                        headers={"Content-Type": "application/json"},
                        method=method,
                    )
                    with urllib.request.urlopen(req, timeout=30) as resp:
                        raw = resp.read()
                        return json.loads(raw.decode("utf-8")) if raw else None


                def retry_request(method, path, payload=None, *, description, validate=None, attempts=60, delay=2):
                    last_error = None
                    for _ in range(attempts):
                        try:
                            result = request(method, path, payload)
                            if validate is None or validate(result):
                                return result
                            last_error = RuntimeError(f"{description} returned an unexpected response: {result!r}")
                        except (HTTPError, URLError, TimeoutError, RuntimeError, ValueError) as exc:
                            last_error = exc
                        time.sleep(delay)
                    raise SystemExit(f"Timed out waiting for {description}: {last_error}")


                health = retry_request(
                    "GET",
                    "/health",
                    description="Open Notebook API health",
                    validate=lambda result: result and result.get("status") == "healthy",
                )

                all_credentials = retry_request("GET", "/api/credentials", description="credential list")

                for credential in config.get("credentials", []):
                    provider = credential["provider"]
                    name = credential["name"]
                    payload = {
                        "name": name,
                        "provider": provider,
                        "modalities": credential.get("modalities"),
                        "api_key": credential.get("apiKey"),
                        "base_url": credential.get("baseUrl"),
                        "endpoint": credential.get("endpoint"),
                        "api_version": credential.get("apiVersion"),
                        "endpoint_llm": credential.get("endpointLlm"),
                        "endpoint_embedding": credential.get("endpointEmbedding"),
                        "endpoint_stt": credential.get("endpointStt"),
                        "endpoint_tts": credential.get("endpointTts"),
                        "project": credential.get("project"),
                        "location": credential.get("location"),
                        "credentials_path": credential.get("credentialsPath"),
                    }
                    payload = {key: value for key, value in payload.items() if value is not None}

                    existing = next(
                        (
                            item
                            for item in all_credentials
                            if item.get("name") == name and item.get("provider") == provider
                        ),
                        None,
                    )

                    if existing is None:
                        current = request("POST", "/api/credentials", payload)
                        all_credentials.append(current)
                    else:
                        current = request(
                            "PUT",
                            "/api/credentials/" + urllib.parse.quote(existing["id"], safe=""),
                            payload,
                        )

                    credential_path = "/api/credentials/" + urllib.parse.quote(current["id"], safe="")

                    retry_request(
                        "POST",
                        credential_path + "/test",
                        description=f"credential test for {name!r}",
                        validate=lambda result: result and result.get("success", False),
                    )

                    discovered = retry_request(
                        "POST",
                        credential_path + "/discover",
                        description=f"model discovery for {name!r}",
                        validate=lambda result: result is not None,
                    )
                    discovered_models = discovered.get("discovered", [])

                    desired_models = credential.get("models")
                    if desired_models:
                        models_to_register = [
                            {
                                "name": model["name"],
                                "provider": provider,
                                "model_type": model.get("modelType", "language"),
                            }
                            for model in desired_models
                        ]
                    else:
                        default_type = credential.get("defaultModelType", "language")
                        models_to_register = [
                            {
                                "name": model["name"],
                                "provider": provider,
                                "model_type": model.get("model_type") or default_type,
                            }
                            for model in discovered_models
                        ]

                    if models_to_register:
                        retry_request(
                            "POST",
                            credential_path + "/register-models",
                            {"models": models_to_register},
                            description=f"model registration for {name!r}",
                        )

                all_credentials = retry_request("GET", "/api/credentials", description="refreshed credential list")
                credentials_by_id = {credential["id"]: credential for credential in all_credentials}
                models = retry_request("GET", "/api/models", description="registered model list")
                defaults = retry_request("GET", "/api/models/defaults", description="default model list")
                updated_defaults = dict(defaults)


                def resolve_default_model(slot, desired):
                    if isinstance(desired, str):
                        model_name = desired
                        credential_name = None
                        provider_name = None
                    elif isinstance(desired, dict):
                        model_name = desired["name"]
                        credential_name = desired.get("credential")
                        provider_name = desired.get("provider")
                    else:
                        raise SystemExit(
                            f"Default model for slot {slot!r} must be a string or record, got {type(desired).__name__}"
                        )

                    matches = []
                    for model in models:
                        if model.get("name") != model_name:
                            continue
                        if provider_name is not None and model.get("provider") != provider_name:
                            continue
                        if credential_name is not None:
                            credential = credentials_by_id.get(model.get("credential"))
                            if credential is None or credential.get("name") != credential_name:
                                continue
                        matches.append(model)

                    if not matches:
                        raise SystemExit(
                            f"Default model {desired!r} for slot {slot!r} was not registered"
                        )
                    if len(matches) > 1:
                        raise SystemExit(
                            f"Default model {desired!r} for slot {slot!r} is ambiguous; qualify it with credential or provider"
                        )
                    return matches[0]


                for slot, desired in config.get("defaultModels", {}).items():
                    updated_defaults[slot] = resolve_default_model(slot, desired)["id"]

                if updated_defaults != defaults:
                    request("PUT", "/api/models/defaults", updated_defaults)
                PY
              '';
            };
          in
          {
            clan.core.vars.generators.${generatorName} = {
              share = true;
              files = {
                "env-file" = {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                };
                "bootstrap-json" = {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                };
              };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                key="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
                printf 'OPEN_NOTEBOOK_ENCRYPTION_KEY=%s\n' "$key" > "$out/env-file"
                cat > "$out/bootstrap-json" <<'EOF'
                ${bootstrapJson}
                EOF
              '';
            };

            systemd.tmpfiles.rules = [
              "d ${stateDir} 0700 root root -"
              "d ${dataDir} 0700 root root -"
              "d ${dbDir} 0700 root root -"
            ];

            systemd.services = {
              "docker-surrealdb".preStart = ''
                install -d -m 0700 ${stateDir}
                install -d -m 0700 ${dbDir}
              '';

              "docker-open-notebook".preStart = ''
                install -d -m 0700 ${stateDir}
                install -d -m 0700 ${dataDir}
                install -d -m 0700 ${dbDir}
                ${lib.getExe waitForSurreal}
              '';

              "open-notebook-bootstrap" = {
                description = "Bootstrap Open Notebook credentials and models";
                wantedBy = [ "multi-user.target" ];
                after = [ "docker-open-notebook.service" ];
                requires = [ "docker-open-notebook.service" ];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = lib.getExe bootstrapScript;
                  Restart = "on-failure";
                  RestartSec = "30s";
                };
              };
            };

            virtualisation.oci-containers = {
              backend = "docker";
              containers = {
                surrealdb = {
                  image = surrealdbImage;
                  pull = "always";
                  user = "root";
                  extraOptions = [ "--network=host" ];
                  cmd = [
                    "start"
                    "--log"
                    "info"
                    "--user"
                    "root"
                    "--pass"
                    "root"
                    "rocksdb:/mydata/mydatabase.db"
                  ];
                  volumes = [ "${dbDir}:/mydata" ];
                };

                "open-notebook" = {
                  image = openNotebookImage;
                  pull = "always";
                  dependsOn = [ "surrealdb" ];
                  extraOptions = [ "--network=host" ];
                  environment = {
                    SURREAL_URL = "ws://127.0.0.1:8000/rpc";
                    SURREAL_USER = "root";
                    SURREAL_PASSWORD = "root";
                    SURREAL_NAMESPACE = "open_notebook";
                    SURREAL_DATABASE = "open_notebook";
                  };
                  environmentFiles = [ envFile ];
                  volumes = [ "${dataDir}:/app/data" ];
                };
              };
            };

            environment.systemPackages = lib.optionals installLauncher [
              inputs.self.packages.${pkgs.stdenv.hostPlatform.system}."open-notebook"
            ];
          };
      };
  };
}
