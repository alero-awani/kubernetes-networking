#!/bin/bash
export master='192.168.56.10'
export node1='192.168.56.11'

##################### Run this on all Linux nodes #######################

#Update the server
sudo apt-get update -y; sudo apt-get upgrade -y

#Get Kernel version. Make sure it is >= v5.3
sudo hostnamectl

#Install helm on master
sudo snap install helm --classic

#Install containerd
sudo apt-get install containerd -y

#Configure containerd and start the service
sudo mkdir -p /etc/containerd
sudo su -
containerd config default  /etc/containerd/config.toml
exit

#Next, install Kubernetes. First you need to add the repository's GPG key with the command:
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p /etc/apt/keyrings
sudo chmod 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

#Install all of the necessary Kubernetes components with the command:
sudo apt-get install kubeadm kubelet kubectl -y
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet


#Modify "sysctl.conf" to allow Linux Node’s iptables to correctly see bridged traffic
#Controls whether packets traversing a Linux bridge (like the one Docker or containerd uses for containers) should also be passed through the iptables firewall rules.
#Without this iptables never sees the packets.
echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf


#Allow packets arriving at the node's network interface to be forwaded to pods. 
# Tells the Linux kernel: “This machine should act like a router, not just a host.”
# Enables forwarding of IP packets between different network interfaces.

echo "net.ipv4.ip_forward = 1" | sudo tee -a /etc/sysctl.conf


#Reload the configurations with the command:
sudo sysctl --system

#Load overlay and netfilter modules 
sudo modprobe overlay
sudo modprobe br_netfilter
  
#Disable swap by opening the fstab file for editing 
#In this Vagrant box, swap is not enabled by default.
sudo nano /etc/fstab
    #Comment out "/swap.img"

#Disable swap from comand line also 
sudo swapoff -a

#Pull the necessary containers with the command:
sudo kubeadm config images pull

#If kubeadm fails
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
check -> https://github.com/kubernetes/kubernetes/issues/112622 or https://github.com/kubernetes/kubernetes/issues/110177

#************************************************** This section must be run only on the Master node*************************************************************************************************

#Make sure "kube-proxy" is not installed, we want cilium to use the new "eBPF" based proxy
sudo kubeadm init --skip-phases=addon/kube-proxy --apiserver-advertise-address=192.168.56.10 #cilium installation

#kube-proxy CNI installtion
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.57.10 #flannel installation for kube-proxy

#*****************************************************
#Once the "init" command has completed successfuly, run the "kubeadm join ..." 
#on all your other nodes before proceeding. 

sudo kubeadm join 192.168.56.10:6443 --token t1nf47.nzgkqlnwck1ct49w \
        --discovery-token-ca-cert-hash sha256:310a544f3ec7e9361e77320207343a1de392d4b45f0b1cbf64dc59783297d2ed 


#Install flannel
 kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

# Check the logs
sudo journalctl -u kubelet -f
sudo crictl ps -a
sudo crictl logs <CONTAINER_ID>
sudo crictl logs 03686b747855e
sudo crictl inspect 331b0c2dfd80f 
sudo crictl logs 2af532cf62ad5 

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#Install cilium CLI
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
rm cilium-linux-amd64.tar.gz{,.sha256sum}

#Setup Helm repository
helm repo add cilium https://helm.cilium.io/

# Kernel requirements => https://docs.cilium.io/en/stable/operations/system_requirements/?utm_source=chatgpt.com#required-kernel-versions-for-advanced-features
helm upgrade cilium cilium/cilium --version 1.18.1 \
  --namespace=kube-system \
  --set encryption.enabled=true \
  --set encryption.ipsec.encryptedOverlay=true \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=192.168.56.10 \
  --set k8sServicePort=6443
#***If "kubectl get nodes" shows "Not Ready"
#***Or  "kubectl get pods -n kube-system" shows "coredns-*" as "Pending",
#**Reboot node(s)
kubectl get nodes
kubectl get pods -n kube-system -o wide

kubectl -n kube-system get pods -l k8s-app=cilium -o wide
MASTER_CILIUM_POD=$(kubectl -n kube-system get pods -l k8s-app=cilium -o wide |  grep master | awk '{ print $1}' )
echo $MASTER_CILIUM_POD

#validate that the Cilium agent is running in the desired mode (non kube-proxy)
kubectl exec -it -n kube-system $MASTER_CILIUM_POD -- cilium status | grep 

kubectl exec -it -n kube-system cilium-jdghc -- cilium status | grep KubeProxyReplacement

#Validate that Cilium installation
cilium status --wait

#Review what network interfaces Cilium has created
ip link show

#Optionally copy the "/.kube" folder to other nodes
scp -r $HOME/.kube gary@$node1:/home/gary


#**************************************************Cluster installation tests*******************************************************
#Optionally untaintthe master node
kubectl taint nodes vm1-cilium node-role.kubernetes.io/control-plane:NoSchedule-
kubectl taint nodes vm1-proxy node-role.kubernetes.io/control-plane:NoSchedule-

#Schedule a Kubernetes deployment using a container from Google samples
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0

#Scale up the replica set to 4
kubectl scale --replicas=4 deployment/hello-world

#Get pod info
kubectl get pods -o wide

kubectl expose deployment hello-world --port=8080 --target-port=8080 --type=NodePort
kubectl get service hello-world

#shows the loadbalancing situation
kubectl exec -it -n kube-system cilium-68xxx -- cilium service list

#Verify that iptables are not used
sudo iptables-save | grep KUBE-SVC

export CLUSTERIP=$(kubectl get service hello-world  -o jsonpath='{ .spec.clusterIP }')
echo $CLUSTERIP

PORT=$( kubectl get service hello-world  -o jsonpath='{.spec.ports[0].port}')
echo $PORT

curl http://$CLUSTERIP:$PORT

NODEPORT=$( kubectl get service hello-world  -o jsonpath='{.spec.ports[0].nodePort}')
echo $NODEPORT

curl http://$master:$NODEPORT


#***************************************************Setup Hubble******************************************************************

cilium hubble enable

#Enabling Hubble requires the TCP port 4245 to be open on all nodes running Cilium. This is required for Relay to operate correctly.

cilium status

#In order to access the observability data collected by Hubble, install the Hubble CL
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz{,.sha256sum}

#In order to access the Hubble API, create a port forward to the Hubble service from your local machine
cilium hubble port-forward&

hubble status
#If you get "Unavailable Nodes: ", follow below troubleshooting:
######Hubbel trouble shooting####

    #Get resolution from: https://github.com/cilium/hubble/issues/599
    kubectl delete secrets -n kube-system cilium-ca
    kubectl get secrets -n kube-system hubble-ca-secret -o yaml | sed -e 's/name: hubble-ca-secret/name: cilium-ca/;/\(resourceVersion\|uid\)/d' | kubectl apply -f -
    cilium hubble disable
    cilium hubble enable
    #Please note that the next time the hubble-generate-certs CronJob runs, 
    #it will override the TLS certificates for both Hubble and Relay signing them with hubble-ca-secret (i.e. not ciliium-ca). 
    #Relay should continue to work, but this could bring more incompatibility with the CLI (e.g. if you were to disable then re-enable Hubble again through the CLI).
    cilium hubble port-forward&
    hubble status
    hubble observe

#Setup Hubble UI
cilium hubble enable --ui

cilium hubble ui










