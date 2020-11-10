version 1.0

import "Utils.wdl" as Utils

workflow AnnotateBarcodesAndUMIsWorkflow {
    input {
        File bam_file
        File? bam_index
        File head_adapter_fasta
        File tail_adapter_fasta
        Int read_end_length

        Boolean use_rle = false

        File? whitelist_10x
        File? whitelist_illumina

        Int? poly_t_length
        Int? barcode_length
        Int? umi_length

        Int? boot_disk_size_gb
        Int? cpu
        Int? disk_space_gb
        Int? mem_gb
        Int? preemptible_attempts
    }

    RuntimeAttr shard_runtime_attrs = object {
        disk_gb:            20*ceil(size(bam_file, "GB"))
    }

    call Utils.ShardLongReadsWithCopy {
        input:
            unmapped_files = [ bam_file ],
            num_reads_per_split = 20000,
            runtime_attr_override =  shard_runtime_attrs
    }

    scatter (reads_file in ShardLongReadsWithCopy.unmapped_shards) {

        call AnnotateBarcodesAndUMIs {
            input:
                bam_file = reads_file,
                head_adapter_fasta = head_adapter_fasta,
                tail_adapter_fasta = tail_adapter_fasta,
                read_end_length = read_end_length,
                use_rle = use_rle,
                whitelist_10x = whitelist_10x,
                whitelist_illumina = whitelist_illumina,
                poly_t_length = poly_t_length,
                barcode_length = barcode_length,
                umi_length = umi_length,
                boot_disk_size_gb = boot_disk_size_gb,
                cpu = cpu,
                disk_space_gb = disk_space_gb,
                mem_gb = mem_gb,
                preemptible_attempts = preemptible_attempts,
        }
    }
    
    output {
      Array[File] output_bam        = AnnotateBarcodesAndUMIs.output_bam
      Array[File] barcode_stats     = AnnotateBarcodesAndUMIs.barcode_stats
      Array[File] starcode          = AnnotateBarcodesAndUMIs.starcode
      Array[File] stats             = AnnotateBarcodesAndUMIs.stats
      Array[File] timing_info       = AnnotateBarcodesAndUMIs.timing_info
    }
}


task AnnotateBarcodesAndUMIs {
    input {
        File bam_file
        File? bam_index
        File head_adapter_fasta
        File tail_adapter_fasta
        Int read_end_length

        Boolean use_rle = false

        File? whitelist_10x
        File? whitelist_illumina

        Int? poly_t_length
        Int? barcode_length
        Int? umi_length

        Int? boot_disk_size_gb
        Int? cpu
        Int? disk_space_gb
        Int? mem_gb
        Int? preemptible_attempts
    }

    # ------------------------------------------------
    # Set runtime options:
    String tool_script = if use_rle then "tool_rle.py" else "tool.py"

    String whitelist_10x_arg = if defined(whitelist_10x) then " --whitelist-10x " else ""
    String whitelist_ilmn_arg = if defined(whitelist_illumina) then " --whitelist-illumina " else ""

    String poly_t_len_arg = if defined(poly_t_length) then " --poly-t-length " else ""
    String barcode_len_arg = if defined(barcode_length) then " --barcode-length " else ""
    String umi_len_arg = if defined(umi_length) then " --umi-length " else ""

    String do_index = if defined(bam_index) then "false" else "true"

    # ------------------------------------------------
    # Get machine settings:
    Boolean use_ssd = false

    # You may have to change the following two parameter values depending on the task requirements
    Int default_ram_mb = 16 * 1024

    Float reads_size_gb = size(bam_file, "GiB") + size(bam_index, "GiB")
    Int default_disk_space_gb = ceil((reads_size_gb * 2) + 20)

    Int default_boot_disk_size_gb = 10

    # Mem is in units of GB but our command and memory runtime values are in MB
    Int machine_mem = if defined(mem_gb) then mem_gb * 1024 else default_ram_mb
    Int command_mem = machine_mem - 1024

    String timing_output_file = "timingInformation.txt"

    String output_name = basename(bam_file) + ".10x_annotated"

    command {
        set -e
        startTime=`date +%s.%N`
        echo "StartTime: $startTime" > ~{timing_output_file}

        source activate 10x_tool

        if ~{do_index} ; then
            samtools index ~{bam_file}
        fi

        bwa index ~{head_adapter_fasta}
        bwa index ~{tail_adapter_fasta}

        python /lrma/~{tool_script} \
            --bam=~{bam_file} \
            --adapter=~{head_adapter_fasta} \
            --reverse-adapter=~{tail_adapter_fasta} \
            --name=~{output_name} \
            --read-end-length=~{read_end_length} \
            --record-umis \
            ~{whitelist_10x_arg}~{default="" sep=" --whitelist-10x " whitelist_10x} \
            ~{whitelist_ilmn_arg}~{default="" sep=" --whitelist-illumina " whitelist_illumina} \
            ~{poly_t_len_arg}~{default="" sep=" --poly-t-length " poly_t_length} \
            ~{barcode_len_arg}~{default="" sep=" --barcode-length " barcode_length} \
            ~{umi_len_arg}~{default="" sep=" --umi-length " umi_length}

        endTime=`date +%s.%N`
        echo "EndTime: $endTime" >> ~{timing_output_file}

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
    runtime {
        docker: "jonnsmith/lrma_10x_tool:latest"
        memory: machine_mem + " MB"
        disks: "local-disk " + select_first([disk_space_gb, default_disk_space_gb]) + if use_ssd then " SSD" else " HDD"
        bootDiskSizeGb: select_first([boot_disk_size_gb, default_boot_disk_size_gb])
        preemptible: 0
        cpu: select_first([cpu, 1])
    }
    output {
      File output_bam        = "${output_name}.bam"
      File barcode_stats     = "${output_name}_barcode_stats.tsv"
      File starcode          = "${output_name}_starcode.tsv"
      File stats             = "${output_name}_stats.tsv"
      File timing_info       = "${timing_output_file}"
    }
}