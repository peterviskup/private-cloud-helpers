# full list of govc environment varialbes available under
# https://github.com/vmware/govmomi/tree/master/govc#usage
export GOVC_URL=vcenter-url.domain.com

# vCenter credentials
export GOVC_USERNAME=myuser
export GOVC_PASSWORD=MyP4ss

# disable cert validation
export GOVC_INSECURE=true

# other variables
export GOVC_DATACENTER=DC-TEST
export GOVC_DATASTORE=/${GOVC_DATACENTER}/datastore/DS-TEST
export GOVC_NETWORK=/${GOVC_DATACENTER}/network/VLAN100-TEST
export GOVC_RESOURCE_POOL=/${GOVC_DATACENTER}/host/Cluster-TEST/Resources
