#/bin/bash



rm -rf /tmp/thetmp2
mkdir -p /tmp/thetmp2/java6
cp -r * /tmp/thetmp2/java6

find /tmp/thetmp2/java6  -type d -name ".svn" |xargs rm -rf
curdir=`pwd`

cd /tmp/thetmp2/ && tar zcf java6.tar.gz java6
cd ${curdir}

rm -rf ./output
mkdir output

cp /tmp/thetmp2/java6.tar.gz ./output
rm -rf /tmp/thetmp2/
