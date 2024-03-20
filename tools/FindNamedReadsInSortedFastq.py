#!/usr/bin/env python3
from __future__ import print_function
import os.path
import sys
import argparse

# Define the arguments and options
parser = argparse.ArgumentParser(description="Find reads in a FASTQ file.")
parser.add_argument("FastqFile", help="Path to the FASTQ file")
parser.add_argument("FileOfReadNames", help="Path to the file containing read names")
parser.add_argument("-v", "--invert", action="store_true", help="Find all reads EXCEPT those named")
parser.add_argument("-s", "--not-sorted", action="store_true", help="Specify that the read file and/or list of desired reads may not be sorted")

args = parser.parse_args()
FastqFile = args.FastqFile
FileOfReadNames = args.FileOfReadNames
invert = args.invert

# Check that all arguments exist and are files
for DataFile in [FastqFile, FileOfReadNames]:
    if not os.path.isfile(DataFile):
        sys.stderr.write(DataFile + ' does not exist or is not a file. Quitting.\n')
        exit(1)

# Read in the read names
if args.not_sorted:
    ReadNames = set([])
else:
    ReadNames = []
with open(FileOfReadNames, 'r') as f:
    for line in f:
        if args.not_sorted:
            ReadNames.add(line.strip())
        else:
            ReadNames.append(line.strip())
NumReadsToFind = len(ReadNames)

# Read through the fastq file...
NumNamedReadsFound = 0
ThisIsAReadWeWant = False
with open(FastqFile, 'r') as f:
    for LineNumberMin1, line in enumerate(f):

        # Those lines that are not read names: print if appropriate, and continue.
        if LineNumberMin1 % 4 != 0:
            if ThisIsAReadWeWant:
                print(line, end='')
            continue

        # Henceforth we're on a line that's a read name (lines 1, 5, 9, 13...)

        # Check if we've found all the named reads already.
        if NumNamedReadsFound == NumReadsToFind:
            if invert:
                ThisIsAReadWeWant = True
                print(line, end='')
                continue
            else:
                break

        # Check it begins with an @ symbol
        if not (len(line) > 0 and line[0] == '@'):
            sys.stderr.write('Unexpected fastq format for ' + FastqFile + ': lines' +
                             ' 1, 5, 9, 13... are expected to start with an @ symbol. Quitting.\n')
            exit(1)

        # See if this is a read we want: a named read if invert = False,
        # or an unnamed read if invert = True.
        if args.not_sorted:
            ThisReadInList = line[1:].split(None, 1)[0] in ReadNames
        else:
            ThisReadInList = line[1:].split(None, 1)[0] == ReadNames[NumNamedReadsFound]
        if ThisReadInList:
            NumNamedReadsFound += 1
            ThisIsAReadWeWant = not invert
        else:
            ThisIsAReadWeWant = invert
        if ThisIsAReadWeWant:
            print(line, end='')

# Check all reads were found
if NumNamedReadsFound < NumReadsToFind:
    if args.not_sorted:
        print("Error:", FileOfReadNames, "contains", NumReadsToFind, "reads but we",
              "only found", NumNamedReadsFound, "in", FastqFile + ".", file=sys.stderr)
    else:
        sys.stderr.write(ReadNames[NumNamedReadsFound] + ' was not found in ' +
                         FastqFile + '. Either it is truly missing, or ' + FastqFile +
                         ' is not sorted, or ' + FileOfReadNames + ' is not sorted, or' + FileOfReadNames +
                         ' contains a multiply specified read.\nQuitting.\n')
        exit(1)
