#!/usr/bin/env bash

set -u
set -o pipefail

source /shiver/pipeline.conf
if [ -f /data/pipeline.conf ]
then
    echo "Pipeline config file found, using the given one"
    source /data/pipeline.conf
else
    echo "Pipeline config does not file found, using the default one"
fi

# copy shiver config:
if [ -f /data/config.sh ]
then
    echo "Shiver config file found, using the given one"
    cp /data/config.sh /shiver/config.sh
else
    echo "Shiver config does not file found, using the default one"
fi

LOGFILE="/data/$Prefix.log"

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
    echo "    init:"
    echo "        Run shiver_init"
    echo ""
    echo "    align_contigs:"
    echo "        Run shiver_align_contigs"
    echo ""
    echo "    map_reads:"
    echo "        Run shiver_map_reads"
    echo ""
    echo "    full:"
    echo "        Run full pipeleine"
    echo ""
    echo ""
}

function de_novo_assembly {
    if [ -z ${ForwardReads+x} ]; then echo "ERROR: missing ForwardReads" | tee -a $LOGFILE; exit 2; fi
    if [ -z ${ReverseReads+x} ]; then echo "ERROR: missing ReverseReads" | tee -a $LOGFILE; exit 2; fi
    if [ -f /data/$ForwardReads ]; then echo ""; else echo "error: file not found $ForwardReads" | tee -a $LOGFILE; exit 3; fi
    if [ -f /data/$ReverseReads ]; then echo ""; else echo "error: file not found $ReverseReads" | tee -a $LOGFILE; exit 3; fi
    echo "\n========== start iva ==========\n"
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
    iva -f reads_1.fastq.gz -r reads_2.fastq.gz /data_tmp/IVAout 2>&1 | tee -a $LOGFILE
    cp /data_tmp/IVAout/contigs.fasta /data/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
    echo "\n========== iva finished ==========\n"  2>&1 | tee -a $LOGFILE
}

function shiver_init {
    if [ -z ${ShiverConfig+x} ]; then echo "ERROR: missing ShiverConfig"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then echo "ERROR: missing RefAlignment"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${Prefix+x} ]; then echo "ERROR: missing Prefix"  2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -f $ShiverConfig ]; then echo ""; else echo "error: file not found $ShiverConfig" 2>&1 | tee -a $LOGFILE; exit 3; fi
    if [ -f /data/$RefAlignment ]; then echo ""; else echo "error: file not found $RefAlignment" 2>&1 | tee -a $LOGFILE; exit 3; fi
    echo "\n========== start shiver_init.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cd /data_tmp
    mkdir ShiverInitDir 2>&1 | tee -a $LOGFILE
    cp $ShiverConfig /data_tmp/config.sh 2>&1 | tee -a $LOGFILE
    cp /data/$RefAlignment /data_tmp/RefAlignment.fasta 2>&1 | tee -a $LOGFILE
    cp /data/$Adapters /data_tmp/Adapters.fasta 2>&1 | tee -a $LOGFILE
    cp /data/$Primers /data_tmp/Primers.fasta 2>&1 | tee -a $LOGFILE
    bash /shiver/shiver_init.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/RefAlignment.fasta /data_tmp/Adapters.fasta /data_tmp/Primers.fasta 2>&1 | tee -a $LOGFILE
    echo "\n========== shiver shiver_init.sh ==========\n" 2>&1 | tee -a $LOGFILE
}

function shiver_align_contigs {
    if [ -z ${ShiverConfig+x} ]; then echo "ERROR: missing ShiverConfig" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${RefAlignment+x} ]; then echo "ERROR: missing RefAlignment" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -z ${Prefix+x} ]; then echo "ERROR: missing Prefix" 2>&1 | tee -a $LOGFILE; exit 2; fi
    if [ -f $ShiverConfig ]; then echo ""; else echo "error: file not found $ShiverConfig" 2>&1 | tee -a $LOGFILE; exit 3; fi
    if [ -f /data/$RefAlignment ]; then echo ""; else echo "error: file not found $RefAlignment" 2>&1 | tee -a $LOGFILE; exit 3; fi
    echo "\n========== start shiver_align_contigs.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cd /data_tmp
    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_DeNovoContigs.fasta" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/Contigs.fasta 2>&1 | tee -a $LOGFILE
    # run
    bash /shiver/shiver_align_contigs.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/Contigs.fasta $Prefix 2>&1 | tee -a $LOGFILE
    echo "\n========== stop shiver_align_contigs.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cp /data_tmp/${Prefix}* /data/.
}

function shiver_map_reads {
    echo "\n========== start shiver_map_reads.sh ==========\n" 2>&1 | tee -a $LOGFILE
    refseqfile="/data/${Prefix}_cut_wRefs.fasta"
    if [ -f "$refseqfile" ]; then
        echo "cut_wRefs file was generated by Shiver, using ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
    else
        echo "cut_wRefs file was not  generated by Shiver, using ${Prefix}_raw_wRefs.fasta as ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
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
    # Contigs.fasta
    if [ -f /data/${Prefix}_DeNovoContigs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_DeNovoContigs.fasta" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_DeNovoContigs.fasta /data_tmp/${Prefix}_DeNovoContigs.fasta 2>&1 | tee -a $LOGFILE
    # SID.blast
    if [ -f /data/${Prefix}.blast ]; then echo ""; else echo "error: file not found ${Prefix}.blast" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}.blast /data_tmp/${Prefix}.blast 2>&1 | tee -a $LOGFILE
    # SID.blast
    if [ -f /data/${Prefix}_cut_wRefs.fasta ]; then echo ""; else echo "error: file not found ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE; exit 3; fi
    cp /data/${Prefix}_cut_wRefs.fasta /data_tmp/${Prefix}_cut_wRefs.fasta 2>&1 | tee -a $LOGFILE

    bash /shiver/shiver_map_reads.sh /data_tmp/ShiverInitDir /data_tmp/config.sh /data_tmp/${Prefix}_DeNovoContigs.fasta $Prefix /data_tmp/${Prefix}.blast /data_tmp/${Prefix}_cut_wRefs.fasta /data_tmp/tmp/reads_1_tmp.fastq /data_tmp/tmp/reads_2_tmp.fastq 2>&1 | tee -a $LOGFILE
    echo "\n========== stop shiver_map_reads.sh ==========\n" 2>&1 | tee -a $LOGFILE
    cp /data_tmp/${Prefix}* /data/. 2>&1 | tee -a $LOGFILE
}

function run_drug_resistance {
    echo "\n========== start drug_res.py ==========\n" 2>&1 | tee -a $LOGFILE
    /usr/bin/python3 /shiver/drug_res.py "/data/${Prefix}_ref.fasta" "/data/${Prefix}_drug_resistance.xlsx" 2>&1 | tee -a $LOGFILE
    echo "\n========== stop drug_res.py ==========\n" 2>&1 | tee -a $LOGFILE

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
    touch $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "========== Shiver Docker Pipeline ==============================================" >> $LOGFILE
    echo "========== Start denovo assembly step ==========================================" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Pipeline config: pipeline.conf =====================================" >> $LOGFILE
    echo /shiver/pipeline.conf >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Shiver config: config.sh ===========================================" >> $LOGFILE
    echo /shiver/config.sh >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    de_novo_assembly
    echo "========== DONE ================================================================" >> $LOGFILE
    exit 0
    ;;
align_contigs)
    touch $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "========== Shiver Docker Pipeline ==============================================" >> $LOGFILE
    echo "========== Start align contigs step ============================================" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Pipeline config: pipeline.conf =====================================" >> $LOGFILE
    echo /shiver/pipeline.conf >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Shiver config: config.sh ===========================================" >> $LOGFILE
    echo /shiver/config.sh >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    shiver_init
    shiver_align_contigs
    echo "========== DONE ================================================================" >> $LOGFILE
    exit 0
    ;;
map_reads)
    touch $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "========== Shiver Docker Pipeline ==============================================" >> $LOGFILE
    echo "========== Start map reads step ================================================" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Pipeline config: pipeline.conf =====================================" >> $LOGFILE
    echo /shiver/pipeline.conf >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Shiver config: config.sh ===========================================" >> $LOGFILE
    echo /shiver/config.sh >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    shiver_init
    shiver_map_reads
    echo "========== DONE ================================================================" >> $LOGFILE
    exit 0
    ;;
drug_resistance)
    touch $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "========== Shiver Docker Pipeline ==============================================" >> $LOGFILE
    echo "========== Start drug resistence step ==========================================" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Pipeline config: pipeline.conf =====================================" >> $LOGFILE
    echo /shiver/pipeline.conf >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Shiver config: config.sh ===========================================" >> $LOGFILE
    echo /shiver/config.sh >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    run_drug_resistance
    exit 0
    ;;
full)
    touch $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "========== Shiver Docker Pipeline ==============================================" >> $LOGFILE
    echo "========== Start full pipeline =================================================" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Pipeline config: pipeline.conf =====================================" >> $LOGFILE
    echo /shiver/pipeline.conf >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    echo "\n\n\n" >> $LOGFILE
    echo "=========== Shiver config: config.sh ===========================================" >> $LOGFILE
    echo /shiver/config.sh >> $LOGFILE
    echo "\n" >> $LOGFILE
    echo "================================================================================" >> $LOGFILE
    de_novo_assembly
    shiver_init
    shiver_align_contigs
    refseqfile="/data/${Prefix}_cut_wRefs.fasta"
    if [ -f "$refseqfile" ]; then
        echo "cut_wRefs file was generated by Shiver, using ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
    else
        echo "cut_wRefs file was not  generated by Shiver, using ${Prefix}_raw_wRefs.fasta as ${Prefix}_cut_wRefs.fasta" 2>&1 | tee -a $LOGFILE
        cp /data/${Prefix}_raw_wRefs.fasta /data/${Prefix}_cut_wRefs.fasta 2>&1 | tee -a $LOGFILE
    fi
    shiver_map_reads
    run_drug_resistance
    echo "========== DONE ================================================================" >> $LOGFILE
    exit 0
    ;;
*)
    echo "ERROR: unknown command"
    exit 1
    ;;
esac
