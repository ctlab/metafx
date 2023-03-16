#!/usr/bin/env bash
##########################################################################################
### MetaFX calc_features module to count values for new samples on extracted features  ###
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX calc_features module – to count values for new samples based on previously extracted features"
    echo "Usage: metafx calc_features [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -m | --memory        <MEM>        memory to use (values with suffix: 1500M, 4G, etc.) [default: 90% of free RAM]"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -k | --k             <int>        k-mer size (in nucleotides, maximum value is 31) [mandatory]"
    echo "    -i | --reads         <filenames>  list of reads files from single environment. FASTQ, FASTA, gzip- or bzip2-compressed [mandatory]"
    echo "    -d | --feature-dir   <dirname>    directory containing folders with components.bin file for each category and categories_samples.tsv file. Usually, it is workDir from other MetaFX modules (unique, stats, colored, metafast, metaspades) [mandatory]"
    echo "    -b | --bad-frequency <int>        maximal frequency for a k-mer to be assumed erroneous [default: 1]"
    echo "         --kmers-dir     <dirname>    directory with pre-computed k-mers for samples in binary format (if given, --reads will be ignored) [optional]"
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
    -d|--feature-dir)
    featDir="$2"
    shift
    shift
    ;;
    --kmers-dir)
    kmers="$2"
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


if [ ! -d ${featDir} ]; then
    error "Invalid directory with features provided"
    exit -1
fi

if [ ! -f ${featDir}/categories_samples.tsv ]; then
    error "categories_samples.tsv file missing in ${featDir}"
fi

# ==== Step 1 ====
if [[ ${kmers} ]]; then
    kmersDir="${kmers}"
    mkdir ${w}
    comment "Skipping step 1: will use provided k-mers"
else
    kmersDir="$w/kmers/kmers"
    comment "Running step 1: counting k-mers for samples"
    cmd1=$cmd
    cmd1+="-t kmer-counter-many "
    if [[ ${b} ]]; then
        cmd1+="-b ${b} "
    fi
    if [[ ${i} ]]; then
        cmd1+="-i ${i} "
    fi
    cmd1+="-w ${w}/kmers/"

    echo "$cmd1"
    $cmd1
    if [[ $? -eq 0 ]]; then
        comment "Step 1 finished successfully!"
    else
        error "Error during step 1!"
        exit 1
    fi
fi


# ==== Step 2 ====
comment "Running step 2: calculating features as coverage of components by samples"

cmd2=$cmd
cmd2+="-t features-calculator "

while read line ; do
    IFS=$'\t' read -ra cat_samples <<< "${line}"
    echo "Processing category ${cat_samples[0]}"
    
    cmd2_i=$cmd2
    cmd2_i+="-cm ${featDir}/components_${cat_samples[0]}/components.bin "
    cmd2_i+="-ka ${kmersDir}/*.kmers.bin "
    cmd2_i+="-w ${w}/features_${cat_samples[0]}/"
    
    
    echo "${cmd2_i}"
    ${cmd2_i}
    if [[ $? -eq 0 ]]; then
        echo "Processed category ${cat_samples[0]}"
    else
        error "Error during step 2!"
        exit 1
    fi
done<${featDir}/categories_samples.tsv

python3 ${SOFT}/join_feature_vectors.py ${w} ${featDir}/categories_samples.tsv
if [[ $? -eq 0 ]]; then
    echo "Feature table saved to ${w}/feature_table.tsv"
else
    error "Error during step 2!"
    exit 1
fi

if [[ $? -eq 0 ]]; then
    comment "Step 2 finished successfully!"
else
    error "Error during step 2!"
    exit 1
fi

comment "MetaFX calc_features module finished successfully!"
exit 0

