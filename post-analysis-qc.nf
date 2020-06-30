#!/usr/bin/env nextflow

Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:',', quote:'"')
    .map{ row-> tuple(row.sample, row.barcode, row.min_length, row.max_length, row.primer_scheme) }
    .into{ samples_bedtools_coverage_ch }

primer_scheme_dir_ch = Channel.fromPath(params.scheme_dir, type: 'dir').first()

artic_output_dir_ch = Channel.fromPath(params.artic_output_dir, type: 'dir').first()

def summary = [:]
summary['Pipeline Name']  = 'post-artic-qc'
summary['Input Sample Table'] = params.input
summary['ARTIC Output dir'] = params.artic_output_dir
summary['Primer scheme dir'] = params.scheme_dir
summary['Output dir']     = params.outdir
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile


summary.each{ k, v -> println "${k}: ${v}" }


/*
 * bedtools_mean_coverage
 */
process bedtools_mean_coverage {
    tag "${sample_id} bedtools_coverage"
    conda '/home/dfornika/miniconda3/envs/bedtools-2.29.2'
    publishDir "${params.outdir}/${sample_id}", mode: 'copy', pattern: "${sample_id}.coverage.bed"
    input:
        set sample_id, barcode, min_length, max_length, primer_scheme from samples_bedtools_coverage_ch
        file(primer_scheme_dir) from primer_scheme_dir_ch
        file(artic_output_dir) from artic_output_dir_ch

    output:
	set sample_id, file("${sample_id}.coverage.bed")
    
    script:
    """
    bedtools coverage \
      -mean \
      -a '${primer_scheme_dir}/${primer_scheme}/nCoV-2019.amplicons.bed' \
      -b '${artic_output_dir}/${sample_id}/${sample_id}.sorted.bam' \
      > '${sample_id}.coverage.bed'
    """
}

