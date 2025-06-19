#!/bin/bash
#SBATCH -p lrz-dgx-1-p100x8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=lucia.layritz@tum.de
#SBATCH --time=02:00:00
#SBATCH --gres=gpu
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --ntasks-per-core=1
#SBATCH -o ssp126_2075_2100_m1.out
#SBATCH -e ssp126_2075_2100_m1.err

# Variables for paths
CONTAINER_IMAGE='/dss/dsshome1/lxc0E/ge96dul2/recovery/recovery_rf_pytorch.sqsh'
SCRIPT_PATH='/dss/dsshome1/lxc0E/ge96dul2/recovery/02_Run_models_parallel.py' 
WRITE_PATH='/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper/data/random_forest'

# Debug print statements
echo "Container Image: $CONTAINER_IMAGE"
echo "Script Path: $SCRIPT_PATH"
echo "Write Path: $WRITE_PATH"

# Loop to run the script 30 times sequentially
for i in {1..100}; do
    echo "Running iteration $i"
    srun --container-image=$CONTAINER_IMAGE \
         --container-mounts=$WRITE_PATH:$WRITE_PATH \
         -c 10 --mpi=none --exclusive -n 1 -N 1 \
         python $SCRIPT_PATH $i 2 "ssp126_2075_2100" 1 --epochs 55 --batch-size 512
done
