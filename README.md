

# Introduction

This data analysis pipeline is based on the shiver pipeline developed by
Chris Wymant (see [“Easy and accurate reconstruction of whole HIV
genomes from short-read sequence data with shiver.” *Virus
evolution* 4.1, 2018](https://doi.org/10.1093/ve/vey007)).

The pipeline has been developed to accurately **reconstruct whole viral
genomes** from short-read sequence data (with HIV as a representative
use case). To enable easy use of the pipeline, we have packed it into a
*docker container* that allows simple installation and convenient access
to the major capabilities of shiver.

We have also made minor optimizations in the original code, which are
not affecting the algorithms. We have added an automated HIV drug
resistance report based on the consensus sequence and using the
[Stanford DRM web service](https:/hivdb.stanford.edu/page/webservice/).

We call this modified version *dshiver* (dockerized version of shiver).

# How to install the required software

dshiver runs in a *docker container*, a great way to pack several
applications and their dependencies into a single “package” that can be
installed and run quickly and easily. To use it, you need to install
**Docker Desktop** on your computer. Go to:
<a href="https://hub.docker.com/signup"
class="uri">https:/hub.docker.com/signup</a>. You need to sign up, then
you can download the software free of charge, and easy-to-follow
instructions guide you through the installation process.

> [!NOTE]
>
> Docker Desktop is also available for Mac and Linux. Most of this
> description is independent of the operating system used. Note also
> that docker technology allows us to use the Linux-based tools
> incorporated in shiver on Windows machines.

In our study, we performed computational resource usage analyses with a
range of contamination and coverage scenarios on a computer with
Intel(R) Core(TM) i7-7700 CPU @3.60GHz processor, 16 GB of system
memory, and a Ubuntu 22.04.2 LTS operating system. For RAM and CPU usage
requirement estimations compared to other pipelines, see [our paper](https://www.biorxiv.org/content/10.1101/2024.03.13.584779v1).

> [!NOTE]
>
> You can also do an online tutorial; however, for the use of dshiver,
> we provide complete instructions, not depending on any prior knowledge
> of docker.

If you stop Docker Desktop launching at startup, you will first need to
launch Docker Desktop whenever you wish to use dshiver.

# How to use dshiver

Create a new directory for the analysis of each sample. Into this
directory, copy the following files:

1.  adapters you used for the Illumina sequencing in a fasta file
    (default name: Adapters.fasta)

2.  primers you used for the amplification of the target prior to Illumina
    sequencing, in a fasta file (default name: Primers.fasta)

3.  reference alignment containing aligned whole genome sequences
    (default name: RefAlignment.fasta)

> [!NOTE]
>
> For HIV-1 sequences, we provide a default RefAlignment.fasta file. We
> also welcome submissions for tested reference alignments for other
> viruses.

> [!TIP]
>
> We recommend handling each segment as a separate virus for segmented
> viruses, i.e., analyze each segment in a separate folder, with a
> reference alignment containing the appropriate ‘whole segment’
> sequences.

4.  paired-end short reads in two files (forward and reverse reads) or single-end short reads in one file (only set the ForwardReads argument),
    e.g., the output of an Illumina MiSeq run (default file names:
    either fastq files: reads_1.fastq, reads_2.fastq or gzipped fastq
    files: reads_1.fastq.gz, reads_2.fastq.gz)

Either rename your files to the default file names (see above) or
provide the names of the input files in the optional config file (see
later in the description of the `gen_config` command). You should always
use the reference alignment, primers, and reads appropriate to your
sample. Pay attention to copy **ALL** these files to your folder!

> [!TIP]
>
> For advanced configuration, modify the default “config.sh” file
> generated with the `gen_config` command (see later). It’s the config
> file of the original shiver pipeline. Read the [Shiver
> Manual](https://github.com/ChrisHIV/shiver/blob/master/info/ShiverManual.pdf)
> for more details.

Make sure Docker Desktop is running, go to the new directory, then open
a Windows PowerShell (from the File menu of File Explorer) or your basic
shell in Linux or on a Mac.

**From this point on, you type all commands in this shell window.**

If unsure, you can test whether Docker is running properly by typing
`docker ps`. If you get an error message, something went wrong;
otherwise, a header line should be printed in your shell.

Before the first use of **dshiver**, you need to `pull` (download) it by
typing:

``` default
docker pull ghcr.io/hcovlab/dshiver
```

When you already have shiver installed, issuing the same `pull` command
checks for updates, and downloads and installs any it can find in the
central repository.

## General introduction on the use of a docker container

Every run command using the docker container should be built like this:

``` default
docker run [switches] <name_of_container> [command]
```

For example, to run it in an interactive way, where you can see the
events on the terminal you should use:

``` default
docker run -it ghcr.io/hcovlab/dshiver gen_config
```

The docker container generates many temporary files, which take up a lot
of space if they are not deleted. Use `--rm` switch like this:

``` default
docker run -it --rm ghcr.io/hcovlab/dshiver gen_config
```

> [!NOTE]
>
> Switches such as “it” and “–rm” can be used with every command of
> dshiver. As in the example, these options should always come after the
> “run” command and precede the name of the docker image.

Here `--rm` deletes all the temporary data after the container stops
without abolishing the mounted volume. It is highly recommended to use
it!

Otherwise, the “detached” mode is more often used, where we can not
follow the events during the run:

``` default
docker run -d ghcr.io/hcovlab/dshiver gen_config
```

If you still want to check on your docker run, use:

``` default
docker ps
```

This shows your running container but not the containers that are not
running anymore. To see those as well, you should use:

``` default
docker ps -a
```

This is very important because this way, you can get the **`dockerID`**
of your “dead” container as well and utilize it for removing temporary
files manually, for instance, by using this command:

``` default
docker -rm dockerID
```

Docker containers use a layered filesystem where each “docker image”
represents a read-only layer; the modifications - the running container
makes - are always written on the top image. This filesystem only
exists while the container is running, afterward, every file dies with
it. So, to mount a new folder (volume) that saves the output files of
your container, you should use the`-v` switch. This switch then needs
the full pathway of your directory where you have your input files on
your computer and, after a **“:”** mark, the guest directory pathway.

Complete pathway of your directory: **Windows:** If you started your
command line from the File menu of File Explorer (Power Shell), where
you store your input files, then you can use `${PwD}` in the command; if
not, then you should add the full directory pathway instead (like:
“C:\Users\John_Doe\HIV_project”). **Linux:** If you are currently
working in the directory where you store your input files, you can use
**`pwd`** instead of the Full pathway of your directory. Guest directory
pathway refers to the temporary directory you mount, which is used only
as long as the container runs. This is always `/data` in case of
dshiver.

> [!NOTE]
>
> Note: `pwd` (or the full pathway of your directory) and the guest
> directory pathway should always be separated with “:”!

General form:

``` default
docker run -it -v <full directory pathway>:<guest directory pathway> <name_of_container> [command]  
```

\[command\] should always be replaced with the command you want to
apply.

The <name_of_container> is **ghcr.io/hcovlab/dshiver**. Example:
Windows:

``` default
docker run -it -v C:\Users\John_Doe\HIV_project:/data ghcr.io/hcovlab/dshiver gen_config
```

Linux:

``` default
docker run -it -v  C:\Users\John_Doe\HIV_project:/data ghcr.io/hcovlab/dshiver gen_config
```

## Commands you need to issue to go through the pipeline

### 1. Read or edit the config file to set the parameters of your run

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver gen_config
```

The default settings are:

``` default
# shiver_pipeline.conf
ForwardReads="reads_1.fastq.gz"
ReverseReads="reads_2.fastq.gz"
ShiverConfig="/shiver/config.sh"
RefAlignment="RefAlignment.fasta"
Adapters="Adapters.fasta"
Primers="Primers.fasta"
Prefix="RESULT"
```

> [!NOTE]
>
> The given Prefix will be used as a **sample ID (SID)** at the
> beginning of each output file and as the sample name in the drug
> resistance report.
>
> This script uses bash format; ensure there is no space before or after
> the “=” sign! The files containing the reads should either be fastq
> files: reads_1.fastq, reads_2.fastq or gzipped fastq files:
> reads_1.fastq.gz, reads_2.fastq.gz.

### 2. Perform de novo assembly to generate contigs

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver de_novo_assembly
```

The contigs that you received from the *de novo* assembly software. The
default tool of this image is SPAdes (from v1.6.1_1.0 instead of IVA (Iterative Virus Assembler)).

### 3. Alignment of contigs

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver align_contigs
```

> [!NOTE]
>
> After the alignment of the contigs, you may have a choice to make. If
> SID_cut.WRefs exists, it is used automatically, if not SID_raw.WRefs
> is used instead. If both files exist, and you decide to use
> SID_raw.WRefs, you can do it by deleting SID_cut.WRefs.

### 4. Mapping of the reads (longest part)

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver map_reads
```

### 5. Obtain clinically relevant drug resistance data (HIV-1)

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver drug_resistance
```

### Run the whole pipeline using one command

``` default
docker run -it -v `pwd`:/data ghcr.io/hcovlab/dshiver full
```

## The output files

All output files begin with a SID (by default, “RESULT” but can be
changed; see edit config file).

The important output files are:

- **SID.bam** and **SID.bam.bai** files: they contain the mapped reads.

- **SID_remap_consensus_MinCov_X_Y.fasta**: The first entry is the final
  consensus sequence, with ?’s indicating the positions present in the
  reference sequence used in the **second round** mapping but absent in
  the consensus. The second entry is the reference sequence for the
  second round of mapping (which is the consensus after the first
  round).

> [!NOTE]
>
> The first entry can be extracted, then remove ‘?’ to obtain the final
> consensus sequence).

- **SID_remap_BaseFreqs**: the frequencies of A, C, G, T, ‘-’ for a
  deletion, and N for unknown, at each position in the final re-mapped
  alignment. The positions are those of the reference sequence used for
  the final mapping. (These frequencies are used to obtain the final
  consensus sequence.)

- **SID_remap_BaseFreqs_WithHXB2**: the frequencies of A, C, G, T, ‘-’
  for a deletion, and N for unknown, at each position in the genome. It
  contains a column with reference (HXB2) coordinates that can be used
  to compare different samples.

- **SID.log:** you find all the records of events that occurred during
  the software run in this file.

- **SID_consensus_MinCov_X_Y_ForGlobalAln.fasta**: the consensus from
  shiver’s **first round** of mapping translated into the global
  alignment coordinates derived from the alignment of the existing
  references. It can be helpful when multiple samples are compared. X is
  the minimum number of reads to call a base, and Y is the minimum
  number to use upper case for the base (these thresholds are specified
  in the config.sh file). The default values of ‘X’ and ‘Y’ are 15 and
  30.

> [!NOTE]
>
> When comparing multiple samples, an alternative (perhaps better)
> method is to generate a multiple alignment of the final (re-mapped)
> consensus sequences. Using the \_ForGlobalAln files loses the error
> correction of the re-mapping. On the other hand, it might perform
> better at the two ends of the alignment if some positions are present
> in a low number of the final consensus sequences.

**SID_drug_resistance.xlsx** and **SID_drug_resistance.json**: the
\*.xlsx file contains a table with a simplified summary of clinically
relevant information (major, accessory mutations, comments regarding
other mutations and drug resistance interpretations by drugs based on
the Stanford University HIV Drug Resistance Database). The JSON file
contains the raw data queried using the
SID_remap_consensus_MinCov_X_Y.fasta file.

# References

Wymant, Chris, et al. "Easy and accurate reconstruction of whole HIV genomes from short-read sequence data with shiver." *Virus evolution* 4.1 (2018): vey007.

Zsichla, Levente et al. "Comparative Evaluation of Bioinformatic Pipelines for Full-Length Viral Genome Assembly." *preprint, bioRxiv* (2024)
