# VM test: Loki ingests logs from Promtail and responds to LogQL queries.
{ pkgs, ... }:
let
  lokiPort = 3100;
in
pkgs.testers.runNixOSTest {
  name = "loki";
  skipLint = true;

  nodes.machine = _: {
    virtualisation.graphics = false;
    virtualisation.memorySize = 1024;

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = lokiPort;
        common = {
          instance_addr = "127.0.0.1";
          path_prefix = "/var/lib/loki";
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
          replication_factor = 1;
          ring.kvstore.store = "inmemory";
        };
        schema_config.configs = [
          {
            from = "2020-10-24";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
      };
    };

    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        positions.filename = "/var/cache/promtail/positions.yaml";
        clients = [
          { url = "http://localhost:${toString lokiPort}/loki/api/v1/push"; }
        ];
        scrape_configs = [
          {
            job_name = "systemd-journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "machine";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d '/var/cache/promtail' 0700 promtail promtail - -"
    ];

    networking.firewall.allowedTCPPorts = [
      lokiPort
      9080
    ];

    # Test helper script that queries Loki from inside the VM
    environment.systemPackages = [
      (pkgs.writers.writePython3Bin "loki-query" { } ''
        import json
        import sys
        import time
        import urllib.request
        import urllib.parse

        base = "http://localhost:${toString lokiPort}"
        action = sys.argv[1] if len(sys.argv) > 1 else "labels"

        if action == "query":
            query = sys.argv[2]
            end = int(time.time())
            start = end - 3600
            params = urllib.parse.urlencode({
                "query": query,
                "start": str(start),
                "end": str(end),
                "limit": "100",
            })
            url = f"{base}/loki/api/v1/query_range?{params}"
        elif action == "labels":
            url = f"{base}/loki/api/v1/labels"
        elif action == "push":
            ts = str(int(time.time() * 1e9))
            streams = [{"stream": {"job": "test"}, "values": [[ts, "vm test"]]}]
            body = json.dumps({"streams": streams})
            req = urllib.request.Request(
                url=f"{base}/loki/api/v1/push",
                data=body.encode(),
                headers={"Content-Type": "application/json"},
            )
            urllib.request.urlopen(req)
            print("pushed")
            sys.exit(0)
        else:
            url = f"{base}{action}"

        try:
            resp = urllib.request.urlopen(url)
            data = json.loads(resp.read().decode())
            print(json.dumps(data))
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            print(f"HTTP {e.code}: {body}", file=sys.stderr)
            sys.exit(1)
      '')
    ];
  };

  testScript = ''
    import json

    machine.wait_for_unit("loki.service")
    machine.wait_for_open_port(${toString lokiPort})

    # Loki takes a while to become ready — retry
    machine.wait_until_succeeds("curl -sf http://localhost:${toString lokiPort}/ready", 60)

    # Promtail running
    machine.wait_for_unit("promtail.service")

    # Push a test log entry
    machine.succeed("loki-query push")

    # Query the pushed log
    machine.sleep(3)
    raw = machine.succeed("loki-query query '{job=\"test\"}'")
    result = json.loads(raw)
    assert result["status"] == "success", f"Query failed: {result}"

    # Labels endpoint works
    raw = machine.succeed("loki-query labels")
    labels = json.loads(raw)
    assert "job" in labels["data"], f"Missing 'job' label, got: {labels['data']}"

    # Promtail ships journal logs
    machine.succeed("logger -t loki-test 'journal test entry'")
    machine.wait_until_succeeds(
        "loki-query query '{job=\"systemd-journal\"}' | grep -q result", 30
    )
  '';
}
