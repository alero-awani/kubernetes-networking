# Kubernetes Networking

## Notes

![alt text](assets/page-1.png)

### Exercise: Create and Connect Containers Across VMs

1. Setup Vagrant VM

    ```sh
    vagrant ssh
    ```

1. Check initial network configuration

    ```sh
    ip addr show
    ```

1. Copy this into VM1

    ```sh
    NS1="NS1"
    NS2="NS2"
    NODE_IP="192.168.56.10"
    BRIDGE_SUBNET="172.16.0.0/24"
    BRIDGE_IP="172.16.0.1"
    IP1="172.16.0.2"
    IP2="172.16.0.3"
    TO_NODE_IP="192.168.56.11"
    TO_BRIDGE_SUBNET="172.16.1.0/24"
    TO_BRIDGE_IP="172.16.1.1"
    TO_IP1="172.16.1.2"
    TO_IP2="172.16.1.3"
    ```

Note: `IP*` `TO_IP*` -> IPS of the Virtual Ethernets.

1. Creating the namespaces

    ```sh
    sudo ip netns add $NS1
    sudo ip netns add $NS2
        ip netns show
    ```

1. Creating the veth pairs

    ```sh
    sudo ip link add veth10 type veth peer name veth11
    sudo ip link add veth20 type veth peer name veth21
    ```

1. Adding the veth pairs to the namespaces

    Here you attach one end of the veth to the namespace.

    ```sh
    sudo ip link set veth11 netns $NS1
    sudo ip link set veth21 netns $NS2
    ```

1. Configuring the interfaces in the network namespaces with IP address

    ```sh
    sudo ip netns exec $NS1 ip addr add $IP1/24 dev veth11 
    sudo ip netns exec $NS2 ip addr add $IP2/24 dev veth21 
    ```

    Here we are using `netns exec` because we are reaching from outside into the namespace. Like a docker exec.

1. Enabling the interfaces inside the network namespaces

    ```sh
    sudo ip netns exec $NS1 ip link set dev veth11 up
    sudo ip netns exec $NS2 ip link set dev veth21 up
    ```

1. Creating the bridge

    ```sh
    sudo ip link add br0 type bridge
        ip link show type bridge
            ip link show br0
            #sudo ip link delete br0
    ```

1. Adding the network namespaces interfaces to the bridge

    ```sh
    sudo ip link set dev veth10 master br0
    sudo ip link set dev veth20 master br0
    ```

    Here we adding the other end of the adapter to the bridge we created (Make reference to the diagram to understand better).

    Note: the `ip` command there doesn’t mean IP address, it refers to the Linux ip utility (part of the `iproute2` suite).

    `dev veth10` → specifies which device (interface) you’re modifying.

    `master br0` → assigns veth10 to the bridge called br0, master here is the bond that will control that interface.

1. Assigning the IP address to the bridge

    ```sh
    sudo ip addr add $BRIDGE_IP/24 dev br0
    ```

1. Enabling the bridge

    ```sh
    sudo ip link set dev br0 up
    ```