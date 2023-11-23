Vagrant.configure("2") do |config|
    config.vm.define "fbsd" do |c|
      c.vm.box = "roboxes/freebsd14"
    end
  
    config.vm.provider "libvirt" do |qe|
      # https://vagrant-libvirt.github.io/vagrant-libvirt/configuration.html
      qe.driver = "kvm"
      qe.cpus = 2
      qe.memory = 8192
    end
  
    config.vm.boot_timeout = 600
  
    config.vm.synced_folder ".", "/vagrant", type: "rsync",
      rsync__exclude: [".git", ".vagrant.d"]
  
    config.vm.provision "shell", inline: <<~SHELL
      set -e

      pkg install -y git sudo

      echo 'vagrant ALL=(ALL) NOPASSWD: ALL' > /usr/local/etc/sudoers.d/vagrant
      pw groupmod wheel -m vagrant      

      git clone --depth 1 https://git.freebsd.org/src.git /usr/src
    SHELL
  end
  