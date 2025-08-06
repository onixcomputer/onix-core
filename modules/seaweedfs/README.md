# SeaweedFS Clan Service Module

SeaweedFS is a distributed file storage system designed to store billions of files and serve them fast. This clan service module provides a declarative way to deploy SeaweedFS clusters across multiple machines.

## Features

- **Multiple deployment modes**: Master, Volume, Filer, or All-in-one
- **Distributed clustering**: Deploy across multiple machines with rack-aware replication
- **S3 API compatibility**: Optional S3-compatible interface
- **Authentication**: Optional JWT-based authentication
- **Reverse proxy support**: Automatic nginx configuration or Traefik integration
- **Secret management**: Automatic generation of JWT keys and admin passwords

## Configuration Examples

### All-in-One Instance

Run all SeaweedFS components (master, volume, filer) on a single machine:

```nix
{
  instances."seaweedfs-all" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."storage" = { };
      settings = {
        # Run all components on one machine
        mode = "all";
        
        # Basic replication: 1 copy on same server
        replication = "000";
        
        # Volume size limit in MB
        volumeSize = 30000; # 30GB
        
        # Optional: Enable web UI access via domain
        # masterDomain = "seaweed-master.example.com";
        # filerDomain = "seaweed.example.com";
        # enableSSL = true;
        
        # Optional: Enable authentication
        # auth = {
        #   enable = true;
        #   adminUsername = "admin";
        # };
        
        # Optional: Enable S3 API compatibility
        # s3 = {
        #   enable = true;
        #   port = 8333;
        #   domain = "s3.example.com";
        # };
      };
    };
  };
}
```

### Distributed Cluster Setup

Deploy a distributed cluster with separate master and volume servers:

#### Master Server
```nix
{
  instances."seaweedfs-master" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."storage-master" = { };
      settings = {
        mode = "master";
        
        # Master with domain for cluster access
        masterDomain = "seaweed-master.example.com";
        enableSSL = true;
        
        # Replication strategy: 1 replica on different servers
        replication = "001";
        volumeSize = 50000; # 50GB volumes
        
        # Data center configuration for rack-aware placement
        dataCenter = "dc1";
        rack = "rack1";
        
        # Enable authentication for secure cluster
        auth = {
          enable = true;
          adminUsername = "admin";
        };
      };
    };
  };
}
```

#### Volume Server
```nix
{
  instances."seaweedfs-volume-1" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."storage-volume" = { };
      settings = {
        mode = "volume";
        
        # Connect to master servers
        masterServers = [ "seaweed-master.example.com:9333" ];
        
        # Same data center, different rack
        dataCenter = "dc1";
        rack = "rack2";
      };
    };
  };
}
```

#### Filer Server with S3 API
```nix
{
  instances."seaweedfs-filer" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."storage-filer" = { };
      settings = {
        mode = "filer";
        
        # Connect to master servers
        masterServers = [ "seaweed-master.example.com:9333" ];
        
        # Public-facing filer with domain
        filerDomain = "files.example.com";
        enableSSL = true;
        
        # Enable S3-compatible API
        s3 = {
          enable = true;
          port = 8333;
          domain = "s3.example.com";
        };
        
        # Same data center
        dataCenter = "dc1";
        rack = "rack1";
      };
    };
  };
}
```

### Two-Node Cluster with Tailscale

Deploy across two machines using Tailscale for private networking:

#### Machine 1: Master + All Services
```nix
{
  instances."seaweedfs-master-node1" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."seaweedfs-master" = { };
      settings = {
        mode = "all"; # Master + Volume + Filer
        replication = "010"; # Cross-rack replication
        volumeSize = 20000; # 20GB volumes
        
        # No authentication for development
        auth.enable = false;
        
        # Enable S3 API
        s3 = {
          enable = true;
          port = 8333;
        };
        
        # Use different filer port to avoid conflicts
        filerPort = 8890;
        
        # Use Traefik for private access
        useTraefik = true;
        
        # Cluster configuration
        dataCenter = "home";
        rack = "node1";
        
        # Advertise actual Tailscale IP
        publicIp = "100.92.36.3";
      };
    };
  };
}
```

#### Machine 2: Volume Server Only
```nix
{
  instances."seaweedfs-volume-node2" = {
    module.name = "seaweedfs";
    module.input = "self";
    roles.server = {
      tags."seaweedfs-volume" = { };
      settings = {
        mode = "volume"; # Only volume server
        
        # Connect to master on node1 (via Tailscale)
        masterServers = [ "100.92.36.3:9333" ];
        
        # Cluster configuration
        dataCenter = "home";
        rack = "node2";
        
        volumeSize = 20000; # 20GB volumes
        
        # Advertise actual Tailscale IP
        publicIp = "100.110.43.11";
      };
    };
  };
}
```

## Replication Strategies

SeaweedFS uses a three-digit replication strategy (xyz):
- **x**: Number of replicas on different data centers
- **y**: Number of replicas on different racks in same data center  
- **z**: Number of replicas on different servers in same rack

Common strategies:
- `000`: No replication (single copy)
- `001`: 1 replica on different server, same rack
- `010`: 1 replica on different rack (good for 2-node clusters)
- `100`: 1 replica on different data center

## Options Reference

### Basic Options
- `mode`: Operation mode - "master", "volume", "filer", or "all"
- `replication`: Replication strategy (default: "000")
- `volumeSize`: Maximum volume size in MB (default: 30000)
- `dataCenter`: Data center name for rack-aware placement
- `rack`: Rack name for rack-aware placement
- `publicIp`: IP address to advertise to master (important for distributed setup)

### Network Options
- `masterServers`: List of master server addresses (for volume/filer nodes)
- `filerPort`: Port for filer service (default: 8888)
- `masterDomain`: Domain name for master UI (enables nginx)
- `filerDomain`: Domain name for filer UI (enables nginx)
- `enableSSL`: Enable HTTPS with ACME certificates (default: true)
- `useTraefik`: Use Traefik instead of nginx for reverse proxy

### Feature Options
- `auth.enable`: Enable JWT authentication
- `auth.adminUsername`: Admin username (default: "admin")
- `s3.enable`: Enable S3-compatible API
- `s3.port`: S3 API port (default: 8333)
- `s3.domain`: Domain name for S3 API endpoint

## Machine Tags

Assign tags to machines in your `machines.nix` to determine where instances run:

```nix
{
  machines = {
    "server1" = {
      tags = [ "seaweedfs-master" ];
      # ... other config
    };
    "server2" = {
      tags = [ "seaweedfs-volume" ];
      # ... other config
    };
  };
}
```

## Accessing the Cluster

After deployment:
- **Master UI**: http://masterDomain:9333 or http://ip:9333
- **Filer UI**: http://filerDomain:8888 or http://ip:8888
- **S3 API**: http://s3Domain:8333 or http://ip:8333

## Troubleshooting

1. **Volume servers show as 0.0.0.0**: Set `publicIp` to the actual IP address the server should advertise
2. **Cross-rack replication fails**: Ensure you have nodes in different racks and use appropriate replication strategy (e.g., "010")
3. **Connection refused errors**: Check firewall rules - the module automatically opens required ports
4. **Authentication issues**: Check that secrets were generated in `/var/lib/secrets/seaweedfs-auth/`