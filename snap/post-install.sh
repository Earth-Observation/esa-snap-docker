#!/bin/bash


SNAPVER=8
# avoid NullPointer crash during S-1 processing
java_max_mem=10G

# set JAVA_HOME (done in Docker as well)
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export JPY_JDK_HOME=$JAVA_HOME
export JDK_HOME=$JPY_JDK_HOME
$JPY_JDK_HOME/bin/java -XshowSettings:properties -version

# install module 'jpy' (A bi-directional Python-Java bridge)
echo 'install module jpy (A bi-directional Python-Java bridge)'
git clone https://github.com/bcdev/jpy.git ${SNAP_HOME}/../snap-src/jpy
pip install --upgrade pip wheel
(cd ${SNAP_HOME}/../snap-src/jpy && python setup.py maven bdist_wheel)

# hack because ./snappy-conf will create this dir but also needs *.whl files...
echo "copy jpy to snappy ${SNAP_USER}"
mkdir -p ${SNAP_USER}/snap-python/snappy
cp ${SNAP_HOME}/../snap-src/jpy/dist/*.whl ${SNAP_USER}/snap-python/snappy


# Current workaround for "commands hang after they are actually executed":  https://senbox.atlassian.net/wiki/spaces/SNAP/pages/30539785/Update+SNAP+from+the+command+line
# /usr/local/snap/bin/snap --nosplash --nogui --modules --update-all
echo "updating snap modules" |& tee ${SNAP_HOME}/../snap-src/.messages.txt |& tee ${SNAP_HOME}/../snap-src/.messages.txt
${SNAP_HOME}/bin/snap --nosplash --nogui --modules --update-all 2>&1 | while read -r line; do
    echo "$line"
    [ "$line" = "updates=0" ] && sleep 2 && pkill -TERM -f "snap/jre/bin/java"
done
echo "update concluded" |& tee ${SNAP_HOME}/../snap-src/.messages.txt



echo "Give read/write permissions for snap home folder"  |& tee ${SNAP_HOME}/../snap-src/.messages.txt
chmod -R 2755 $SNAP_HOME |& tee ${SNAP_HOME}/../snap-src/.messages.txt


# check if $SNAP_HOME/snap-python/snappy directory exists, if not create it
if [ -d "${SNAP_USER}/snap-python/snappy" ]
then
	echo "${SNAP_USER}/snap-python/snappy directory exists"  |& tee ${SNAP_HOME}/../snap-src/.messages.txt
	ls -l ${SNAP_USER}/snap-python/snappy |& tee ${SNAP_HOME}/../snap-src/.messages.txt
else
	echo "creating ${SNAP_USER}/snap-python/snappy directory"  |& tee ${SNAP_HOME}/../snap-src/.messages.txt
	mkdir -p ${SNAP_USER}/snap-python/snappy |& tee ${SNAP_HOME}/../snap-src/.messages.txt
fi

echo "running snappy-conf: ${SNAP_HOME}/bin/snappy-conf ${CONDA_DIR}/bin/python ${SNAP_USER}/snap-python" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
# ${SNAP_USER}/snap-python
${SNAP_HOME}/bin/snappy-conf ${CONDA_DIR}/bin/python ${SNAP_USER}/snap-python | while read -r line; do
    echo "$line"
    [ "$line" = "or copy the 'snappy' module into your Python's 'site-packages' directory." ] && sleep 2 && pkill -TERM -f "nbexec"
done


# echo list files in ${SNAP_USER}/snap-python/snappy |& tee ${SNAP_HOME}/../snap-src/.messages.txt
ls -l ${SNAP_USER}/snap-python/snappy |& tee ${SNAP_HOME}/../snap-src/.messages.txt
# cat snappyutil.log
if [ -f "${SNAP_USER}/snap-python/snappy/snappyutil.log" ]
then
	cat snappyutil.log
	cat ${SNAP_USER}/snap-python/snappy/snappyutil.log |& tee ${SNAP_HOME}/../snap-src/.messages.txt
fi

# create snappy and python binding with snappy
# ${SNAP_HOME}/bin/snappy-conf /usr/bin/python3

echo "setting python_version variable" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
python_version=$( ${CONDA_DIR}/bin/python -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))' )
echo "python_version is $python_version " |& tee ${SNAP_HOME}/../snap-src/.messages.txt


echo " link snappy folder to site-packages to make it importable: ln -fs ${SNAP_USER}/snap-python/snappy ${CONDA_DIR}/lib/python${python_version}/esasnappy"
ln -fs ${SNAP_USER}/snap-python/snappy ${CONDA_DIR}/lib/python${python_version}/esasnappy |& tee ${SNAP_HOME}/../snap-src/.messages.txt

echo "Setting execution permissions to gdal.jar" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
chmod +x ${SNAP_USER}/auxdata/gdal/gdal-3-0-0/java/gdal.jar |& tee ${SNAP_HOME}/../snap-src/.messages.txt

## Jdk from package requirements
#echo "Setting the default version of java to 1.7" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
#JAVA_PATH=/opt/anaconda/pkgs/java-1.7.0-openjdk-cos6-x86_64-1.7.0.131-h06d78d4_0/x86_64-conda_cos6-linux-gnu/sysroot/usr/lib/jvm/java-1.7.0-openjdk-1.7.0.131.x86_64/jre/bin/java
#echo "Java binary: $JAVA_PATH" |& tee ${SNAP_HOME}/../snap-src/.messages.txt
## update java alternatives
#alternatives --install /usr/bin/java java $JAVA_PATH 1 |& tee ${SNAP_HOME}/../snap-src/.messages.txt
## choose the java version you just installed 
#alternatives --set java $JAVA_PATH |& tee ${SNAP_HOME}/../snap-src/.messages.txt

