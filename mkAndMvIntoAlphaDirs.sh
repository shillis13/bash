for l in {a..z}; do
    echo "mkdir $l";
    mkdir $l;
    for d in `\ls -1 $l*.txt | sed 's/[0-9][0-9][0-9].txt$//' | sort | uniq`; do
        echo "mkdir $l/$d";
        mkdir $l/$d;
        echo "mv $d*.txt $l/$d";
        mv $d*.txt $l/$d;
    done
done

