#!/bin/sh

weka="java -cp /usr/share/java/weka.jar"

for f in `ls models/*.model`; do
    tid=`echo $f | sed -e 's!models/!!' | sed -e 's!-.*!!'`

    echo "TID: $tid"

    $weka weka.classifiers.trees.RandomForest \
        -l $f -T arffs/$tid-spread.arff \
        -p last
done
