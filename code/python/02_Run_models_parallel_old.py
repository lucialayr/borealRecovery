# ## Running the models
#
# This script will run the model in paralllel as input to a batch script

import matplotlib.pyplot as plt
from fore.data_old import FOREData
import numpy as np
import pandas as pd
from sklearn.metrics import ConfusionMatrixDisplay, balanced_accuracy_score, make_scorer
from sklearn.cluster import DBSCAN

from mlxtend.feature_selection import SequentialFeatureSelector as SFS
from mlxtend.plotting import plot_sequential_feature_selection as plot_sfs
from sklearn.model_selection import GroupKFold, GroupShuffleSplit

from sklearn.ensemble import ExtraTreesClassifier
from sklearn.ensemble import RandomForestClassifier
from pathlib import Path
import zarr
import argparse
import os
from ast import literal_eval
import sys

parser = argparse.ArgumentParser(
    prog="Forest Recovery",
    description="Boreal forest recovery",
)

# #### Feed in external variables from slurm script

# +
var1=literal_eval(sys.argv[1]) #seed
var2=literal_eval(sys.argv[2]) #number of features
var3=sys.argv[3] # scenarios
var4=sys.argv[4] # model (set of covariates)

print(var1, var2, var4)
# -

seed = int(var1) # this needs to be an external variable

rng = np.random.default_rng(seed=seed)

# ### Housekeeping variables

mode = "states"
k= var2 #Numbers of features, this should also be externally
fname = var3 # this needs to be an external variable
save_path = Path("/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper/data/random_forest")
exp_name = f"{fname}_seed_{seed}_mode_{mode}_k_{k}_m{var4}"


# +
### Function for processing data we will need later
# -

def process_data(data, mode="both"):
    x_t, x_s, y = data

    x_t = x_t.reshape(x_t.shape[0], -1, order="F")

    if mode == "clim":
        x = x_t 
    elif mode == "states":
        x = x_s
    elif mode == "both":
        x = np.concatenate([x_t, x_s], axis=1)
    
    return x, y


# ## Load data
#
# The `FOREdata` function is a custom function defined in `fore/data.py` that will read the zarr data and with `.data` we obtain all the elements we need

# +
data = FOREData(f"/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper/data/random_forest/{fname}_m{var4}_old.zarr")

print(os.path.exists(data.ds_path))
# -

x_t, x_s, y_start, y_end, y_block, lat_lon_pid = data.data()

# ## Clustering 
#
# We cluster the trajectories with DBSCAN into three clusters:
# 1. Needleleaf recovery
# 2. Deciduous recovery
# 3. Misceleanous cluster, e.g. TeBS or other conifer dominance
#
# ### Calculating

model = DBSCAN(eps=0.35, min_samples=1000)
model.fit(y_block.reshape(y_block.shape[0], -1)) #we use y_block data
print(np.unique(model.labels_, return_counts=True))
target = model.labels_


len(target)

# ## Prepare test and training data
#
# This prepares the test and training samples. The goal here is to make sure we have random samples in space

lat_arr = np.linspace(lat_lon_pid[:,0].min(), lat_lon_pid[:,0].max(), 20)
lon_arr = np.linspace(lat_lon_pid[:,1].min(), lat_lon_pid[:,1].max(), 150)


group_ind = np.zeros(lat_lon_pid.shape[0], dtype=int)
for i in range(lat_lon_pid.shape[0]):
    lat = lat_lon_pid[i, 0]
    lon = lat_lon_pid[i, 1]

    for j in range(lat_arr.shape[0]):
        
        if lat<=lat_arr[j]:
            group_ind[i] = j*100
            break
    
    for m in range(lon_arr.shape[0]):
        if lon<=lon_arr[m]:
            group_ind[i] = group_ind[i]+m
            break

len(group_ind) == len(lat_lon_pid)

x_t

# ### Merging traning data with labels
#
# `x_t`, `x_s` are original data, `target` are the results of the classification
# `process_data` is a custom function defined above that merges the labels with the data
#
# $\rightarrow$ *If we wanted to add other labels, that would have to happen here. They would need to be in the right format*

x, target = process_data((x_t, x_s, target))

# Train Test split
print(f"Shapes:{x.shape, target.shape}")
gss = GroupShuffleSplit(1, test_size=0.25, random_state=42)
train_index, test_index = list(gss.split(x,target, group_ind))[0]

print(train_index.shape)
print(test_index.shape)
print(group_ind.shape)

with zarr.open(f"/dss/dssfs02/lwp-dss-0001/pr48va/pr48va-dss-0000/ge96dul2/patch_analysis_paper/data/random_forest/{fname}_m{var4}_old.zarr", "a") as f:
    
    f[f"train_index_seed_{seed}"] = train_index
    f[f"test_index_seed_{seed}"] = train_index
    f[f"group_index_seed_{seed}"] = group_ind
    print(f.tree())

    print(f"Data Written for {fname}")

def normalize(train, test):
    
    
    mu = np.mean(train, axis=0)
    sigma = np.std(train, axis=0)

    train = (train-mu)/sigma
    test = (test-mu)/sigma    
        
    return train, test


x_train = x[train_index]
x_test = x[test_index]
target_train = target[train_index]
target_test = target[test_index]
group_ind_train = group_ind[train_index]
group_ind_test = group_ind[test_index]
lat_lon_pid_train = lat_lon_pid[train_index]
lat_lon_pid_test = lat_lon_pid[test_index]

x_train, x_test = normalize(x_train, x_test)

kfold = GroupKFold(n_splits=5)
cv = list(kfold.split(x_train, target_train, group_ind_train ))

len(x_train)

# ## Classification model
#
# Per default this is random forest, but it can be change to by substituting the function `RandomForestClassifier` with `ExtraTreesClassifier`. `n_jobs = -1` will make use of all available ressources.

clf = RandomForestClassifier(class_weight="balanced", n_jobs=-1)
clf.fit(x_train, target_train)
sfs = SFS(clf, k_features=(1,k), cv=cv, verbose=2, n_jobs=-1, floating=True, scoring=make_scorer(balanced_accuracy_score))
sfs.fit(x_train, target_train) 

# ## Write results to disk for plotting
#
# ### Feature selection 
# **this needs to be adapted to have the features correct for all models!**

# +
import collections

results = pd.DataFrame.from_dict(sfs.get_metric_dict()).T
results.to_csv(save_path/f"{exp_name}_sfs_results.csv", index=False, header=True)

data = pd.read_csv(save_path/f"{exp_name}_sfs_results.csv") #change path accordingly

feature_list = []
top_n = 5
feature_idx = [int(i) for i in data.feature_idx[top_n-1][1:-1].split(", ")]
print(len(feature_idx))
feature_list.append(feature_idx) #get 5 most important features

# Save as DataFrame to a CSV file
df = pd.DataFrame({'Codes': feature_list})
df.to_csv(save_path/f"results/{exp_name}_sfs_results.csv", index=False, header=True)

# -

# ### Feature importance

feature_importances = clf.feature_importances_
pd.DataFrame(feature_importances, columns=['importance']).to_csv(save_path/f"results/{exp_name}_feature_importance.csv", index=False, header=True)


# ### True vs False for confusion matrix

predictions = clf.predict(x_test)
true_labels = target_test
pd.DataFrame({'true_labels': true_labels, 'predictions': predictions}).to_csv(save_path/f"results/{exp_name}_predictions.csv", index=False, header=True)


# ### Save model

# +
import joblib

joblib.dump(clf, save_path/f"results/{exp_name}_random_forest_model.joblib")
# -

# ### Partial dependence plots

# +
from sklearn.inspection import partial_dependence

from sklearn.preprocessing import StandardScaler

output_dir = save_path

for feature_index in range(x_train.shape[1]):
    # Create a grid of values for the current feature (check if th is correct, the variables have a lot of negatives we do not seem right ..)
    feature_values = np.linspace(x_train[:, feature_index].min(), x_train[:, feature_index].max(), 100) 
    # Prepare an array to hold probabilities
    probabilities = np.zeros((len(feature_values), len(clf.classes_)))

    # Compute probabilities for each value of the feature
    for i, value in enumerate(feature_values):
        # Create a new data point with the feature value and the mean of other features
        new_data = np.mean(x_train, axis=0)
        new_data[feature_index] = value
        # Predict the class probabilities for this new data point
        probas = clf.predict_proba([new_data])
        probabilities[i, :] = probas

    # Convert to DataFrame for saving
    pdp_df = pd.DataFrame(probabilities, columns=[f'Prob_{cls}' for cls in clf.classes_])
    pdp_df['Feature_Value'] = feature_values
    pdp_df['Feature'] = feature_index  # To track which feature this data belongs to


    pdp_df.to_csv(os.path.join(output_dir, f'results/{exp_name}_pdp_results_feature_{feature_index}.csv'), index=False)
