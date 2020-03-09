#!/bin/bash

if [ -z $1 ]
then
        echo "Please enter a domain name."
        read DOMAIN
else
        DOMAIN=$1
fi
echo "Creating directory /srv/ssl/${DOMAIN}"
mkdir /srv/ssl/${DOMAIN}

echo "Generating certificate for ${DOMAIN} and *.${DOMAIN}..."
export LINODE_V4_API_KEY="LINODE API KEY GOES HERE"
/root/.acme.sh/acme.sh --issue --dns dns_linode_v4 --dnssleep 900 -d "${DOMAIN}" -d "*.${DOMAIN}" --force
if [ $? -eq 0 ]; then
        echo "Installing the certificate..."
        /root/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
            --cert-file /srv/ssl/${DOMAIN}/certificate.pem \
            --key-file /srv/ssl/${DOMAIN}/privkey.pem \
            --fullchain-file /srv/ssl/${DOMAIN}/fullchain.pem \
            --reloadcmd "systemctl reload nginx"
else
        echo "Getting the certificate failed for some reason..."
fi