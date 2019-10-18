#!/bin/bash

set -o errexit

OPENRESTY_VERSION=1.15.8.1
LUAROCKS_VERSION=3.0.4
KONG_VERSION=1.3.0
KONG_CONFIG=/etc/kong/kong.conf

echo "*************************************************************************"
echo "Installing apt dependencies"
echo "*************************************************************************"

# sudo sed -i "s/archive.ubuntu.com/mirrors.163.com/g" /etc/apt/sources.list
# sudo apt update -qq
# sudo apt install make gcc libpcre3-dev libssl-dev perl build-essential curl zlib1g-dev unzip m4 libyaml-dev valgrind -y -qq

echo "*************************************************************************"
echo "Building openresty"
echo "*************************************************************************"
if [ -d "openresty-build-tools" ]; then
    echo "already clone"
    rm -rf openresty-build-tools/work rm -rf openresty-build-tools/buildroot
else
    git clone https://github.com/Kong/openresty-build-tools.git
fi
cd openresty-build-tools
./kong-ngx-build \
    -p buildroot \
    --openresty $OPENRESTY_VERSION \
    --openssl 1.1.1b \
    --luarocks $LUAROCKS_VERSION \
    --force
echo "export PATH=$(pwd)/buildroot/luarocks/bin:\$PATH" >>~/.bashrc
echo "export PATH=$(pwd)/buildroot/openssl/bin:\$PATH" >>~/.bashrc
echo "export PATH=$(pwd)/buildroot/openresty/bin:\$PATH" >>~/.bashrc
echo "export PATH=$(pwd)/buildroot/openresty/nginx/sbin:\$PATH" >>~/.bashrc
# source ~/.bashrc
eval "$(cat ~/.bashrc | tail -n +10)"
luarocks --version
openresty -v
nginx -v
cd

echo "*************************************************************************"
echo "Installing kong dependencies"
echo "*************************************************************************"
wget -O "kong-${KONG_VERSION}.tar.gz" "https://github.com/Kong/kong/archive/${KONG_VERSION}.tar.gz"
tar -xvf "kong-${KONG_VERSION}.tar.gz"
cd "kong-${KONG_VERSION}"
# luarocks install pgmoon 1.10.0
# luarocks install lua-pack 1.0.5
make install

echo "export PATH=$(pwd)/bin:\$PATH" >>~/.bashrc
# source ~/.bashrc
eval "$(cat ~/.bashrc | tail -n +10)"
eval "$(luarocks path)"
kong version

echo "*************************************************************************"
echo "Configuring kong"
echo "*************************************************************************"
if [ -d "/etc/kong" ]; then

else
    sudo mkdir -p /etc/kong
fi
wget https://gist.githubusercontent.com/ciiiii/4f5fa80e02f820d7e7490bc9854da59f/raw/10aee35f4268c61cb0c52e9d0f62115f4b820eba/kong.conf
sudo cp kong.conf /etc/kong/kong.conf
if [ -d "/kong" ]; then

else
    sudo mkdir /kong
fi
sudo chown -R "$USER:$(groups)" /kong
kong start
