#!/bin/bash

# https://senbox.atlassian.net/wiki/spaces/SNAP/pages/30539778/Install+SNAP+on+the+command+line
# https://senbox.atlassian.net/wiki/spaces/SNAP/pages/30539785/Update+SNAP+from+the+command+line
# http://step.esa.int/main/download/snap-download/

SNAPVER=8
# avoid NullPointer crash during S-1 processing
java_max_mem=10G

# set JAVA_HOME (done in Docker as well)
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export JPY_JDK_HOME=$JAVA_HOME
export JDK_HOME=$JPY_JDK_HOME
$JPY_JDK_HOME/bin/java -XshowSettings:properties -version

# install and update snap
echo "Download SNAP" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
echo wget -q -O ${SNAP_HOME}/../snap-src/esa-snap_all_unix_${SNAPVER}_0.sh \
  "http://step.esa.int/downloads/${SNAPVER}.0/installers/esa-snap_all_unix_${SNAPVER}_0.sh" |& tee ${SNAP_HOME}/../snap-src/.messages.txt

wget -q -O ${SNAP_HOME}/../snap-src/esa-snap_all_unix_${SNAPVER}_0.sh \
  "http://step.esa.int/downloads/${SNAPVER}.0/installers/esa-snap_all_unix_${SNAPVER}_0.sh"

echo Install SNAP in ${SNAP_HOME} |& tee ${SNAP_HOME}/../snap-src/.messages.txt
chmod 755 ${SNAP_HOME}/../snap-src/esa-snap_all_unix_${SNAPVER}_0.sh
sh ${SNAP_HOME}/../snap-src/esa-snap_all_unix_${SNAPVER}_0.sh -q -dir ${SNAP_HOME} -varfile ${SNAP_HOME}/../snap-src/response.varfile |& tee ${SNAP_HOME}/../snap-src/.messages.txt

# echo copy default snap conf: ${HOME}/.snap/* to SNAP_USER: $SNAP_USER
# cp -rf ${HOME}/.snap/* $SNAP_USER

echo SNAP_HOME is $SNAP_HOME |& tee ${SNAP_HOME}/../snap-src/.messages.txt
echo "updating snap.home ${SNAP_HOME} in  ${SNAP_HOME}/etc/snap.properties" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
sed -i "s!#snap.home=!snap.home=${SNAP_HOME}!g" ${SNAP_HOME}/etc/snap.properties  
echo cat ${SNAP_HOME}/etc/snap.properties  |& tee ${SNAP_HOME}/../snap-src/.messages.txt
cat ${SNAP_HOME}/etc/snap.properties  |& tee ${SNAP_HOME}/../snap-src/.messages.txt

echo SNAP_HOME is $SNAP_HOME |& tee ${SNAP_HOME}/../snap-src/.messages.txt
echo "updating snap.userdir ${SNAP_USER} in  ${SNAP_HOME}/etc/snap.properties" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
sed -i "s!#snap.userdir=!snap.userdir=${SNAP_USER}!g" ${SNAP_HOME}/etc/snap.properties  
echo cat ${SNAP_HOME}/etc/snap.properties  |& tee ${SNAP_HOME}/../snap-src/.messages.txt
cat ${SNAP_HOME}/etc/snap.properties  |& tee ${SNAP_HOME}/../snap-src/.messages.txt

echo "updating default_userdir in ${SNAP_HOME}/etc/snap.conf" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
sed -i "s!\${HOME}/.snap!${SNAP_USER}!g" ${SNAP_HOME}/etc/snap.conf 
echo cat ${SNAP_HOME}/etc/snap.conf |& tee ${SNAP_HOME}/../snap-src/.messages.txt
cat ${SNAP_HOME}/etc/snap.conf |& tee ${SNAP_HOME}/../snap-src/.messages.txt


# Current workaround for "commands hang after they are actually executed":  https://senbox.atlassian.net/wiki/spaces/SNAP/pages/30539785/Update+SNAP+from+the+command+line
# /usr/local/snap/bin/snap --nosplash --nogui --modules --update-all
echo "updating snap modules" |& tee ${SNAP_HOME}/../snap-src/.messages.txt |& tee ${SNAP_HOME}/../snap-src/.messages.txt
${SNAP_HOME}/bin/snap --nosplash --nogui --modules --update-all 2>&1 | while read -r line; do
    echo "$line"
    [ "$line" = "updates=0" ] && sleep 2 && pkill -TERM -f "snap/jre/bin/java"
done

echo "update concluded" |& tee ${SNAP_HOME}/../snap-src/.messages.txt

# # create snappy and python binding with snappy
# ls -la /usr/local/snap/bin/snappy-conf
# /usr/local/snap/bin/snappy-conf python3
# (cd /root/.snap/snap-python/snappy && python3 setup.py install)
# 
# # increase the JAVA VM size to avoid NullPointer exception in Snappy during S-1 processing
# (cd /root/.snap/snap-python/snappy && sed -i "s/^java_max_mem:.*/java_max_mem: $java_max_mem/" snappy.ini)
# 
# # get minor python version
# PYMINOR=$(python3 -c 'import platform; major, minor, patch = platform.python_version_tuple(); print(minor)')
# echo $PYMINOR
# (cd /usr/local/lib/python3.$PYMINOR/dist-packages/snappy/ && sed -i "s/^java_max_mem:.*/java_max_mem: $java_max_mem/" snappy.ini)
# 
# # test
# /usr/bin/python3 -c 'from snappy import ProductIO'

# cleanup installer
rm -f ${SNAP_HOME}/../snap-src/esa-snap_all_unix_${SNAPVER}_0.sh

################################################################################
# keep for debugging
# export INSTALL4J_KEEP_TEMP=yes

