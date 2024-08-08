#!/usr/bin/env python
from __future__ import print_function
from six.moves import range
import argparse
import os
import sys
from Bio import SeqIO, Seq
import collections
import copy

## Author: Chris Wymant, chris.wymant@bdi.ox.ac.uk
## Acknowledgement: I wrote this while funded by ERC Advanced Grant PBDR-339251

if __name__ == "__main__":

  ## Overview:
  ExplanatoryMessage = '''For each DNA sequence in an input fasta file, generate
  all possible sequences that differ by a single SNP (i.e. a change between an A,
  C, G or T).'''
  
  # Define a function to check files exist, as a type for the argparse.
  def File(MyFile):
    if not os.path.isfile(MyFile):
      raise argparse.ArgumentTypeError(MyFile+' does not exist or is not a file.')
    return MyFile
  
  # Set up the arguments for this script
  parser = argparse.ArgumentParser(description=ExplanatoryMessage)
  parser.add_argument('InputFasta', type=File)
  parser.add_argument('OutputFasta')
  #parser.add_argument('-RC', '--rev-comp', action='store_true')
  args = parser.parse_args()
  
  OKbases = "ACGT"
  NumOKbases = len(OKbases)
  
  UniqueSeqs = set([])
  InSeqObjects = []
  for seq in SeqIO.parse(open(args.InputFasta),'fasta'):
  
    # Convert to upper case, then to a string
    seq.seq = seq.seq.upper()
    SeqAsStr = str(seq.seq)
  
    # Check for duplicate seqs in the input.
    if SeqAsStr in UniqueSeqs:
      print('Skipping input seq', seq.id, 'whose seq has already been',
      'encountered in', args.InputFasta, '(ignoring upper v lower case',
      'differences).')
      continue
  
    # Check for unexpected bases in input.
    if not all(_base in OKbases for _base in SeqAsStr):
      print('Seq', seq.id, 'contains a base not in "' + OKbases + '". Quitting.',
      file=sys.stderr)
      exit(1)
  
    UniqueSeqs.add(SeqAsStr)
    InSeqObjects.append(seq)
  
    #if args.rev_comp:
    #  RevSeq = copy.deepcopy(seq)
    #  RevSeq.seq = RevSeq.seq.reverse_complement()
    #  RevSeq.id += '_RevComp'
    #  UniqueSeqs.add(str(RevSeq.seq))
    #  InSeqObjects.append(RevSeq)
  
  OutSeqs = []
  for seq in InSeqObjects:
    OutSeqs.append(seq)
    SeqAsStr = str(seq.seq)
    SeqLen = len(SeqAsStr)
    for pos in range(SeqLen):
      OrigBase = SeqAsStr[pos]
      for base in OKbases:
        if base == OrigBase:
          continue
        MutatedSeq = SeqAsStr[:pos] + base + SeqAsStr[pos + 1:]
        if MutatedSeq in UniqueSeqs:
          continue
        ID = seq.id + '_pos_' + str(pos + 1) + '_' + OrigBase + '_to_' + base
        OutSeqs.append(SeqIO.SeqRecord(Seq.Seq(MutatedSeq), id=ID,
        description=''))
        UniqueSeqs.add(MutatedSeq)
        
  SeqIO.write(OutSeqs, args.OutputFasta, "fasta")
  #SeqIO.write(OutSeqs, sys.stdout, "fasta")
