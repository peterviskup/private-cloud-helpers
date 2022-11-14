#cloud-config
users:
  - default
  - name: test
    gecos: 'Test user'
    groups: wheel
    plain_text_passwd: testUSERpass.0
    lock_passwd: false
    ssh_authorized_keys:
      - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBIjqkI2jZtpa0UGY0a3X30cd1ig/UTW3jiz/eXo8A4c/TDwjpVs15jyI9oyZzYnISQelqUgC0bXf+1Vf90kfQvg= eddsa-key-test
chpasswd:
  list: |
    root:strongROOTpass.0
    cloud-user:cloudUSERpass.0
  expire: False
yum_repos:
  epel:
    baseurl: http://download.fedoraproject.org/pub/epel/$releasever/Everything/$basearch
    enabled: true
    gpgcheck: true
    #gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-$releasever
    gpgkey: https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$releasever
    proxy: http://proxy.domain.com:8080
    name: Extra Packages for Enterprise Linux $releasever
  zabbix-6lts:
    baseurl: http://repo.zabbix.com/zabbix/6.0/rhel/$releasever/$basearch/
    enabled: true
    gpgcheck: true
    #gpgkey: file:///etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX
    gpgkey: https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX
    proxy: http://proxy.domain.com:8080
    name: Zabbix 6.0LTS Packages for Enterprise Linux $releasever
#rh_subscription:
#  activation-key: foobar
#  org: 12345
#  auto-attach: true
#  service-level: self-support
#  add-pool:
#    - 1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a
#    - 2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b
#  enable-repo:
#    - repo-id-to-enable
#    - other-repo-id-to-enable
#  disable-repo:
#    - repo-id-to-disable
#    - other-repo-id-to-disable
packages:
  - zabbix-agent
package_update: true
package_upgrade: true
package_reboot_if_required: true
write_files:
  - path: /etc/sysctl.d/22-disable-redirects.conf
    content: |
      net.ipv4.conf.all.send_redirects=0
      net.ipv4.conf.default.send_redirects=0
      net.ipv4.conf.all.accept_redirects=0
      net.ipv4.conf.default.accept_redirects=0
      net.ipv4.conf.all.secure_redirects=0
      net.ipv4.conf.default.secure_redirects=0
    permissions: '0644'
  - path: /etc/sysctl.d/21-disable-ip-forwarding.conf
    content: |
      net.ipv4.ip_forward=0
    permissions: '0644'
  - path: /etc/sysctl.d/21-disable-source-route.conf
    content: |
      net.ipv4.conf.default.accept_source_route=0
    permissions: '0644'
  - path: /etc/sysctl.d/21-log-martians.conf
    content: |
      net.ipv4.conf.all.log_martians=1
      net.ipv4.conf.default.log_martians=1
    permissions: '0644'
  - path: /etc/sysctl.d/21-icmp-ignores.conf
    content: |
      net.ipv4.icmp_echo_ignore_broadcasts=1
      net.ipv4.icmp_ignore_bogus_error_responses-1
    permissions: '0644'
  - path: /etc/pki/ca-trust/source/anchors/RootCA-internal.pem
    content: |
      -----BEGIN CERTIFICATE-----
      CERT CONTENT HERE
      -----END CERTIFICATE-----
    permissions: '0444'
  - path: /etc/pki/ca-trust/source/anchors/SubCA-internal.pem
    content: |
      -----BEGIN CERTIFICATE-----
      CERT CONTENT HERE
      -----END CERTIFICATE-----
    permissions: '0444'
rsyslog:
  config_dir: /etc/rsyslog.d
  config_filename: 99-late-cloud-config.conf
  configs:
    - filename: 90-os-forward.conf
      content: |
            template(name="os-log-template" type="string"
                   string="<%PRI%> %TIMESTAMP:::date-rfc3339% %HOSTNAME% %syslogtag%%msg:::sp-if-no-1st-sp%%msg:::drop-last-lf%\n"
            )
            *.info;local0,local1,local2,local3,local4,local5,local6,local7.none action(
                   type="omfwd" target="%TPL_SYSLOG%" port="2514" protocol="tcp"
                   name="os-logs"
                   template="os-log-template"
                   action.resumeRetryCount="-1"
                   action.resumeInterval="10"
                   action.reportSuspension="on"
                   action.reportSuspensionContinuation="on"
                   queue.spoolDirectory="/var/lib/rsyslog"
                   queue.size="10000"
                   queue.maxDiskSpace="1G"
                   queue.checkpointInterval="100"
                   queue.type="LinkedList"
                   queue.maxFileSize="100M"
                   queue.saveOnShutdown="on"
                   queue.filename="os-logs"
            )
ntp:
  enabled: true
  ntp_client: chrony
  servers:
    - server1.local
    - server2.local
    - server3.local
runcmd:
  - [ systemctl, enable, tmp.mount ]
  - [ systemctl, start, tmp.mount ]
  - [ sysctl, -p, --system ]
  - [ cloud-init, single, --name, ntp ]
  - [ semanage, port, -a, -t, syslogd_port_t, -p, udp, 2514 ]
  - [ semanage, port, -a, -t, syslogd_port_t, -p, tcp, 2514 ]
  - [ firewall-cmd, --add-service, zabbix-agent ]
  - [ firewall-cmd, --runtime-to-permanent ]
  - "sed -i 's/=127.0.0.1$/=%TPL_ZBXPX%.domain.com/g;s/# HostMetadata=/HostMetadata=%TPL_ZBXMD%/g;s/Hostname=/# Hostname=/g;s/# HostnameItem=/HostnameItem=/g' /etc/zabbix_agentd.conf"
  - [ systemctl, restart, zabbix-agent ]
#  - "curl --proxy http://proxy.domain.com:8080 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-9 https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9"
#  - "curl --proxy http://proxy.domain.com:8080 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-ZABBIX https://repo.zabbix.com/RPM-GPG-KEY-ZABBIX"
#  - "rpm --httpproxy=proxy.domain.com --httpport=8080 -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
#  - "rpm --httpproxy=proxy.domain.com --httpport=8080 -Uvh https://repo.zabbix.com/zabbix/6.0/rhel/9/x86_64/zabbix-release-6.0-4.el9.noarch.rpm"
