#!/bin/bash

file_name=$1
exp_file=prd_procedures.txt

cat $file_name | tr ',' '\n' | tr '[' ' ' | tr ']' ' ' | cut -d ':' -f 2 > $exp_file

a7a59e7460717fe81c43f649d44b03bb157d9d92