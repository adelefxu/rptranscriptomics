# before running this script:
# module load anaconda
# git commit 
# run from directory in which script is stored; otherwise git query won't work

import os
import subprocess
import argparse
import glob
import json

parser = argparse.ArgumentParser(description="Run STAR and RSEM on all .fastq.gz files found in subdirectories of directory provided.")
parser.add_argument('--trimmed_dir')
parser.add_argument('--out_dir')
parser.add_argument('--log_dir')
parser.add_argument("--sb_name")
parser.add_argument("--sb_time", default = "12:0:0")
parser.add_argument("--sb_mem", default = "64G")
parser.add_argument("--sb_cpus", default = "2")
parser.add_argument("--exclude", nargs=argparse.REMAINDER)
args = parser.parse_args()

# make sure output and log directories exist
os.makedirs(args.out_dir, exist_ok=True)
os.makedirs(args.log_dir, exist_ok=True)

sample = next(os.walk(args.trimmed_dir))[1]

#exclude the pilot
sample = [s for s in sample if s not in args.exclude]

SR_script = "/home/adelexu/research/rptranscriptomics/rptranscriptomics/scripts/STAR_RSEM_modified.sh"
STARgenomeDir = "/labs/mbarna/users/adelexu/rptranscriptomics/genomes/gencode.v22_ERCC/STAR_genome"
RSEMoutprefix = "/labs/mbarna/users/adelexu/rptranscriptomics/genomes/gencode.v22_ERCC/RSEM_genome/RSEM_genome"
dataType = "str_PE"
nThreadsSTAR = args.sb_cpus
nThreadsRSEM = args.sb_cpus

sb_defaults = "-e %x-%j.e -o %x-%j.o -A mbarna -p batch"

# for each sample, make output subdirectory and call skewer
for smp in sample:
    os.makedirs(os.path.join(args.out_dir, smp), exist_ok=True)
    pair1 = glob.glob(os.path.join(args.trimmed_dir, smp, "*-trimmed-pair1.fastq.gz"))[0]
    pair2 = glob.glob(os.path.join(args.trimmed_dir, smp, "*-trimmed-pair2.fastq.gz"))[0]
    
    call_script = f"{SR_script} {pair1} {pair2} {STARgenomeDir} {RSEMoutprefix} {dataType} {nThreadsSTAR} {nThreadsRSEM}"
    
    sb_cmd = f"sbatch {sb_defaults} -D {args.log_dir} -J {smp}_{args.sb_name} -t {args.sb_time} --mem={args.sb_mem} -c {args.sb_cpus} {call_script}"
    sb_sub_msg = subprocess.check_output(sb_cmd, shell=True).decode('ascii')
    print(sb_sub_msg)
    job_id = sb_sub_msg.strip().replace("Submitted batch job ", "")
 
#    uncomment when running from command line
    with open(os.path.join(args.log_dir, f"{smp}_{args.sb_name}_STAR_RSEM_{job_id}.config"), 'w') as config_file:
        git_version = str(subprocess.check_output(['git', 'rev-parse', 'HEAD']).strip())
        configs = {"git version": git_version, "arguments": vars(args), "sbatch command line": sb_cmd}
        json.dump(configs, config_file, indent=4)

