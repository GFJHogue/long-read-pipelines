#!/usr/bin/env bash

IMAGE_NAME=lr-cartographer

########################################
# Prepare environment: 

## Build the LRMA python package and copy it here:
#cd ../../packages/python/lrma
#python3 setup.py sdist
#cd -
#lrma_package=$(ls -rt ../../packages/python/lrma/dist/*.gz | tail -n1)
#cp -va ${lrma_package} .

########################################
# Build the container:
time docker build -t ${IMAGE_NAME} .

########################################
# Clean local files:

