FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y build-essential curl python3 python3-dev \
    python3-setuptools git zip unzip wget tar bzip2 zlib1g-dev libbz2-dev bc \
    liblzma-dev default-jre dh-autoreconf ruby && \
    rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3 && \
    pip3 install --upgrade pip && \
    pip3 install pyfastaq biopython xlsxwriter requests

RUN cd ~ && \
    wget ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.7.1/ncbi-blast-2.7.1+-x64-linux.tar.gz && \
    tar -xzf ncbi-blast-2.7.1+-x64-linux.tar.gz && \
    cp ncbi-blast-2.7.1+/bin/* /usr/bin/ && \
    cd ~ && rm -rf ncbi-blast-2.7.1+ && rm -rf ncbi-blast-2.7.1+-x64-linux.tar.gz

RUN cd ~ && \
    wget https://github.com/samtools/samtools/releases/download/1.6/samtools-1.6.tar.bz2 && \
    tar -xjf samtools-1.6.tar.bz2 && \
    cd samtools-1.6/ && \
    ./configure --without-curses && \
    make && \
    make install && \
    cd ~ && rm -rf samtools-1.6 && rm -rf samtools-1.6.tar.bz2

RUN cd ~ && \
    wget https://mafft.cbrc.jp/alignment/software/mafft-7.505-without-extensions-src.tgz && \
    tar -xzf mafft-7.505-without-extensions-src.tgz && \
    cd mafft-7.505-without-extensions/core/ && \
    make clean && \
    make && \
    make install && \
    cd ~ && rm -rf mafft-7.505-without-extensions-src.tgz && rm -rf mafft-7.505-without-extensions

RUN cd ~ && \
    wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.36.zip && \
    unzip Trimmomatic-0.36.zip && \
    cd Trimmomatic-0.36 && \
    cp trimmomatic-0.36.jar /usr/bin/.  && \
    ln -s /usr/bin/trimmomatic-0.36.jar /usr/bin/trimmomatic.jar && \
    echo "#!/bin/bash\njava -jar /usr/bin/trimmomatic.jar \"\$@\"\n" > /usr/bin/trimmomatic && \
    chmod +x /usr/bin/trimmomatic && \
    cp -r adapters /usr/bin/adapters && \
    cd ~ && rm -rf Trimmomatic-0.36 && rm -rf Trimmomatic-0.36.zip

RUN cd ~ && \
    wget https://sourceforge.net/projects/smalt/files/latest/download -O smalt.tgz && \
    tar -xzf smalt.tgz && \
    cd $(ls | grep smalt-) && \
    ./configure && \
    make && \
    make install && \
    cd ~ && rm -rf $(ls | grep smalt-) && rm -rf smalt.tgz

RUN cd ~ && \
    git clone https://github.com/lh3/bwa.git && \
    cd bwa && \
    make && \
    cp bwa /usr/bin/. && \
    cd ~ && rm -rf bwa

RUN cd ~ && \
    wget https://sourceforge.net/projects/bowtie-bio/files/bowtie2/2.3.3.1/bowtie2-2.3.3.1-linux-x86_64.zip/download -O bowtie2.zip && \
    unzip bowtie2.zip && \
    cd bowtie2-2.3.3.1-linux-x86_64 && \
    cp bowtie2* /usr/bin/. && \
    cd ~ && rm -rf bowtie2-2.3.3.1-linux-x86_64 && rm -rf bowtie2.zip

RUN cd ~ && \
    git clone https://github.com/refresh-bio/KMC.git && \
    cd KMC && \
    make && \
    cp bin/* /usr/bin/ && \
    cd ~ && rm -rf KMC

RUN cd ~ && \
    wget https://github.com/gmarcais/yaggo/releases/download/v1.5.9/yaggo && \
    chmod a+rx yaggo && \
    mv yaggo /usr/bin/. && \
    git clone https://github.com/mummer4/mummer.git && \
    cd mummer && \
    git checkout v4.0.0beta2 && \
    autoreconf -fi && \
    ./configure && \
    make && \
    make install && \
    ldconfig && \
    cd ~ && rm -rf mummer

RUN pip3 install iva

COPY . /shiver
RUN chmod +x /shiver/pipeline.sh && \
    mkdir /data && \
    mkdir /data_tmp

WORKDIR /data_tmp
ENTRYPOINT ["/shiver/pipeline.sh"]
CMD ["help"]

