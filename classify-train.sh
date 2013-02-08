#!/bin/sh

weka="java -cp /usr/share/java/weka.jar"

for f in `ls /tmp/fr_*`; do
    tid=`echo $f | sed -e 's!/tmp/fr_!!' | sed -e 's!_.*!!'`
    cp $f arffs/$tid.arff

    echo "TID: $tid"

    echo "String to word vector"

    $weka weka.filters.unsupervised.attribute.StringToWordVector \
        -S -R 2 -P title- -W 1000 -prune-rate -1.0 -C -N 0 -L \
        -stemmer weka.core.stemmers.LovinsStemmer -M 1 \
        -tokenizer "weka.core.tokenizers.WordTokenizer -delimiters \" \\r\\n\\t.,;:\\\'\\\"()?\!\"" \
        -i arffs/$tid.arff -o arffs/$tid-wordvec.arff

    echo "Reordering class label"

    $weka weka.filters.unsupervised.attribute.Reorder \
        -R 3-last,1-2 -i arffs/$tid-wordvec.arff -o arffs/$tid-reorder.arff

    echo "Spread subsample"

    $weka weka.filters.supervised.instance.SpreadSubsample \
        -M 1.0 -X 0.0 -S 1 -c last -i arffs/$tid-reorder.arff -o arffs/$tid-spread.arff

    echo "Random Forest"

    $weka weka.classifiers.trees.RandomForest \
        -I 20 -K 0 -t arffs/$tid-spread.arff -v -d models/$tid-rf.model.xml

    $weka weka.classifiers.trees.RandomForest \
        -I 20 -K 0 -t arffs/$tid-spread.arff -v -d models/$tid-rf.model

done
