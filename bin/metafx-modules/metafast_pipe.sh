#!/usr/bin/env bash
##########################################################################################
#####     MetaFX metafast module – unsupervised feature extraction via MetaFast     ######
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX metafast module – unsupervised feature extraction and distance estimation via MetaFast (https://github.com/ctlab/metafast/)"
    echo "Usage: metafx metafast [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -m | --memory        <MEM>        memory to use (values with suffix: 1500M, 4G, etc.) [default: 90% of free RAM]"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -k  | --k             <int>        k-mer size (in nucleotides, maximum value is 31) [mandatory]"
    echo "    -i  | --reads         <filenames>  list of reads files from single environment. FASTQ, FASTA, gzip- or bzip2-compressed [mandatory]"
    echo "    -b  | --bad-frequency <int>        maximal frequency for a k-mer to be assumed erroneous [default: 1]"
    echo "    -l  | --min-seq-len   <int>        minimal sequence length to be added to a component (in nucleotides) [default: 100]"
    echo "    -b1 | --min-comp-size <int>        minimum size of extracted components (features) in k-mers [default: 1000]"
    echo "    -b2 | --max-comp-size <int>        maximum size of extracted components (features) in k-mers [default: 1000]"
    echo "          --kmers-dir     <dirname>    directory with pre-computed k-mers for samples in binary format [optional, if set '-i' can be omitted]"
    echo "";}


# Paths to pipelines and scripts
mfx_path=$(which metafx)
bin_path=${mfx_path%/*}
SOFT=${bin_path}/metafx-scripts
PIPES=${bin_path}/metafx-modules
pwd=`dirname "$0"`

comment () { ${SOFT}/pretty_print.py "$1" "-"; }
warning () { ${SOFT}/pretty_print.py "$1" "*"; }
error   () { ${SOFT}/pretty_print.py "$1" "*"; exit 1; }



print_args () {
    touch $1
    if [[ $k ]]; then
        echo "k = $k" >> $1
    fi
    if [[ $i ]]; then 
        for f in $i ; do
            echo "reads = $(realpath $f)" >> $1
        done
    else
        echo "reads = plug.fa" >> $1
    fi
    if [[ $b ]]; then
        echo "maximal-bad-frequence = $b" >> $1
    fi
    echo "output-dir = $(realpath $w)/kmer-counter-many/kmers" >> $1
    echo "stats-dir = $(realpath $w)/kmer-counter-many/stats" >> $1
    if [[ $minSeqLen ]]; then
        echo "min-seq-len = $minSeqLen" >> $1
    fi
    if [[ $minCompSize ]]; then
        echo "min-component-size = $minCompSize" >> $1
    fi
    if [[ $maxCompSize ]]; then
        echo "max-component-size = $maxCompSize" >> $1
    fi
}


w="workDir"
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    help_message
    exit 0
    ;;
    -k|--k)
    k="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--bad-frequency)
    b="$2"
    shift
    shift
    ;;
    -i|--reads)
    shift
    i=""
    while [[ $1 ]] && [ ${1:0:1} != "-" ] 
    do
        i+="$1 "
        shift
    done
    ;;
    --kmers-dir)
    kmers="$2"
    shift
    shift
    ;;
    -l|--min-seq-len)
    minSeqLen="$2"
    shift
    shift
    ;;
    -b1|--min-comp-size)
    minCompSize="$2"
    shift
    shift
    ;;
    -b2|--max-comp-size)
    maxCompSize="$2"
    shift
    shift
    ;;
    -m|--memory)
    m="$2"
    shift
    shift
    ;;
    -t|--threads)
    p="$2"
    shift
    shift
    ;;
    -w|--work-dir)
    w="$2"
    shift
    shift
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


cmd="${PIPES}/metafast.sh "
if [[ $k ]]; then
    cmd+="-k $k "
fi
if [[ $m ]]; then
    cmd+="-m $m "
fi
if [[ $p ]]; then
    cmd+="-p $p "
fi



# ==== Step 1 ====

comment "Running step 1: extracting components & creating distance matrix"

cmd1=$cmd
cmd1+="-t matrix-builder "
if [[ ${b} ]]; then
    cmd1+="-b ${b} "
fi
if [[ ${minSeqLen} ]]; then
    cmd1+="-l ${minSeqLen} "
fi
if [[ ${minCompSize} ]]; then
    cmd1+="-b1 ${minCompSize} "
fi
if [[ ${maxCompSize} ]]; then
    cmd1+="-b2 ${maxCompSize} "
fi
cmd1+="-w ${w}"

if [[ ${kmers} ]]; then
    kmersDir="${kmers}"
    mkdir ${w}
    mkdir ${w}/kmer-counter-many
    ln -s -t ${w}/kmer-counter-many ${kmersDir}
    touch ${w}/kmer-counter-many/SUCCESS
    print_args ${w}/in.properties
    print_args ${w}/kmer-counter-many/in.properties
    touch ${w}/kmer-counter-many/out.properties
    for f in $(ls -1 ${w}/kmer-counter-many/kmers/*.kmers.bin) ; do
        echo "resulting-kmers-files = $(realpath $f)" >> ${w}/kmer-counter-many/out.properties
    done
    comment "Skipping kmer-counter: will use provided k-mers"
    cmd1+=" -c"
else
    if [[ ${i} ]]; then
        cmd1+=" -i ${i} "
    fi
fi

echo "$cmd1"
$cmd1
if [[ $? -eq 0 ]]; then
    comment "Step 1 finished successfully!"
else
    error "Error during step 1!"
    exit 1
fi


# ==== Step 2 ====
comment "Running step 2: creating feature table"

mkdir ${w}/components_all
ln -s -t ${w}/components_all/ ../component-cutter/components.bin

mkdir ${w}/features_all
echo "all	$(for f in ${w}/features-calculator/vectors/*.breadth ; do x=$(basename $f); echo ${x%.breadth} ; done | tr '\n' ' ')	" > ${w}/categories_samples.tsv
python3 ${SOFT}/get_samples_categories.py ${w}
ln -s ../features-calculator/vectors ${w}/features_all/vectors
python3 ${SOFT}/join_feature_vectors.py ${w} ${w}/categories_samples.tsv
if [[ $? -eq 0 ]]; then
    echo "Feature table saved to ${w}/feature_table.tsv"
    comment "Step 2 finished successfully!"
else
    error "Error during step 2!"
    exit 1
fi
rm -r ${w}/features_all


# ==== Step 3 ====
comment "Running step 3: transforming binary components to fasta sequences (contigs)"

cmd3=$cmd
cmd3+="-t comp2seq "

cmd3+="-cf ${w}/components_all/components.bin "
cmd3+="-w ${w}/contigs_all/"

    
echo "${cmd3}"
${cmd3}
if [[ $? -eq 0 ]]; then
    comment "Step 3 finished successfully!"
else
    error "Error during step 3!"
    exit 1
fi


comment "MetaFX metafast module finished successfully!"
exit 0
