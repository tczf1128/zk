#!/bin/sh

WORKDIR=`dirname $0`
WORKDIR=`cd "$WORKDIR"; pwd`

python $WORKDIR/roshancli.py $@
