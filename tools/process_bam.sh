#!/usr/bin/env bash

set -u
set -o pipefail

UsageInstructions=$(echo '
Arguments for this script:
(1) the configuration file, containing all your parameter choices etc.;
(2) your bam;
(3) the reference sequence to which the reads were mapped in that bam;
(4) A sample ID ("SID") used for naming the output from this script.
')

# Check for the right number of arguments. Assign them to variables.
NumArgsExpected=4
if [ "$#" -ne "$NumArgsExpected" ]; then
  echo $UsageInstructions
  echo "$#" 'arguments specified;' "$NumArgsExpected" 'expected. Quitting' >&2
  exit 1
fi
ConfigFile="$1"
bam="$2"
ref="$3"
OutFileStem="$4"

ThisDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ShiverDir=$(dirname $ThisDir)

source "$ShiverDir/shiver_funcs.sh" || { echo "Problem sourcing "\
"$ShiverDir/shiver_funcs.sh. Quitting." >&2 ; exit 1 ; }

CheckFilesExist "$ConfigFile" "$bam" "$ref"
source "$ConfigFile"

ProcessBam "$bam" "$ref" "$OutFileStem" ||
{ status=$?; echo "Quitting." >&2; exit $status; }
