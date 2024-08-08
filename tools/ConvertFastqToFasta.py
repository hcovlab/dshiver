#!/usr/bin/env python
from __future__ import print_function
import argparse
import os
import sys
from Bio import SeqIO

## Author: Chris Wymant, chris.wymant@bdi.ox.ac.uk
## Acknowledgement: I wrote this while funded by ERC Advanced Grant PBDR-339251

if __name__ == "__main__":

  ## Overview:
  ExplanatoryMessage = '''This script converts sequence data from fastq format to
  fasta format (discarding sequence quality information).
  '''
  
  # Define a function to check files exist, as a type for the argparse.
  def File(MyFile):
    if not os.path.isfile(MyFile):
      raise argparse.ArgumentTypeError(MyFile+' does not exist or is not a file.')
    return MyFile
  
  # Set up the arguments for this script
  ExplanatoryMessage = ExplanatoryMessage.replace('\n', ' ').replace('  ', ' ')
  parser = argparse.ArgumentParser(description=ExplanatoryMessage)
  parser.add_argument('InputFastqFile', type=File)
  parser.add_argument('OutputFastaFile')
  parser.add_argument('-O', '--overwrite-output-file', action='store_true')
  args = parser.parse_args()
  
  if (not args.overwrite_output_file) and os.path.isfile(args.OutputFastaFile):
    print(args.OutputFastaFile, 'exists already and --overwrite-output-file was',
    'not specified. Exiting.', file=sys.stderr)
    exit(1)  
  
  SeqIO.convert(args.InputFastqFile, "fastq", args.OutputFastaFile, "fasta")
