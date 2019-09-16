#!/bin/bash

set -o errexit

printf "\n[-] Installing app NPM dependencies...\n\n"

cd $APP_SOURCE_FOLDER

meteor npm install
meteor npm install --save @babel/runtime@latest
meteor npm install --save meteor-node-stubs
