import numpy as np
from collections import Counter
from sklearn.utils import resample
from random import sample

class CARTTree:
    def __init__(self, min_samples_split=10, max_depth=5):
        self.min_samples_split = min_samples_split
        self.max_depth = max_depth
        self.tree = None

    def fit(self, X, y):
        self.tree = self._build_tree(X, y)

    def _build_tree(self, X, y, depth=0):
        if depth >= self.max_depth or len(y) < self.min_samples_split or len(set(y)) == 1:
            return Counter(y).most_common(1)[0][0]
    
        best_split = self._find_best_split(X, y)
        if best_split is None:
            return Counter(y).most_common(1)[0][0]
    
        feature, threshold, left_idx, right_idx = best_split
    
        if len(left_idx) == 0 or len(right_idx) == 0:
            return Counter(y).most_common(1)[0][0]
    
        if len(left_idx) < self.min_samples_split or len(right_idx) < self.min_samples_split:
            return Counter(y).most_common(1)[0][0]
    
        node = {"feature": feature, "threshold": threshold, "left": None, "right": None}
        node["left"] = self._build_tree(X[left_idx], y[left_idx], depth + 1)
        node["right"] = self._build_tree(X[right_idx], y[right_idx], depth + 1)
    
        return node

    def _find_best_split(self, X, y):
        best_feature, best_threshold, best_gini = None, None, float("inf")
        best_left_idx, best_right_idx = None, None
    
        for feature in range(X.shape[1]): 
            thresholds = np.unique(X[:, feature])
            for threshold in thresholds:
                left_idx = X[:, feature] <= threshold
                right_idx = X[:, feature] > threshold
    
                left_y = y[left_idx]
                right_y = y[right_idx]

                gini = self._gini_impurity(left_y, right_y)
                if gini < best_gini:
                    best_gini = gini
                    best_feature = feature
                    best_threshold = threshold
                    best_left_idx, best_right_idx = left_idx, right_idx
    
        return (best_feature, best_threshold, best_left_idx, best_right_idx) if best_feature is not None else None

    def _gini_impurity(self, left_y, right_y):
        def gini(y):
            counts = np.bincount(y)
            probs = counts / len(y)
            return 1 - np.sum(probs ** 2)
        
        n_left, n_right = len(left_y), len(right_y)
        n_total = n_left + n_right
        return (n_left / n_total) * gini(left_y) + (n_right / n_total) * gini(right_y)

    def predict_sample(self, sample, node):
        while isinstance(node, dict):
            if sample[node["feature"]] <= node["threshold"]:
                node = node["left"]
            else:
                node = node["right"]
        return node

    def predict(self, X):
        return np.array([self.predict_sample(sample, self.tree) for sample in X])

class RandomForestCART:
    def __init__(self, n_trees=10, sample_size=0.8, min_samples_split=10, max_depth=5, max_features="sqrt"):
        self.n_trees = n_trees
        self.sample_size = sample_size
        self.min_samples_split = min_samples_split
        self.max_depth = max_depth
        self.max_features = max_features
        self.trees = []
        self.selected_features = []
    
    def fit(self, X, y):
        n_samples = int(self.sample_size * len(X))
        n_features = self._calculate_n_features(X)
        
        for _ in range(self.n_trees):
            X_sample, y_sample = resample(X, y, n_samples=n_samples, random_state=None)
            selected_features = tuple(sample(range(X.shape[1]), n_features))
            self.selected_features.append(selected_features)
            
            tree = CARTTree(min_samples_split=self.min_samples_split, max_depth=self.max_depth)
            tree.fit(X_sample[:, selected_features], y_sample)
            self.trees.append(tree)
    
    def predict(self, X):
        tree_preds = np.zeros((self.n_trees, X.shape[0]), dtype=np.int32)
        for i, features in enumerate(self.selected_features):
            tree_preds[i] = self.trees[i].predict(X[:, features])
        return np.apply_along_axis(lambda x: Counter(x).most_common(1)[0][0], axis=0, arr=tree_preds)
    
    def _calculate_n_features(self, X):
        if self.max_features == "sqrt":
            return max(1, int(np.sqrt(X.shape[1])))
        elif self.max_features == "log2":
            return max(1, int(np.log2(X.shape[1])))
        elif isinstance(self.max_features, int):
            return min(X.shape[1], self.max_features)
        else:
            return X.shape[1]
