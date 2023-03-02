#!/usr/bin/env python
# Utility for pca visualisation of feature table
import sys
import pandas as pd
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D


base_colors = ['tab:blue', 'tab:red', 'tab:green', 'tab:orange', 'tab:purple', 'tab:brown', 'tab:pink', 'tab:olive', 'tab:cyan']
default_color = 'tab:gray'

features = pd.read_csv(sys.argv[1], header=0, index_col=0, sep="\t")

M = features.shape[0] # features count
N = features.shape[1] # samples  count

outName = sys.argv[2]
showLabels = True if sys.argv[3] == "true" else False
metadata = None
if len(sys.argv) == 5:
    metadata = pd.read_csv(sys.argv[4], sep="\t", header=None, index_col=0)

it = 0
colors_dict = dict()
meta_dict = dict(zip(features.columns, [None] * N))
if metadata is not None:
    for key, vals in metadata.iterrows():
        for val in vals.iloc[0].split():
            if val in meta_dict:
                meta_dict[val] = key
                if key not in colors_dict:
                    colors_dict[key] = base_colors[it]
                    it = (it + 1) % 9
if None in meta_dict.values():
    colors_dict[None] = default_color


pca = PCA(n_components=2)
pca.fit(features.T)
pca_vals = pca.transform(features.T)

plt.scatter(pca_vals[:, 0], pca_vals[:, 1], c = [colors_dict[meta_dict[i]] for i in features.columns])
plt.xlabel("pca[0], explained_variance = " + str(round(pca.explained_variance_ratio_[0], 2)))
plt.ylabel("pca[1], explained_variance = " + str(round(pca.explained_variance_ratio_[1], 2)))

# Creating legend
legend = []
for cat, col in colors_dict.items():
    legend.append(Line2D([], [], color=col, marker='o', linestyle='', label="Unlabeled" if cat is None else cat))
plt.legend(handles=legend, title="Categories")

# Show samples labels
if showLabels:
    for i in range(N):
        plt.annotate(features.columns[i], pca_vals[i])

plt.savefig(outName+".png", bbox_inches='tight')
plt.savefig(outName+".svg", bbox_inches='tight')