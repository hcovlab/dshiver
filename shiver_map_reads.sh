#!/usr/bin/env bash

UsageInstructions=$(echo '
Arguments for this script:
(1) the initialisation directory you created using the shiver_init.bash command;
(2) the configuration file, containing all your parameter choices etc.;
(3) a fasta file of contigs (output from processing the short reads with an
assembly program);
(4) A sample ID ("SID") used for naming the output from this script (a sensible
choice might be the contig file name minus its path and extension);
(5) the blast file created by the shiver_align_contigs.bash command;
(6) either the alignment of contigs to refs produced by the
shiver_align_contigs.bash command, or a fasta file containing a single reference
to be used for mapping;
(7) the forward reads;
(8) the reverse reads.
')

set -u

################################################################################
# PRELIMINARIES

# Check for the right number of arguments. Assign them to variables.
NumArgsExpected=8
if [ "$#" -ne "$NumArgsExpected" ]; then
  echo $UsageInstructions
  echo "$#" 'arguments specified;' "$NumArgsExpected" 'expected. Quitting' >&2
  exit 1
fi
InitDir="$1"
ConfigFile="$2"
RawContigsFile="$3"
SID="$4"
ContigBlastFile="$5"
FastaFile="$6"
reads1="$7"
reads2="$8"

# Check InitDir exists. Remove a trailing slash, if present.
if [ ! -d "$InitDir" ]; then
  echo "$InitDir does not exist. Quitting." >&2
  exit 1
fi
InitDir=$(cd "$InitDir"; pwd)

RefList="$InitDir"/'ExistingRefNamesSorted.txt'
ExistingRefAlignment="$InitDir"/'ExistingRefAlignment.fasta'
adapters="$InitDir"/'adapters.fasta'
primers="$InitDir"/'primers.fasta'

# Source required code & check files exist
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$ThisDir"/'shiver_funcs.bash'
CheckFilesExist "$ConfigFile" "$reads1" "$reads2" "$RawContigsFile" \
"$ContigBlastFile" "$FastaFile" "$RefList" "$ExistingRefAlignment" "$adapters" \
"$primers"
source "$ConfigFile"

# Some files we'll create
TheRef="$SID$OutputRefSuffix"
consensus="$SID"'_consensus_MinCov_'"$MinCov1"'_'"$MinCov2.fasta"
ConsensusForGlobalAln="$SID"'_consensus_MinCov_'"$MinCov1"'_'"$MinCov2$GlobalAlnSuffix"
consensusWcontigs="$SID"'_consensus_MinCov_'"$MinCov1"'_'"$MinCov2"'_wContigs.fasta'
MappedContaminantReads="$SID$MappedContaminantReadsSuffix"
cleaned1reads="$SID$CleanedReads1Suffix"
cleaned2reads="$SID$CleanedReads2Suffix"
CoordsDict="$SID$CoordsDictSuffix"
BaseFreqs="$SID$BaseFreqsSuffix"
InsertSizeCounts="$SID$InsertSizeCountsSuffix"
################################################################################

################################################################################
# CONSTRUCT A REFERENCE, OR USE THE ONE SUPPLIED

# FastaFile should be either a single seq, which we map to as is, or else an 
# alignment of contigs to real refs.
RefIsInAlignment=true
NumSeqsInFastaFile=$(grep -e '^>' "$FastaFile" | wc -l)
if [ "$NumSeqsInFastaFile" -eq 0 ]; then
  echo 'Error: there are no sequences in' "$FastaFile". 'Quitting.' >&2
  exit 1

elif [ "$NumSeqsInFastaFile" -eq 1 ]; then

  # Try to find the sequence in FastaFile in ExistingRefAlignment.
  RefName=$(awk '/^>/ {print substr($1,2)}' "$FastaFile")
  "$Code_FindSeqsInFasta" "$ExistingRefAlignment" -g "$RefName" > \
  "$RefFromAlignment" || \
  { echo "Could not find seq $RefName in $ExistingRefAlignment; that's OK," \
  'but after mapping we will not be able to produce a version of the' \
  'consensus seq with gaps suitable for a global alignment. Continuing.' ; \
  RefIsInAlignment=false ; }

  # Compare the sequence in FastaFile to the one in ExistingRefAlignment.
  if $RefIsInAlignment; then
    "$Code_CheckFastaFileEquality" "$RefFromAlignment" "$FastaFile"
    ComparisonExitStatus=$?
    if [ $ComparisonExitStatus -eq 111 ]; then
      echo 'Seq' "$RefName" 'differs between' "$FastaFile" 'and' \
      "$ExistingRefAlignment; that's OK," \
      'but after mapping we will not be able to produce a version of the' \
      'consensus seq with gaps suitable for a global alignment. Continuing.' ;
      RefIsInAlignment=false
    elif [ $ComparisonExitStatus -ne 0 ]; then
      echo 'Problem running' "$Code_CheckFastaFileEquality"'. Quitting.' >&2
      exit 1
    fi 
  fi

  # Set the flag appropriate for use of a real ref, when it comes to
  # coordinate translation for a global alignment.
  GlobalAlignExcisionFlag='-d'

  cp "$FastaFile" "$TheRef"
  cp "$ExistingRefAlignment" "$TempRefAlignment"

  # Extract those contigs that have a blast hit.
  HIVcontigNames=$(awk -F, '{print $1}' "$ContigBlastFile" | sort | uniq)
  NumHIVContigs=$(echo $HIVcontigNames | wc -w)
  if [[ $NumHIVContigs -gt 0 ]]; then
    "$Code_FindSeqsInFasta" "$RawContigsFile" $HIVcontigNames > \
    "$RawContigFile2" || \
    { echo 'Problem extracting the HIV contigs. Quitting.' >&2 ; exit 1 ; }
  fi

else

  ContigToRefAlignment="$FastaFile"

  #HIVcontigNames=$(awk '/^>/ {print substr($1,2)}' "$ContigToRefAlignment" | \
  #awk '/'"$SID"'/ {print}')
  #HIVcontigNames=$(awk '/^>/' "$ContigToRefAlignment" | \
  #awk '/'"$SID"'/ {printf substr($1,2) " "}')
  #HIVcontigNames=$(awk '/^>CPZ.US.85.US_Marilyn.AF103818$/ {FoundLastRef=1; next} FoundLastRef && /^>/ {printf substr($0,2) " "}' "$ContigToRefAlignment")
  #HIVcontigNames=$(awk -F, '{print $1}' "$ContigBlastFile" | sort | uniq)

  # ContigToRefAlignment should contain the same set of sequences in the input
  # existing reference alignment, plus the contigs.
  awk '/^>/ {print substr($1,2)}' "$ContigToRefAlignment" | sort \
  | sed $'s/\r//g' > "$AllSeqsInAln"
  MissingRefs=$(comm -1 -3 "$AllSeqsInAln" "$RefList")
  NumMissingRefs=$(echo $MissingRefs | wc -w)
  if [ $NumMissingRefs -gt 0 ]; then
    echo "Error: the following references from $ExistingRefAlignment are"\
    "missing from $ContigToRefAlignment: $MissingRefs. Quitting." >&2
    exit 1
  fi
  HIVcontigNames=$(comm -2 -3 "$AllSeqsInAln" "$RefList")
  NumHIVContigs=$(echo $HIVcontigNames | wc -w)
  if [ $NumHIVContigs -eq 0 ]; then
    echo "Error: no contigs found in $ContigToRefAlignment. Quitting" >&2
    exit 1
  fi

  # Extract just the existing references (i.e. everything but the contigs) from
  # ContigToRefAlignment, and check that they are the same as in
  # ExistingRefAlignment. Also extract just the contigs, stripping gaps, ready
  # for later.
  "$Code_FindSeqsInFasta" "$ContigToRefAlignment" $HIVcontigNames -v > \
  "$TempRefAlignment" &&
  "$Code_FindSeqsInFasta" "$ContigToRefAlignment" $HIVcontigNames -g > \
  "$RawContigFile2" || { echo 'Problem separating the contigs and existing'\
  "refs in $ContigToRefAlignment. Quitting." >&2 ; exit 1 ; }
  "$Code_RemoveBlankCols" "$TempRefAlignment" > "$AlignmentForTesting" || \
  { echo "Problem removing pure-gap columns from $TempRefAlignment (which was"\
  "created by removing the contigs from $ContigToRefAlignment - that's"\
  "probably the problematic file). Quitting." >&2 ; exit 1; }
  "$Code_CheckFastaFileEquality" "$AlignmentForTesting" "$ExistingRefAlignment"
  ComparisonExitStatus=$?
  if [ $ComparisonExitStatus -eq 111 ]; then
    echo "The reference sequences in $ContigToRefAlignment are different from"\
    "those in $ExistingRefAlignment. When modifying $ContigToRefAlignment you"\
    "should only have modified the contigs. Quitting." >&2  
    exit 1
  elif [ $ComparisonExitStatus -ne 0 ]; then
    echo 'Problem running' "$Code_CheckFastaFileEquality"'. Quitting.' >&2
    exit 1
  fi

  # Construct the tailored ref
  "$Code_ConstructRef" "$ContigToRefAlignment" $HIVcontigNames \
  > "$GappyRefWithExtraSeq" || \
  { echo 'Failed to construct a ref from the alignment. Quitting.' >&2 ; \
  exit 1 ; }

  # Extract just the constructed ref (the first sequence)
  awk '/^>/{if(N)exit;++N;} {print;}' "$GappyRefWithExtraSeq" > "$RefWithGaps"

  # Remove any gaps from the reference
  "$Code_UngapFasta" "$RefWithGaps" > "$TheRef" || \
  { echo 'Gap stripping code failed. Quitting.' >&2 ; exit 1 ; }

  RefName=$(awk '/^>/ {print substr($1,2)}' "$TheRef")

  # Set the flag appropriate for use of a constructed ref, when it comes to
  # coordinate translation for a global alignment.
  GlobalAlignExcisionFlag='-e'

  # Create a version of the alignment of contigs to real refs, with the contigs 
  # replaced by the constructed ref, ready for coordinate translation later.
  cat "$RefWithGaps" >> "$TempRefAlignment"

fi

# Index the ref
"$smalt" index $smaltIndexOptions "$smaltIndex" "$TheRef" || \
{ echo 'Problem indexing the refererence with smalt. Quitting.' >&2 ; exit 1 ; }
# TODO: check that the following line should be here.
"$samtools" faidx "$TheRef" || \
{ echo 'Problem indexing the refererence with samtools. Quitting.' >&2 ; 
exit 1 ; }


################################################################################

################################################################################
# TRIM & CLEAN READS

# Copy the reads to the working directory. Unzip them if they end in .gz.
cp "$reads1" "$reads2" .
reads1=$(basename "$reads1")
reads2=$(basename "$reads2")
if [[ "$reads1" == *.gz ]]; then
  gunzip -f "$reads1"
  reads1="${reads1%.gz}"
fi
if [[ "$reads2" == *.gz ]]; then
  gunzip -f "$reads2"
  reads2="${reads2%.gz}"
fi

# Check all 1 read seq ids end in /1, and 2 reads in /2. Check there are
# no tabs in the seq id lines.
CheckReadNames "$reads1" 1
CheckReadNames "$reads2" 2

HaveModifiedReads=false

# Read trimming:
if [[ "$TrimReads" == "true" ]]; then 

  # Trim adapters and low-quality bases
  echo 'Now trimming reads - typically a slow step.'
  java -jar "$trimmomatic" PE -quiet -threads $NumThreadsTrimmomatic \
  "$reads1" "$reads2" "$reads1trim1" "$reads1trimmings" "$reads2trim1" \
  "$reads2trimmings" ILLUMINACLIP:"$adapters":"$IlluminaClipParams" \
  $BaseQualityParams || \
  java -jar "$trimmomatic" PE -threads $NumThreadsTrimmomatic \
  "$reads1" "$reads2" "$reads1trim1" "$reads1trimmings" "$reads2trim1" \
  "$reads2trimmings" ILLUMINACLIP:"$adapters":"$IlluminaClipParams" \
  $BaseQualityParams || { echo 'Problem running trimmomatic. Quitting.' >&2 ; \
  exit 1 ; }

  # Trim primers
  $FastaqSequenceTrim --revcomp "$reads1trim1" "$reads2trim1" "$reads1trim2" \
  "$reads2trim2" "$primers" || \
  { echo 'Problem running fastaq. Quitting.' >&2 ; exit 1 ; }

  HaveModifiedReads=true
  reads1="$reads1trim2"
  reads2="$reads2trim2"
fi

# Read trimming:
if [[ "$CleanReads" != "true" ]]; then

  # If we have trimmed the reads, change the trimmed file name into the cleaned
  # one: we'll be saving them at the end, so the filess shouldn't begin 'temp'.
  # If we haven't trimmed, then just make the cleaned reads variables point to
  # the unprocessed reads: we're not doing anything to the read files provided
  # as input so the copy in the local dir can remain called 'temp'.
  if $HaveModifiedReads; then
    mv "$reads1" "$cleaned1reads"
    mv "$reads2" "$cleaned2reads"
  else
    cleaned1reads="$reads1"
    cleaned2reads="$reads2"
  fi
else

  # List all the contigs and the HIV ones.
  # TODO: later on we assume the blast file first field has no whitespace in it.
  awk '/^>/ {print substr($1,2)}' "$RawContigsFile" | sort > "$AllContigsList"
  awk -F, '{print $1}' "$ContigBlastFile" | sort | uniq > "$HIVContigsList"

  # Check there are some contigs
  NumContigs=$(wc -l "$AllContigsList" | awk '{print $1}')
  if [ "$NumContigs" -eq 0 ]; then
    echo 'Error: there are no contigs in' "$RawContigsFile"
    echo 'Quitting.' >&2
    exit 1
  fi

  # Check that there aren't any contigs appearing in the blast file & missing from
  # the file of contigs.
  NumUnknownContigsInBlastHits=$(comm -1 -3 "$AllContigsList" "$HIVContigsList" \
  | wc -l | awk '{print $1}')
  if [ "$NumUnknownContigsInBlastHits" -ne 0 ]; then
    echo 'Error: the following contigs are named in' "$ContigBlastFile"\
    'but are not in' "$RawContigsFile"':'
    comm -1 -3 "$AllContigsList" "$HIVContigsList"
    echo 'Quitting.' >&2
    exit 1
  fi

  # Find the contaminant contigs.
  ContaminantContigNames=$(comm -3 "$AllContigsList" "$HIVContigsList")
  NumContaminantContigs=$(echo $ContaminantContigNames | wc -w)

  # If there are no contaminant contigs, we don't need to clean.
  # We create a blank mapping file to more easily keep track of the fact that 
  # there are no contaminant reads in this case.
  if [ "$NumContaminantContigs" -eq 0 ]; then
    echo 'There are no contaminant contigs: read cleaning unnecessary.'
    echo -n > "$MappedContaminantReads"
    if $HaveModifiedReads; then
      mv "$reads1" "$cleaned1reads"
      mv "$reads2" "$cleaned2reads"
    else
      cleaned1reads="$reads1"
      cleaned2reads="$reads2"
    fi

  # We enter this scope if there are some contaminant contigs:
  else

    # Make a blast database out of the contaminant contigs and the ref.
    "$Code_FindSeqsInFasta" "$RawContigsFile" $ContaminantContigNames > \
    "$RefAndContaminantContigs"
    cat "$TheRef" >> "$RefAndContaminantContigs"
    "$BlastDBcommand" -dbtype nucl -in "$RefAndContaminantContigs" \
    -input_type fasta -out "$BlastDB" || \
    { echo 'Problem creating a blast database. Quitting.' >&2 ; exit 1 ; }

    # Convert fastq to fasta.
    sed -n '1~4s/^@/>/p;2~4p' "$reads1" > "$reads1asFasta" &&
    sed -n '1~4s/^@/>/p;2~4p' "$reads2" > "$reads2asFasta" || \
    { echo 'Problem converting the reads from fastq to fasta. Quitting.' >&2 ; \
    exit 1 ; }

    # Blast the reads.
    echo 'Now blasting the reads - typically a slow step.'
    blastn -query "$reads1asFasta" -db "$BlastDB" -out "$reads1blast1" \
    -max_target_seqs 1 -outfmt \
    '10 qacc sacc sseqid evalue pident qstart qend sstart send' &&
    blastn -query "$reads2asFasta" -db "$BlastDB" -out "$reads2blast1" \
    -max_target_seqs 1 -outfmt \
    '10 qacc sacc sseqid evalue pident qstart qend sstart send' || \
    { echo 'Problem blasting' "$ContigFile"'. Quitting.' >&2 ; exit 1 ; }

    # For multiple blast hits, keep the one with the highest evalue
    # TODO: test what blast does with fasta headers that have comments in them -
    # does it include them too?
    sort -t, -k1,1 -k4,4g "$reads1blast1" | sort -t, -k1,1 -u --merge > \
    "$reads1blast2"
    sort -t, -k1,1 -k4,4g "$reads2blast1" | sort -t, -k1,1 -u --merge > \
    "$reads2blast2"

    # Find the read pairs that blast best to something other than the reference.
    "$Code_FindContaminantReadPairs" "$reads1blast2" "$reads2blast2" \
    "$RefName" "$BadReadsBaseName" && ls "$BadReadsBaseName"_1.txt \
    "$BadReadsBaseName"_2.txt > /dev/null 2>&1 || \
    { echo 'Problem finding contaminant read pairs using' \
    "$Code_FindContaminantReadPairs. Quitting." >&2 ; exit 1 ; }

    # If none of the read pairs blast better to contaminant contigs than the
    # reference, we just duplicate the original short read files.
    NumContaminantReadPairs=$(wc -l "$BadReadsBaseName"_1.txt | \
    awk '{print $1}')
    if [ "$NumContaminantReadPairs" -eq 0 ]; then
      echo 'There are no contaminant read pairs.'
      echo -n > "$MappedContaminantReads"
      if $HaveModifiedReads; then
        mv "$reads1" "$cleaned1reads"
        mv "$reads2" "$cleaned2reads"
      else
        cleaned1reads="$reads1"
        cleaned2reads="$reads2"
      fi

    # We enter this scope if there are some read pairs that blast better to 
    # contaminant contigs than the reference.
    else

      # Sort the raw reads by name. Check every read has a mate.
      # TODO: move the 'unpaired' check right to the beginning?
      cat "$reads1" | paste - - - - | sort -k1,1 -t$'\t' | tr "\t" "\n" > \
      "$reads1sorted"
      cat "$reads2" | paste - - - - | sort -k1,1 -t$'\t' | tr "\t" "\n" > \
      "$reads2sorted"
      if ! cmp <(awk '{if ((NR-1)%4==0) print substr($1,2,length($1)-3)}' \
      "$reads1sorted" | sort) \
      <(awk '{if ((NR-1)%4==0) print substr($1,2,length($1)-3)}' \
      "$reads2sorted" | sort); then
        echo 'At least one read in' "$reads1" 'or' "$reads2" 'is unpaired.' \
        'Quitting.' >&2 ; exit 1 ;
      fi

      # Extract the non-contaminant read pairs
      mv "$BadReadsBaseName"_1.txt "$BadReadsBaseName"_1_unsorted.txt
      mv "$BadReadsBaseName"_2.txt "$BadReadsBaseName"_2_unsorted.txt
      sort "$BadReadsBaseName"_1_unsorted.txt > "$BadReadsBaseName"_1.txt
      sort "$BadReadsBaseName"_2_unsorted.txt > "$BadReadsBaseName"_2.txt
      "$Code_FindReadsInFastq" -v "$reads1sorted" "$BadReadsBaseName"_1.txt > \
      "$cleaned1reads" &&
      "$Code_FindReadsInFastq" -v "$reads2sorted" "$BadReadsBaseName"_2.txt > \
      "$cleaned2reads" || \
      { echo 'Problem extracting the non-contaminant reads using' \
      "$Code_FindReadsInFastq"'. Quitting.' >&2 ; exit 1 ; }

      # Map the contaminant reads to the reference, to measure how useful the
      # cleaning procedure was.
      if [[ "$MapContaminantReads" == "true" ]]; then
        "$Code_FindReadsInFastq" "$reads1sorted" "$BadReadsBaseName"_1.txt > \
        "$BadReadsBaseName"_1.fastq &&
        "$Code_FindReadsInFastq" "$reads2sorted" "$BadReadsBaseName"_2.txt > \
        "$BadReadsBaseName"_2.fastq || \
        { echo 'Problem extracting the contaminant reads using' \
        "$Code_FindReadsInFastq. Quitting." >&2 ; exit 1 ; }
        #"$samtools" faidx "$TheRef" &&
        "$smalt" map $smaltMapOptions -o "$AllMappedContaminantReads" \
        "$smaltIndex" "$BadReadsBaseName"_1.fastq "$BadReadsBaseName"_2.fastq &&
        "$samtools" view -bS -F 4 -t "$TheRef".fai -o \
        "$MappedContaminantReads" "$AllMappedContaminantReads" || \
        { echo "Problem mapping the contaminant reads to $RefName using smalt."\
        'Quitting.' >&2 ; exit 1 ; }
      fi

      HaveModifiedReads=true

    fi
  fi
fi

################################################################################
# MAP

# Do the mapping!
echo 'Now mapping - typically a slow step.'
"$smalt" map $smaltMapOptions -o "$MapOutAsSam" "$smaltIndex" "$cleaned1reads" \
"$cleaned2reads" || \
{ echo 'Smalt mapping failed. Quitting.' >&2 ; exit 1 ; }

# Convert that sam file into a bam file. Thanks Nick Croucher!
"$samtools" view -bS $samtoolsReadFlags -t "$TheRef".fai -o \
"$MapOutConversion1".bam "$MapOutAsSam" &&
"$samtools" sort -n "$MapOutConversion1".bam -o "$MapOutConversion2".bam -T "$SamtoolsSortFile" &&
"$samtools" fixmate "$MapOutConversion2".bam "$MapOutConversion3".bam &&
"$samtools" sort "$MapOutConversion3".bam -o "$SID".bam -T "$SamtoolsSortFile" &&
"$samtools" index "$SID.bam" || \
{ echo 'Failed to convert from sam to bam format. Quitting.' >&2 ; exit 1 ; }

# Calculate the normalised insert size distribution.
"$samtools" view "$SID.bam" | awk '{if ($9 > 0) print $9}' > "$InsertSizes1"
sort -n "$InsertSizes1" | uniq -c > "$InsertSizes2"
InsertCount=$(awk '{sum+=$1} END {print sum}' "$InsertSizes1")
awk '{print $2 "," $1 "," $1/'$InsertCount'}' "$InsertSizes2" > \
"$InsertSizeCounts"

# Generate pileup
echo 'Now calculating pileup - typically a slow step.'
"$samtools" mpileup $mpileupOptions -f "$TheRef" "$SID.bam" > "$PileupFile" || \
{ echo 'Failed to generate pileup. Quitting.' >&2 ; exit 1 ; }

# Generate base frequencies and the consensuses
"$Code_AnalysePileup" "$PileupFile" "$TheRef" > "$BaseFreqs" || \
{ echo 'Problem analysing the pileup. Quitting' >&2 ; exit 1 ; }
"$Code_CallConsensus" "$BaseFreqs" "$MinCov1" "$MinCov2" "$MinBaseFrac" \
--consensus-seq-name "$SID"'_consensus' --ref-seq-name "$RefName" > \
"$consensus" || \
{ echo 'Problem calling the consensus. Quitting.' >&2 ; exit 1 ; }

# Add the contigs to the alignment of the consensus and its reference.
OldMafft=false
if [[ $NumHIVContigs -gt 0 ]]; then
  SwapContigsToTop=false
  AlignContigsToRefs "$Code_AlignToConsensus" '-S' "$RawContigFile2" \
  "$consensus" "$consensusWcontigs" "$SwapContigsToTop" "$OldMafft" || { echo \
  'Problem aligning the contigs to the consensus. Quitting.' >&2 ; exit 1 ; }
fi

# Add gaps and excise unique insertions, to allow this consensus to be added to
# a global alignment with others.
if $RefIsInAlignment; then
  "$Code_MergeAlignments" "$GlobalAlignExcisionFlag" -L "$CoordsDict" \
  "$TempRefAlignment" "$consensus" > "$ConsensusForGlobalAln"
fi

# TODO: merge CoordsDict with BaseFreqs, like this?
#  ~/Dropbox\ \(Infectious\ Disease\)/chris/SeqAnal/MergeBaseFreqsAndCoords.py "$BaseFreqs" "$CoordsDict" > "$CoordsDict"_wGlobal.csv; 

if [[ "$remap" == "true" ]]; then

  echo 'Beginning remapping to the consensus.'

  # New file names
  NewSID="$SID"'_remap'
  NewRef="$NewSID$OutputRefSuffix"
  NewRefName="$SID"'_ConsensusRound1_GapsFilled'
  NewConsensus="$NewSID"'_consensus_MinCov_'"$MinCov1"'_'"$MinCov2.fasta"
  NewBaseFreqs="$NewSID$BaseFreqsSuffix"
  NewConsensusWcontigs="$NewSID"'_consensus_MinCov_'"$MinCov1"'_'"$MinCov2"'_wContigs.fasta'

  # Fill in any gaps in the consensus with the corresponding part of the orginal
  # reference for mapping.
  "$Code_FillConsensusGaps" "$consensus" '--output-seq-name' \
  "$NewRefName" > "$NewRef" || { echo 'Problem'\
  'filling in gaps in the consensus with the corresponding part of the orginal'\
  'reference for mapping. Quitting.' >&2 ; exit 1 ; }

  # Index the ref
  "$smalt" index $smaltIndexOptions "$smaltIndex" "$NewRef" || \
  { echo 'Problem indexing the refererence with smalt. Quitting.' >&2 ; exit 1 ; }
  "$samtools" faidx "$NewRef" || \
  { echo 'Problem indexing the refererence with samtools. Quitting.' >&2 ; 
  exit 1 ; }

  # Do the mapping!
  echo 'Now mapping - typically a slow step.'
  "$smalt" map $smaltMapOptions -o "$MapOutAsSam" "$smaltIndex" \
  "$cleaned1reads" "$cleaned2reads" || \
  { echo 'Smalt mapping failed. Quitting.' >&2 ; exit 1 ; }

  # Convert that sam file into a bam file.
  "$samtools" view -bS $samtoolsReadFlags -t "$NewRef".fai -o \
  "$MapOutConversion1".bam "$MapOutAsSam" &&
  "$samtools" sort -n "$MapOutConversion1".bam -o "$MapOutConversion2".bam -T "$SamtoolsSortFile" &&
  "$samtools" fixmate "$MapOutConversion2".bam "$MapOutConversion3".bam &&
  "$samtools" sort "$MapOutConversion3".bam -o "$NewSID".bam -T "$SamtoolsSortFile" &&
  "$samtools" index "$NewSID.bam" || \
  { echo 'Failed to convert from sam to bam format. Quitting.' >&2 ; exit 1 ; }

  # Generate pileup
  echo 'Now calculating pileup - typically a slow step.'
  "$samtools" mpileup $mpileupOptions -f "$NewRef" "$NewSID.bam" > \
  "$PileupFile" || { echo 'Failed to generate pileup. Quitting.' >&2 ; exit 1 ; }

  # Generate base frequencies and the consensuses
  "$Code_AnalysePileup" "$PileupFile" "$NewRef" > "$NewBaseFreqs" || \
  { echo 'Problem analysing the pileup. Quitting' >&2 ; exit 1 ; }
  "$Code_CallConsensus" "$NewBaseFreqs" "$MinCov1" "$MinCov2" "$MinBaseFrac" \
  --consensus-seq-name "$NewSID"'_consensus' --ref-seq-name "$NewRefName" > \
  "$NewConsensus" || \
  { echo 'Problem calling the consensus. Quitting.' >&2 ; exit 1 ; }

  if [[ $NumHIVContigs -gt 0 ]]; then
    # Add the contigs to the alignment of the consensus and its reference.
    AlignContigsToRefs "$Code_AlignToConsensus" '-S' "$RawContigFile2" \
    "$NewConsensus" "$NewConsensusWcontigs" "$SwapContigsToTop" "$OldMafft" || \
    { echo 'Problem aligning the contigs to the consensus. Quitting.' >&2 ; \
    exit 1 ; }
  fi

fi

# If we did something to the reads, zip them
#if $HaveModifiedReads; then
#  gzip -f "$cleaned1reads" "$cleaned2reads"
#fi
