#!/usr/bin/env bash
##########################################################################################
#####  MetaFX extract_kmers module to count k-mers presence in samples' reads files  #####
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX extract_kmers module – to count k-mers presence in samples' reads files (to speed up multiple calculations)"
    echo "Usage: metafx extract_kmers [<Launch options>] [<Input parameters>]"
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
    echo "    -b | --bad-frequency <int>        maximal frequency for a k-mer to be assumed erroneous [default: 1]"
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


comment "Counting k-mers presence for samples"

kmersDir="$w/kmers"
cmd1=$cmd
cmd1+="-t kmer-counter-many "
if [[ ${b} ]]; then
    cmd1+="-b ${b} "
fi
if [[ ${i} ]]; then
    cmd1+="-i ${i} "
fi
cmd1+="-w ${w}/"

echo "$cmd1"
$cmd1
if [[ $? -eq 0 ]]; then
    comment "Extracted k-mers saved to ${kmersDir}"
else
    error "Error during k-mer counting!"
    exit 1
fi


comment "MetaFX extract_kmers module finished successfully!"
exit 0

