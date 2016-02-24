#!/bin/bash -xe
#Generates userdata.txt to be run on the machines 
cat <<EOF >userdata.txt
#!/bin/bash
date
set -x
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export layout=full
export git_protocol=https 
release="\$(lsb_release -cs)"
sudo mkdir -p /etc/facter/facts.d
export no_proxy="127.0.0.1,169.254.169.254,localhost,consul,jiocloud.com"
export http_proxy=${http_proxy} 
export https_proxy=${http_proxy}
iecho no_proxy="'127.0.0.1,localhost,consul'" >> /etc/environment
echo http_proxy="'${http_proxy}'" >> /etc/environment
echo https_proxy="'${https_proxy}'" >> /etc/environment
/bin/bash -c 'sudo echo "deb http://10.140.221.229/apt/JcsDSS/JcsDSS jiocloud main" | sudo tee -a /etc/apt/sources.list'
/bin/bash -c 'sudo echo "deb http://10.140.221.229/mirrors/mirrors/42/jiocloud.rustedhalo.com/ubuntu/ trusty main" | sudo tee -a /etc/apt/sources.list'
/bin/bash -c 'sudo echo "deb http://apt.puppetlabs.com trusty main" | sudo tee -a /etc/apt/sources.list'
/bin/bash -c 'sudo echo "deb-src http://apt.puppetlabs.com trusty main" | sudo tee -a /etc/apt/sources.list'
/bin/bash -c 'sudo echo "deb http://apt.puppetlabs.com trusty dependencies" | sudo tee -a /etc/apt/sources.list'
/bin/bash -c 'sudo echo "deb-src http://apt.puppetlabs.com trusty dependencies"  | sudo tee -a /etc/apt/sources.list'
apt-get update
wget -O puppet.deb -t 5 -T 30 http://apt.puppetlabs.com/puppetlabs-release-trusty.deb
dpkg -i puppet.deb
apt-get update 
n=0
while [ \$n -le 6 ]
do
  apt-get install --force-yes -y puppet-dss hiera ruby puppet software-properties-common && break
  n=\$((\$n+1))
  sleep 5
done

apt-get install -y --force-yes python-jiocloud
time gem install faraday faraday_middleware --no-ri --no-rdoc;
time gem install librarian-puppet-simple --no-ri --no-rdoc;

echo 'consul_discovery_token='${consul_discovery_token} > /etc/facter/facts.d/consul.txt
# default to first 16 bytes of discovery token
echo 'consul_gossip_encrypt'=`echo ${consul_discovery_token} | cut -b 1-15 | base64` >> /etc/facter/facts.d/consul.txt
#echo 'current_version='${BUILD_NUMBER} > /etc/facter/facts.d/current_version.txt
echo 'env=dev-test'> /etc/facter/facts.d/env.txt



while true
do
  # first install all packages to make the build as fast as possible
  puppet apply --detailed-exitcodes /etc/puppet/manifests/site.pp --config_version='echo packages' --tags package
  ret_code_package=\$?
  apt-get install -f -y
  # now perform base config
  (echo 'File<| title == "/etc/consul" |> { purge => false }'; echo 'include rjil::jiocloud' ) | puppet apply --config_version='echo bootstrap' --detailed-exitcodes --debug /etc/puppet/manifests/site.pp
  ret_code_jio=\$?
  if [[ \$ret_code_jio = 1 || \$ret_code_jio = 4 || \$ret_code_jio = 6 || \$ret_code_package = 1 || \$ret_code_package = 4 || \$ret_code_package = 6 ]]
  then
    echo "Puppet failed. Will retry in 5 seconds"
    sleep 5
  else
    break
  fi
done
date
EOF
