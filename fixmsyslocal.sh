#!/bin/sh
# This script moves /usr/local to /local to workaround an issue with
# the MSYS 1.0.11 Technology preview. It has /usr mounted to the same
# path as /. Hence /usr/local is unaccessible.
cd /
if [ -e $1/usr ]; then
    echo "moving"
    cp -a $1/usr/* .
    rm -rf $1/usr
fi
