#!/usr/bin/env bash
##########################################################################################
##### MetaFX feature_analysis module – analyze selected feature in multiple samples  #####
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX feature_analysis module – pipeline to build de Bruijn graphs for samples with selected feature and visualize them in BandageNG (https://github.com/ctlab/BandageNG)"
    echo "Usage: metafx feature_analysis [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -m | --memory        <MEM>        memory to use (values with suffix: 1500M, 4G, etc.) [default: 90% of free RAM]"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -k | --k             <int>        k-mer size to build de Bruij graphs (in nucleotides, maximum value is 31) [mandatory]"
    echo "    -f | --feature-dir   <dirname>    directory containing folders with contigs for each category, feature_table.tsv and categories_samples.tsv files. Usually, it is workDir from other MetaFX modules (unique, stats, colored, metafast, metaspades) [mandatory]"
    echo "    -n | --feature-name  <string>     name of the feature of interest (should be one of the values from first column of feature_table.tsv) [mandatory]"
    echo "    -r | --reads-dir     <dirname>    directory containing files with reads for samples. FASTQ, FASTA, gzip- or bzip2-compressed [mandatory]"
    echo "         --relab         <int>        minimal relative abundance of feature in sample to include sample for further analysis [optional, default: 0.1]"
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
    shift
    shift
    ;;
    -f|--feature-dir)
    featDir="$2"
    shift
    shift
    ;;
    -n|--feature-name)
    featName="$2"
    shift
    shift
    ;;
    -r|--reads-dir)
    readsDir="$2"
    shift
    shift
    ;;
    --relab)
    relab="$2"
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




if [ ! -d ${featDir} ]; then
    error "Invalid directory with features provided"
fi

if [ ! -d ${readsDir} ]; then
    error "Invalid directory with samples' reads provided"
fi

if [ ! -f ${featDir}/feature_table.tsv ]; then
    error "feature_table.tsv file missing in ${featDir}"
fi

# ==== Step 1 ====
comment "Running step 1: selecting samples containing feature '${featName}'"
cnt=`awk -v var="${featName}" '$1==var {CNT++} END{ print CNT }' ${featDir}/feature_table.tsv`
if [[ cnt -ne 1 ]]; then
    error "Cannot find feature '${featName}' in ${featDir}/feature_table.tsv"
fi

mkdir ${w}
cmd1="python ${SOFT}/select_samples_by_feature.py --work-dir ${featDir} --feature ${featName} --res-dir ${w} "
if [[ $relab ]]; then
    cmd1+="--board ${relab}"
fi

echo "$cmd1"
$cmd1
if [[ $? -eq 0 ]]; then
    echo "Total `wc -l ${w}/samples_list_feature_${featName}.txt | cut -d" " -f1` samples were selected"
    echo "List of samples containing feature '${featName}' saved to ${w}/samples_list_feature_${featName}.txt"
    echo "Nucleotide sequence for feature '${featName}' saved to ${w}/seq_feature_${featName}.fasta"
    comment "Step 1 finished successfully!"
else
    error "Error during step 1!"
    exit 1
fi


# ===== Step 2 =====

comment "Running step 2: constructing de Brujn graphs for each selected sample"


cmd2="${PIPES}/metacherchant.sh "
if [[ $k ]]; then
    cmd2+="-k $k "
fi
if [[ $m ]]; then
    cmd2+="-m $m "
fi
if [[ $p ]]; then
    cmd2+="-p $p "
fi

cmd2+="--coverage 1 --maxradius 1000 --bothdirs true --chunklength 10  --merge true "
cmd2+="--seq ${w}/seq_feature_${featName}.fasta "

mkdir ${w}/graphs

while read sample ; do
    cmd2_i=${cmd2}
    cmd2_i+="-w ${w}/wd_${sample} "
    cmd2_i+="-o ${w}/wd_${sample}/output "
    readsFiles=`find ${readsDir}/${sample}_* ${readsDir}/${sample}.* 2>/dev/null | paste -s -d " " -`
    cmd2_i+="--reads ${readsFiles}"

    echo "${cmd2_i}"
    echo -n "Processing sample ${sample} (log saved to ${w}/metacherchant.log) ...    "

    ${cmd2_i} 1>>${w}/metacherchant.log 2>&1
    if [[ $? -eq 0 ]]; then
        echo "DONE"
    else
        error "Error during step 2!"
    fi
    ln -s `realpath $w`/wd_${sample}/output/merged/graph.gfa ${w}/graphs/${sample}.gfa
done<${w}/samples_list_feature_${featName}.txt


if [[ $? -eq 0 ]]; then
    comment "All de Bruijn graphs saved to: ${w}/graphs/. To visualise them simultaneously in BandageNG follow instructions from https://github.com/ctlab/BandageNG/wiki#multigraph-mode"
    comment "Step 2 finished successfully!"
else
    error "Error during step 2!"
    exit 1
fi


comment "MetaFX feature_analysis module finished successfully!"
exit 0
