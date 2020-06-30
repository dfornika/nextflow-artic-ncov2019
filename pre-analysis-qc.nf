#!/usr/bin/env nextflow

Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:',', quote:'"')
    .map{ row-> tuple(row.sample, row.barcode, row.min_length, row.max_length, row.primer_scheme) }
    .into{ samples_count_reads_ch }

run_dir_ch = Channel.fromPath(params.run_dir, type: 'dir').first()


def summary = [:]
summary['Pipeline Name']  = 'post-analysis-qc'
summary['Input Sample Table'] = params.input
summary['Run fastq dir'] = params.run_dir
summary['Output dir']     = params.outdir
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile


summary.each{ k, v -> println "${k}: ${v}" }

/*
 * pycoQC
 */
process pycoqc {
    tag "pycoQC"
    conda '/home/dfornika/miniconda3/envs/pycoqc-2.5.0.21'
    publishDir "${params.outdir}", mode: 'copy', pattern: "pycoQC.*"
    input:
        file(run_dir) from run_dir_ch

    output:
	file("pycoQC.*")
    
    script:
    """
    pycoQC \
      -f '${run_dir}/fastq/sequencing_summary.txt' \
      -o 'pycoQC.html' \
      -j 'pycoQC.json'
    """
}


/*
 * count_reads
 */
process count_reads {
    tag "${sample_id} count_reads"
    // conda ''
    publishDir "${params.outdir}/${sample_id}", mode: 'copy', pattern: "${sample_id}.num_reads_pass_fail.tsv"
    input:
        set sample_id, barcode, min_length, max_length, primer_scheme from samples_count_reads_ch
        file(run_dir) from run_dir_ch

    output:
	file("${sample_id}.num_reads_pass_fail.tsv") into summarise_read_count_ch
    
    shell:
    '''
    echo "!{sample_id}" > sample_id.txt
    echo "!{barcode}" > barcode.txt
    echo "$(wc -l !{run_dir}/fastq/pass/!{barcode}/*.fastq | tail -n 1 | sed 's/^\\s*//' | tr -s ' ' | cut -d ' ' -f 1) / 4" | bc > num_pass_reads.txt
    echo "$(wc -l !{run_dir}/fastq/fail/!{barcode}/*.fastq | tail -n 1 | sed 's/^\\s*//' | tr -s ' ' | cut -d ' ' -f 1) / 4" | bc > num_fail_reads.txt
    paste sample_id.txt barcode.txt num_pass_reads.txt num_fail_reads.txt > !{sample_id}.num_reads_pass_fail.tsv
    '''
}

/*
 * summarise_read_counts
 */
process summarise_read_counts {
    tag "summarise_read_counts"
    // conda ''
    publishDir "${params.outdir}", mode: 'copy', pattern: "num_reads_pass_fail.tsv"
    input:
        file(read_counts) from summarise_read_count_ch.collect()

    output:
	file("num_reads_pass_fail.tsv")
    
    shell:
    '''
    cat !{read_counts} | sort -k 2 > num_reads_pass_fail.tsv
    '''
}




