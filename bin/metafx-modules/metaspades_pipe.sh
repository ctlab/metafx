#!/usr/bin/env bash
##########################################################################################
#####   MetaFX metaspades module – unsupervised feature extraction via metaSpades   ######
##########################################################################################

help_message () {
    echo ""
    echo "$(metafx -v)"
    echo "MetaFX metaspades module – unsupervised feature extraction and distance estimation via metaSpades (https://cab.spbu.ru/software/meta-spades/)"
    echo "Usage: metafx metaspades [<Launch options>] [<Input parameters>]"
    echo ""
    echo "Launch options:"
    echo "    -h | --help                       show this help message and exit"
    echo "    -t | --threads       <int>        number of threads to use [default: all]"
    echo "    -m | --memory        <MEM>        memory to use (values with suffix: 1500M, 4G, etc.) [default: 90% of free RAM]"
    echo "    -w | --work-dir      <dirname>    working directory [default: workDir/]"
    echo ""
    echo "Input parameters:"
    echo "    -k  | --k             <int>        k-mer size (in nucleotides, maximum value is 31) [mandatory]"
    echo "    -i  | --reads         <filenames>  list of PAIRED-END reads files from single environment. FASTQ, FASTA, gzip-compressed [mandatory]"
    echo "          --separate                   if TRUE use every spades contig as a separate feature (do not combine them in components; -l, -b1, -b2 ignored) [default: False]"
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
    --separate)
    separate=true
    shift
    ;;
    -i|--reads-file)
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

comment "Running step 1: extracting contigs via metaSPAdes assembly"

cmd1="metaspades.py "
if [[ $m ]]; then
    if [[ "${m:0-1}" == "G" ]]; then
        cmd1+="-m ${m: : -1} "
    else
        cmd1+= "-m 1 "
    fi
fi
if [[ $p ]]; then
    cmd1+="-t $p "
fi

samples_spades=$(python3 ${SOFT}/parse_samples_for_spades.py ${i})
if [[ $? -ne 0 ]]; then
    error "Error during step 1!"
    exit 1
fi

mkdir ${w}

while read line ; do
    IFS=$' ' read -ra samples <<< "${line}"
    cmd1_i=$cmd1
    if [[ ${samples[0]} == "True" ]]; then
        cmd1_i+="--only-assembler "
    fi
    cmd1_i+="-o ${w}/spades_${samples[1]} "
    cmd1_i+="-1 ${samples[2]} -2 ${samples[3]} "
    comment "Processing samples: ${samples[2]} & ${samples[3]}"
    
    echo "${cmd1_i}"
    echo "Log is saved to ${w}/spades_${samples[1]}.log"
    ${cmd1_i} &> "${w}/spades_${samples[1]}.log"
    if [[ $? -eq 0 ]]; then
        comment "Assembly results saved to: ${w}/spades_${samples[1]}"
    else
        error "Error during step 1!"
        exit 1
    fi
done<<<"${samples_spades}"


if [[ $? -eq 0 ]]; then
    comment "Step 1 finished successfully!"
else
    error "Error during step 1!"
    exit 1
fi



# ==== Step 2 ====
if [[ ${separate} ]]; then
    comment "Running step 2: transforming contigs into components"
    cmd2=$cmd
    cmd2+="-t seq2comp "
    
    tmp=$(cut -d$" " -f2 <<< ${samples_spades} | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
    tmp="$w/spades_${tmp// /\/contigs.fasta ${w}\/spades_}/contigs.fasta"
    cmd2+="-i ${tmp} "
    cmd2+="-w $w/components"
    
    echo "${cmd2}"
    ${cmd2}
    if [[ $? -eq 0 ]]; then
        comment "Step 2 finished successfully!"
    else
        error "Error during step 2!"
        exit 1
    fi
else
    comment "Running step 2: building components based on contigs"
    cmd2=$cmd
    cmd2+="-t component-cutter "
    
    if [[ ${minSeqLen} ]]; then
        cmd2+="-l ${minSeqLen} "
    fi
    if [[ ${minCompSize} ]]; then
        cmd2+="-b1 ${minCompSize} "
    fi
    if [[ ${maxCompSize} ]]; then
        cmd2+="-b2 ${maxCompSize} "
    fi
    
    tmp=$(cut -d$" " -f2 <<< ${samples_spades} | tr '\n' ' ' | sed -e 's/[[:space:]]*$//')
    tmp="$w/spades_${tmp// /\/contigs.fasta ${w}\/spades_}/contigs.fasta"
    cmd2+="-i ${tmp} "
    cmd2+="-w $w/components"
    
    echo "${cmd2}"
    ${cmd2}
    if [[ $? -eq 0 ]]; then
        comment "Step 2 finished successfully!"
    else
        error "Error during step 2!"
        exit 1
    fi
fi


# ==== Step 3 ====
comment "Running step 3: calculating features as coverage of components by samples"

cmd3=$cmd
cmd3+="-t features-calculator "

cmd3+="-cm ${w}/components/components.bin "
if [[ ${kmers} ]]; then
    cmd3+="-ka ${kmers}/*.kmers.bin "
else
    cmd3+="-i ${i} "
fi
cmd3+="-w ${w}/features-calculator/"


echo "${cmd3}"
${cmd3}
if [[ $? -ne 0 ]]; then
    error "Error during step 3"
    exit 1
fi


mkdir ${w}/features_all
echo "all	$(for f in ${w}/features-calculator/vectors/*.breadth ; do x=$(basename $f); echo ${x%.breadth} ; done | tr '\n' ' ')	" > ${w}/categories_samples.tsv
ln -s ../features-calculator/vectors ${w}/features_all/vectors
python3 ${SOFT}/join_feature_vectors.py ${w}
if [[ $? -eq 0 ]]; then
    echo "Feature table saved to ${w}/feature_table.tsv"
    comment "Step 3 finished successfully!"
else
    error "Error during step 3!"
    exit 1
fi
rm -r ${w}/features_all



# ==== Step 4 ====
comment "Running step 4: calculating distance matrix using features values"

cmd4="${PIPES}/metafast.sh "
if [[ $m ]]; then
    cmd4+="-m $m "
fi
if [[ $p ]]; then
    cmd4+="-p $p "
fi
cmd4+="-t dist-matrix-calculator "

cmd4+="--features ${w}/features-calculator/vectors/*.vec "
cmd4+="-w ${w}/matrices/"


echo "${cmd4}"
${cmd4}
if [[ $? -eq 0 ]]; then
    comment "Step 4 finished successfully!"
else
    error "Error during step 4!"
    exit 1
fi


# ==== Step 5 ====
comment "Running step 5: constructing heatmap with dendrogram for distance matrix"

cmd5="${PIPES}/metafast.sh "
if [[ $m ]]; then
    cmd5+="-m $m "
fi
if [[ $p ]]; then
    cmd5+="-p $p "
fi
cmd5+="-t heatmap-maker "

cmd5+="-i ${w}/matrices/dist_matrix_*_original_order.txt "
cmd5+="-w ${w}/heatmap-maker/"


echo "${cmd5}"
${cmd5}
if [[ $? -eq 0 ]]; then
    comment "Step 5 finished successfully!"
else
    error "Error during step 5!"
    exit 1
fi


if [[ ${separate} ]]; then
    :
else
    # ==== Step 6 ====
    comment "Running step 6: transforming binary components to fasta sequences (contigs)"

    cmd6=$cmd
    cmd6+="-t comp2seq "

    cmd6+="-cf ${w}/components/components.bin "
    cmd6+="-w ${w}/contigs_all/"

        
    echo "${cmd6}"
    ${cmd6}
    if [[ $? -eq 0 ]]; then
        comment "Step 6 finished successfully!"
    else
        error "Error during step 6!"
        exit 1
    fi
fi

comment "MetaFX metaspades module finished successfully!"
exit 0