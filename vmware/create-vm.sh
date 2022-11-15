#!/bin/sh
# script for deployment of VM from template with use of govc utility
# govc dokumentation available on
#    https://github.com/vmware/govmomi/tree/master/govc#govc
# script provides
#  - support basic OS configuration with help of cloud-init
#    https://cloudinit.readthedocs.io/en/latest/topics/datasources/vmware.html
#  - support Zabbix autoregistration
#    https://blog.zabbix.com/zabbix-agent-auto-registration/9313/
# can be extended

. ./.env.sh

#IP
#SNET
#NETWORK
#VM
#TPL
#FOLDER
#UD
#MD
#SYSLOG
#ZBXPRX
#ZBXMD

usage() {
  cat <<print-usage
$0 [-t template][-v new-vm][-f "vSphere folder"]
   [-s cidr_subnet][-i last_ip_octet][-n "vSphere network"]
   [-m "metadata template file"][u "userdata template file"]
   [-z "zabbix server/zabbix metadata"]
   [-l "syslog server"]
   [-p "on/off"]

template, new-vm - names of objects in "vSphere folder"
cidr_subnet - first three octets of subnet
last_ip_octet - last octet of IP
vSphere network - name of vSphere network to connect to
[meta/user]data_template_file - files used as template for guestinfo arguments
zabbix_server/zabbix_metadata - string of Zabbix server hostname and the Zabbix host metadata for autoregistration
syslog server - hostname or IP of server for remote logging
-p - power setting on/off
print-usage
}

printall() {
  cat <<print-all
-------------------------------------
FOLDER=${FOLDER}
VM=${VM}
TPL=${TPL}
IP=${SNET}.${IP}
NETWORK=${NWK}
MD=${MDTPL}
UD=${UDTPL}
SYSLOG=${SYSLOG}
ZABBIX PROXY=${ZBXPX}
ZABBIX MDATA=${ZBXMD}
POWER=${POWER}
-------------------------------------
print-all
}

checkapi(){
  ./govc about >/dev/null 2>&1 || exit 9
}

checkvm(){
  if [ $(./govc vm.info "${FOLDER}/${1}"|grep -c "${FOLDER}") -ne 1 ]; then
    return 1
  else
    return 0
  fi
}

clonevm() {
  ./govc folder.info "${FOLDER}" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    checkvm "${FOLDER}/${TPL}"
    if [ $? -ne 0 ]; then
      echo "Template ${FOLDER}/${TPL} does not exist"
	  exit 11
	fi
	checkvm "${FOLDER}/${VM}"
	if [ $? -ne 1 ]; then
	  echo "VM ${FOLDER}/${VM} does already exist"
	  exit 12
	fi
	./govc vm.clone -on=false -folder="${FOLDER}" -vm "${TPL}" "${VM}"
  else
    echo "Folder $FOLDER does not exist!"
    exit 10
  fi
}

prepguestinfo(){
  USERDATA=$(sed 's/%TPL_ZBXPX%/'${ZBXPX}'/g;s/%TPL_ZBXMD%/'${ZBXMD}'/g;s/%TPL_SYSLOG%/'${SYSLOG}'/g' ${UDTPL}| gzip -c9 | { base64 -w0 2>/dev/null || base64; })
  METADATA=$(sed 's/%TPL_IP%/'${IP}'/g;s/%TPL_NET%/'${SNET}'/g;s/%TPL_VM%/'${VM}'/g' ${MDTPL} | gzip -qc9 | { base64 -w0 2>/dev/null || base64; })
}

addguestinfo(){
  ./govc vm.change -vm "${FOLDER}/${VM}" \
    -e guestinfo.metadata="${METADATA}" \
    -e guestinfo.metadata.encoding="gzip+base64" \
    -e guestinfo.userdata="${USERDATA}" \
    -e guestinfo.userdata.encoding="gzip+base64"
}

dumpguestino(){
  echo USERDATA=$(echo $USERDATA|base64 -d|gzip -d)
  echo METADATA=$(echo $METADATA|base64 -d|gzip -d)
}

changevmnet(){
  ./govc vm.network.change -vm "${1}" ethernet-0 "${2}"
}

while getopts f:i:l:m:n:p:s:t:u:v:z: name
do
  case $name in
  f)
    FOLDER="${OPTARG}";;
  i)
    IP="${OPTARG}";;
  s)
    SNET="${OPTARG}";;
  n)
    NWK="${OPTARG}";;
  l)
    SYSLOG="${OPTARG}";;
  m)
    MDTPL="${OPTARG}"
    [ ! -f ${MDTPL} ] || [ ! -r ${MDTPL} ] && exit 2;;
  u)
    UDTPL="${OPTARG}"
    [ ! -f ${UDTPL} ] || [ ! -r ${UDTPL} ] && exit 2;;
  t)
    TPL="${OPTARG}";;
  v)
    VM="${OPTARG}";;
  z)
    ZBXPX=${OPTARG%%/*}
    ZBXMD=${OPTARG##*/};;
  p)
    POWER="${OPTARG}"
    POWER=$(echo "${POWER}" | tr '[:upper:]' '[:lower:]')
    [ "${POWER}" == "false" or "${POWER}" == "no" ] && POWER=0 && next
    [ "${POWER}" == "true" or "${POWER}" == "yes" ] && POWER=1 && next
    POWER=0;;
  ?)
    usage;;
  *)
    usage;;
  esac
done

printall
checkapi
clonevm
prepguestinfo
addguestinfo
#dumpguestino
changevmnet "${VM}" "${NWK}"
[ ${POWER} -ne 0 ] && ./govc vm.power -on "${FOLDER}/${VM}"
