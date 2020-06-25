#!/usr/bin/env nextflow

Channel
    .fromPath(params.input)
    .splitCsv(header:true, sep:',', quote:'"')
    .map{ row-> tuple(row.sample, row.barcode, row.min_length, row.max_length, row.primer_scheme) }
    .into{ samples_guppyplex_ch; samples_minion_ch }

fastq_dir_ch = Channel.fromPath(params.fastq_dir, type: 'dir').first()

fast5_dir_ch = Channel.fromPath(params.fast5_dir, type: 'dir').first()

primer_scheme_dir_ch = Channel.fromPath(params.scheme_dir, type: 'dir').first()

def summary = [:]
summary['Pipeline Name']  = 'artic'
summary['Input Sample Table'] = params.input
summary['Input fastq pass dir'] = params.fastq_pass_dir
summary['Input fast5 dir'] = params.fast5_dir
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
 * artic_guppyplex
 */
process artic_guppyplex {
    tag "${sample_id} artic_guppyplex"
    conda '/home/dfornika/miniconda3/envs/artic-1.1.3'

    input:
        set sample_id, barcode, min_length, max_length, primer_scheme from samples_guppyplex_ch
        file(fastq_dir) from fastq_dir_ch

    output:
	set sample_id, file("${sample_id}_${barcode}.fastq") into minion_fastq_ch
    
    script:
    """
    artic guppyplex \
      --min-length '${min_length}' \
      --max-length '${max_length}' \
      --directory '${fastq_dir}/pass/${barcode}' \
      --prefix '${sample_id}'
    """
}

/*
 * artic_minion
 */
process artic_minion {
    tag "${sample_id} artic_minion"
    cpus 4
    conda '/home/dfornika/miniconda3/envs/artic-1.1.3'

    publishDir "${params.outdir}/${sample_id}", mode: 'copy', pattern: "${sample_id}{.,-}*"
    input:
        set sample_id, barcode, min_length, max_length, primer_scheme, file(read_file) from samples_minion_ch.join(minion_fastq_ch)
        file(primer_scheme_dir) from primer_scheme_dir_ch
        file(fast5_dir) from fast5_dir_ch
        file(fastq_dir) from fastq_dir_ch

    output:
	set sample_id, file("${sample_id}_${barcode}.fastq")
    
    script:
    """
    artic minion \
      --normalise 200 \
      --threads 4 \
      --scheme-directory '${primer_scheme_dir}' \
      --read-file '${read_file}' \
      --fast5-directory '${fast5_dir}' \
      --sequencing-summary '${fastq_dir}/sequencing_summary.txt' \
      '${primer_scheme}' \
      '${sample_id}'
    """
}



