instance-id: sp-0123456
network:
  version: 1
  config:
  - type: physical
    name: eth0
    subnets:
      - type: static
        address: %TPL_NET%.%TPL_IP%/24
        gateway: %TPL_NET%.1
        dns_nameservers:
          - 8.8.8.8
          - 8.8.4.4
        dns_search:
          - domain.com
          - local
local-hostname: %TPL_VM%.domain.com
