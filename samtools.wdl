version 1.0

# Copyright (c) 2017 Leiden University Medical Center
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

task BgzipAndIndex {
    input {
        File inputFile
        String outputDir
        String type = "vcf"

        Int timeMinutes = 1 + ceil(size(inputFile, "G"))
        String dockerImage = "quay.io/biocontainers/tabix:0.2.6--ha92aebf_0"
    }

    String outputGz = outputDir + "/" + basename(inputFile) + ".gz"

    command {
        set -e
        mkdir -p "$(dirname ~{outputGz})"
        bgzip -c ~{inputFile} > ~{outputGz}
        tabix ~{outputGz} -p ~{type}
    }

    output {
        File compressed = outputGz
        File index = outputGz + ".tbi"
    }

    runtime {
        time_minutes: timeMinutes
        docker: dockerImage
    }

    parameter_meta {
        # inputs
        inputFile: {description: "The file to be compressed and indexed.", category: "required"}
        outputDir: {description: "The directory in which the output will be placed.", category: "required"}
        type: {description: "The type of file (eg. vcf or bed) to be compressed and indexed.", category: "common"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task Faidx {
    input {
        File inputFile
        String outputDir

        String memory = "2G"
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    command {
        set -e
        mkdir -p "~{outputDir}"
        ln -s ~{inputFile} "~{outputDir}/$(basename ~{inputFile})"
        samtools faidx \
        "~{outputDir}/$(basename ~{inputFile})"
    }

    output {
        File outputIndex = outputDir + "/" + basename(inputFile) + ".fai"
    }

    runtime {
        memory: memory
        docker: dockerImage
    }

    parameter_meta {
        # inputs
        inputFile: {description: "The input fasta file.", category: "required"}
        outputDir: {description: "Output directory path.", category: "required"}
        memory: {description: "The amount of memory available to the job.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.", category: "advanced"}

        # outputs
        outputIndex: {description: "Index of the input fasta file."}
    }
}

task Fastq {
    input {
        File inputBam
        String outputRead1
        String? outputRead2
        String? outputRead0
        Int? includeFilter
        Int? excludeFilter
        Int? excludeSpecificFilter
        Boolean appendReadNumber = false
        Boolean outputQuality = false
        Int? compressionLevel

        Int threads = 1
        String memory = "1G"
        Int timeMinutes = 1 + ceil(size(inputBam) * 2)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    command {
        samtools fastq \
        ~{true="-1" false="-s" defined(outputRead2)} ~{outputRead1} \
        ~{"-2 " + outputRead2} \
        ~{"-0 " + outputRead0} \
        ~{"-f " + includeFilter} \
        ~{"-F " + excludeFilter} \
        ~{"-G " + excludeSpecificFilter} \
        ~{true="-N" false="-n" appendReadNumber} \
        ~{true="-O" false="" outputQuality} \
        ~{"-c " + compressionLevel} \
        ~{"--threads " + threads} \
        ~{inputBam}
    }

    output {
        File read1 = outputRead1
        File? read2 = outputRead2
        File? read0 = outputRead0
    }

    runtime {
        cpu: threads
        memory: memory
        docker: dockerImage
        time_minutes: timeMinutes
    }

    parameter_meta {
        # inputs
        inputBam: {description: "The bam file to process.", category: "required"}
        outputRead1: {description: "The location the reads (first reads for pairs, in case of paired-end sequencing) should be written to.", category: "required"}
        outputRead2: {description: "The location the second reads from pairs should be written to.", category: "common"}
        outputRead0: {description: "The location the unpaired reads should be written to (in case of paired-end sequenicng).", category: "advanced"}
        includeFilter: {description: "Include reads with ALL of these flags. Corresponds to `-f`", category: "advanced"}
        excludeFilter: {description: "Exclude reads with ONE OR MORE of these flags. Corresponds to `-F`", category: "advanced"}
        excludeSpecificFilter: {description: "Exclude reads with ALL of these flags. Corresponds to `-G`", category: "advanced"}
        appendReadNumber: {description: "Append /1 and /2 to the read name, or don't. Corresponds to `-n/N`", category: "advanced"}
        outputQuality: {description: "Equivalent to samtools fastq's `-O` flag.", category: "advanced"}
        threads: {description: "The number of threads to use.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task FilterShortReadsBam {
    input {
        File bamFile
        String outputPathBam
        String memory = "1G"
        Int timeMinutes = 1 + ceil(size(bamFile, "G") * 8)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    String outputPathBamIndex = sub(outputPathBam, "\.bam$", ".bai")

    command {
        set -e
        mkdir -p "$(dirname ~{outputPathBam})"
        samtools view -h ~{bamFile} | \
        awk 'length($10) > 30 || $1 ~/^@/' | \
        samtools view -bS -> ~{outputPathBam}
        samtools index ~{outputPathBam} ~{outputPathBamIndex}
    }

    output {
        File filteredBam = outputPathBam
        File filteredBamIndex = outputPathBamIndex
    }

    runtime {
        memory: memory
        time_minutes: timeMinutes
        docker: dockerImage
    }

    parameter_meta {
        bamFile: {description: "The bam file to process.", category: "required"}
        outputPathBam: {description: "The filtered bam file.", category: "common"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.", category: "advanced"}
    }
}

task Flagstat {
    input {
        File inputBam
        String outputPath

        String memory = "256M"  # Only 40.5 MiB used for 150G bam file.
        Int timeMinutes = 1 + ceil(size(inputBam, "G"))
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputPath})"
        samtools flagstat ~{inputBam} > ~{outputPath}
    }

    output {
        File flagstat = outputPath
    }

    runtime {
        memory: memory
        time_minutes: timeMinutes
        docker: dockerImage
    }

    parameter_meta {
        # inputs
        inputBam: {description: "The BAM file for which statistics should be retrieved.", category: "required"}
        outputPath: {description: "The location the ouput should be written to.", category: "required"}
        memory: {description: "The amount of memory needed for the job.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task Index {
    input {
        File bamFile
        String? outputBamPath
        String memory = "2G"
        Int timeMinutes = 1 + ceil(size(bamFile, "G") * 4)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    # Select_first is needed, otherwise womtool validate fails.
    String outputPath = select_first([outputBamPath, basename(bamFile)])
    String bamIndexPath = sub(outputPath, "\.bam$", ".bai")

    command {
        bash -c '
        set -e
        # Make sure outputBamPath does not exist.
        if [ ! -f ~{outputPath} ]
        then
            mkdir -p "$(dirname ~{outputPath})"
            ln ~{bamFile} ~{outputPath}
        fi
        samtools index ~{outputPath} ~{bamIndexPath}
        '
    }

    output {
        File indexedBam = outputPath
        File index =  bamIndexPath
    }

    runtime {
        memory: memory
        time_minutes: timeMinutes
        docker: dockerImage
    }

    parameter_meta {
        # inputs
        bamFile: {description: "The BAM file for which an index should be made.", category: "required"}
        outputBamPath: {description: "The location where the BAM file should be written to. The index will appear alongside this link to the BAM file.",
                        category: "common"}
        memory: {description: "The amount of memory needed for the job.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task Markdup {
    input {
        File inputBam
        String outputBamPath

        Int timeMinutes = 1 + ceil(size(inputBam, "G") * 2)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }

    command {
        set -e
        mkdir -p "$(dirname ~{outputBamPath})"
        samtools markdup ~{inputBam} ~{outputBamPath}
    }

    output {
        File outputBam = outputBamPath
    }

    runtime {
        docker: dockerImage
        time_minutes: timeMinutes
    }

    parameter_meta {
        # inputs
        inputBam: {description: "The BAM file to be processed.", category: "required"}
        outputBamPath: {description: "The location of the output BAM file.", category: "required"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task Merge {
    input {
        Array[File]+ bamFiles
        String outputBamPath = "merged.bam"
        Boolean force = true
        Int threads = 1

        Int timeMinutes = 1 + ceil(size(bamFiles, "G") * 2)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }
    String indexPath = sub(outputBamPath, "\.bam$",".bai")

    # Samtools uses additional threads for merge.
    command {
        set -e
        mkdir -p "$(dirname ~{outputBamPath})"
        samtools merge \
        --threads ~{threads - 1} \
        ~{true="-f" false="" force} \
        ~{outputBamPath} ~{sep=' ' bamFiles}
        samtools index ~{outputBamPath} ~{indexPath}
    }

    output {
        File outputBam = outputBamPath
        File outputBamIndex = indexPath
    }

    runtime {
        cpu: threads
        docker: dockerImage
        time_minutes: timeMinutes
    }

    parameter_meta {
        # inputs
        bamFiles: {description: "The BAM files to merge.", category: "required"}
        outputBamPath: {description: "The location the merged BAM file should be written to.", category: "common"}
        force: {description: "Equivalent to samtools merge's `-f` flag.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task Sort {
    input {
        File inputBam
        String outputPath = basename(inputBam, "\.bam") + ".sorted.bam"
        Boolean sortByName = false
        Int compressionLevel = 1
        Int threads = 1
        Int memoryPerThreadGb = 4
        Int memoryGb = 1 + threads * memoryPerThreadGb
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
        Int timeMinutes = 1 + ceil(size(inputBam, "G") * 3)
    }

    # Select first needed as outputPath is optional input. (bug in cromwell)
    String bamIndexPath = sub(select_first([outputPath]), "\.bam$", ".bai")

    command {
        set -e
        mkdir -p "$(dirname ~{outputPath})"
        samtools sort \
        -l ~{compressionLevel} \
        ~{true="-n" false="" sortByName} \
        ~{"--threads " + threads} \
        -m ~{memoryPerThreadGb}G \
        -o ~{outputPath} \
        ~{inputBam}
        samtools index \
        -@ ~{threads} \
        ~{outputPath} ~{bamIndexPath}
    }

    output {
        File outputBam = outputPath
        File outputBamIndex = bamIndexPath
    }

    runtime {
        cpu: 1
        memory: "~{memoryGb}G"
        docker: dockerImage
        time_minutes: timeMinutes
    }

    parameter_meta {
        # inputs
        inputBam: {description: "The input SAM file.", category: "required"}
        outputPath: {description: "Output directory path + output file.", category: "required"}
        sortByName: {description: "Sort the inputBam by read name instead of position.", category: "advanced"}
        compressionLevel: {description: "Compression level from 0 (uncompressed) to 9 (best).", category: "advanced"}
        memoryGb: {description: "The amount of memory available to the job in gigabytes.", category: "advanced"}
        memoryPerThreadGb: {description: "The amount of memory used per sort thread in gigabytes", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.", category: "advanced"}
        threads: {description: "The number of additional threads that will be used for this task.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}

        # outputs
        outputBam: {description: "Sorted BAM file."}
    }
}

task TabixList {
    input {
        File inputFile
        File indexFile
        String dockerImage = "quay.io/biocontainers/tabix:0.2.6--ha92aebf_0" 
    }
    
    command {
        tabix -l ~{inputFile}
    }

    output {
        Array[String] chromosomes = read_lines(stdout())
    }

    runtime {
        docker: dockerImage
    }
}

task Tabix {
    input {
        File inputFile
        String outputFilePath = "indexed.vcf.gz"
        String type = "vcf"
        Int timeMinutes = 1 + ceil(size(inputFile, "G") * 2)
        String dockerImage = "quay.io/biocontainers/tabix:0.2.6--ha92aebf_0"
    }
    # FIXME: It is better to do the indexing on VCF creation. Not in a separate task. With file localization this gets hairy fast.
    command {
        set -e
        mkdir -p "$(dirname ~{outputFilePath})"
        if [ ! -f ~{outputFilePath} ]
        then
            ln ~{inputFile} ~{outputFilePath}
        fi
        tabix ~{outputFilePath} -p ~{type}
    }

    output {
        File indexedFile = outputFilePath
        File index = outputFilePath + ".tbi"
    }

    runtime {
        time_minutes: timeMinutes
       docker: dockerImage
    }

    parameter_meta {
        # inputs
        inputFile: {description: "The file to be indexed.", category: "required"}
        outputFilePath: {description: "The location where the file should be written to. The index will appear alongside this link to the file.",
                        category: "common"}
        type: {description: "The type of file (eg. vcf or bed) to be indexed.", category: "common"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}

task View {
    input {
        File inFile
        File? referenceFasta
        String outputFileName = "view.bam"
        Boolean uncompressedBamOutput = false
        Int? includeFilter
        Int? excludeFilter
        Int? excludeSpecificFilter
        Int? MAPQthreshold

        Int threads = 1
        String memory = "1G"
        Int timeMinutes = 1 + ceil(size(inFile, "G") * 5)
        String dockerImage = "quay.io/biocontainers/samtools:1.10--h9402c20_2"
    }
    String outputIndexPath = basename(outputFileName) + ".bai"

    # Always output to bam and output header
    command {
        set -e
        mkdir -p "$(dirname ~{outputFileName})"
        samtools view -b \
        ~{"-T " + referenceFasta} \
        ~{"-o " + outputFileName} \
        ~{true="-u " false="" uncompressedBamOutput} \
        ~{"-f " + includeFilter} \
        ~{"-F " + excludeFilter} \
        ~{"-G " + excludeSpecificFilter} \
        ~{"-q " + MAPQthreshold} \
        ~{"--threads " + (threads - 1)} \
        ~{inFile}
        samtools index ~{outputFileName} ~{outputIndexPath}
    }

    output {
        File outputBam = outputFileName
        File outputBamIndex = outputIndexPath
    }

    runtime {
        cpu: threads
        memory: memory
        time_minutes: timeMinutes
        docker: dockerImage
    }

    parameter_meta {
        # inputs
        inFile: {description: "A BAM, SAM or CRAM file.", category: "required"}
        referenceFasta: {description: "The reference fasta file also used for mapping.", category: "advanced"}
        outputFileName: {description: "The location the output BAM file should be written.", category: "common"}
        uncompressedBamOutput: {description: "Equivalent to samtools view's `-u` flag.", category: "advanced"}
        includeFilter: {description: "Equivalent to samtools view's `-f` option.", category: "advanced"}
        excludeFilter: {description: "Equivalent to samtools view's `-F` option.", category: "advanced"}
        excludeSpecificFilter: {description: "Equivalent to samtools view's `-G` option.", category: "advanced"}
        MAPQthreshold: {description: "Equivalent to samtools view's `-q` option.", category: "advanced"}
        threads: {description: "The number of threads to use.", category: "advanced"}
        memory: {description: "The amount of memory this job will use.", category: "advanced"}
        timeMinutes: {description: "The maximum amount of time the job will run in minutes.", category: "advanced"}
        dockerImage: {description: "The docker image used for this task. Changing this may result in errors which the developers may choose not to address.",
                      category: "advanced"}
    }
}
