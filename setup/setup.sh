#!/bin/sh

# TODO: import global var inside called scripts
export NODE_ENV=production
export SERVER_PORT= 3000
export DB_CONNECTION_STRING=mongodb://mongo:27017/phoenix
export USERNAME=alessandroaffinito

# --- Install Docker and Composer
echo -e '\n I\m assuming you have already Docker, docker-machine, virtualbox and docker-composer up & running..'

# Docker Machine
# base=https://github.com/docker/machine/releases/download/v0.16.0 &&
#   curl -L $base/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine &&
#   sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
docker-machine version


# ---- Log Rotation ----
echo -e 'Setting up log rotation files..'
echo -e 'Logs are rotated weekly, keeping the last 2 weeks files.'
echo -e 'At container level no more than 3 MB are used for logs.'

DAEMON_FILE="/etc/docker/daemon.json"
ROTATE_FILE="/etc/logrotate.d/docker"

sudo /bin/cat <<EOM >$DAEMON_FILE
{
"log-driver": "json-file",
"log-opts": {
    "max-size": "1m",    
    "max-file": "3",
    "compress": "true"
    }
} 
EOM

sudo /bin/cat <<EOM >$ROTATE_FILE
/var/lib/docker/containers/*/*.log {
        rotate 2
        weekly
        compress
}
EOM


# ---- Clean everything ! ----
docker-compose down 
docker system prune 
# docker-compose up

### This section is replaced by below docker-compose building
#   search for: stack-deploy-docker-compose-swarm
#   ---- Build images ----
docker network create backend
# - DB
# docker run -d \
#   --name mongo \
#   --mount source=data,target=/data/db \
#   --network backend \
#   -p 27017 \
#   mongo:latest
  
# - nodejs server
# cp config/dockerfile/node-swarm . && \
#     docker build --tag=server -f node-swarm --force-rm . && \
#     rm node-swarm 
# docker run -p 3000:3000 --network backend --link mongo server
# cd ../..

echo -e '\nAvailable images: '
docker image ls
echo

# ---- PUBLISH
# docker login
# docker tag server ${USERNAME}/node-server:prd
# docker push ${USERNAME}/node-server:prd


# ---- DEPLOY AND RUN THE CLUSTER ----
docker swarm init

# ---- use this also to redeploy after a change (eg: scaling)
docker stack deploy -c docker-compose-swarm.yml phoenix

docker stack services phoenix

# ---- Take down
# docker stack rm cloud

docker service ls


# ------------------------------------------------------------- #
# ------ Auto Scaling & monitoring stack  --------------------- #
# TODO: check req/sec & cpu usage (https://github.com/google/cadvisor)

# REPLICAS=$( docker service ps cloud_app | grep Running| wc -l)
# docker service update --replicas $(($REPLICAS + 1)) cloud_app

if [[ "$(uname -s )" == "Linux" ]]; then
  export VIRTUALBOX_SHARE_FOLDER="$PWD:$PWD"
fi

service virtualbox start

# creates machines with virtualbox driver
# PLEASE WAIT
# for i in 1 2 3; do
#     docker-machine create \
#         -d virtualbox \
#         swarm-$i
# done

# OR if they are already created
for i in 1 2 3; do
    docker-machine start swarm-$i
done

# to force machine ip settings
# echo "ifconfig eth1 192.168.99.111 netmask 255.255.255.0 broadcast 192.168.99.255 up" | docker-machine ssh swarm-1 sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null

docker-machine ls
eval $(docker-machine env swarm-1)

# Promote first machine as manager
docker swarm init --advertise-addr $(docker-machine ip swarm-1)

# Add workers
TOKEN=$(docker swarm join-token -q manager)
for i in 2 3; do
    eval $(docker-machine env swarm-$i)

    docker swarm join \
        --token $TOKEN \
        --advertise-addr $(docker-machine ip swarm-$i) \
        $(docker-machine ip swarm-1):2377
done

echo ">> The swarm cluster is up and running"


# the proxy is used as single access point to the cluster
docker network create -d overlay proxy
docker stack deploy \
    -c config/dockerfile/docker-flow-proxy-mem.yml \
    proxy

docker service ls

docker network create -d overlay monitor
echo "route:
  group_by: [service,scale]
  repeat_interval: 5m
  group_interval: 5m
  # receiver: 'slack'
  routes:
  - match:
      service: 'phoenix_app'
      scale: 'up'
    receiver: 'jenkins-phoenix_app-up'
  - match:
      service: 'phoenix_app'
      scale: 'down'
    receiver: 'jenkins-phoenix_app-down'

receivers:
  - name: 'jenkins-phoenix_app-up'
    webhook_configs:
      - send_resolved: false
        url: 'http://$(docker-machine ip swarm-1)/jenkins/job/service-scale/buildWithParameters?token=PHOENIX&service=phoenix_app&scale=1'
  - name: 'jenkins-phoenix_app-down'
    webhook_configs:
      - send_resolved: false
        url: 'http://$(docker-machine ip swarm-1)/jenkins/job/service-scale/buildWithParameters?token=PHOENIX&service=phoenix_app&scale=-1'
" | docker secret create alert_manager_config -

# deploy the monitor cluster
#   - Prometheus 
#   - docker-flow-monitor
#   - docker-flow-swarm-listener
DOMAIN=$(docker-machine ip swarm-1) \
    docker stack deploy \
    -c config/dockerfile/docker-flow-monitor-slack.yml \
    monitor

docker stack ps monitor

# Deploy 
#   - cadvisor
#   - node-exporter
docker stack deploy \
    -c config/dockerfile/exporters.yml \
    exporter

docker stack ps exporter


# ----------------------------------------------
#     JENKINS
# ----------------------------------------------
echo "admin" | docker secret create jenkins-user -
echo "admin" | docker secret create jenkins-pass -
docker stack deploy -c config/dockerfile/jenkins-scale.yml jenkins
docker stack ps jenkins

echo "Configure Jenkins jobs at: "
echo "http://$(docker-machine ip swarm-1)/jenkins/job/service-scale/configure"
# ----------------------------------------------


# ----------------------------------------------
#     NODE SERVER
# ----------------------------------------------

#  TODO: prometeus functions: https://github.com/siimon/prom-client

## stack-deploy-docker-compose-swarm
docker stack deploy -c docker-compose-swarm.yml phoenix


# --- SCREENSHOTS
# --> see screenshot stack-deploy-docker-compose-swarm for expected architecture
# --> see screenshot swarm-1_serverCall_generateCert.png to see a working call to
#       the server exposed by the virtualbox machine


echo "Prometeus alert screen at: http://$(docker-machine ip swarm-1)/monitor/alerts"

# ------ Mongo DB backup ------
# TODO: Jenkins scheduler
# docker run --rm --link mongo:mongo --network backend -v bkp:/backup mongo bash -c 'mongodump --out /backup --host mongo:27017'
# to restore the backup
# docker run --rm --link mongo:mongo --network backend -v /root:/backup mongo bash -c 'mongorestore /backup --host mongo:27017'
