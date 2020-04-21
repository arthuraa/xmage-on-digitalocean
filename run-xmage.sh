#!/bin/bash

SSHKEYFILE=$(mktemp)

doctl compute ssh-key list --format FingerPrint > $SSHKEYFILE

SSHKEY=$(tail -n 1 $SSHKEYFILE)

echo "SSH key fingerprint: ${SSHKEY}"

IPFILE=$(mktemp)
echo -n "Creating droplet named 'xmage'... "

doctl compute droplet create xmage \
      --size s-1vcpu-2gb           \
      --image docker-18-04         \
      --region nyc1                \
      --format PublicIPv4          \
      --ssh-keys $SSHKEY           \
      --wait > $IPFILE

IP=$(tail -n 1 $IPFILE)

echo "Droplet IP: ${IP}"

SSH_READY=1

echo -n "Waiting for SSH.."

while echo -n "." && ! (ssh -o StrictHostKeyChecking=accept-new root@$IP "echo ' SSH ready.'" 2> /dev/null)
do
    sleep 2
done

echo "Installing XMage on server..."

ssh -tt root@$IP <<-EOF
    if [ ! -d docker-xmage-alpine ]; then
        git clone https://github.com/goesta/docker-xmage-alpine.git
    fi
    docker image build docker-xmage-alpine -t xmage
    docker run --rm -it \
        -p 17171:17171 -p 17179:17179 \
        --add-host $IP.nip.io:0.0.0.0 \
        -e "XMAGE_DOCKER_SERVER_ADDRESS=$IP.nip.io" \
        xmage
EOF

doctl compute droplet delete xmage
