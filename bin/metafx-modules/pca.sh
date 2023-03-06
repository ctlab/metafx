#!/usr/bin/env bash
##########################################################################################
#####    MetaFX pca module – visualisation of samples based on extracted feature    ######
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX pca module – PCA dimensionality reduction and visualisation of samples based on extracted features"
    echo "Usage: metafx pca [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                        show this help message and exit"
    echo "    -w | --work-dir       <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -f | --feature-table  <filename>   file with feature table in tsv format: rows – features, columns – samples (\"workDir/feature_table.tsv\" can be used) [mandatory]"
    echo "    -i | --metadata-file  <filename>   tab-separated file with 2 values in each row: <sample>\t<category> (\"workDir/samples_categories.tsv\" can be used) [optional, default: None]"
    echo "         --name           <filename>   name of output image in workDir [optional, default: pca]"
    echo "         --show                        if TRUE print samples' names on plot [optional, default: False]"
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
show="false"
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
    --name)
    outputName="$2"
    shift
    shift
    ;;
    --show)
    show="true"
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

comment "Creating PCA visualisation"
if [[ ! -f ${featureFile} ]]; then
    error "Feature table file ${featureFile} does not exist!"
    exit 1
fi

mkdir -p ${w}
if [[ ${metadataFile} ]]; then
    n_cols=$(head -n 1 ${metadataFile} | awk -F'\t' '{print NF}')
    if [[ ${n_cols} -ne 2 ]]; then
        error "Metadata file ${metadataFile} contains ${n_cols} columns. It should have two columns: <sample>\t<category>"
        exit 1
    fi
else
    metadataFile=""
fi

if [[ ${outputName} ]]; then
    outputName="${w}/${outputName}"
else
    outputName="${w}/pca"
fi


python3 ${SOFT}/pca.py ${featureFile} ${outputName} ${show} ${metadataFile}
if [[ $? -ne 0 ]]; then
    error "PCA visualisation failed!"
    exit 1
fi


comment "MetaFX pca module finished successfully!"
exit 0
