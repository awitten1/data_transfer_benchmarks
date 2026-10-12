#!/bin/bash

set -eux

conda install libadbc-driver-manager

cmake -B build -DCH_USE_3X_API=ON -DCMAKE_BUILD_TYPE=Release -G Ninja
cmake --build build
