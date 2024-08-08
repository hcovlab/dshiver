#!/usr/bin/env bash

set -u
set -o pipefail

NumArgsExpected=5
UsageInstructions=$(echo "
In normal usage this script requires $NumArgsExpected arguments:\n
(1) an output directory for the initialisation files.\n
(2) the configuration file, containing all your parameter choices etc.;\n
(3) your chosen alignment of references;\n
(4) a fasta file of the adapters used in sequencing;\n
(5) a fasta file of the primers used in sequencing.
\nAlternatively call this script with one argument - '--help' or '-h' - to see
this message. Alternatively call this script with two arguments - '--test' then
the configuration file - to just test whether the configuration file is OK
(including whether this script can call the external programs it needs using
commands given in the config file) and then exit.
")

# Print help & exit if desired
# NB A && B || C is (A && B) || C; we nest to get A && (B || C)
if [[ "$#" -eq 1 ]]; then
  if [[ "$1" == '--help' ]] || [[ "$1" == '-h' ]]; then
    echo -e $UsageInstructions
    exit 0
  fi
fi

# Check for the right number of arguments and whether we're testing.
test=false
if [[ "$#" -eq 2 ]] && [[ "$1" == '--test' ]]; then
  test=true
fi
if ! $test && [ "$#" -ne "$NumArgsExpected" ]; then
  echo -e $UsageInstructions
  echo 'Invalid set of arguments specified. Quitting' >&2
  exit 1
fi

ConfigFile="$2"

# Source the shiver funcs, check the config file exists, check (and source) it
ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$ThisDir"/'shiver_funcs.sh'
CheckFilesExist "$ConfigFile"
CheckConfig "$ConfigFile" true false false false || \
{ echo "Problem with $ConfigFile. Quitting." >&2 ; exit 1 ; }

# Quit if only testing the config file
if $test; then
  echo "No problems relevant for this script were detected in $ConfigFile." \
  "Quitting successfully."
  exit 0
fi

# Assign remaining arguments to variables
OutDir="$1"
RefAlignment="$3"
adapters="$4"
primers="$5"

CheckFilesExist "$RefAlignment" "$adapters" "$primers"

# If OutDir does not exist, try to create it.
if [ ! -d "$OutDir" ]; then
  mkdir "$OutDir"
fi || { echo 'Unable to create the specified output directory. (NB it should' \
'not exist already.) Quitting.' >&2 ; exit 1; }

# Remove a trailing slash, if present.
OutDir=$(cd "$OutDir"; pwd)

# Check that OutDir does not have whitespace in it
if [[ "$OutDir" =~ ( |\') ]]; then
  echo "Your specified directory $OutDir contains whitespace; we need to be"\
  "able to build a blast database in there, and unfortunately, blast cannot"\
  "handle whitespace in paths (stupid, I know). Try again with a different"\
  "directory. Quitting." >&2
  exit 1;
fi

# Check OutDir is empty
if ! find "$OutDir"/ -maxdepth 0 -empty | read v; then
  echo "$OutDir is not empty. Delete or move its contents. Quitting." >&2
  exit 1;
fi

# Some files we'll create
NewRefAlignment="$OutDir"/'ExistingRefAlignment.fasta'
RefList="$OutDir"/'ExistingRefNamesSorted.txt'
UngappedRefs="$OutDir"/'ExistingRefsUngapped.fasta'
database="$OutDir"/'ExistingRefsBlastDatabase'

# Copy the three input fasta files into the initialisation directory, removing
# pure-gap columns from RefAlignment.
"$python" "$Code_RemoveBlankCols" "$RefAlignment" > "$NewRefAlignment" || \
{ echo "Problem removing pure-gap columns from $RefAlignment. Quitting." >&2 ; \
exit 1; }
cp "$adapters" "$OutDir"/'adapters.fasta'
cp "$primers" "$OutDir"/'primers.fasta'

if [[ "$TrimPrimerWithOneSNP" == "true" ]]; then
  "$python" "$Code_AddSNPsToSeqs" "$OutDir/primers.fasta" \
  "$OutDir/PrimersWithSNPs.fasta" || { echo "Problem generating all possible"\
  "variants of the sequences in $primers differing by a single base mutation."\
  "Quitting." >&2; exit 1; }
fi

# List all names in the reference alignment
awk '/^>/ {print substr($1,2)}' "$NewRefAlignment" | sort > "$RefList"

# Check that RefAlignment has some sequences, that their IDs are unique, and
# that their IDs don't contain commas.
NumRefs=$(wc -l "$RefList" | awk '{print $1}')
if [[ $NumRefs -eq 0 ]]; then
  echo "$RefAlignment contains no sequences. Quitting." >&2
  exit 1;
fi
NumUniqueIDs=$(uniq "$RefList" | wc -l)
if [[ $NumUniqueIDs -ne $NumRefs ]]; then
  echo "$RefAlignment contains some identically named sequences. Rename"\
  'these and try again. Quitting.' >&2
  exit 1;
fi
RefNames=$(cat "$RefList")
if [[ "$RefNames" == *","* ]]; then
  echo "Reference names must not contain commas. Quitting." >&2
  exit 1
fi

# Ungap RefAlignment
"$python" "$Code_UngapFasta" "$NewRefAlignment" > "$UngappedRefs" || \
{ echo "Problem ungapping $RefAlignment. Quitting." >&2 ; exit 1; }

# Create the blast database
"$BlastDBcommand" -dbtype nucl -in "$UngappedRefs" -input_type fasta -out \
"$database" || \
{ echo 'Problem creating a blast database out of' \
"$OutDir/ExistingRefsUngapped.fasta. Quitting." >&2 ; exit 1; }

# Make a set of files each containing one (ungapped) sequence from the reference
# alignment.
IndividualRefDir="$OutDir"/'IndividualRefs'
mkdir -p "$IndividualRefDir" || \
{ echo "Problem making the directory $IndividualRefDir. Quitting." >&2 ; \
exit 1; }
"$python" "$Code_SplitFasta" -G "$RefAlignment" "$IndividualRefDir" || { echo "Problem" \
"splitting $RefAlignment into one file per sequence. Quitting." >&2 ; exit 1; }
