#!/bin/sh

# Remove all stopped containers.
docker ps -q |xargs docker rm 

# Remove all unused images.
docker images -q |xargs docker rmi

