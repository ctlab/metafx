#!/usr/bin/env bash
##########################################################################################
#####    MetaFX cv module – Machine Learning to train classifier & check accuracy    #####
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX cv module – Machine Learning methods to train classification model based on extracted features and check accuracy via cross-validation"
    echo "Usage: metafx cv [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                        show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -w | --work-dir       <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -f | --feature-table  <filename>   file with feature table in tsv format: rows – features, columns – samples (\"workDir/feature_table.tsv\" can be used) [mandatory]"
    echo "    -i | --metadata-file  <filename>   tab-separated file with 2 values in each row: <sample>\t<category> (\"workDir/samples_categories.tsv\" can be used) [mandatory]"
    echo "    -n | --n-splits       <int>        number of folds in cross-validation. Must be at least 2. [optional, default: 5]"
    echo "         --name           <filename>   name of output trained model in workDir [optional, default: rf_model_cv]"
    echo "         --grid                        if TRUE, perform grid search of optimal parameters for classification model [optional, default: False]"
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
nSplits=5
nThreads=1
grid="false"
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -h|--help)
    help_message
    exit 0
    ;;
    -f|--feature-table)
    featureFile="$2"
    shift # past argument
    shift # past value
    ;;
    -i|--metadata-file)
    metadataFile="$2"
    shift
    shift
    ;;
    -n|--n-splits)
    nSplits="$2"
    shift
    shift
    ;;
    --name)
    outputName="$2"
    shift
    shift
    ;;
    --grid)
    grid="true"
    shift
    ;;
    -t|--threads)
    nThreads="$2"
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

comment "Training classification model with cross-validation"
if [[ ! -f ${featureFile} ]]; then
    error "Feature table file ${featureFile} does not exist!"
    exit 1
fi

if [[ ! -f ${metadataFile} ]]; then
    error "Metadata file ${metadataFile} does not exist!"
    exit 1
fi

mkdir -p ${w}


if [[ ${outputName} ]]; then
    outputName="${w}/${outputName}"
else
    outputName="${w}/rf_model_cv"
fi


python3 ${SOFT}/cv.py ${featureFile} ${outputName} ${metadataFile} ${nSplits} ${grid} ${nThreads}
if [[ $? -ne 0 ]]; then
    error "Classification model training failed!"
    exit 1
else
    echo "Trained model saved to ${outputName}.joblib"
fi


comment "MetaFX cv module finished successfully!"
exit 0
