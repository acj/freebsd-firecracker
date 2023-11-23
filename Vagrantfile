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

      pw groupmod wheel -m vagrant

      pkg install -y git

      su -l vagrant <<'EOF'
      git clone --depth 1 https://git.freebsd.org/src.git /vagrant/src
      EOF
    SHELL
  end
  