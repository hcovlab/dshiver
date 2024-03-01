#!/usr/bin/env python3
import os
import collections
import sys
import argparse
import pysam

## Author: Chris Wymant, chris.wymant@bdi.ox.ac.uk
## Acknowledgement: I wrote this while funded by ERC Advanced Grant PBDR-339251
##
## Overview:
ExplanatoryMessage = '''Gives the coverage - the depth/number of mapped reads at
each position - for a bam file. Output printed to stdout suitable for
redirection into a csv file.'''

# Define a function to check files exist, as a type for the argparse.
def File(MyFile):
    if not os.path.isfile(MyFile):
        raise argparse.ArgumentTypeError(MyFile+' does not exist or is not a file.')
    return MyFile

# Set up the arguments for this script
parser = argparse.ArgumentParser(description=ExplanatoryMessage)
parser.add_argument('BamFile', type=File)
args = parser.parse_args()

BamFile = pysam.AlignmentFile(args.BamFile, "rb")

# Find the reference in the bam file; there should only be one.
AllReferences = BamFile.references
if len(AllReferences) != 1:
    print('Expected exactly one reference in', args.BamFile+'; found',\
    str(len(AllReferences))+'.\nQuitting.', file=sys.stderr)
    exit(1)
RefName = AllReferences[0]

counts_by_ref_pos = collections.Counter()

for read in BamFile.fetch(RefName):

    MappedPositions = read.get_reference_positions(full_length=False)

    # Skip unmapped reads
    if not MappedPositions:
        continue

    for pos in MappedPositions:
        counts_by_ref_pos[pos] += 1

min_ref_pos = min(counts_by_ref_pos.keys())
max_ref_pos = max(counts_by_ref_pos.keys())
for pos in range(min_ref_pos, max_ref_pos + 1):
    if pos not in counts_by_ref_pos:
        counts_by_ref_pos[pos] = 0

print("reference position (1-based),coverage")
for pos, coverage in sorted(counts_by_ref_pos.items(), key=lambda x:x[0]):
    print(pos + 1, coverage, sep=",")
