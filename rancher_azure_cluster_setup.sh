#!/bin/bash
#\******************************************************************/#
# |  network loadbalancer  ----------------------------------------| #
#\******************************************************************/#
#-> https://docs.microsoft.com/en-us/azure/virtual-machines/linux/tutorial-load-balancer
#-> az login:karl.ring@leap.expert:sUSDT9bXu2AZ8ye

nextsteps(){
  printf '--->>>

  *** this script can be used as TEMPLATE: -k8s cluster deploy- ***

  1. replace "LoadBal-VMs" with "k8s VMs
  2. replace "LoadBal-Port -> 9345" 
        --port 80
        --frontend-port 80 \
        --backend-port 80 \
        --destination-port-range 80
'
}


alias azlbsu=". ${SCRIPT} ${1} ${2}; flist"

#\******************************************************************/#
# | general functions
#/------------------------------------------------------------------\#
function __MSG_HEADLINE__(){
    echo "[INFO]  ===== ${1} ====="
}
function __MSG_LINE__(){
    echo "-------------------------------------------------"
}
function __MSG_BANNER__(){
    __MSG_LINE__
    __MSG_HEADLINE__ "${1}"
    __MSG_LINE__

}

#\******************************************************************/#
# | utility functions
#/------------------------------------------------------------------\#

#--- List Functions ------#
function az_group_list(){ azenv az_group_list ; az group list -otable ; }
function az_network_list_public_ip(){ azenv az_network_list_public_ip ; az network public-ip list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_network_list_load_balancer(){ azenv az_network_list_load_balancer ; az network lb list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_network_list_lb_probe(){ azenv az_network_list_lb_probe ;  az network lb probe list  -g ${AZ_RESOURCE_GROUP_NAME} -otable --lb-name ${AZ_LOADBALANCER} ; }
function az_network_list_lb_rule(){ azenv az_network_list_lb_rule ; az network lb rule list -g ${AZ_RESOURCE_GROUP_NAME} -otable --lb-name ${AZ_LOADBALANCER} ; }
function az_network_list_vnet(){ azenv az_network_list_vnet ; az network vnet list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_network_list_nsg(){ azenv az_network_list_nsg ; az network nsg list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_network_list_nsg_rule(){ azenv az_network_list_nsg_rule ; az network nsg rule list -g ${AZ_RESOURCE_GROUP_NAME} -otable --nsg-name ${AZ_NET_SVC_GROUP} ; }
function az_network_list_nic (){ azenv az_network_list_nic ; az network nic list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_vm_list_cloud_config(){ azenv az_vm_list_cloud_config ; [ -f `pwd`/az-cloud-init.txt ] && cat `pwd`/az-cloud-init.txt ; }
function az_vm_list_avset(){ azenv az_vm_list_avset ; az vm availability-set list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_vm_list_vms(){ azenv az_vm_list_vms ; az vm list -g ${AZ_RESOURCE_GROUP_NAME} -otable ; }
function az_sshkeys_list(){ azenv az_sshkeys_list ; az sshkey list --resource-group ${AZ_RESOURCE_GROUP_NAME} -otable ; }



function getenv(){ set | grep "${1}" | sed "s/^ [ \t]*//" | egrep -v "getenv|grep|az |\;" | sort -u ; }

function AZ_F_GET_SCRIPT_FUNCTIONS(){
             script="${1}"
             regex="${2}"
             tempfile=/tmp/AZ_F_GET_SCRIPT_FUNCTIONS.tmp
             __MSG_LINE__
             __MSG_BANNER__ "[script] function list: ${script}"
             __MSG_LINE__
             grep '(){' ${script} \
               | egrep -v 'grep|#' \
               | sed -e 's/(){//g' -e 's/function //g' \
               | grep -v 'sed' \
               | sort -u  > ${tempfile}
             
             [ -z ${regex} ] && cat ${tempfile} || cat ${tempfile} | grep -i "${regex}"
}

function flist(){
    __MSG_BANNER__ "AZ LoadBalancer Functions"
    AZ_F_GET_SCRIPT_FUNCTIONS ${SCRIPT} 'az_' | awk '{print $1}' |egrep -v 'getenv|FUNCTIONS'
    __MSG_LINE__
}



#\******************************************************************/#
# | set functions
#/------------------------------------------------------------------\#


function azenv(){
    __MSG_BANNER__ "${1}"
    AZ_RESOURCE_GROUP_NAME="rg-${AZ_CLUSTER_GROUP_NAME}-1"
    AZ_RESOURCE_LOCATION="westus2"
    AZ_PUBLIC_IP="ip-pub-${AZ_RESOURCE_GROUP_NAME}-lb"
    AZ_PUBLIC_IP_VM_NAME="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm"
    # AZ_PUBLIC_IP_VM_2="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm-2"
    # AZ_PUBLIC_IP_VM_3="ip-pub-${AZ_RESOURCE_GROUP_NAME}-vm-3"
    AZ_LOADBALANCER="lb-${AZ_RESOURCE_GROUP_NAME}"
    AZ_IP_POOL_FRONTEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-frontend"
    AZ_IP_POOL_BACKEND="ip-pool-${AZ_RESOURCE_GROUP_NAME}-backend"
    AZ_VM_NET_PRIMARY="vnet-${AZ_RESOURCE_GROUP_NAME}"
    AZ_LOADBALANCER_PROBE="${AZ_RESOURCE_GROUP_NAME}-probe-health"
    AZ_LOADBALANCER_RULE="${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_NET_SUBNET="${AZ_RESOURCE_GROUP_NAME}-subnet"
    AZ_NET_SVC_GROUP="nsg-${AZ_RESOURCE_GROUP_NAME}"
    AZ_NET_SVC_GROUP_RULE="nsg-${AZ_RESOURCE_GROUP_NAME}-rule"
    AZ_VM_AVAIL_SET="avset-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NAME_ROOT="vm-${AZ_RESOURCE_GROUP_NAME}"
    AZ_VM_NET_PRIMARY_NIC="${AZ_RESOURCE_GROUP_NAME}-nic"
    # getenv 'AZ_'
    set | grep AZ_ | grep '=' | egrep -v '\(\)|;|\$'
}

#-------------------------------------------------------#

function az_delete_resource_group(){
    azenv az-delete-resource-group
    __MSG_LINE__
    echo "Delete ResourceGroup: ${AZ_RESOURCE_GROUP_NAME}: (yes/no) ?"
    __MSG_LINE__
    read DEL_RSG
    [[ "${DEL_RSG}" == "yes" ]] && az group delete --name ${AZ_RESOURCE_GROUP_NAME}
}

function az_vm_delete_rsg(){ azenv az_vm_delete_rsg
                             az vm delete --ids $(az vm list -g ${AZ_RESOURCE_GROUP_NAME} --query "[].id" -o tsv) ; }

#-------------------------------------------------------#

function az_create_resource_group(){
    __MSG_LINE__
    echo "Create ResourceGroup: ${AZ_RESOURCE_GROUP_NAME}: (yes/no) ?"
    __MSG_LINE__
    read CR8_RSG
    if [[ "${CR8_RSG}" == "yes" ]] ; then 
      azenv az_create_resource-group
      az group create --name ${AZ_RESOURCE_GROUP_NAME} --location ${AZ_RESOURCE_LOCATION}
    fi    
}


function az_create_network-ip-public(){
    azenv az_create_network-ip-public

    az network public-ip create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${1} \
        --allocation-method Static
}

function az_create_lb(){
    azenv az_create_lb
    az network lb create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${AZ_LOADBALANCER} \
        --frontend-ip-name ${AZ_IP_POOL_FRONTEND} \
        --backend-pool-name ${AZ_IP_POOL_BACKEND} \
        --public-ip-address ${AZ_PUBLIC_IP}
}

function az_create_lb-probe(){
    azenv az_create_lb-probe
    az network lb probe create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --lb-name ${AZ_LOADBALANCER} \
        --name ${AZ_LOADBALANCER_PROBE} \
        --protocol tcp \
        --port 80
}


function az_create_lb-rule(){
    azenv az_create_lb-rule
    az network lb rule create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --lb-name ${AZ_LOADBALANCER} \
        --name ${AZ_LOADBALANCER_RULE} \
        --protocol tcp \
        --frontend-port 443 \
        --backend-port 443 \
        --frontend-ip-name ${AZ_IP_POOL_FRONTEND} \
        --backend-pool-name ${AZ_IP_POOL_BACKEND} \
        --probe-name ${AZ_LOADBALANCER_PROBE}  
}

function az_create_network-vnet(){
    azenv az_create_network-vnet
    az network vnet create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${AZ_VM_NET_PRIMARY} \
        --subnet-name ${AZ_VM_NET_SUBNET}
}

function az_create_network-group-service(){
    azenv az_create_network-group-service
    az network nsg create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${1}
}

function az_create_network_group_service_rules_rke(){
    azenv az_create_network_group_service_rules_rke
    #-- open single ports --
    AZ_NET_SVC_GROUP="${1}"
    AZ_NET_SVC_GROUP_RULE="${AZ_NET_SVC_GROUP}-rule"

    #->https://rancher.com/docs/rancher/v2.5/en/installation/requirements/ports/#ports-for-rancher-server-nodes-on-rancherd-or-rke2
    # Commonly Used Ports - These ports are typically opened on your Kubernetes nodes, regardless of what type of cluster it is.
    
    PORTS_TCP='22 80 443 179 2376 2379 2380 6443 6783 8443 9099 9100 9345 9443 9796 10250 10254'
    i=100
    for p in ${PORTS_TCP}
     do
       az network nsg rule create --name "${AZ_NET_SVC_GROUP_RULE}-${i}-${p}" --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --nsg-name ${AZ_NET_SVC_GROUP} \
            --priority ${i} \
            --access Allow \
            --source-address-prefixes '*' \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges ${p} \
            --protocol Tcp
         ((i=i+1))
    done

    PORTS_UDP='8472 4789 6783 6784' 
    for p in ${PORTS_UDP}
     do
        az network nsg rule create --name "${AZ_NET_SVC_GROUP_RULE}-${i}-${p}" --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --nsg-name ${AZ_NET_SVC_GROUP} \
            --priority ${i} \
            --access Allow \
            --source-address-prefixes '*' \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges ${p} \
            --protocol Udp
         ((i=i+1))
    done

    #-- open port range --
    RANG_TCP_UDP='30000-32767'
        az network nsg rule create --name "${AZ_NET_SVC_GROUP_RULE}-${i}-${RANG_TCP_UDP}" --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --nsg-name ${AZ_NET_SVC_GROUP} \
            --priority ${i} \
            --access Allow \
            --source-address-prefixes '*' \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges ${RANG_TCP_UDP} \
            --protocol Tcp
            ((i=i+1))

    #-- open port range --
    RANG_TCP_UDP='30000-32767'
        az network nsg rule create --name "${AZ_NET_SVC_GROUP_RULE}-${i}-${RANG_TCP_UDP}" --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --nsg-name ${AZ_NET_SVC_GROUP} \
            --priority ${i} \
            --access Allow \
            --source-address-prefixes '*' \
            --source-port-ranges '*' \
            --destination-address-prefixes '*' \
            --destination-port-ranges ${RANG_TCP_UDP} \
            --protocol Udp
            ((i=i+1))
}

function az_create_network-nic(){
    azenv az_create_network-nic
    AZ_NETWORK_NIC_NAME="${1}"
    # for i in `seq 1 3`; do
       az network nic create \
            --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --name ${AZ_NETWORK_NIC_NAME} \
            --vnet-name ${AZ_VM_NET_PRIMARY} \
            --subnet ${AZ_VM_NET_SUBNET} \
            --network-security-group vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg \
            --lb-name ${AZ_LOADBALANCER} \
            --lb-address-pools ${AZ_IP_POOL_BACKEND} # \
            # --public-ip-address "20.112.95.221"
    # done
}

function az_create_vm-file-cloud-init(){
    azenv az_create_vm-file-cloud-init

# cat <<EOF| tee cloud-init.txt
printf "#cloud-config
package_upgrade: true
packages:
  - nginx
  - nodejs
  - npm
write_files:
  - owner: www-data:www-data
  - path: /etc/nginx/sites-available/default
    content: |
      server {
        listen 80;
        location / {
          proxy_pass http://localhost:3000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade "'$http_upgrade'";
          proxy_set_header Connection keep-alive;
          proxy_set_header Host "'$host'";
          proxy_cache_bypass "'$http_upgrade'";
        }
      }
  - owner: azureuser:azureuser
  - path: /home/azureuser/myapp/index.js
    content: |
      var express = require('express')
      var app = express()
      var os = require('os');
      app.get('/', function (req, res) {
        res.send('Hello World from host ' + os.hostname() + '!')
      })
      app.listen(3000, function () {
        console.log('Hello world app listening on port 3000!')
      })
runcmd:
  - service nginx restart
  - cd "'/home/azureuser/myapp'"
  - npm init
  - npm install express -y
  - nodejs index.js
"|tee `pwd`/az-cloud-init.txt

__MSG_HEADLINE__ "Created: `pwd`/az-cloud-init.txt"
# EOF
}


function az_create_vm-availability-set(){
    azenv az_create_vm-availability-set
    az vm availability-set create \
        --resource-group ${AZ_RESOURCE_GROUP_NAME} \
        --name ${AZ_VM_AVAIL_SET}
}

function az_create_sshkeys(){
      azenv az_create_sshkeys
      AZ_SSHKEY_NAME="${1}"
      az sshkey create --location ${AZ_RESOURCE_LOCATION} \
                       -g ${AZ_RESOURCE_GROUP_NAME} \
                       --name ${AZ_SSHKEY_NAME}
}



function az_create_vm-machines(){
      AZ_NETWORK_SERVICE_GROUP="${1}"   #-- "vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg"
      AZ_SSH_KEY_NAME="${2}"            #-- sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-${i}

       az vm create \
            --resource-group ${AZ_RESOURCE_GROUP_NAME} \
            --name ${AZ_VM_NAME_ROOT}-$i \
            --availability-set ${AZ_VM_AVAIL_SET} \
            --image UbuntuLTS \
            --admin-username azureuser \
            --no-wait \
            --accelerated-networking true \
            --nsg ${AZ_NETWORK_SERVICE_GROUP} \
            --ssh-key-name ${AZ_SSH_KEY_NAME}
            # \ # --nics ${AZ_VM_NET_PRIMARY_NIC}-$i \
            # --custom-data `pwd`/az-cloud-init.txt \
}


function az_list_deployment(){
    az_group_list
    az_network_list_public_ip
    az_network_list_load_balancer
    az_network_list_lb_probe
    az_network_list_lb_rule
    az_network_list_vnet
    az_network_list_nsg
    az_network_list_nsg_rule
    az_network_list_nic
    az_vm_list_cloud_config
    az_vm_list_avset
    az_vm_list_vms
}

#-- Start : 17:18 
#-- Finish: 18:03 (pre-vm creates)
          # 18:09 (8xvms)


#\******************************************************************/#
#| MAIN
#\******************************************************************/#

ACTION="${1}"                  #---- load
AZ_CLUSTER_GROUP_NAME="${2}"   #---- clsrke2
azenv load
SCRIPT="`pwd`/azure_setup_load_balancer.sh"

cat <<EOF
[INFO]  installation instructions:
[INFO]  1. check env vars are correct
[INFO]  2. run function:   run_create
EOF

function run_create(){
    azenv run_create
    az_create_resource_group

    # az_create_network-ip-public ${AZ_PUBLIC_IP}
    for i in `seq 1 3`; do
      az_create_network-ip-public "${AZ_PUBLIC_IP_VM_NAME}-${i}"  #-- ${AZ_PUBLIC_IP_VM_1}
    done 

    az_create_lb
    az_create_lb-probe
    az_create_lb-rule
    az_create_network-vnet

    az_create_network-group-service ${AZ_NET_SVC_GROUP}

    for i in `seq 1 3`; do
      az_create_network-group-service vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg
    done

    for i in `seq 1 3`; do
      az_create_sshkeys sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-${i}
    done

    for i in `seq 1 3`; do
      az_create_network_group_service_rules_rke vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg
    done

            #--- nics attached to vm via the vm create command... auto creates nic. ---
            # for i in `seq 4 8`; do
            #   az_create_network-nic ${AZ_VM_NET_PRIMARY}-nic-$i
            # done

    az_create_vm-availability-set

            #-- az_create_vm-file-cloud-init

    for i in `seq 1 3`; do 
      az_create_vm-machines "vm-${AZ_RESOURCE_GROUP_NAME}-${i}-nsg" "sshkey-${AZ_RESOURCE_GROUP_NAME}-vm-${i}"
    done

        #-- az_list_cluster_group
}

function run_remove(){
    az_delete_resource_group
}

#__main__#













