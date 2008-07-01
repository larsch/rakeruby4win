#!/bin/sh
# This script moves /usr/local to /local to workaround an issue with
# the MSYS 1.0.11 Technology preview. It has /usr mounted to the same
# path as /. Hence /usr/local is unaccessible.
cd /
if [ ! -e usr/local ]; then
        echo "moving"
	/bin/mv $1/usr/local $1/local
fi
#if [ -e usr/bin/m4.exe ]; then
#    mv usr/bin/m4.exe bin/m4.exe
#fi
