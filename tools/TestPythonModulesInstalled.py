#!/usr/bin/env python
import argparse

## Author: Chris Wymant, chris.wymant@bdi.ox.ac.uk
## Acknowledgement: I wrote this while funded by ERC Advanced Grant PBDR-339251

if __name__ == "__main__":
  
  ExplanatoryMessage = '''This script tests that all the Python modules required
  by shiver_init.sh, shiver_align_contigs.sh and shiver_map_reads.sh are
  installed. IMPORTANT: you should specify which version of Python you want to
  execute this script with, and that version should be identical to what you
  specify for the "python" variable in your shiver config file. For example if
  you have set this variable to be "python3", and if your shiver code lives in
  ~/shiver/, you should execute this script by running
  "python3 ~/shiver/tools/TestPythonModulesInstalled.py"'''

  # Set up the arguments for this script
  ExplanatoryMessage = ExplanatoryMessage.replace('\n', ' ').replace('  ', ' ')
  parser = argparse.ArgumentParser(description=ExplanatoryMessage)
  args = parser.parse_args()

  import AddAllPossibleSNPsToSeqs
  import AlignMoreSeqsToPairWithMissingCoverage
  import AnalysePileup
  import AuxiliaryFunctions
  import CallConsensus
  import CheckFastaFileEquality
  import ConstructBestRef
  import ConvertFastqToFasta
  import CorrectContigs
  import CutAlignedContigs
  import FillConsensusGaps
  import FindContaminantReadPairs
  import FindNamedReadsInSortedFastq
  import FindSeqsInFasta
  import KeepBestLinesInDataFile
  import MergeAlignments
  import MergeBaseFreqsAndCoords
  import PrintSeqLengths
  import RemoveBlankColumns
  import ShiverFuncs
  import SplitFasta
  import UngapFasta
  
  print("All Python modules required by the shiver*.sh commands are installed.")
