#!/bin/bash

## ------ REQUISITES ------
## docker, docker-machine, virtualbox, node, 
##

# TODO: import global var inside called scripts
export NODE_ENV=production
export SERVER_PORT=3000

export MONGO_EXT_PORT=27018
export NODE_STACK_NAME=phoenix
export MONGO_SERVICE_NAME=${NODE_STACK_NAME}_mongo_app
export DB_CONNECTION_STRING=mongodb://${MONGO_SERVICE_NAME}:${MONGO_EXT_PORT}/phoenix

export DOCKER_HUB_USERNAME=alessandroaffinito

# --- Install Docker and Composer
echo -e '\n I\m assuming you have already Docker, docker-machine, virtualbox and docker-composer up & running..'

sudo usermod -aG docker $USER


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

sudo bash -c "cat > $DAEMON_FILE " <<EOF
{
"log-driver": "json-file",
"log-opts": {
    "max-size": "1m",    
    "max-file": "3",
    "compress": "true"
    }
} 
EOF

sudo bash -c "cat > $ROTATE_FILE " <<EOF
/var/lib/docker/containers/*/*.log {
        rotate 2
        weekly
        compress
}
EOF


cd ..

# ---- Clean everything ! ----
docker-compose down 
docker-compose -f docker-compose-swarm.yml down
# - CAUTION
# docker system prune 

docker network create --attachable backend

### OLD
### This section is replaced by below docker-compose building
#   search for: stack-deploy-docker-compose-swarm
#   ---- Build images ----
# - DB
# docker run -d \
#   --name mongo \
#   --mount source=data,target=/data/db \
#   --network backend \
#   -p 27017 \
#   mongo:3.4.1
  
# - nodejs server
cp config/dockerfile/node-swarm . && \
    docker build --no-cache --tag=server -f node-swarm --force-rm . && \
    rm node-swarm 
# docker run -p 3000:3000 --network backend --link mongo server
# cd ../..

echo -e '\nAvailable images: '
docker image ls
echo

# ---- PUBLISH
docker login --username DOCKER_HUB_USERNAME
# docker tag server ${DOCKER_HUB_USERNAME}/node-server:prd
# docker push ${DOCKER_HUB_USERNAME}/node-server:prd

# ------------------------------------------------------------- #
# ---- initialize the stack manager  ----
docker swarm init

# ---- use this also to redeploy after a change (eg: scaling)
# docker stack deploy -c docker-compose-swarm.yml phoenix
# docker stack services phoenix

# ---- Take down
# docker stack rm phoenix
# docker service ls


if [[ "$(uname -s )" == "Linux" ]]; then
  export VIRTUALBOX_SHARE_FOLDER="$PWD:$PWD"
fi

service virtualbox start

# creates machines with virtualbox driver
# PLEASE WAIT
# for i in 1 2; do
#     docker-machine create -d virtualbox --virtualbox-cpu-count 2 swarm-$i
# done

# OR if they are already created
# for i in 1 2; do
#     docker-machine start swarm-$i
# done

# to force machine ip settings
# echo "ifconfig eth1 192.168.99.111 netmask 255.255.255.0 broadcast 192.168.99.255 up" | docker-machine ssh swarm-1 sudo tee /var/lib/boot2docker/bootsync.sh > /dev/null

docker-machine ls

# Connect shell to the manager machine
eval $(docker-machine env swarm-1)

# Promote first machine as manager
docker swarm init --advertise-addr $(docker-machine ip swarm-1)

# Add workers to the swarm 
TOKEN=$(docker swarm join-token -q manager)
for i in 2; do
    eval $(docker-machine env swarm-$i)

    docker swarm join \
        --token $TOKEN \
        --advertise-addr $(docker-machine ip swarm-$i) \
        $(docker-machine ip swarm-1):2377
done

echo ">> The swarm cluster is up and running"
docker-machine env swarm-1

# the proxy is used as single access point to the cluster
docker network create -d overlay --attachable proxy

docker stack deploy \
    -c config/dockerfile/docker-flow-proxy-mem.yml \
    proxy

docker service ls
docker network create -d overlay --attachable monitor


## Install "Incoming WebHooks" Slack App first, then save your web hook
#   This API will be used as a default receiver by the alert_manager
#   custom INCOMING Slack web hook: https://hooks.slack.com/services/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
#   APP INCOMING Slack web hook :   https://hooks.slack.com/services/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
echo "route:
  group_by: [service,scale]
  repeat_interval: 5m
  group_interval: 5m
  receiver: 'slack'
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
  - name: 'slack'
    slack_configs:
      - send_resolved: true
        title: '[{{ .Status | toUpper }}] {{ .GroupLabels.service }} service is in danger!'
        title_link: 'http://$(docker-machine ip swarm-1)/monitor/alerts'
        text: '{{ .CommonAnnotations.summary}}'
        api_url: 'https://hooks.slack.com/services/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'
  - name: 'jenkins-phoenix_app-up'
    webhook_configs:
      - send_resolved: false
        url: 'http://$(docker-machine ip swarm-1)/jenkins/job/service-scale/buildWithParameters?token=PHOENIX&service=phoenix_app&scale=1'
  - name: 'jenkins-phoenix_app-down'
    webhook_configs:
      - send_resolved: false
        url: 'http://$(docker-machine ip swarm-1)/jenkins/job/service-scale/buildWithParameters?token=PHOENIX&service=phoenix_app&scale=-1'
" | docker secret create alert_manager_config -

# deploy the monitor stack
#   - Prometheus 
#   - docker-flow-monitor
#   - docker-flow-swarm-listener
# DOMAIN=$(docker-machine ip swarm-1)
# here the secret alert_manager_config is loaded in the swarm listener
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

# ------ Auto Scaling & monitoring stack  --------------------- #
# TODO: check req/sec & cpu usage (https://github.com/google/cadvisor)

### MANUALLY
# REPLICAS=$( docker service ps phoenix_app | grep Running| wc -l)
# docker service update --replicas $(($REPLICAS + 1)) phoenix_app


# ----------------------------------------------
#     NODE SERVER
# ----------------------------------------------
#  TODO: prometeus functions: https://github.com/siimon/prom-client
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



## ---------------------------------------------
##    Monitoring commands 
## ---------------------------------------------

# docker-machine ssh swarm-1
# docker@swarm-1:~$ docker inspect `docker ps -f name=mongo | awk 'END{ print $1 }'`                                                                    

