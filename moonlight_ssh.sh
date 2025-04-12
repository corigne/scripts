#!/bin/bash

#Enables Playing on a moonlight server via an ssh tunnel. This is useful on restricted networks, as only the ssh port is needed.
#Needs the complimentary script, redirectudp, running on the ssh server to function.

#needs a private key for the ssh server
#sudo apt install ssh socat snap
#snap install moonlight

#IP of the gaming rig on the local network
gip=ishimura
#User and Address of the SSH server (sharing local network with the gaming rig
sshuser=nexus
sip=traveler

#Program to start with moonlight
app=Desktop

ssh \
-L 47984:$gip:47984 \
-L 47989:$gip:47989 \
-L 48010:$gip:48010 \
-L 48998:localhost:48998 \
-L 48999:localhost:48999 \
-L 49000:localhost:49000 \
-L 49002:localhost:49002 \
-L 49010:localhost:49010 \
-N  $sshuser@$sip &
socat -T15 udp4-recvfrom:47998,reuseaddr,fork tcp:localhost:48998 &
socat -T15 udp4-recvfrom:47999,reuseaddr,fork tcp:localhost:48999 &
socat -T15 udp4-recvfrom:48000,reuseaddr,fork tcp:localhost:49000 &
socat -T15 udp4-recvfrom:48002,reuseaddr,fork tcp:localhost:49002 &
socat -T15 udp4-recvfrom:48010,reuseaddr,fork tcp:localhost:49010 &
read
kill $(lsof -t -i:49000)
