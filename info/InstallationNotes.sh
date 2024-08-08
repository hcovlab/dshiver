# MAC OS NOTES FURTHER DOWN.

####################################################################################################
# INSTALLATION INSTRUCTIONS ON UBUNTU LINUX

# Preliminaries
sudo apt install python-pip
pip install --upgrade pip
sudo apt install python3-pip
sudo apt install git
cd ~

# fastaq
pip3 install pyfastaq

# biopython
sudo pip install biopython

# The command below retrieves pre-compiled binaries for blast version 2.7.1; to check that this is
#the latest version, visit ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/
wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/LATEST/ncbi-blast-2.7.1+-x64-linux.tar.gz
tar -xzf ncbi-blast-2.7.1+-x64-linux.tar.gz
echo 'PATH=$PATH:~/ncbi-blast-2.7.1+/bin/' >> ~/.bashrc; source ~/.bashrc
# NB you can also download the blast source code and compile it, but doing this I encountered an
# error I couldn't fix. 

# samtools. Check which is the latest version at http://www.htslib.org/download/; below I assume
# it's 1.6.
sudo apt-get install zlib1g-dev libbz2-dev liblzma-dev
wget https://github.com/samtools/samtools/releases/download/1.6/samtools-1.6.tar.bz2
tar -xjf samtools-1.6.tar.bz2 
cd samtools-1.6/
./configure
make
make install
echo 'PATH=$PATH:~/samtools-1.6/' >> ~/.bashrc; source ~/.bashrc
cd ~

# mafft. Check which is the latest version at https://mafft.cbrc.jp/alignment/software/source.html;
# below I assume it's 7.313.
wget https://mafft.cbrc.jp/alignment/software/mafft-7.313-without-extensions-src.tgz
tar -xzf mafft-7.313-without-extensions-src.tgz
cd mafft-7.313-without-extensions/core/
make clean
make
sudo make install
cd ~

# Optional: if you are going to use shiver's option to trim reads for quality and adapter
# sequences, you need Trimmomatic, which requires java.
sudo apt-get install default-jre
# Check which is the latest version of Trimmomatic at
# http://www.usadellab.org/cms/?page=trimmomatic; below I assume it's 0.36.
wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.36.zip
unzip Trimmomatic-0.36.zip
# The 'trimmomatic' variable in shiver's config file tells shiver what command is needed to run
# trimmomatic. You need to do one of the following two things, whichever you like more.
# (1) change the value of that variable to "java -jar $HOME/Trimmomatic-0.36/trimmomatic-0.36.jar"; or
# (2) copy the file called 'trimmomatic' from shiver's tools directory into your
# $HOME/Trimmomatic-0.36/ directory, then add $HOME/Trimmomatic-0.36/ to your PATH variable
# e.g. with
# echo 'PATH=$PATH:~/Trimmomatic-0.36/' >> ~/.bashrc; source ~/.bashrc
# This means that running the command 'trimmomatic' in a terminal is equivalent to running
# "java -jar $HOME/Trimmomatic-0.36/trimmomatic-0.36.jar", and you can leave the trimmomatic
# varible in shiver's config file as its default value.

# By default, shiver uses smalt to map reads. Alternatively you can use BWA or bowtie2;
# at least one of these three mappers needs to be installed

# smalt
wget https://sourceforge.net/projects/smalt/files/latest/download -O smalt.tgz
tar -xzf smalt.tgz
# the above command should have created a directory named like smalt-XXX, where XXX is the
# version number. The command below assumes that this is 0.7.6.
cd smalt-0.7.6/
./configure
make
sudo make install
cd ~

# BWA
git clone https://github.com/lh3/bwa.git
cd bwa
make
echo 'PATH=$PATH:~/bwa/' >> ~/.bashrc; source ~/.bashrc

# bowtie2
# See which is the latest version at http://bowtie-bio.sourceforge.net/bowtie2/index.shtml;
# below I assume it's 2.3.3.1
wget https://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.3.3.1/bowtie2-2.3.3.1-linux-x86_64.zip/download -O bowtie2.zip 
unzip bowtie2.zip
echo 'PATH=$PATH:~/bowtie2-2.3.3.1-linux-x86_64/' >> ~/.bashrc; source ~/.bashrc

####################################################################################################



####################################################################################################
# INSTALLATION NOTES ON MAC OS

# Trimmomatic binary downloaded from http://www.usadellab.org/cms/?page=trimmomatic

# Subsequently, command-line based installation:

# xcode
xcode-select --install

# home brew: 
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Newer MacOS versions do not contain python2, which shiver requires.
# It can be installed from here: https://www.python.org/downloads/release/python-2718/

# My MacOS had python3 installed already (at least after installing xcode) so the command
# below was unnessecary 
brew install python3

# fastaq
pip3 install pyfastaq

# biopython needs to be installed into your python2.
# version 1.76 is the latest version for which that was supported.
python2 -m pip install biopython==1.76

# smalt: one of the two commands below might work...
brew install smalt
brew install brewsci/bio/smalt
# ...if not, see installation instructions at https://www.sanger.ac.uk/tool/smalt-0/

# blast
brew install blast

# samtools
brew install samtools

# mafft
brew install mafft


####################################################################################################
