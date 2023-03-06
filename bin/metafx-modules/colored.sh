#!/usr/bin/env bash
##########################################################################################
#####  MetaFX colored module to extract features from group-colored de Bruijn graph ######
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX colored module – supervised feature extraction using group-colored de Bruijn graph"
    echo "Important! This module supports up to 3 categories of samples. If you have more, consider using other modules of MetaFX."
    echo "Usage: metafx colored [<Launch options>] [<Input parameters>]"
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
    echo "         --total-coverage             if TRUE count k-mers occurrences in colored graph as total coverage in samples, otherwise as number of samples [default: False]"
    echo "         --separate                   if TRUE use only color-specific k-mers in components (does not work in linear mode) [default: False]"
    echo "         --linear                     if TRUE extract only linear components choosing best path on each graph fork [default: False]"
    echo "         --n-comps       <int>        select not more than <int> components for each category [default: -1, means all components]"
    echo "         --perc          <float>      relative abundance of k-mer in category to be considered color-specific [default: 0.9]"
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
    --total-coverage)
    totalCoverage=true
    shift
    ;;
    --separate)
    separate=true
    shift
    ;;
    --linear)
    linear=true
    shift
    ;;
    --n-comps)
    nComps="$2"
    shift
    shift
    ;;
    --perc)
    perc="$2"
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


if [[ ${separate} && ${linear} ]]; then
    help_message
    error "Error! Both 'separate' and 'linear' flags were selected! You can choose only one."
    exit 1
fi


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
comment "Running step 2: defining k-mers colors based on occurrences in categories"

python3 ${SOFT}/parse_samples_categories.py ${i} > ${w}/categories_samples.tsv
python3 ${SOFT}/get_samples_categories.py ${w}
n_cat=$(wc -l < ${w}/categories_samples.tsv)
if [[ ${n_cat} -lt 2 ]]; then
    echo "Found only ${n_cat} categories in ${i} file. Provide at least 2 categories of input samples!"
    error "Error during step 2!"
    exit 1
fi
if [[ ${n_cat} -gt 3 ]]; then
    echo "Found ${n_cat} categories in ${i} file. This module supports up to 3 categories of samples, consider using other modules of MetaFX."
    error "Error during step 2!"
    exit 1
fi
IFS=$'\n' read -rd '' -a catNames <<< "$(python3 ${SOFT}/get_samples_labels_for_colored.py ${w})"


cmd2=$cmd
cmd2+="-t kmers-color "
tmp=$(cut -d$'\t' -f2 ${w}/categories_samples.tsv | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
tmp="${kmersDir}/${tmp// /.kmers.bin ${kmersDir}\/}.kmers.bin "
cmd2+="-kf ${tmp} "
cmd2+="--class ${w}/samples_labels.tsv "
if [[ ${b} ]]; then
    cmd2+="-b ${b} "
fi
if [[ ${totalCoverage} ]]; then
    cmd2+="--val "
fi
cmd2+="-w ${w}/kmers_color/"

echo "${cmd2}"
${cmd2}
if [[ $? -eq 0 ]]; then
    comment "Step 2 finished successfully!"
else
    error "Error during step 2!"
    exit 1
fi


# ==== Step 3 ====
comment "Running step 3: extracting graph components based on k-mers coloring"

cmd3=$cmd
cmd3+="-t component-colored "
cmd3+="-i ${w}/kmers_color/colored-kmers/colored_kmers.kmers.bin "
cmd3+="--n_groups ${n_cat} "
if [[ ${separate} ]]; then 
    cmd3+="--separate "
fi
if [[ ${linear} ]]; then 
    cmd3+="--linear "
fi
if [[ ${nComps} ]]; then 
    cmd3+="--n_comps ${nComps} "
fi
if [[ ${perc} ]]; then 
    cmd3+="--perc ${perc} "
fi
cmd3+="-w ${w}/component_colored/"

echo "${cmd3}"
${cmd3}

if [[ $? -eq 0 ]]; then
    comment "Step 3 finished successfully!"
else
    error "Error during step 3!"
    exit 1
fi

for ((i=0;i<n_cat;i++)); do
    mkdir ${w}/components_${catNames[$i]}
    ln -s ../component_colored/colored-components/components_color_${i}.bin ${w}/components_${catNames[$i]}/components.bin
done


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


comment "MetaFX colored module finished successfully!"
exit 0

