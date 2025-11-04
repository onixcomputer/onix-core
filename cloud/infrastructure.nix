{ lib, ... }:
{

  terraform = {
    required_providers = {
      aws = {
        source = "registry.opentofu.org/hashicorp/aws";
        version = "~> 5.0";
      };
      http = {
        source = "registry.opentofu.org/hashicorp/http";
        version = "~> 3.0";
      };
    };
    required_version = ">= 1.0.0";
  };

  provider = {
    aws = {
      region = "us-east-1";
    };
    http = { };
  };

  # Get current IP for security group rules
  data.http.my_ip = {
    url = "https://ipv4.icanhazip.com";
  };

  # NixOS AMI data source
  data.aws_ami.nixos = {
    owners = [ "535002876703" ];
    most_recent = true;

    filter = [
      {
        name = "name";
        values = [ "determinate/nixos/epoch-1/*" ];
      }
      {
        name = "architecture";
        values = [ "x86_64" ];
      }
    ];
  };

  resource = {
    # SSH key
    aws_key_pair.claudia_key = {
      key_name = "claudia-ssh-key";
      public_key = lib.tfRef "file(\"~/.ssh/claudia.pub\")";
    };

    # Security group
    aws_security_group.claudia_sg = {
      name = "claudia-sg";
      description = "Security group for Claudia server";

      ingress = [
        # SSH access from current IP
        {
          from_port = 22;
          to_port = 22;
          protocol = "tcp";
          cidr_blocks = [ "\${chomp(data.http.my_ip.response_body)}/32" ];
          description = "SSH from current IP";
          ipv6_cidr_blocks = [ ];
          prefix_list_ids = [ ];
          security_groups = [ ];
          self = false;
        }
        # Minecraft server ports
        {
          from_port = 25565;
          to_port = 25568;
          protocol = "tcp";
          cidr_blocks = [ "0.0.0.0/0" ];
          description = "Minecraft server";
          ipv6_cidr_blocks = [ ];
          prefix_list_ids = [ ];
          security_groups = [ ];
          self = false;
        }
        # Minecraft Voice Chat mod UDP ports
        {
          from_port = 24454;
          to_port = 24457;
          protocol = "udp";
          cidr_blocks = [ "0.0.0.0/0" ];
          description = "Simple Voice Chat";
          ipv6_cidr_blocks = [ ];
          prefix_list_ids = [ ];
          security_groups = [ ];
          self = false;
        }
      ];

      egress = [
        {
          from_port = 0;
          to_port = 0;
          protocol = "-1";
          cidr_blocks = [ "0.0.0.0/0" ];
          description = "All outbound traffic";
          ipv6_cidr_blocks = [ ];
          prefix_list_ids = [ ];
          security_groups = [ ];
          self = false;
        }
      ];

      tags = {
        Name = "claudia-security-group";
      };
    };

    # EC2 Instance
    aws_instance.claudia = {
      ami = "\${data.aws_ami.nixos.id}";
      instance_type = "t2.small";
      key_name = "\${aws_key_pair.claudia_key.key_name}";
      vpc_security_group_ids = [ "\${aws_security_group.claudia_sg.id}" ];

      root_block_device = {
        volume_size = 128;
        volume_type = "gp3";
        encrypted = true;
      };

      tags = {
        Name = "claudia";
        ManagedBy = "Terraform";
      };
    };

    # Elastic IP for consistent addressing
    aws_eip.claudia_eip = {
      domain = "vpc";
      tags = {
        Name = "claudia-eip";
        ManagedBy = "Terraform";
      };
    };

    # Associate EIP with instance
    aws_eip_association.claudia_eip_assoc = {
      instance_id = "\${aws_instance.claudia.id}";
      allocation_id = "\${aws_eip.claudia_eip.id}";
    };
  };

  output = {
    # AWS Infrastructure outputs
    claudia_ip = {
      value = "\${aws_eip.claudia_eip.public_ip}";
      description = "Public IP of Claudia";
    };
    claudia_ssh = {
      value = "ssh -i ~/.ssh/claudia root@\${aws_eip.claudia_eip.public_ip}";
      description = "SSH command for Claudia";
    };
    claudia_id = {
      value = "\${aws_instance.claudia.id}";
      description = "Claudia instance ID";
    };
  };
}
