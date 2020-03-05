#!/usr/bin/env nextflow

def summary = [:]
summary['Pipeline Name']  = 'artic-ncov2019'
summary['Input fast5 directory'] = params.fast5_dir
// summary['Input fastq']    = params.fastq
summary['Primer scheme directory'] = params.primers
summary['Run Name']       = params.run_name
summary['Sample Name']    = params.sample_name
summary['Output dir']     = params.outdir
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile


summary.each{ k, v -> println "${k}: ${v}" }


Channel
    .fromPath(params.fast5_dir)
    .first()
    .set { guppy_fast5_dir_ch }

/*
Channel
    .fromPath(params.fastq)
    .first()
    .set { demultiplex_ch }
 */

Channel
    .fromPath(params.primers)
    .first()
    .set { primer_scheme_ch }

Channel
    .value(params.run_name)
    .set { run_name_ch }

Channel
    .value(params.sample_name)
    .set { sample_name_ch }

/*
 * Guppy
 */
process guppy_basecaller {
    cpus 16
    conda 'artic-ncov2019'

    input:
    file(fast5_dir) from guppy_fast5_dir_ch

    output:
    file("outdir") into gather_ch

    script:
    """
    guppy_basecaller \
      -c dna_r9.4.1_450bps_fast.cfg \
      --num_callers 4 \
      --cpu_threads_per_caller 4 \
      -i ${fast5_dir} \
      -s outdir \
      -r
    """
}


/*
 * Gather
 */
process artic_gather {
    cpus 4
    conda 'artic-ncov2019'

    input:
    val run_name from run_name_ch
    file(basecalled_reads_dir) from gather_ch

    output:

    file("${run_name}_all.fastq") into demultiplex_ch

    script:
    """
    artic gather \
      --min-length 400 \
      --max-length 700 \
      --prefix ${run_name} \
      --directory ${basecalled_reads_dir}
    """
}


/*
 * Demultiplex
 */
process artic_demultiplex {
    cpus 8
    conda 'artic-ncov2019'

    input:
    val run_name from run_name_ch
    file(basecalled_gathered_reads) from demultiplex_ch

    output:
    file("*-NB*.fastq") into minion_reads_ch

    script:
    """
    artic demultiplex \
      --threads 8 \
      ${basecalled_gathered_reads}
    """
}


/*
 * Artic MinION
 */
process artic_minion {
    cpus 4
    conda 'artic-ncov2019'
    publishDir "${params.outdir}/${sample_name}", mode: 'copy', pattern: "${sample_name}*"
    
    input:
    val sample_name from sample_name_ch
    file(primer_scheme_dir) from primer_scheme_ch
    each file(demultiplexed_reads) from minion_reads_ch

    output:
    file("${sample_name}*")

    script:
    """
    artic minion \
      --threads 4 \
      --normalise 200 \
      --medaka \
      --scheme-directory ${primer_scheme_dir} \
      --read-file ${demultiplexed_reads} \
      nCoV-2019/V1 \
      ${sample_name}
    """
}



