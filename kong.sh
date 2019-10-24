#!/bin/bash

set -o errexit

OPENRESTY_VERSION=1.15.8.1
LUAROCKS_VERSION=3.1.3
OPENSSL_VERSION=1.1.1b
KONG_VERSION=1.3.0

echo "*************************************************************************"
echo "Building openresty"
echo "*************************************************************************"

cd /

sudo git clone https://github.com/Kong/openresty-build-tools.git

cd /openresty-build-tools
sudo chown -R "travis:travis" /openresty-build-tools
./kong-ngx-build \
    -p buildroot \
    --openresty $OPENRESTY_VERSION \
    --openssl $OPENSSL_VERSION \
    --luarocks $LUAROCKS_VERSION \
    --force

sudo ln -s "$(pwd)/buildroot/luarocks/bin/luarocks" /usr/bin/luarocks
sudo ln -s "$(pwd)/buildroot/openresty/nginx/sbin/nginx" /usr/bin/nginx
sudo ln -s "$(pwd)/buildroot/openresty/bin/resty" /usr/bin/resty
sudo ln -s "$(pwd)/buildroot/openresty/bin/openresty" /usr/bin/openresty
sudo mv "$(pwd)/buildroot/openresty/bin/resty" /usr/bin
luarocks --version
openresty -v
nginx -v
cd /

echo "*************************************************************************"
echo "Installing kong dependencies"
echo "*************************************************************************"
sudo wget -O "kong-${KONG_VERSION}.tar.gz" "https://github.com/Kong/kong/archive/${KONG_VERSION}.tar.gz"
sudo tar -xvf "kong-${KONG_VERSION}.tar.gz"
sudo chown -R "travis:travis" "kong-${KONG_VERSION}"
cd "kong-${KONG_VERSION}"
make install

sudo ln -s "$(pwd)/bin/kong" /usr/bin/kong
eval "$(luarocks path)"
kong version -vv
cd /

echo "*************************************************************************"
echo "Configuring kong"
echo "*************************************************************************"

sudo mkdir -p /etc/kong
echo "prefix = /kong/
pg_password = \"kong\"
proxy_listen = 0.0.0.0:80, 0.0.0.0:443 ssl
" | sudo tee -a /etc/kong/kong.conf >/dev/null

sudo mkdir /kong
sudo chown -R "travis:travis" /kong

echo "*************************************************************************"
echo "Configuring systemd"
echo "*************************************************************************"

export LUAROCKS_PREFIX=$(pwd)/openresty-build-tools/buildroot/luarocks
echo "LUA_PATH=\"${LUAROCKS_PREFIX}/share/lua/5.1/?.lua;;${LUAROCKS_PREFIX}/share/lua/5.1/?/init.lua;/kong-plugin/?.lua;/kong-plugin/?/init.lua\"" | sudo tee -a /etc/systemd/system/kong.env >/dev/null

echo "[Unit]
Description=kong
After=network.target
[Service]
# Restart=always
User=root
Type=simple
EnvironmentFile=/etc/systemd/system/kong.env
ExecStart=/usr/bin/kong start -v
ExecReload=/usr/bin/kong reload -v
ExecStop=/usr/bin/kong stop -v
PIDFile=/kong/pids/nginx.pid

[Install]
WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/kong.service >/dev/null

sudo systemctl daemon-reload
sudo systemctl enable kong.service
kong migrations bootstrap -vv
sudo systemctl start kong.service
sleep 10

res="$(curl localhost 2>/dev/null)"
echo $res

echo "*************************************************************************"
echo "Configuring custom plugins"
echo "*************************************************************************"
sudo git clone https://github.com/Kong/kong-plugin.git
sudo systemctl reload kong.service

curl -s localhost:8001 | jq .plugins
