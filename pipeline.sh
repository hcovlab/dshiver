#!/usr/bin/env bash

set -u
set -o pipefail

source /shiver/shiver_pipeline.conf
if [ -f /data/shiver_pipeline.conf ]
then
    echo "config file found"
    source /data/shiver_pipeline.conf
fi

function usage {
    echo "SHIVER pipeline"
    echo "usage:"
    echo "    docker run -it --rm -v <data_path>:/data fazekasda/shiver:latest <command> <parameters>"
    echo ""
    echo "commands:"
    echo "    help:"
    echo "        Print this message"
    echo ""
    echo "    shell:"
    echo "        Run bash shell"
    echo ""
    echo "    de_novo_assembly:"
    echo "        Run iva"
    echo ""
    echo "    init:"
    echo "        Run shiver_init"
    echo ""
    echo "    align_contigs:"
    echo "        Run shiver_align_contigs"
    echo ""
    echo "    map_reads:"
    echo "        Run shiver_map_reads"
    echo ""
    echo ""
}

function de_novo_assembly {
    if [ -z ${ForwardReads+x} ]; then echo "ERROR: missing ForwardReads" 1>&2; exit 2; fi
    if [ -z ${ReverseReads+x} ]; then echo "ERROR: missing ReverseReads" 1>&2; exit 2; fi
    if [ -f /data/$ForwardReads ]; then echo ""; else echo "error: file not found $ForwardReads"; exit 3; fi
    if [ -f /data/$ReverseReads ]; then echo ""; else echo "error: file not found $ReverseReads"; exit 3; fi
    echo "\n========== start iva ==========\n"
    cd /data_tmp
    # reads_1.fastq
    if [[ /data/$ForwardReads == *.gz ]]
    then
        cp /data/$ForwardReads /data_tmp/reads_1.fastq.gz
    else
        cp /data/$ForwardReads /data_tmp/reads_1.fastq
        gzip /data_tmp/reads_1.fastq
    fi
    # reads_2.fastq
    if [[ /data/$ReverseReads == *.gz ]]
    then
        cp /data/$ReverseReads /data_tmp/reads_2.fastq.gz
    else
        cp /data/$ReverseReads /data_tmp/reads_2.fastq
        gzip /data_tmp/reads_2.fastq
    fi
    iva -f reads_1.fastq.gz -r reads_2.fastq.gz /data_tmp/IVAout
    cp /data_tmp/IVAout/contigs.fasta /data/${Prefix}_DeNovoContigs.fasta
    echo "\n========== iva finished ==========\n"
}

function shiver_init {
    if [ -z ${ShiverConfig+x} ]; then echo "ERROR: missing ShiverConfig" 1>&2; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then echo "ERROR: missing RefAlignment" 1>&2; exit 2; fi
    if [ -z ${Prefix+x} ]; then echo "ERROR: missing Prefix" 1>&2; exit 2; fi
    if [ -f $ShiverConfig ]; then echo ""; else echo "error: file not found $ShiverConfig"; exit 3; fi
    if [ -f /data/$RefAlignment ]; then echo ""; else echo "error: file not found $RefAlignment"; exit 3; fi
    echo "\n========== start shiver_init.sh ==========\n"
    cd /data_tmp
    mkdir ShiverInitDir
    cp $ShiverConfig /data_tmp/config.sh
    cp /data/$RefAlignment /data_tmp/RefAlignment.fasta
    cp /data/$Adapters /data_tmp/Adapters.fasta
    cp /data/$Primers /data_tmp/Primers.fasta
    bash /shiver/shiver_init.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/RefAlignment.fasta /data_tmp/Adapters.fasta /data_tmp/Primers.fasta
    echo "\n========== shiver shiver_init.sh ==========\n"
}

function shiver_align_contigs {
    if [ -z ${ShiverConfig+x} ]; then echo "ERROR: missing ShiverConfig" 1>&2; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then echo "ERROR: missing RefAlignment" 1>&2; exit 2; fi
    if [ -z ${Prefix+x} ]; then echo "ERROR: missing Prefix" 1>&2; exit 2; fi
    if [ -f $ShiverConfig ]; then echo ""; else echo "error: file not found $ShiverConfig"; exit 3; fi
    if [ -f /data/$RefAlignment ]; then echo ""; else echo "error: file not found $RefAlignment"; exit 3; fi
    echo "\n========== start shiver_align_contigs.sh ==========\n"
    cd /data_tmp
    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_DeNovoContigs.fasta"; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/Contigs.fasta
    # run
    bash /shiver/shiver_align_contigs.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/Contigs.fasta $Prefix
    echo "\n========== stop shiver_align_contigs.sh ==========\n"
    cp /data_tmp/${Prefix}* /data/.
}

function shiver_map_reads {
    echo "\n========== start shiver_map_reads.sh ==========\n"
    mkdir /data_tmp/tmp
    cd /data_tmp
    # reads_1.fastq
    if [[ /data/$ForwardReads == *.gz ]]
    then
        cp /data/$ForwardReads /data_tmp/reads_1.fastq.gz
        gunzip reads_1.fastq.gz
    else
        cp /data/$ForwardReads /data_tmp/reads_1.fastq
    fi
    awk '{if (NR%4 == 1) {print $1 "/1"} else print}' /data_tmp/reads_1.fastq > /data_tmp/reads_1.fastq_tmp
    rm /data_tmp/reads_1.fastq
    mv /data_tmp/reads_1.fastq_tmp /data_tmp/tmp/reads_1_tmp.fastq
    # reads_2.fastq
    if [[ /data/$ReverseReads == *.gz ]]
    then
        cp /data/$ReverseReads /data_tmp/reads_2.fastq.gz
        gunzip reads_2.fastq.gz
    else
        cp /data/$ReverseReads /data_tmp/reads_2.fastq
    fi
    awk '{if (NR%4 == 1) {print $1 "/2"} else print}' /data_tmp/reads_2.fastq > /data_tmp/reads_2.fastq_tmp
    rm /data_tmp/reads_2.fastq
    mv /data_tmp/reads_2.fastq_tmp /data_tmp/tmp/reads_2_tmp.fastq
    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_DeNovoContigs.fasta"; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/${Prefix}_DeNovoContigs.fasta
    # SID.blast
    if [ -f /data/${Prefix}.blast ]; then echo ""; else echo "error: file not found ${Prefix}.blast"; exit 3; fi
    cp /data/${Prefix}.blast /data_tmp/${Prefix}.blast
    # SID.blast
    if [ -f /data/${Prefix}_cut_wRefs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_cut_wRefs.fasta"; exit 3; fi
    cp /data/${Prefix}_cut_wRefs.fasta /data_tmp/${Prefix}_cut_wRefs.fasta

    bash /shiver/shiver_map_reads.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/${Prefix}_DeNovoContigs.fasta $Prefix /data_tmp/${Prefix}.blast /data_tmp/${Prefix}_cut_wRefs.fasta /data_tmp/tmp/reads_1_tmp.fastq /data_tmp/tmp/reads_2_tmp.fastq
    echo "\n========== stop shiver_map_reads.sh ==========\n"
    cp /data_tmp/${Prefix}* /data/.
}

function run_drug_resistance {
    /usr/bin/python3 /shiver/drug_res.py "/data/${Prefix}_ref.fasta" "/data/${Prefix}_drug_resistance.xlsx"
}

function usage {
    echo ""
}

POSITIONAL=()
while [[ $# -gt 0 ]]; do
	key="$1"
	case $key in
	--forward-reads)
		ForwardReads="$2"
		shift
		shift
		;;
	--reverse-reads)
		ReverseReads="$2"
		shift
		shift
		;;
	--config)
		ShiverConfig="$2"
		shift
		shift
		;;
	--ref-alignment)
		RefAlignment="$2"
		shiftNoDockerBuild
		shift
		;;
	--adapters)
		Adapters="$2"
		shift
		shift
		;;
	--primers)
		Primers="$2"
		shift
		shift
		;;
	--prefix)
		Prefix="$2"
		shift
		shift
		;;
	--denovo-contigs)
		DeNovoContigs="$2"
		shift
		shift
		;;
	--aligned-contigs)
		AlignedContigs="$2"
		shift
		shift
		;;
	--no-docker-build)
		NoDockerBuild=yes
		shift
		;;
	-h|--help)
        usage
		exit 0
		;;
    *)
    	POSITIONAL+=("$1")
    	shift
    	;;
    esac
done
set -- "${POSITIONAL[@]}"

# post process parameters
NoDockerBuild=${NoDockerBuild:-no}

case $1 in
help)
    usage
    exit 0
    ;;
shell|bash)
    /bin/bash
    exit 0
    ;;
gen_config)
    cp /shiver/shiver_pipeline.conf /data/shiver_pipeline.conf
    # TUDO: make shiver config as well
    exit 0
    ;;
de_novo_assembly)
    de_novo_assembly
    exit 0
    ;;
init)
    shiver_init
    exit 0
    ;;
align_contigs)
    shiver_init
    shiver_align_contigs
    exit 0
    ;;
skip_consensus_check)
    # TUDO: if SID_cut_wRefs.fasta exsist do NOT overwrite
    cp /data/${Prefix}_raw_wRefs.fasta /data/${Prefix}_cut_wRefs.fasta
    ;;
map_reads)
    shiver_init
    shiver_map_reads
    exit 0
    ;;
drug_resistance)
    run_drug_resistance
    exit 0
    ;;
full)
    de_novo_assembly
    shiver_init
    shiver_align_contigs
    # TUDO: if SID_cut_wRefs.fasta exsist do NOT overwrite
    cp /data/${Prefix}_raw_wRefs.fasta /data/${Prefix}_cut_wRefs.fasta
    shiver_map_reads
    run_drug_resistance
    exit 0
    ;;
*)
    echo "ERROR: unknown command"
    exit 1
    ;;
esac
