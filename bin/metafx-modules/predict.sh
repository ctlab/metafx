#!/usr/bin/env bash
##########################################################################################
###  MetaFX predict module – Machine Learning to classify samples by pre-trained model ###
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX predict module – Machine Learning methods to classify new samples based on pre-trained model"
    echo "Usage: metafx predict [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                        show this help message and exit"
    echo "    -w | --work-dir       <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -f | --feature-table  <filename>   file with feature table in tsv format: rows – features, columns – samples (\"workDir/feature_table.tsv\" can be used) [mandatory]"
    echo "         --model          <filename>   file with pre-trained classification model, obtained via 'fit' or 'cv' module (\"workDir/model.joblib\" can be used) [mandatory]"
    echo "    -e | --estimator      [RF, XGB, Torch] classification model: RF – scikit-learn Random Forest, XGB – XGBoost, Torch – PyTorch neural network, default: RF]"
    echo "    -i | --metadata-file  <filename>   tab-separated file with 2 values in each row: <sample>\t<category> to check accuracy of predictions [optional, default: None]"
    echo "         --name           <filename>   name of output file with samples predicted labels in workDir [optional, default: predictions]"
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
metadataFile=""
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
    --model)
    modelFile="$2"
    shift
    shift
    ;;
    -e|--estimator)
    estimator="$2"
    shift
    shift
    ;;
    -i|--metadata-file)
    metadataFile="$2"
    shift
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

comment "Predict samples' labels by pre-trained classification model"
if [[ ! -f ${featureFile} ]]; then
    error "Feature table file ${featureFile} does not exist!"
    exit 1
fi

if [[ ! -f ${modelFile} ]]; then
    error "Pre-trained model file ${modelFile} does not exist!"
    exit 1
fi

mkdir -p ${w}


if [[ ${outputName} ]]; then
    outputName="${w}/${outputName}"
else
    outputName="${w}/predictions"
fi

if [[ ${estimator} ]] ; then
    case ${estimator} in
        "RF") : ;;
        "XGB") : ;;
        "Torch") : ;;
        *) 
        error "Unknown classification model type! Please, select from [RF, XGB, Torch]"
        exit 1
        ;;
    esac
fi


python3 ${SOFT}/predict.py ${featureFile} ${outputName} ${modelFile} ${estimator} ${metadataFile}
if [[ $? -ne 0 ]]; then
    error "Labels prediction failed!"
    exit 1
else
    echo "Predicted labels saved to ${outputName}.tsv"
fi


comment "MetaFX predict module finished successfully!"
exit 0
