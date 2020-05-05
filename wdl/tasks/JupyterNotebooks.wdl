version 1.0

import "Structs.wdl"

task PB10xMasSeqSingleFlowcellReport {
    input {
        File notebook_template

        File subreads_stats
        File ccs_reads_stats
        File array_elements_stats
        File ccs_report_file

        File ccs_bam_file
        File array_element_bam_file

        File ebr_element_marker_alignments
        File ebr_initial_section_alignments
        File ebr_final_section_alignments
        File ebr_bounds_file

        File ten_x_metrics_file
        File rna_seq_metrics_file

        File workflow_dot_file

        String prefix = ""
        RuntimeAttr? runtime_attr_override
    }

    String nb_name = prefix + "report.ipynb"
    String html_out = prefix + "report.html"
    String pdf_out = prefix + "report.pdf"

    Int disk_size = 20 + 8*ceil((
            size(notebook_template, "GB") +
            size(subreads_stats, "GB") +
            size(ccs_reads_stats, "GB") +
            size(ccs_report_file, "GB") +
            size(ccs_bam_file, "GB") +
            size(array_element_bam_file, "GB") +
            size(ebr_element_marker_alignments, "GB") +
            size(ebr_initial_section_alignments, "GB") +
            size(ebr_final_section_alignments, "GB") +
            size(ebr_bounds_file, "GB") +
            size(ccs_bam_file, "GB") +
            size(ten_x_metrics_file, "GB") +
            size(rna_seq_metrics_file, "GB") +
            size(workflow_dot_file, "GB")
        ))

    command <<<
        set -euxo pipefail

        # Copy the notebook template to our current folder:
        cp ~{notebook_template} ~{nb_name}

        # Create a template to create the html report with collapsed code:
        echo "{%- extends 'full.tpl' -%}" > hidecode.tpl
        echo "" >> hidecode.tpl
        echo "{% block input_group %}" >> hidecode.tpl
        echo "    {%- if cell.metadata.get('nbconvert', {}).get('show_code', False) -%}" >> hidecode.tpl
        echo "        ((( super() )))" >> hidecode.tpl
        echo "    {%- endif -%}" >> hidecode.tpl
        echo "{% endblock input_group %}" >> hidecode.tpl

        # Set some environment variables for the notebook to read in:
        export DATE_RUN=$()
        export WDL_NAME="PB10xMasSeqArraySingleFlowcell.wdl"
        export REPO_INFO="git@github.com:broadinstitute/long-read-pipelines.git"

        # Prepare the config file:
        rm -f mas-seq_qc_inputs.config

        echo "~{subreads_stats}" >> mas-seq_qc_inputs.config
        echo "~{ccs_reads_stats}" >> mas-seq_qc_inputs.config
        echo "~{array_elements_stats}" >> mas-seq_qc_inputs.config
        echo "~{ccs_report_file}" >> mas-seq_qc_inputs.config

        echo "~{ccs_bam_file}" >> mas-seq_qc_inputs.config
        echo "~{array_element_bam_file}" >> mas-seq_qc_inputs.config

        echo "~{ebr_element_marker_alignments}" >> mas-seq_qc_inputs.config
        echo "~{ebr_initial_section_alignments}" >> mas-seq_qc_inputs.config
        echo "~{ebr_final_section_alignments}" >> mas-seq_qc_inputs.config
        echo "~{ebr_bounds_file}" >> mas-seq_qc_inputs.config

        echo "~{ten_x_metrics_file}" >> mas-seq_qc_inputs.config
        echo "~{rna_seq_metrics_file}" >> mas-seq_qc_inputs.config

        echo "~{workflow_dot_file}" >> mas-seq_qc_inputs.config

        # Do the conversion:

        # Run the notebook and populate the notebook itself:
        jupyter nbconvert --execute ~{nb_name} --to notebook --inplace --no-prompt --no-input --clear-output --debug --ExecutePreprocessor.timeout=3600

        # Convert the notebook output we created just above here to the HTML report:
        jupyter nbconvert ~{nb_name} --to html --no-prompt --no-input --debug --ExecutePreprocessor.timeout=3600

        # One more for good measure - make a PDF so we don't need to wait for the browser all the time.
        jupyter nbconvert ~{nb_name} --to pdf --no-prompt --no-input --debug --ExecutePreprocessor.timeout=3600
    >>>

    output {
        File populated_notebook = nb_name
        File html_report = html_out
        File pdf_report = pdf_out
    }

    #########################
    RuntimeAttr default_attr = object {
        cpu_cores:          1,
        mem_gb:             64,
        disk_gb:            disk_size,
        boot_disk_gb:       10,
        preemptible_tries:  0,
        max_retries:        1,
        docker:             "jonnsmith/jupyternotebook_interactive:latest"
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
    runtime {
        cpu:                    select_first([runtime_attr.cpu_cores,         default_attr.cpu_cores])
        memory:                 select_first([runtime_attr.mem_gb,            default_attr.mem_gb]) + " GiB"
        disks: "local-disk " +  select_first([runtime_attr.disk_gb,           default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb:         select_first([runtime_attr.boot_disk_gb,      default_attr.boot_disk_gb])
        preemptible:            select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries:             select_first([runtime_attr.max_retries,       default_attr.max_retries])
        docker:                 select_first([runtime_attr.docker,            default_attr.docker])
    }
}
