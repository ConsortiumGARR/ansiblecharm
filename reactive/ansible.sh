#!/bin/bash 

set -x

source charms.reactive.sh

source "$(dirname $0)/functions.sh"

reactive_handler_main

