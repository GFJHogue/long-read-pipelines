version 1.0

import "tasks/JupyterNotebooks.wdl" as JUPYTER

workflow PB10xMasSeqSingleFlowcellReport {
    input {
        File notebook_template              = "gs://broad-dsde-methods-long-reads/covid-19-aziz/MAS-seq_QC_report_template-interactive.ipynb"
        File subreads_stats
        File ccs_reads_stats
        File array_elements_stats
        File ccs_report_file
        File ccs_bam_file
        File array_element_bam_file
        File ebr_element_marker_alignments
        File ebr_initial_section_alignments
        File ebr_final_section_alignments
        File ebr_bounds_file                = "gs://broad-dsde-methods-long-reads/covid-19-aziz/bounds_file_for_extraction.txt"
        File ten_x_metrics_file
        File rna_seq_metrics_file
        File workflow_dot_file              = "gs://broad-dsde-methods-long-reads/covid-19-aziz/PB10xMasSeqArraySingleFlowcell.dot"
    }

    ## NOTE: This assumes ONE file for both the raw input and the 10x array element stats!
    ##       This should be fixed in version 2.
    call JUPYTER.PB10xMasSeqSingleFlowcellReport as GenerateReport {
        input:
            notebook_template              = notebook_template,

            subreads_stats                 = subreads_stats,
            ccs_reads_stats                = ccs_reads_stats,
            array_elements_stats           = array_elements_stats,
            ccs_report_file                = ccs_report_file,

            ccs_bam_file                   = ccs_bam_file,
            array_element_bam_file         = array_element_bam_file,

            ebr_element_marker_alignments  = ebr_element_marker_alignments,
            ebr_initial_section_alignments = ebr_initial_section_alignments,
            ebr_final_section_alignments   = ebr_final_section_alignments,
            ebr_bounds_file                = ebr_bounds_file,

            ten_x_metrics_file             = ten_x_metrics_file,
            rna_seq_metrics_file           = rna_seq_metrics_file,

            workflow_dot_file              = workflow_dot_file,
    }
}