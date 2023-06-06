#!/usr/bin/env bash
##########################################################################################
### MetaFX bandage module – classification model and setup for visualisation in Bandage ##
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX bandage module – Machine Learning methods to train classifier and prepare for visualisation in Bandage (https://github.com/ctlab/BandageNG)"
    echo "Usage: metafx bandage [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -f | --feature-dir   <dirname>        directory containing folders with contigs for each category, feature_table.tsv and categories_samples.tsv files. Usually, it is workDir from other MetaFX modules (unique, stats, colored, metafast, metaspades) [mandatory]"
    echo "         --model         <filename>       file with pre-trained classification model, obtained via 'fit' or 'cv' module (\"workDir/rf_model.joblib\" can be used) [optional, if set '-n', '-d', '-e' will be ignored]"
    echo "    -n | --n-estimators  <int>            number of estimators in classification model [optional]"
    echo "    -d | --max-depth     <int>            maximum depth of decision tree base estimator [optional]"
    echo "    -e | --estimator     [RF, ADA, GBDT]  classification model: RF – Random Forest, ADA – AdaBoost, GBDT – Gradient Boosted Decision Trees [optional, default: RF]"
    echo "         --draw-graph                     if TRUE performs de Bruijn graph construction by SPAdes to GFA format [default: False]"
    echo "         --gui                            if TRUE opens Bandage GUI and draw images. Does NOT work on servers with command line interface only [default: False]"
    echo "         --name          <filename>       name of output file with tree model in text format in workDir [optional, default: tree_model]"
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
    -f|--feature-dir)
    featDir="$2"
    shift
    shift
    ;;
    --model)
    modelFile="$2"
    shift
    shift
    ;;
    -n|--n-estimators)
    nEstimators="$2"
    shift
    shift
    ;;
    -d|--max-depth)
    maxDepth="$2"
    shift
    shift
    ;;
    -e|--estimator)
    estimator="$2"
    shift
    shift
    ;;
    --draw-graph)
    drawGraph=true
    shift
    ;;
    --gui)
    gui=true
    shift
    ;;
    --name)
    outputName="$2"
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

if [[ ${outputName} ]]; then
    outputName="${w}/${outputName}"
else
    outputName="${w}/tree_model"
fi



# ==== Step 1 ====


comment "Running step 1: preparing classification model"
mkdir ${w}
cmd1="python ${SOFT}/build_model_for_bandage.py --res-file ${outputName}.txt "

if [ ! -d ${featDir} ]; then
    error "Invalid directory with features provided"
    exit -1
fi

if [ ! -f ${featDir}/samples_categories.tsv ]; then
    error "samples_categories.tsv file missing in ${featDir}"
fi

if [ ! -f ${featDir}/feature_table.tsv ]; then
    error "feature_table.tsv file missing in ${featDir}"
fi

cmd1+="--source-dir ${featDir} "

if [[ ${modelFile} ]]; then
    cmd1+="--model-file ${modelFile} "
else
    if [[ ${nEstimators} ]]; then
        cmd1+="--tree-num ${nEstimators} "
    fi
    if [[ ${maxDepth} ]]; then
        cmd1+="--max-depth ${maxDepth} "
    fi
    if [[ ${estimator} ]] ; then
        case ${estimator} in
            "RF") cmd1+="--type-of-forest 0" ;;
            "GBDT") cmd1+="--type-of-forest 1" ;;
            "ADA") cmd1+="--type-of-forest 2" ;;
            *) 
            error "Unknown classification model type! Please, select from [RF, ADA, GBDT]"
            exit 1
            ;;
        esac
    fi
fi



echo "$cmd1"
$cmd1
if [[ $? -eq 0 ]]; then
    comment "Text model file for visualisation saved in ${outputName}.txt"
    comment "Step 1 finished successfully!"
else
    error "Error during step 1!"
    exit 1
fi


# ===== Step 2 =====

if [[ ${drawGraph} ]]; then
    comment "Running step 2: constructing de Brujn graph"
    cmd2="spades.py --only-assembler --sc -o ${w}/spades_graph "
    
    counter=1
    while read line ; do
        IFS=$'\t' read -ra cat_samples <<< "${line}"
        cmd2+="--s${counter} ${featDir}/contigs_${cat_samples[0]}/seq-builder-many/sequences/component.seq.fasta "
        counter=$((counter + 1))
    done<${featDir}/categories_samples.tsv
    
    echo "$cmd2"
    echo "Log is saved to ${w}/spades_graph.log"
    $cmd2 > "${w}/spades_graph.log"
    if [[ $? -eq 0 ]]; then
        comment "De Bruijn graph saved to: ${w}/spades_graph/assembly_graph_with_scaffolds.gfa"
        graph="${w}/spades_graph/assembly_graph_with_scaffolds.gfa"
    else
        error "Error during step 1!"
        exit 1
    fi
else
    comment "Skipping step 2 (de Brujn graph construction): will draw only forest model"
    graph="\"\""
fi


# ==== Step 3 ====

if [[ ${gui} ]]; then
    comment "Running step 3: Bandage GUI"

    cmd3="BandageNG load --draw --features-draw ${graph} ${outputName}.txt"
    echo "${cmd3}"
    ${cmd3}
    if [[ $? -eq 0 ]]; then
        comment "Step 3 finished successfully!"
    else
        error "Error during step 3!"
        exit 1
    fi
else
    comment "To visualise results in Bandage GUI follow instructions from https://github.com/ctlab/metafx/wiki/#metafx-bandage"
fi

comment "MetaFX bandage module finished successfully!"
exit 0
