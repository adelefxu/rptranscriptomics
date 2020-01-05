#!/bin/bash -l
#
#SBATCH -J fastq-dump
#SBATCH -o fastq-dump.o
#SBATCH -e fastq-dump.e
#
#SBATCH --mail-user adelexu@stanford.edu
#SBATCH --mail-type=ALL
#
#SBATCH -t 96:0:0
#SBATCH -A mbarna
#SBATCH --mem=8G
#
# options for partition are batch, interactive, or nih_s10
#SBATCH -p batch

#to run: sbatch sbatch_fastq-dump.sh <first X reads> /path/to/destination/directory SRR0000000

module load sratoolkit/2.9.0

fastq-dump -I -X $1 --split-files --gzip -O $2 $3