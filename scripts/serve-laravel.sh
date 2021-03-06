#!/usr/bin/env bash

mkdir /etc/nginx/ssl 2>/dev/null

PATH_SSL="/etc/nginx/ssl"
PATH_KEY="${PATH_SSL}/${1}.key"
PATH_CSR="${PATH_SSL}/${1}.csr"
PATH_CRT="${PATH_SSL}/${1}.crt"

PATH_SAN_EXTENSION="${PATH_SSL}/${1}.san"

PATH_CA_ROOT_CRT="${PATH_SSL}/homestead_root_ca.crt"
PATH_CA_ROOT_KEY="${PATH_SSL}/homestead_root_ca.key"
PATH_CA_ROOT_SRL="${PATH_SSL}/homestead_root_ca.srl"

PATH_CERT_EXPORT_DIR="/home/vagrant/Code/cert"
PATH_CERT_EXPORT="${PATH_CERT_EXPORT_DIR}/homestead_root_ca.crt"

if [ ! -f $PATH_CA_ROOT_CRT ] || [ ! -f $PATH_CA_ROOT_KEY ]
then
  openssl req -x509 -nodes -newkey rsa:4096 -keyout "$PATH_CA_ROOT_KEY" -out "$PATH_CA_ROOT_CRT" -days 365 -subj "/C=UK/O=Vagrant Homestead Improved/CN=Vagrant Homestead Improved Root CA" 2>/dev/null
fi

if [ ! -f $PATH_SAN_EXTENSION ]
then
  printf "[SAN]\nsubjectAltName=DNS:${1},DNS:www.${1}\n" > $PATH_SAN_EXTENSION
fi

if [ ! -f $PATH_KEY ] || [ ! -f $PATH_CSR ] || [ ! -f $PATH_CRT ]
then
  openssl genrsa -out "$PATH_KEY" 2048 2>/dev/null
  openssl req -new -key "$PATH_KEY" -out "$PATH_CSR" -subj "/CN=$1" 2>/dev/null
  openssl x509 -req -days 365 -extfile "$PATH_SAN_EXTENSION" -extensions "SAN" -CAcreateserial -CAserial "$PATH_CA_ROOT_SRL" -CAkey "$PATH_CA_ROOT_KEY" -CA "$PATH_CA_ROOT_CRT" -in "$PATH_CSR" -out "$PATH_CRT" 2>/dev/null
fi

if [ ! -d $PATH_CERT_EXPORT_DIR ]
then
  mkdir -p $PATH_CERT_EXPORT_DIR
fi

cp -u $PATH_CA_ROOT_CRT $PATH_CERT_EXPORT


block="server {
    listen ${3:-80};
    listen ${4:-443} ssl http2;
    server_name $1 www.$1;
    root \"$2\";

    index index.html index.htm index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/$1-error.log error;

    sendfile off;

    client_max_body_size 100m;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/var/run/php/php7.1-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;

        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }

    ssl_certificate     /etc/nginx/ssl/$1.crt;
    ssl_certificate_key /etc/nginx/ssl/$1.key;
}
"

echo "$block" > "/etc/nginx/sites-available/$1"
ln -fs "/etc/nginx/sites-available/$1" "/etc/nginx/sites-enabled/$1"
