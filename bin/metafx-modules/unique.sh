#!/usr/bin/env bash
##########################################################################################
#####  MetaFX unique module to extract specific k-mers from groups of metagenomes   ######
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX unique module – supervised feature extraction using group-specific k-mers"
    echo "Usage: metafx unique [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -m | --memory        <MEM>        memory to use (values with suffix: 1500M, 4G, etc.) [default: 90% of free RAM]"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -k | --k             <int>        k-mer size (in nucleotides, maximum value is 31) [mandatory]"
    echo "    -i | --reads-file    <filename>   tab-separated file with 2 values in each row: <path_to_file>\t<category> [mandatory]"
    echo "    -b | --bad-frequency <int>        maximal frequency for a k-mer to be assumed erroneous [default: 1]"
    echo "         --min-samples   <int>        k-mer is considered group-specific if present in at least G samples of that group. G iterates in range [--min-samples; --max-samples] [default: 2]"
    echo "         --max-samples   <int>        k-mer is considered group-specific if present in at least G samples of that group. G iterates in range [--min-samples; --max-samples] [default: #{samples in category}/2 + 1]"
    echo "         --kmers-dir     <dirname>    directory with pre-computed k-mers for samples in binary format [optional]"
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
    -i|--reads-file)
    i="$2"
    shift
    shift
    ;;
    --kmers-dir)
    kmers="$2"
    shift
    shift
    ;;
    
    --min-samples)
    minSamples="$2"
    shift
    shift
    ;;
    --max-samples)
    maxSamples="$2"
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
        cmd1+="-i $(cut -f1 ${i} | tr '\n' ' ') "
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
comment "Running step 2: extracting group-specific k-mers"

python3 ${SOFT}/parse_samples_categories.py ${i} > ${w}/categories_samples.tsv
python3 ${SOFT}/get_samples_categories.py ${w}
tmp=$(wc -l < ${w}/categories_samples.tsv)
if [[ $tmp -lt 2 ]]; then
    echo "Found only $tmp categories in ${i} file. Provide at least 2 categories of input samples!"
    error "Error during step 2!"
    exit 1
fi

cmd2=$cmd
cmd2+="-t unique-kmers-multi "
while read line ; do
    IFS=$'\t' read -ra cat_samples <<< "${line}"
    echo "Processing category ${cat_samples[0]}"
    
    cmd2_i=$cmd2
    
    if [[ ${minSamples} ]]; then
        cmd2_i+="--min-samples ${minSamples} "
    elif [[ $(wc -w <<< "${cat_samples[1]}") -eq 1 ]]; then
        cmd2_i+="--min-samples 1 "
    else
        cmd2_i+="--min-samples 2 "
    fi
    if [[ ${maxSamples} ]]; then
        cmd2_i+="--max-samples ${maxSamples} "
    else
        cmd2_i+="--max-samples $(( $(wc -w <<< "${cat_samples[1]}") / 2 + 1)) "
    fi
    
    tmp="${kmersDir}/${cat_samples[1]// /.kmers.bin ${kmersDir}/}.kmers.bin "
    cmd2_i+="-i $tmp"
    tmp="${kmersDir}/${cat_samples[2]// /.kmers.bin ${kmersDir}/}.kmers.bin "
    cmd2_i+="--filter-kmers $tmp"
    cmd2_i+="-w ${w}/unique_kmers_${cat_samples[0]}/"

    echo "${cmd2_i}"
    ${cmd2_i}
    if [[ $? -eq 0 ]]; then
        echo "Processed category ${cat_samples[0]}"
    else
        error "Error during step 2!"
        exit 1
    fi
done<${w}/categories_samples.tsv

if [[ $? -eq 0 ]]; then
    comment "Step 2 finished successfully!"
else
    error "Error during step 2!"
    exit 1
fi


# ==== Step 3 ====
comment "Running step 3: extracting graph components around group-specific k-mers"

cmd3=$cmd
cmd3+="-t component-extractor "

while read line ; do
    IFS=$'\t' read -ra cat_samples <<< "${line}"
    echo "Processing category ${cat_samples[0]}"
    
    cmd3_i=$cmd3
    if [[ ${minSamples} ]]; then
        tmp=${minSamples}
    elif [[ $(wc -w <<< "${cat_samples[1]}") -eq 1 ]]; then
        tmp=1
    else
        tmp=2
    fi
    G=$(bash ${SOFT}/get_G.sh ${w}/unique_kmers_${cat_samples[0]}/log ${tmp})
    if [[ $? -ne 0 ]]; then
        error "Error during step 3! Cannot determine G value"
        exit 1
    fi
    echo "Using G = $G"
    tmp="${w}/unique_kmers_${cat_samples[0]}/kmers/filtered_${G}.kmers.bin "
    cmd3_i+="--pivot $tmp"
    tmp="${kmersDir}/${cat_samples[1]// /.kmers.bin ${kmersDir}/}.kmers.bin "
    cmd3_i+="-i $tmp"
    cmd3_i+="-w ${w}/components_${cat_samples[0]}/"

    
    echo "${cmd3_i}"
    ${cmd3_i}
    if [[ $? -eq 0 ]]; then
        echo "Processed category ${cat_samples[0]}"
    else
        error "Error during step 3!"
        exit 1
    fi
done<${w}/categories_samples.tsv

if [[ $? -eq 0 ]]; then
    comment "Step 3 finished successfully!"
else
    error "Error during step 3!"
    exit 1
fi



# ==== Step 4 ====
comment "Running step 4: calculating features as coverage of components by samples"

cmd4=$cmd
cmd4+="-t features-calculator "

while read line ; do
    IFS=$'\t' read -ra cat_samples <<< "${line}"
    echo "Processing category ${cat_samples[0]}"
    
    cmd4_i=$cmd4
    cmd4_i+="-cm ${w}/components_${cat_samples[0]}/components.bin "
    cmd4_i+="-ka ${kmersDir}/*.kmers.bin "
    cmd4_i+="-w ${w}/features_${cat_samples[0]}/"

    
    echo "${cmd4_i}"
    ${cmd4_i}
    if [[ $? -eq 0 ]]; then
        echo "Processed category ${cat_samples[0]}"
    else
        error "Error during step 4"
        exit 1
    fi
done<${w}/categories_samples.tsv

python3 ${SOFT}/join_feature_vectors.py ${w} ${w}/categories_samples.tsv
if [[ $? -eq 0 ]]; then
    echo "Feature table saved to ${w}/feature_table.tsv"
else
    error "Error during step 4!"
    exit 1
fi

if [[ $? -eq 0 ]]; then
    comment "Step 4 finished successfully!"
else
    error "Error during step 4!"
    exit 1
fi



# ==== Step 5 ====
comment "Running step 5: transforming binary components to fasta sequences (contigs)"

cmd5=$cmd
cmd5+="-t comp2seq "

while read line ; do
    IFS=$'\t' read -ra cat_samples <<< "${line}"
    echo "Processing category ${cat_samples[0]}"
    
    cmd5_i=$cmd5
    cmd5_i+="-cf ${w}/components_${cat_samples[0]}/components.bin "
    cmd5_i+="-w ${w}/contigs_${cat_samples[0]}/"

    
    echo "${cmd5_i}"
    ${cmd5_i}
    if [[ $? -eq 0 ]]; then
        echo "Processed category ${cat_samples[0]}"
    else
        error "Error during step 5"
        exit 1
    fi
done<${w}/categories_samples.tsv

if [[ $? -eq 0 ]]; then
    comment "Step 5 finished successfully!"
else
    error "Error during step 5!"
    exit 1
fi


comment "MetaFX unique module finished successfully!"
exit 0

