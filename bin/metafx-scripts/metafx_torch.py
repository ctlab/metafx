#!/usr/bin/env python
# PyTorch Liner Classification Model
import torch
from torch import nn, optim
import numpy as np


class TorchLinearModel():
    """PyTorch sequential linear model for classification into C classes"""

    def __init__(self, n_features, n_classes, n_epochs=1000):
        self.n_features = n_features
        self.n_classes = n_classes
        self.n_epochs = n_epochs
        self.model = nn.Sequential(
          nn.Linear(self.n_features, 32),
          nn.Sigmoid(),
          nn.Linear(32, self.n_classes),
          nn.Sigmoid()
          )
        self.criterion = nn.CrossEntropyLoss()
        self.optimizer = optim.SGD(self.model.parameters(), lr=0.001, momentum=0.9)

    def fit(self, X, y):
        y_true = np.zeros((X.shape[0], self.n_classes))
        for i, val in enumerate(y):
            y_true[i, val] = 1.

        X = torch.from_numpy(X.values).float()
        y_true = torch.from_numpy(y_true)

        for epoch in range(self.n_epochs):
            self.optimizer.zero_grad()

            y_pred = self.model(X)
            loss = self.criterion(y_pred, y_true)
            loss.backward()
            self.optimizer.step()

            if (epoch+1) % 100 == 0:
                print("Epoch", epoch+1, "/", self.n_epochs, ":", round(loss.item(), 5), "loss", flush=True)

    def predict(self, X):
        y_pred = self.model(torch.from_numpy(X.values).float()).cpu().data.numpy()
        return np.argmax(y_pred, axis=1)

    def get_model(self):
        return self.model
