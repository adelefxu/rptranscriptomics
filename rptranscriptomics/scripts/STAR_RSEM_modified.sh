#!/bin/bash

# AX: Copied from https://github.com/kundajelab/mesoderm/blob/master/RNA-seq/STAR_RSEM.sh
# AX: Commit 1d3909b251d3841306f77d5fa9a3b86ba803ff7e
#
# AX: changes from original
# - added code to load necessary modules
# - removed STARparsMeta from STAR command call b/c never initialized
# - added command line arguments for output directory, output file prefix (full path), and output file short prefix

# Modified from https://github.com/ENCODE-DCC/long-rna-seq-pipeline/blob/master/DAC/STAR_RSEM.sh
# Commit 313830c7c10e8567091131c40bdec2b9477627e0

# STAR mapping / RSEM quantification pipeline
# usage: run:
# ./STAR_RSEM.sh (read1) (read2 or "") (STARgenomeDir) (RSEMrefDir) (dataType) (nThreadsSTAR) (nThreadsRSEM) (output directory) (output prefix)

# input: gzipped fastq file read1 [read2 for paired-end] 
#        STAR genome directory, RSEM reference directory - prepared with STAR_RSEM_prep.sh script
read1=$1 #gzipped fastq file for read1
read2=$2 #gzipped fastq file for read1, use "" if single-end
STARgenomeDir=$3 
RSEMrefDir=$4 # This needs the "RSEMref" suffix if prepared by the prep script
dataType=$5 # RNA-seq type, possible values: str_SE str_PE unstr_SE unstr_PE
nThreadsSTAR=$6 # number of threads for STAR
nThreadsRSEM=$7 # number of threads for RSEM
outdir=$8
outprefix=$9
shortprefix=$10

# change working directory to outdir
cd $outdir

# output: all in the working directory, fixed names
# {outprefix}_Aligned.sortedByCoord.out.bam                 # alignments, standard sorted BAM, agreed upon formatting
# {outprefix}_Log.final.out                                 # mapping statistics to be used for QC, text, STAR formatting
# {outprefix}_Quant.genes.results                           # RSEM gene quantifications, tab separated text, RSEM formatting
# {outprefix}_Quant.isoforms.results                        # RSEM transcript quantifications, tab separated text, RSEM formatting
# {outprefix}_Quant.pdf                                     # RSEM diagnostic plots
# {outprefix}_Signal.{Unique,UniqueMultiple}.strand{+,-}.bw # 4 bigWig files for stranded data
# {outprefix}_Signal.{Unique,UniqueMultiple}.unstranded.bw  # 2 bigWig files for unstranded data

# STAR parameters: common
STARparCommon=" --genomeDir $STARgenomeDir  --readFilesIn $read1 $read2   --outSAMunmapped Within --outFilterType BySJout \
 --outSAMattributes NH HI AS NM MD    --outFilterMultimapNmax 20   --outFilterMismatchNmax 999   \
 --outFilterMismatchNoverReadLmax 0.04   --alignIntronMin 20   --alignIntronMax 1000000   --alignMatesGapMax 1000000   \
 --alignSJoverhangMin 8   --alignSJDBoverhangMin 1 --sjdbScore 1 --readFilesCommand zcat \
 --twopassMode Basic --twopass1readsN -1 --outFileNamePrefix $outprefix"
STARparRun=" --runThreadN $nThreadsSTAR --limitBAMsortRAM 60000000000"
STARparBAM="--outSAMtype BAM SortedByCoordinate --quantMode TranscriptomeSAM"


# STAR parameters: strandedness, affects bedGraph (wiggle) files and XS tag in BAM 
case "$dataType" in
str_SE|str_PE)
      #OPTION: stranded data
      STARparStrand=""
      STARparWig="--outWigStrand Stranded"
      ;;
      #OPTION: unstranded data
unstr_SE|unstr_PE)
      STARparStrand="--outSAMstrandField intronMotif"
      STARparWig="--outWigStrand Unstranded"
      ;;
esac

# STAR parameters: metadata
#STARparsMeta="--outSAMheaderCommentFile commentsENCODElong.txt --outSAMheaderHD @HD VN:1.4 SO:coordinate"

## not needed ## --outSAMheaderPG @PG ID:Samtools PN:Samtools CL:"$samtoolsCommand" PP:STAR VN:0.1.18"

# ENCODE metadata BAM comments
#echo -e '@CO\tLIBID:ENCLB175ZZZ
#@CO\tREFID:ENCFF001RGS
#@CO\tANNID:gencode.v19.annotation.gtf.gz
#@CO\tSPIKEID:ENCFF001RTP VN:Ambion-ERCC Mix, Cat no. 445670' > commentsENCODElong.txt

###### STAR command
echo STAR $STARparCommon $STARparRun $STARparBAM $STARparStrand

module load STAR/2.4.1d
STAR $STARparCommon $STARparRun $STARparBAM $STARparStrand

###### bedGraph generation, now decoupled from STAR alignment step
# working subdirectory for this STAR run
mkdir Signal

echo STAR --runMode inputAlignmentsFromBAM   --inputBAMfile ${outprefix}Aligned.sortedByCoord.out.bam --outWigType bedGraph $STARparWig --outFileNamePrefix ./Signal/${shortprefix} --outWigReferencesPrefix chr
STAR --runMode inputAlignmentsFromBAM   --inputBAMfile ${outprefix}Aligned.sortedByCoord.out.bam --outWigType bedGraph $STARparWig --outFileNamePrefix ./Signal/${shortprefix} --outWigReferencesPrefix chr

# move the signal files from the subdirectory
mv Signal/${shortprefix}Signal*bg .




###### bigWig conversion commands
# # exclude spikeins
# grep ^chr $STARgenomeDir/chrNameLength.txt > chrNL.txt

# case "$dataType" in
# str_SE|str_PE)
#       # stranded data
#       str[1]=-; str[2]=+;
#       for istr in 1 2
#       do
#       for imult in Unique UniqueMultiple
#       do
#           grep ^chr Signal.$imult.str$istr.out.bg > sig.tmp
#           $bedGraphToBigWig sig.tmp  chrNL.txt Signal.$imult.strand${str[istr]}.bw
#       done
#       done
#       ;;
# unstr_SE|unstr_PE)
#       # unstranded data
#       for imult in Unique UniqueMultiple
#       do
#           grep ^chr Signal.$imult.str1.out.bg > sig.tmp
#           $bedGraphToBigWig sig.tmp chrNL.txt  Signal.$imult.unstranded.bw
#       done
#       ;;
# esac




######### RSEM

#### prepare for RSEM: sort transcriptome BAM to ensure the order of the reads, to make RSEM output (not pme) deterministic
trBAMsortRAM=40G

mv ${outprefix}Aligned.toTranscriptome.out.bam Tr.bam 

module load samtools/1.9

case "$dataType" in
str_SE|unstr_SE)
      # single-end data
      cat <( samtools view -H Tr.bam ) <( samtools view -@ $nThreadsRSEM Tr.bam | sort -S $trBAMsortRAM -T ./ ) | samtools view -@ $nThreadsRSEM -bS - > Aligned.toTranscriptome.out.bam
      ;;
str_PE|unstr_PE)
      # paired-end data, merge mates into one line before sorting, and un-merge after sorting
      cat <( samtools view -H Tr.bam ) <( samtools view -@ $nThreadsRSEM Tr.bam | awk '{printf "%s", $0 " "; getline; print}' | sort -S $trBAMsortRAM -T ./ | tr ' ' '\n' ) | samtools view -@ $nThreadsRSEM -bS - > ${outprefix}Aligned.toTranscriptome.out.bam
      ;;
esac

'rm' Tr.bam


# RSEM parameters: common
# RSEMparCommon="--bam --estimate-rspd  --calc-ci --no-bam-output --seed 12345"
RSEMparCommon="--bam --estimate-rspd --no-bam-output --seed 12345"

# RSEM parameters: run-time, number of threads and RAM in MB
# RSEMparRun=" -p $nThreadsRSEM --ci-memory 40000 "
RSEMparRun=" -p $nThreadsRSEM "

# RSEM parameters: data type dependent

case "$dataType" in
str_SE)
      #OPTION: stranded single end
      RSEMparType="--forward-prob 0"
      ;;
str_PE)
      #OPTION: stranded paired end
      RSEMparType="--paired-end --forward-prob 0"
      ;;
unstr_SE)
      #OPTION: unstranded single end
      RSEMparType=""
      ;;
unstr_PE)
      #OPTION: unstranded paired end
      RSEMparType="--paired-end"
      ;;
esac


###### RSEM command
module load rsem/1.2.21
echo rsem-calculate-expression $RSEMparCommon $RSEMparRun $RSEMparType ${outprefix}Aligned.toTranscriptome.out.bam $RSEMrefDir ${outprefix}Quant >& ${outprefix}Log.rsem
rsem-calculate-expression $RSEMparCommon $RSEMparRun $RSEMparType ${outprefix}Aligned.toTranscriptome.out.bam $RSEMrefDir ${outprefix}Quant >& ${outprefix}Log.rsem

###### RSEM diagnostic plot creation
# Notes:
# 1. rsem-plot-model requires R (and the Rscript executable)
# 2. This command produces the file Quant.pdf, which contains multiple plots

module load r/3.6

echo rsem-plot-model ${outprefix}Quant ${outprefix}Quant.pdf
rsem-plot-model ${outprefix}Quant ${outprefix}Quant.pdf