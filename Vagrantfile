Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provision "shell", inline: <<-SHELL
    sudo su -
    cd /vagrant
    apt-get update
    ./run_tests.sh
  SHELL
end
