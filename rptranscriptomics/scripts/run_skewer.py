# before running:
# module load anaconda
# git commit
# run from directory that script is in (otherwise won't be able to report git commit)

import os
import subprocess
import argparse
import glob
import json

parser = argparse.ArgumentParser(description="Run Skewer on all .fastq.gz files found in subdirectories of directory provided.")
parser.add_argument('--fastq_dir')
parser.add_argument('--out_dir')
parser.add_argument('--log_dir')
parser.add_argument("--sb_name")
parser.add_argument("--sb_time", default = "2:0:0")
parser.add_argument("--sb_mem", default = "1G")
parser.add_argument("--sb_cpus", default = "1")
parser.add_argument("--exclude", nargs=argparse.REMAINDER)
args = parser.parse_args()

# make sure output and log directories exist
os.makedirs(args.out_dir, exist_ok=True)
os.makedirs(args.log_dir, exist_ok=True)

sample = next(os.walk(args.fastq_dir))[1]

#exclude the pilot
sample = [s for s in sample if s not in args.exclude]

skewer_path = "/labs/mbarna/users/adelexu/bin/skewer-0.1.127-linux-x86_64"
adapter1 = "AGATCGGAAGAGCACACGTCTGAACTCCAGTCACNNNNNNATCTCGTATGCCGTCTTCTGCTTG"
adapter2 = "AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGTAGATCTCGGTGGTCGCCGTATCATT"

sb_defaults = "-e %j-%x.e -o %j-%x.o -A mbarna -p batch"

# for each sample, make output subdirectory and call skewer
for smp in sample:
    os.makedirs(os.path.join(args.out_dir, smp), exist_ok=True)
    pair1 = glob.glob(os.path.join(args.fastq_dir, smp, "*_1.fastq.gz"))[0]
    pair2 = glob.glob(os.path.join(args.fastq_dir, smp, "*_2.fastq.gz"))[0]
    prefix = os.path.basename(pair1).replace("_1.fastq.gz", "")
    
    sh_code = "\n".join([f"#!/bin/sh",
                         f"{skewer_path} -x {adapter1} -y {adapter2} -t {args.sb_cpus} -q 21 -l 21 -n -u -f sanger -z -o {os.path.join(args.out_dir, smp, prefix)} {pair1} {pair2}"])
    
    sb_cmd = f"sbatch {sb_defaults} -D {args.log_dir} -J {smp}_{args.sb_name} -t {args.sb_time} --mem={args.sb_mem} -c {args.sb_cpus} <<EOF \n{sh_code}\nEOF"

    sb_sub_msg = subprocess.check_output(sb_cmd, shell=True).decode('ascii')
    print(sb_sub_msg)
    job_id = sb_sub_msg.strip().replace("Submitted batch job ", "")
    
    with open(os.path.join(args.log_dir, f"{smp}_{args.sb_name}_skewer_{job_id}.config"), 'w') as config_file:
        git_version = str(subprocess.check_output(['git', 'rev-parse', 'HEAD']).strip())
        configs = {"git version": git_version, "arguments": vars(args), "sbatch command line": sb_cmd}
        json.dump(configs, config_file, indent=4)
    
    
    
