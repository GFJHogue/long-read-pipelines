version 1.0

# Run extract_bounded_read_sections on a dataset to map out known and unknown segments of reads.
#
# Description of inputs:
#
#   Required:
#     File reads_file            - SAM/BAM/FASTA/FASTQ file containing reads for which to determine the layout.
#     File segments_fasta        - FASTA file containing the sequences and names of known possible segments in the reads.
#     File boundaries_file       - A plain text file with two comma separated sequence names per line.  The names should correspond to the sequence names in the given sequence FASTA file.
#
#   Optional:
#     Int max_read_lenmgth       - The read length beyond which a read will not be processed.
#     Float min_qual             - Minimum quality for good alignment.
#     Int min_bases              - Minimum number of bases for an alignment to be retained.
#     Float prec_known           - Probability of recombination for known segment alignment.
#     Float prec_unknown         - Probability of recombination for UNKNOWN segment alignment.
#     Boolean use_mosaic_aligner - If True, will use MosaicAligner instead of Tesserae for alignments.
#
#   Runtime:
#     Int  mem                   - Amount of memory to give to the machine running each task in this workflow.
#     Int  preemptible_attempts  - Number of times to allow each task in this workflow to be preempted.
#     Int  disk_space_gb         - Amount of storage disk space (in Gb) to give to each machine running each task in this workflow.
#     Int  cpu                   - Number of CPU cores to give to each machine running each task in this workflow.
#     Int  boot_disk_size_gb     - Amount of boot disk space (in Gb) to give to each machine running each task in this workflow.
#
task ExtractBoundedReadSectionsTask {

    input {
        # ------------------------------------------------
        # Input args:
        # Required:

        File reads_file
        File segments_fasta
        File boundaries_file

        Int? max_read_length
        Float? min_qual
        Int? min_bases
        Float? prec_known
        Float? prec_unknown

        Int? mem_gb
        Int? preemptible_attempts
        Int? disk_space_gb
        Int? cpu
        Int? boot_disk_size_gb
    }

    # Docker image:
    String docker_image = "jonnsmith/lrma_cartographer:latest"

    # ------------------------------------------------
    # Process input args:

    String log_file_name = "extract_bounded_read_sections.log"
    String timing_output_file = "timingInformation.txt"
    String memory_log_file = "memory_log.txt"

    String max_read_length_arg = if defined(max_read_length) then " --max_read_length " else ""
    String min_qual_arg = if defined(min_qual) then " --minqual " else ""
    String min_bases_arg = if defined(min_bases) then " --minbases " else ""
    String prec_known_arg = if defined(prec_known) then " --prec_known " else ""
    String prec_unknown_arg = if defined(prec_unknown) then " --prec_unknown " else ""

    # ------------------------------------------------
    # Get machine settings:
    Boolean use_ssd = false

    Float input_files_size_gb = size(reads_file, "GiB") + size(segments_fasta, "GiB") + size(boundaries_file, "GiB")

    # You may have to change the following two parameter values depending on the task requirements
    Int default_ram_mb = 8192
    Int default_disk_space_gb = ceil((input_files_size_gb * 2) + 1024)

    Int default_boot_disk_size_gb = 15

    # Mem is in units of GB but our command and memory runtime values are in MB
    Int machine_mem = if defined(mem_gb) then mem_gb * 1024 else default_ram_mb

    # ------------------------------------------------
    # Run our command:
    command {
        # Set up memory logging daemon:
        MEM_LOG_INTERVAL_s=5
        DO_MEMORY_LOG=true
        while $DO_MEMORY_LOG ; do
            date
            date +%s
            cat /proc/meminfo
            sleep $MEM_LOG_INTERVAL_s
        done >> ~{memory_log_file} &
        mem_pid=$!

        set -e

        # Do the real work here:
        startTime=`date +%s.%N`
        echo "StartTime: $startTime" > ~{timing_output_file}

        /usr/bin/time -v /cartographer/extract_bounded_read_sections.py -v \
            -r ~{reads_file} \
            -s ~{segments_fasta} \
            -b ~{boundaries_file} \
            ~{max_read_length_arg}~{default="" sep=" --max_read_length " max_read_length} \
            ~{min_qual_arg}~{default="" sep=" --minqual " min_qual} \
            ~{min_bases_arg}~{default="" sep=" --minbases " min_qual} \
            ~{prec_known_arg}~{default="" sep=" --prec_known " prec_known} \
            ~{prec_unknown_arg}~{default="" sep=" --prec_unknown " prec_unknown} \
            --aligner BWA_MEM \
            2>&1 | tee ~{log_file_name}

        endTime=`date +%s.%N`
        echo "EndTime: $endTime" >> ~{timing_output_file}

        # Stop the memory daemon softly.  Then stop it hard if it's not cooperating:
        set +e
        DO_MEMORY_LOG=false
        sleep $(($MEM_LOG_INTERVAL_s  * 2))
        kill -0 $mem_pid &> /dev/null
        if [ $? -ne 0 ] ; then
            kill -9 $mem_pid
        fi

        # Get and compute timing information:
        set +e
        elapsedTime=""
        which bc &> /dev/null ; bcr=$?
        which python3 &> /dev/null ; python3r=$?
        which python &> /dev/null ; pythonr=$?
        if [[ $bcr -eq 0 ]] ; then elapsedTime=`echo "scale=6;$endTime - $startTime" | bc`;
        elif [[ $python3r -eq 0 ]] ; then elapsedTime=`python3 -c "print( $endTime - $startTime )"`;
        elif [[ $pythonr -eq 0 ]] ; then elapsedTime=`python -c "print( $endTime - $startTime )"`;
        fi
        echo "Elapsed Time: $elapsedTime" >> ~{timing_output_file}
    }

    # ------------------------------------------------
    # Runtime settings:
     runtime {
         docker: docker_image
         memory: machine_mem + " MB"
         disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + if use_ssd then " SSD" else " HDD"
         bootDiskSizeGb: select_first([boot_disk_size_gb, default_boot_disk_size_gb])
         preemptible: select_first([preemptible_attempts, 0])
         cpu: select_first([cpu, 1])
     }

    # ------------------------------------------------
    # Outputs:
    output {
      # Default output file name:
      File extracted_reads            = "extracted_bounded_sub_reads.fasta"
      File rejected_reads             = "extracted_bounded_sub_reads.rejected.fasta"
      File raw_marker_alignments      = "extracted_bounded_sub_reads.raw_marker_alignments.txt"
      File initial_section_alignments = "extracted_bounded_sub_reads.initial_section_alignments.txt"
      File final_section_alignments   = "extracted_bounded_sub_reads.final_section_alignments.txt"
      File log_file                   = "${log_file_name}"
      File timing_info                = "${timing_output_file}"
      File memory_log                 = "${memory_log_file}"
    }
 }

