#!/bin/bash
export DOCKER_HUB_USERNAME=alessandroaffinito
set -x -e

export MONGO_EXT_PORT=27017
export NODE_STACK_NAME=phoenix
export MONGO_SERVICE_NAME=${NODE_STACK_NAME}_mongo_app
export DB_CONNECTION_STRING=mongodb://${MONGO_SERVICE_NAME}:${MONGO_EXT_PORT}/phoenix

# execute this script from the root folder
# cd .. 

docker service rm phoenix_app 
docker image prune

set +x
cp config/stack/node-swarm . && \
    docker build --no-cache --tag=server -f node-swarm --force-rm . && \
    rm node-swarm

echo -e "\n Connecting to docker-hub to push the new built image"
# docker login --username DOCKER_HUB_USERNAME
docker tag server ${DOCKER_HUB_USERNAME}/node-server:prd && \
    docker push ${DOCKER_HUB_USERNAME}/node-server:prd

echo "-----------------------------------------------"
echo -e "\n Deploying on the stack"
docker stack deploy -c config/stack/docker-compose-swarm.yml $NODE_STACK_NAME

echo "-----------------------------------------------"
echo -e "\n docker stack services ${NODE_STACK_NAME}"
docker stack services ${NODE_STACK_NAME}
echo "-----------------------------------------------"
echo -e "\n docker service ps ${MONGO_SERVICE_NAME}: "
docker service ps ${MONGO_SERVICE_NAME}

echo "-----------------------------------------------"
echo -e "\n First lines app logs, waiting for new service logs: "
sleep 2
docker service logs -f ${NODE_STACK_NAME}_app
# docker service logs --since `date +%s` -f ${NODE_STACK_NAME}_app




## DEV NOTES
# docker service create --name phoenix_app --replicas 1 --env DB_CONNECTION_STRING=mongodb://phoenix_mongo_app:27018/phoenix --publish 3000:3000 --replicas-max-per-node 3  --network proxy --network monitor  server

## To get specific image id 
# docker ps --no-trunc -f name=phoenix_mongo_app ...

