### Notes

To see the interfaces Cilium created, run the command `ip link show`

![alt text](assets/image.png)

- All these are the veth counterparts that are attached to the host when the pod is created.
- By default cilium uses vxlan, so we can see the interface created for vxlan.


### Conntrack test between eBPF vs Iptables

1. Install conntrack

```sh
sudo apt-get install -y linux-tools-common "linux-tools-$(uname -r)" conntrack
```

2. Configure the Linux kernel to allow access to the performance events system. For that purpose set kernel.kptr_restrict to 0. Make perf output human-readable function names instead of just addresses.

```sh
sudo sysctl -w kernel.kptr_restrict=0
```

3. Generate traffic to pods

```sh
for i in {1..30000}; do
  echo "Request $i:"
  curl -s http://localhost:30570
  echo
done
```

```sh
for i in {1..3000}; do
  echo "Request $i:"
  curl -s http://192.168.56.10:32633
  echo
done
```


```sh
sudo conntrack -S
```

```sh
sudo perf top -a -e cycles:k --stdio

```