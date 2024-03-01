#!/usr/bin/env python3
from __future__ import print_function

## Author: Chris Wymant, chris.wymant@bdi.ox.ac.uk
## Acknowledgement: I wrote this while funded by ERC Advanced Grant PBDR-339251 
##
## Overview
ExplanatoryMessage = '''We construct the optimal reference for a given sample by
flattening its (de novo assembled) contigs with a set of references.
How it works:
(1) We flatten the contigs, taking the base (or gap) of the longest one where
they disagree (expecting that the de novo assembly makes the longest contig
first with the dominant i.e. most numerous set of short reads).
(2) We compare every reference to the flattened contigs and count the number of
agreeing bases. The comparison is not done in the gaps between contigs nor
before/after the reference/contigs. When we are inside a contig and inside the
reference, however, gaps count - here they are taken to represent a genuine
deletion, so the gap character holds equal footing with a base.
(3) Starting with the reference with the highest score, we elongate it both
directions using references or progressively lower scores. We stop when both
edges reach the edges of the alignment, or when a reference is reached which has
a score of zero. This defines the elongated best reference.
(4) We fill in gaps before, between and after (but not within) the contigs using
the elongated best reference. This defines the constructed best reference.
'''

################################################################################
## USER INPUT
# The character that indicates a gap (missing base). If there are multiple such
# characters, put the one to be used in the output first.
GapChar = '-'
# Excise unique insertions present in the contigs but not any of the references?
ExciseUniqueInsertions = False
################################################################################

FloatComparisonTolerance = 1e-6

import os.path
import sys
import collections
import argparse
from AuxiliaryFunctions import ReadSequencesFromFile, PropagateNoCoverageChar

# Define a function to check files exist, as a type for the argparse.
def File(MyFile):
  if not os.path.isfile(MyFile):
    raise argparse.ArgumentTypeError(MyFile+' does not exist or is not a file.')
  return MyFile

# For using new lines in the argument help
class SmartFormatter(argparse.HelpFormatter):
    def _split_lines(self, text, width):
        if text.startswith('R|'):
            return text[2:].splitlines()  
        return argparse.HelpFormatter._split_lines(self, text, width)

# Set up the arguments for this script
parser = argparse.ArgumentParser(description=ExplanatoryMessage, \
formatter_class=SmartFormatter)
parser.add_argument('AlignmentOfContigsToRefs', type=File)
parser.add_argument('OutputFile')
parser.add_argument('ContigName', nargs='+')
parser.add_argument('-AS', '--always-use-sequence', action='store_true',
help='''By default, at each position we always use whatever the longest contig
has there, even if it's a deletion (i.e. an internal gap) and a shorter contig
has a base there. With this option we'll always use a base from the contigs if
possible, i.e. if a shorter contig has an insertion relative to a longer contig
we will use the insertion. This protects against cases where a long contig has
an erroneous internal gap due to misalignment, but may introduce artefactual
insertions in the flattened contigs due to misalignment. e.g. By default the
contigs GGGGA-CC- and --TG-ACCT would be flattened to GGGGA-CCT (using the
longer first contig wherever possible); with this option they would be flattened
to GGGGAACCT, giving a double-A that is seen in neither contig.''')
parser.add_argument('-L', '--contigs-length', action='store_true', \
help='Simply print the length of the flattened contigs (i.e. the number of '+\
'positions in the alignment that are inside at least one contig, excluding '+\
'positions where all contigs have a gap), and exit.')
parser.add_argument('-P', '--print-best-score', action='store_true', \
help='Simply print the fractional identity and the name of the reference ' +\
'with the highest fractional identity, then exit.')
parser.add_argument('-S1', '--summarise-contigs-1', action='store_true', \
help='Simply print the length and gap fraction of each contig, then exit.')
parser.add_argument('-S2', '--summarise-contigs-2', action='store_true', \
help='Simply print the length and gap fraction of each contig in an alignment'+\
' in which only the best reference is kept with the contigs (i.e. all other ' +\
'references are discarded, then pure-gap columns are removed), then exit.')
parser.add_argument('-C', '--compare-contigs-to-consensus', \
help='''R|Use this option to specify the name of the consensus
sequence; use it when the AlignmentOfContigsToRefs argument is the
alignment of contigs, consensus and mapping reference.
We put each position in the alignment in one of the
following four categories, then print the counts of 
each. (1) At least one of the flattened contigs agrees
with the consensus. (2) All contigs disagree with the
consensus. (3) At least one contig has a base and the
reference has "?". (4) There is no contig coverage but
the consensus has a base. We do not count positions
where the consensus has "?" and all contigs have gaps or
no coverage, nor positions where the consensus has a gap
and [at least one contig has a gap or no contig has
coverage], since such positions constitute trivial
agreement. We also do not count any position where the
consensus has an 'N'.The table below may help clarify
the categorisation of positions:

                          Consensus:
                       |  base  | gap |  ?  |  N
          -------------|--------|-----|-----|-----
         just bases    | 1 or 2 |  2  |  3  | n/a
Contigs: bases + gaps  | 1 or 2 | n/a |  3  | n/a
         just gaps     |   2    | n/a | n/a | n/a
         no coverage   |   4    | n/a | n/a | n/a
''')
parser.add_argument('-C2', '--compare-contigs-to-consensus-2', \
help='''R|Use this option to specify the name of the consensus
sequence; use it when the AlignmentOfContigsToRefs argument is the
alignment of contigs, consensus and mapping reference.
As -C but compare the consensus to the mapping
reference, not to the contigs.''')
Args = parser.parse_args()

# Read in the sequences
Seqs, Refs = ReadSequencesFromFile(Args.AlignmentOfContigsToRefs)

# Print the contigs length and exit, if requested
if Args.contigs_length:
  print('The contigs are of length '+str(len(Seqs[Args.ContigName[0]])))
  sys.exit()

# Define a class to store all the per-position counts
class PositionCounts:
  def __init__(self):
    self.Counts = collections.defaultdict(lambda: collections.defaultdict(float))
  def Add(self, RefName, RefBase, ContigBase, Weight):
    if RefBase != GapChar or ContigBase != GapChar:
      self.Counts[RefName][ContigBase] += Weight

# Define a function to update BestRefGivenContigAlignment
def UpdateBestRefGivenContigAlignment(BestRefGivenContigAlignment, \
RefBase, ContigBase, TotalWeight):
  if (ContigBase != GapChar and \
  (RefBase == GapChar or ContigBase == RefBase)):
    BestRefGivenContigAlignment[RefName].Add(RefName, RefBase, \
    ContigBase, TotalWeight)

# Work out the score for each reference.
# The score is the sum over positions of the weighted number of contigs that
# agree with the reference, divided by the total number of contigs. Weighting
# by the number of contigs with non-gap bases at the position would be better,
# but then we'd have to find the total number of contigs at each position, so
# it's a bit more complicated. This method will weight by coverage only if the
# contigs are uniformly distributed across the reference.
Scores = collections.defaultdict(float)
BestRefGivenContigAlignment = collections.defaultdict(PositionCounts)
for RefName in Seqs:
  TotalWeight = float(len(Seqs))
  for Pos in range(len(Seqs[RefName])):
    RefBase = Seqs[RefName][Pos]
    if RefBase == '?' or RefBase == 'N':
      TotalWeight -= 1.0
      continue
    TotalWeightHere = TotalWeight
    if Args.always_use_sequence:
      TotalWeightHere = float(len(Args.ContigName))
    Counts = collections.defaultdict(float)
    for ContigName in Args.ContigName:
      ContigBase = Seqs[ContigName][Pos]
      if Args.always_use_sequence and ContigBase != GapChar:
        TotalWeightHere += 1.0
      Counts[ContigBase] += 1.0
    if len(Counts) == 1:
      # There's no disagreement, so there's no evidence that this position
      # comes from the reference
      TotalWeight -= 1.0
      continue
    BestContigBases = sorted(Counts.keys(), key=lambda x: Counts[x], \
    reverse=True)
    BestContigWeight = Counts[BestContigBases[0]]
    if Args.always_use_sequence:
      TotalWeightHere = BestContigWeight
    for ContigBase in Counts:
      if Args.always_use_sequence and ContigBase != GapChar:
        TotalWeightHere += 1.0
      if ContigBase == GapChar:
        continue
      ScoreIncrement = BestContigWeight
      if Args.always_use_sequence:
        ScoreIncrement = Counts[ContigBase]
      Scores[RefName] += ScoreIncrement/TotalWeightHere
      UpdateBestRefGivenContigAlignment(BestRefGivenContigAlignment, RefBase, \
      ContigBase, TotalWeightHere)

if Args.print_best_score:
  BestRef = max(Scores, key=Scores.get)
  print('The best reference is '+BestRef+\
  ', which has a score of '+str(Scores[BestRef])+'/'+str(len(Seqs)))
  sys.exit()

# Sort the references by score, and work out the best reference.
SortedRefs = sorted(Scores.keys(), key=lambda x: Scores[x], reverse=True)
BestRef = SortedRefs[0]

# Print the consensus sequence of the contigs and exit, if requested
if Args.summarise_contigs_1:
  SummariseContigs(BestRef, Args.ContigName, Seqs)
  sys.exit()

# Print the consensus sequence of the contigs after applying the best reference
# and exit, if requested
if Args.summarise_contigs_2:
  SummariseContigs(BestRef, Args.ContigName, Seqs, BestRefGivenContigAlignment)
  sys.exit()

# Print the comparison of the contigs to the consensus and exit, if requested
if Args.compare_contigs_to_consensus:
  CompareContigsToConsensus(BestRef, Args.ContigName, Seqs, Args.compare_contigs_to_consensus)
  sys.exit()

# Print the comparison of the consensus to the reference and exit, if requested
if Args.compare_contigs_to_consensus_2:
  CompareConsensusToContigs(BestRef, Args.ContigName, Seqs, Args.compare_contigs_to_consensus_2)
  sys.exit()

# Apply the best reference to the contigs.
BestRefGivenContigAlignmentList = []
for Pos in range(len(Seqs[BestRef])):
  BestRefGivenContigAlignmentList.append(BestRefGivenContigAlignment[BestRef].Counts[BestRef][Seqs[BestRef][Pos]])

for RefName in Seqs:
    if RefName == BestRef:
        continue
    new_seq = ''
    for Pos in range(len(Seqs[RefName])):
        RefBase = Seqs[RefName][Pos]
        if RefBase == GapChar:
            new_seq += GapChar
        else:
            new_seq += RefBase
    Seqs[RefName] = new_seq

# Write the sequences to file
OutFile = open(Args.OutputFile,'w')
for RefName in Seqs:
  OutFile.write('>'+RefName+'\n')
  OutFile.write(Seqs[RefName]+'\n')
OutFile.close()
