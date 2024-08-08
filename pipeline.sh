#!/usr/bin/env bash

set -u
set -o pipefail

if [ -f /data/pipeline.conf ]
then
    printf "Pipeline config file found, using the given one\n"
    source /data/pipeline.conf
else
    printf "Pipeline config file is not found, using the default one\n"
    source /shiver/pipeline.conf
fi

# copy shiver config:
if [ -z ${ShiverConfig+x} ]
then
    printf "Shiver config file is not found, using the default one\n"
    SIVERCONFIGPATH="/shiver/config.sh"
else
    printf "Shiver config file found, using the given one\n"
    SIVERCONFIGPATH="/data/$ShiverConfig"
fi

LOGFILE="/data/$Prefix.log"

# check if pipeline mode is Paired or Unpaired
if [ -z ${ReverseReads+x} ]
then 
    printf "ReverseReads argument not found in pipeline.conf, mode set to Unpaired" | tee -a $LOGFILE
    Paired=false
    if [ -z ${ForwardReads+x} ]
    then
        printf "ForwardReads argument not found in pipeline.conf. Exit run" | tee -a $LOGFILE
        exit 2
    fi
else
    printf "ReverseReads argument found in pipeline.conf, mode set to Paired" | tee -a $LOGFILE
    Paired=true
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
    echo "    gen_config:"
    echo "        generate delault config file in output directory"
    echo ""
    echo "    de_novo_assembly:"
    echo "        Run iva"
    echo ""
    echo "    align_contigs:"
    echo "        Run shiver_align_contigs"
    echo ""
    echo "    map_reads:"
    echo "        Run shiver_map_reads"
    echo ""
    echo "    drug_resistance:"
    echo "        Run drug_resistance"
    echo ""
    echo "    full:"
    echo "        Run full pipeleine"
    echo ""
    echo ""
}

function de_novo_assembly {
    # check input files
    if [ -z ${ForwardReads+x} ]; then printf "ERROR: missing ForwardReads\n" | tee -a $LOGFILE; exit 2; fi
    if [ $Paired = true ]; then 
        if [ -z ${ReverseReads+x} ]; then printf "ERROR: missing ReverseReads\n" | tee -a $LOGFILE; exit 2; fi
    fi
    if [ -f /data/$ForwardReads ]; then printf ""; else printf "error: file not found $ForwardReads\n" | tee -a $LOGFILE; exit 3; fi
    if [ $Paired = true ]; then 
        if [ -f /data/$ReverseReads ]; then printf ""; else printf "error: file not found $ReverseReads\n" | tee -a $LOGFILE; exit 3; fi
    fi
    # run de novo assembly algorithm
    if [ $Paired = true ]; then 
        printf "\n========== start IVA ==========\n" 2>&1 | tee -a $LOGFILE
        cd /data_tmp
        # reads_1.fastq
        if [[ /data/$ForwardReads == *.gz ]]
        then
            cp /data/$ForwardReads /data_tmp/reads_1.fastq.gz 2>&1 | tee -a $LOGFILE
        else
            cp /data/$ForwardReads /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
            gzip /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
        fi
        # reads_2.fastq
        if [[ /data/$ReverseReads == *.gz ]]
        then
            cp /data/$ReverseReads /data_tmp/reads_2.fastq.gz 2>&1 | tee -a $LOGFILE
        else
            cp /data/$ReverseReads /data_tmp/reads_2.fastq 2>&1 | tee -a $LOGFILE
            gzip /data_tmp/reads_2.fastq 2>&1 | tee -a $LOGFILE
        fi
        #python3 /usr/bin/spades.py --isolate -1 reads_1.fastq.gz -2 reads_2.fastq.gz -o /data_tmp/SPADESout | tee -a $LOGFILE
        #cp /data_tmp/SPADESout/contigs.fasta /data/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
        iva -vv --seed_stop_length 400 -f reads_1.fastq.gz -r reads_2.fastq.gz /data_tmp/IVAout 2>&1 | tee -a $LOGFILE
        cp /data_tmp/IVAout/contigs.fasta /data/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
        printf "\n========== IVA finished ==========\n" 2>&1 | tee -a $LOGFILE
    else
        printf "\n========== start spades ==========\n" 2>&1 | tee -a $LOGFILE
        cd /data_tmp
        # reads_1.fastq
        if [[ /data/$ForwardReads == *.gz ]]
        then
            cp /data/$ForwardReads /data_tmp/reads_1.fastq.gz 2>&1 | tee -a $LOGFILE
        else
            cp /data/$ForwardReads /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
            gzip /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
        fi
        python3 /usr/bin/spades.py --isolate -s reads_1.fastq.gz -o /data_tmp/SPADESout | tee -a $LOGFILE
        cp /data_tmp/SPADESout/contigs.fasta /data/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
        printf "\n========== spades finished ==========\n" 2>&1 | tee -a $LOGFILE
    fi
}

function shiver_init {
    if [ -z ${SIVERCONFIGPATH+x} ]; then printf "ERROR: missing $SIVERCONFIGPATH\n"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then printf "ERROR: missing RefAlignment\n"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${Prefix+x} ]; then printf "ERROR: missing Prefix\n"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -f $SIVERCONFIGPATH ]; then printf ""; else printf "error: file not found $SIVERCONFIGPATH\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    if [ -f /data/$RefAlignment ]; then printf ""; else printf "error: file not found $RefAlignment\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    printf "\n========== start shiver_init.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cd /data_tmp
    mkdir ShiverInitDir 2>&1 | tee -a $LOGFILE
    cp $SIVERCONFIGPATH /data_tmp/config.sh 2>&1 | tee -a $LOGFILE
    cp /data/$RefAlignment /data_tmp/RefAlignment.fasta 2>&1 | tee -a $LOGFILE
    cp /data/$Adapters /data_tmp/Adapters.fasta 2>&1 | tee -a $LOGFILE
    cp /data/$Primers /data_tmp/Primers.fasta 2>&1 | tee -a $LOGFILE
    bash /shiver/shiver_init.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/RefAlignment.fasta /data_tmp/Adapters.fasta /data_tmp/Primers.fasta 2>&1 | tee -a $LOGFILE
    printf "\n========== shiver shiver_init.sh ==========\n" 2>&1 | tee -a $LOGFILE
}

function shiver_align_contigs {
    if [ -z ${SIVERCONFIGPATH+x} ]; then printf "ERROR: missing $SIVERCONFIGPATH\n" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then printf "ERROR: missing RefAlignment\n" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${Prefix+x} ]; then printf "ERROR: missing Prefix\n" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -f $SIVERCONFIGPATH ]; then printf ""; else printf "error: file not found $SIVERCONFIGPATH\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    if [ -f /data/$RefAlignment ]; then printf ""; else printf "error: file not found $RefAlignment\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    printf "\n========== start shiver_align_contigs.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cd /data_tmp
    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then printf ""; else printf "error: file not found ${Prefix}_DeNovoContigs.fasta\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/Contigs.fasta 2>&1 | tee -a $LOGFILE
    # run
    bash /shiver/shiver_align_contigs.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/Contigs.fasta $Prefix 2>&1 | tee -a $LOGFILE
    printf "\n========== stop shiver_align_contigs.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cp /data_tmp/${Prefix}* /data/.
}

function shiver_map_reads {
    printf "\n========== start shiver_map_reads.sh ==========\n" 2>&1 | tee -a $LOGFILE
    refseqfile="/data/${Prefix}_cut_wRefs.fasta"
    if [ -f "$refseqfile" ]; then
        printf "cut_wRefs file was generated by Shiver, using ${Prefix}_cut_wRefs.fasta\n" 2>&1 | tee -a $LOGFILE
    else
        printf "cut_wRefs file was not  generated by Shiver, using ${Prefix}_raw_wRefs.fasta as ${Prefix}_cut_wRefs.fasta\n" 2>&1 | tee -a $LOGFILE
        cp /data/${Prefix}_raw_wRefs.fasta /data/${Prefix}_cut_wRefs.fasta 2>&1 | tee -a $LOGFILE
    fi
    mkdir /data_tmp/tmp 2>&1 | tee -a $LOGFILE
    cd /data_tmp
    # reads_1.fastq
    if [[ /data/$ForwardReads == *.gz ]]
    then
        cp /data/$ForwardReads /data_tmp/reads_1.fastq.gz 2>&1 | tee -a $LOGFILE
        gunzip reads_1.fastq.gz 2>&1 | tee -a $LOGFILE
    else
        cp /data/$ForwardReads /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
    fi
    awk '{if (NR%4 == 1) {print $1 "/1"} else print}' /data_tmp/reads_1.fastq > /data_tmp/reads_1.fastq_tmp 2>&1 | tee -a $LOGFILE
    rm /data_tmp/reads_1.fastq 2>&1 | tee -a $LOGFILE
    mv /data_tmp/reads_1.fastq_tmp /data_tmp/tmp/reads_1_tmp.fastq 2>&1 | tee -a $LOGFILE
    if [ $Paired = true ]; then
        # reads_2.fastq
        if [[ /data/$ReverseReads == *.gz ]]
        then
            cp /data/$ReverseReads /data_tmp/reads_2.fastq.gz 2>&1 | tee -a $LOGFILE
            gunzip reads_2.fastq.gz 2>&1 | tee -a $LOGFILE
        else
            cp /data/$ReverseReads /data_tmp/reads_2.fastq 2>&1 | tee -a $LOGFILE
        fi
        awk '{if (NR%4 == 1) {print $1 "/2"} else print}' /data_tmp/reads_2.fastq > /data_tmp/reads_2.fastq_tmp 2>&1 | tee -a $LOGFILE
        rm /data_tmp/reads_2.fastq 2>&1 | tee -a $LOGFILE
        mv /data_tmp/reads_2.fastq_tmp /data_tmp/tmp/reads_2_tmp.fastq 2>&1 | tee -a $LOGFILE
    fi

    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then printf ""; else printf "error: file not found ${Prefix}_DeNovoContigs.fasta\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
    # SID.blast
    if [ -f /data/${Prefix}.blast ]; then printf ""; else printf "error: file not found ${Prefix}.blast\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}.blast /data_tmp/${Prefix}.blast 2>&1 | tee -a $LOGFILE
    # SID.blast
    if [ -f /data/${Prefix}_cut_wRefs.fasta ]; then printf ""; else printf "error: file not found ${Prefix}_cut_wRefs.fasta\n" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_cut_wRefs.fasta /data_tmp/${Prefix}_cut_wRefs.fasta 2>&1 | tee -a $LOGFILE

    if [ $Paired = true ]; then
        bash /shiver/shiver_map_reads.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/${Prefix}_DeNovoContigs.fasta $Prefix /data_tmp/${Prefix}.blast /data_tmp/${Prefix}_cut_wRefs.fasta /data_tmp/tmp/reads_1_tmp.fastq /data_tmp/tmp/reads_2_tmp.fastq 2>&1 | tee -a $LOGFILE
    else
        bash /shiver/shiver_map_reads.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/${Prefix}_DeNovoContigs.fasta $Prefix /data_tmp/${Prefix}.blast /data_tmp/${Prefix}_cut_wRefs.fasta /data_tmp/tmp/reads_1_tmp.fastq 2>&1 | tee -a $LOGFILE
    fi
    printf "\n========== stop shiver_map_reads.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cp /data_tmp/${Prefix}* /data/. 2>&1 | tee -a $LOGFILE
}

function run_drug_resistance {
    printf "\n========== start drug_res.py ==========\n" 2>&1 | tee -a $LOGFILE
    python3 /shiver/tools/SplitFasta.py /data/${Prefix}_remap_consensus_MinCov_15_30.fasta /data_tmp
    cat /data_tmp/${Prefix}_remap_consensus.fasta | sed "s/\?/N/g" | sed "s/-//g" | awk "NF" > /data/${Prefix}_shiver_cons.fasta
    /usr/bin/python3 /shiver/drug_res.py /data/${Prefix}_shiver_cons.fasta /data/${Prefix}_drug_resistance.xlsx 2>&1 | tee -a $LOGFILE
    printf "\n========== stop drug_res.py ==========\n" 2>&1 | tee -a $LOGFILE
}

function init_log {
    if [ -f $LOGFILE ]
    then
        mv $LOGFILE "$LOGFILE-bak_`date "+%Y%m%d-%H%M%S"`"
    fi
    touch $LOGFILE
    printf "================================================================================\n" >> $LOGFILE
    printf "========== Shiver Docker Pipeline - $1 ===================================\n" >> $LOGFILE
    printf "================================================================================\n" >> $LOGFILE
    printf "\n\n\n" >> $LOGFILE
    printf "=========== Pipeline config: pipeline.conf =====================================\n" >> $LOGFILE
    cat /shiver/pipeline.conf >> $LOGFILE
    printf "\n" >> $LOGFILE
    printf "================================================================================\n" >> $LOGFILE
    printf "\n\n\n" >> $LOGFILE
    printf "=========== Shiver config: config.sh ===========================================\n" >> $LOGFILE
    cat $SIVERCONFIGPATH >> $LOGFILE
    printf "\n" >> $LOGFILE
    printf "================================================================================\n" >> $LOGFILE
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
		shift
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
    cp /shiver/pipeline.conf /data/pipeline.conf
    cp /shiver/config.sh /data/config.sh
    # TUDO: make shiver config as well
    exit 0
    ;;
de_novo_assembly)
    init_log "denovo assembly"
    de_novo_assembly
    printf "========== DONE ================================================================\n" >> $LOGFILE
    exit 0
    ;;
align_contigs)
    init_log "align contigs"
    shiver_init
    shiver_align_contigs
    printf "========== DONE ================================================================\n" >> $LOGFILE
    exit 0
    ;;
map_reads)
    init_log "map reads"
    shiver_init
    shiver_map_reads
    printf "========== DONE ================================================================\n" >> $LOGFILE
    exit 0
    ;;
drug_resistance)
    init_log "drug resistence prediction"
    cat /shiver/config.sh >> $LOGFILE
    printf "\n" >> $LOGFILE
    printf "================================================================================\n" >> $LOGFILE
    run_drug_resistance
    exit 0
    ;;
full)
    init_log "full pipeline"
    de_novo_assembly
    shiver_init
    shiver_align_contigs
    refseqfile="/data/${Prefix}_cut_wRefs.fasta"
    if [ -f "$refseqfile" ]; then
        printf "cut_wRefs file was generated by Shiver, using ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
    else
        printf "cut_wRefs file was not  generated by Shiver, using ${Prefix}_raw_wRefs.fasta as ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
        cp /data/${Prefix}_raw_wRefs.fasta /data/${Prefix}_cut_wRefs.fasta 2>&1 | tee -a $LOGFILE
    fi
    shiver_map_reads
    run_drug_resistance
    printf "========== DONE ================================================================\n" >> $LOGFILE
    exit 0
    ;;
*)
    printf "ERROR: unknown command\n"
    exit 1
    ;;
esac
