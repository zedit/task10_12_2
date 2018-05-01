#!/bin/bash
set -x
source config
path_to_workir=$(pwd)
ssl_cert="${path_to_workir}/certs/web.crt"
ssl_cert_key="${path_to_workir}/certs/web.key"
root_cert="${path_to_workir}/certs/root-ca.crt"
root_cert_key="${path_to_workir}/certs/root-ca.key"

function docker_install {
  apt-get update
  apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"
  apt-get update
  apt-get install -y docker-ce docker-compose
}

function get_ssl_certs() {
  if [ ! -e "${path_to_workir}/certs" ]; then
    mkdir ${path_to_workir}/certs
  fi
  local ssl_conf="${path_to_workir}/certs/opensll_san.cnf"
  local ssl_csr="${path_to_workir}/certs/web.csr"
cat << EOF > ${ssl_conf}
[ v3_req ]
basicConstraints            = CA:FALSE
keyUsage                    = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName              = @alt_names
 
[alt_names]
IP.1   = ${EXTERNAL_IP}
DNS.1   = ${HOSTNAME}
EOF
  openssl genrsa -out "${root_cert_key}" 4096
  openssl req -x509 -new -nodes -key "${root_cert_key}" -sha256 -days 10000 -out "${root_cert}" -subj "/C=UA/ST=Kharkov/L=Kharkov/O=homework/OU=task6_7/CN=root_cert"
  openssl genrsa -out "${ssl_cert_key}" 2048
  openssl req -new -out "${ssl_csr}" -key "${ssl_cert_key}" -subj "/C=UA/ST=Kharkov/L=Kharkov/O=homework/OU=task6_7/CN=${HOSTNAME}/"
  openssl x509 -req -in "${ssl_csr}" -CA "${root_cert}" -CAkey "${root_cert_key}" -CAcreateserial -out "${ssl_cert}" -extensions v3_req -extfile "${ssl_conf}"
  cat "${ssl_cert}" "${root_cert}" > ${ssl_cert_chain}
}

function run_docker_compose {
  if ! [ -d ${NGINX_LOG_DIR} ]; then
    mkdir -p /srv/log/nginx
  fi
  touch ${NGINX_LOG_DIR}/access.log
  local template_path="templates/docker-compose.yml.template"
  cp ${template_path} docker-compose.yml
  sed -i "s/SED_NGINX_IMAGE/${NGINX_IMAGE}/" docker-compose.yml
  sed -i "s/SED_APACHE_IMAGE/${APACHE_IMAGE}/" docker-compose.yml
  sed -i "s/SED_NGINX_PORT/${NGINX_PORT}/" docker-compose.yml
  sed -i "s#SED_NGINX_LOG_DIR#${NGINX_LOG_DIR}#" docker-compose.yml
  docker-compose up
}

docker_install
get_ssl_certs
run_docker_compose
