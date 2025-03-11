#!/bin/bash

# Script to generate self-signed certificates for local development

# Create certs directory if it doesn't exist
mkdir -p /etc/traefik/certs

# Generate a private key
openssl genrsa -out /etc/traefik/certs/local-key.pem 2048

# Generate a certificate signing request
openssl req -new -key /etc/traefik/certs/local-key.pem -out /etc/traefik/certs/local.csr -subj "/C=US/ST=State/L=City/O=PhotoPrism/CN=photoprismpi.local"

# Generate a self-signed certificate
openssl x509 -req -days 3650 -in /etc/traefik/certs/local.csr -signkey /etc/traefik/certs/local-key.pem -out /etc/traefik/certs/local-cert.pem

# Create an empty acme.json file with proper permissions
touch /etc/traefik/acme.json
chmod 600 /etc/traefik/acme.json

# Clean up
rm /etc/traefik/certs/local.csr

echo "Self-signed certificates generated successfully." 