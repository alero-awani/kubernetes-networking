Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  
  config.vm.define "vm1" do |vm1|
    vm1.vm.hostname = "vm1-proxy"
    vm1.vm.network "private_network", ip: "192.168.57.10"
    vm1.vm.provider "virtualbox" do |vb|
      vb.name = "ubuntu-master"
      vb.memory = "2048"
      vb.cpus = 2
    end
  end

  config.vm.define "vm2" do |vm2|
    vm2.vm.hostname = "vm2-proxy"
    vm2.vm.network "private_network", ip: "192.168.57.11"
    vm2.vm.provider "virtualbox" do |vb|
      vb.name = "ubuntu-worker"
      vb.memory = "2048"
      vb.cpus = 2
    end
  end
end