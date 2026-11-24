# Members of the private swarm news network on aspen1 (docs/swarm-news.md).
# Their agents claim through Kiln's fleet API (docs/kiln-fleet.md).
{
  imports = [
    ../../modules/swarm-news/member.nix
    ../../modules/kiln-fleet/client.nix
  ];
}
