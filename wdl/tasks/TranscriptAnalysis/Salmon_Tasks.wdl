version 1.0

task RunSalmonQuantTask {

    meta {
        description : "Quantify transcripts from RNA transcript reads using SALMON."
        author : "Jonn Smith"
        email : "jonn@broadinstitute.org"
    }

    input {
        File reads_fasta
        File salmon_index_tar_gz

        String? extra_args
    }

    parameter_meta {
        reads_fasta : "FASTA/FASTQ file containing unaligned reads."
        salmon_index_tar_gz : "SALMON index file corresponding to the transcripts FASTA file used to quantify the transcripts in the reads (TAR.GZ format)."

        extra_args : "[optional] Extra arguments to pass to SALMON after the rest of the command line has been given."
    }

    String out_prefix = basename(reads_fasta, ".fasta")

    String extra_args_arg = select_first([extra_args, ""])

    # 10x for the decompressed file size
    # 3x for salmon index files
    # 10 for baseline size
    Int disk_size = 10*ceil(size(reads_fasta, "GB"))*2 + (3 * ceil(size(salmon_index_tar_gz, "GB"))) + 10

    command <<<
        index_folder=$( tar -tvf ~{salmon_index_tar_gz}  | head -n1 | awk '{print $NF}' )
        tar -xf ~{salmon_index_tar_gz}

        salmon quant -lSR --dumpEq  -i $index_folder -r ~{reads_fasta} --validateMappings -o out_folder ~{extra_args_arg}

        # In the event that the salmon process does not align anything,
        # we still want to succeed, but we want to make our files empty:
        for f in "out_folder/quant.sf" "out_folder/cmd_info.json" "out_folder/lib_format_counts.json" "out_folder/aux_info/ambig_info.tsv" "out_folder/aux_info/eq_classes.txt.gz" "out_folder/aux_info/expected_bias.gz" "out_folder/aux_info/fld.gz" "out_folder/aux_info/meta_info.json" "out_folder/aux_info/observed_bias.gz" "" "out_folder/aux_info/observed_bias_3p.gz" "" "out_folder/logs/salmon_quant.log" ; do
          if [ ! -e $f ] ; then
            echo "Run did not produce output file: $f"
            echo "Creating empty file."
            touch $f
          fi
        done

        # Rename the output files by the fasta name:
        mv out_folder/quant.sf out_folder/~{out_prefix}_quant.sf
        mv out_folder/cmd_info.json out_folder/~{out_prefix}_cmd_info.json
        mv out_folder/lib_format_counts.json out_folder/~{out_prefix}_lib_format_counts.json
        mv out_folder/aux_info/ambig_info.tsv out_folder/aux_info/~{out_prefix}_ambig_info.tsv
        mv out_folder/aux_info/eq_classes.txt.gz out_folder/aux_info/~{out_prefix}_eq_classes.txt.gz
        mv out_folder/aux_info/expected_bias.gz out_folder/aux_info/~{out_prefix}_expected_bias.gz
        mv out_folder/aux_info/fld.gz out_folder/aux_info/~{out_prefix}_fld.gz
        mv out_folder/aux_info/meta_info.json out_folder/aux_info/~{out_prefix}_meta_info.json
        mv out_folder/aux_info/observed_bias.gz out_folder/aux_info/~{out_prefix}_observed_bias.gz
        mv out_folder/aux_info/observed_bias_3p.gz out_folder/aux_info/~{out_prefix}_observed_bias_3p.gz
        mv out_folder/logs/salmon_quant.log out_folder/logs/~{out_prefix}_salmon_quant.log
    >>>

    output {
        File quant_file = "out_folder/~{out_prefix}_quant.sf"
        File cmd_info = "out_folder/~{out_prefix}_cmd_info.json"
        File lib_format_counts = "out_folder/~{out_prefix}_lib_format_counts.json"

        File ambig_info  = "out_folder/aux_info/~{out_prefix}_ambig_info.tsv"
        File eq_classes  = "out_folder/aux_info/~{out_prefix}_eq_classes.txt.gz"
        File expected_bias  = "out_folder/aux_info/~{out_prefix}_expected_bias.gz"
        File fld  = "out_folder/aux_info/~{out_prefix}_fld.gz"
        File meta_info  = "out_folder/aux_info/~{out_prefix}_meta_info.json"
        File observed_bias  = "out_folder/aux_info/~{out_prefix}_observed_bias.gz"
        File observed_bias_3p  = "out_folder/aux_info/~{out_prefix}_observed_bias_3p.gz"

        File log = "out_folder/logs/~{out_prefix}_salmon_quant.log"
    }

    runtime {
        docker: "combinelab/salmon"
        memory: 16 + " GiB"
        disks: "local-disk " + disk_size + " HDD"
        boot_disk_gb: 10
        preemptible: 0
        cpu: 8
    }
}
