import json
import sys
from sklearn.datasets import fetch_openml
import numpy as np


# ============================================================
# Configurazione
# ============================================================

DEFAULT_SIZE = 1000
DEFAULT_THRESHOLD = 900
RANDOM_SEED = 42
NUM_CLASSES = 10


# ============================================================
# Lettura dei parametri
# ============================================================

if len(sys.argv) > 1:
    SIZE = int(sys.argv[1])
else:
    SIZE = DEFAULT_SIZE

if len(sys.argv) > 2:
    THRESHOLD = int(sys.argv[2])
else:
    THRESHOLD = DEFAULT_THRESHOLD


if SIZE <= 0:
    raise ValueError("SIZE deve essere maggiore di 0")

if THRESHOLD < 0 or THRESHOLD > SIZE:
    raise ValueError("La soglia deve essere compresa tra 0 e SIZE")


# ============================================================
# Calcolo dei limiti di bilanciamento
# ============================================================

# Distribuzione ideale:
# SIZE / NUM_CLASSES
# Intervallo ammesso:
# 50% <= count_i <= 150%
# rispetto alla distribuzione ideale.

TB = SIZE // 20
TA = (3 * SIZE) // 20

if TB < 1:
    TB = 1


# ============================================================
# Caricamento MNIST
# ============================================================

print("Caricamento MNIST...")

mnist = fetch_openml(
    "mnist_784",
    version=1,
    as_frame=False,
    parser="liac-arff"
)

labels = mnist.target.astype(int)


# ============================================================
# Selezione deterministica del sottoinsieme
# ============================================================

rng = np.random.default_rng(RANDOM_SEED)

indices = rng.choice(
    len(labels),
    size=SIZE,
    replace=False
)

selected_labels = labels[indices]


# ============================================================
# Vettore enabled
# ============================================================

enabled = [1] * SIZE


# ============================================================
# Calcolo cardinalità
# ============================================================

# cardinality = sum(enabled)


# ============================================================
# Calcolo distribuzione delle classi
# ============================================================

# class_counts = []

# for c in range(NUM_CLASSES):
#    count = int(np.sum(selected_labels == c))
#    class_counts.append(count)


# ============================================================
# Creazione input Cardinality
# ============================================================

cardinality_input = {
    "labels": selected_labels.tolist(),
    "enabled": enabled,
    "threshold": THRESHOLD
}

with open("inputs/cardinality_input.json", "w") as f:
    json.dump(cardinality_input, f, indent=4)


# ============================================================
# Creazione input Balance
# ============================================================

balance_input = {
    "labels": selected_labels.tolist(),
    "enabled": enabled,
    "Tb": TB,
    "Ta": TA
}

with open("inputs/balance_input.json", "w") as f:
    json.dump(balance_input, f, indent=4)


# ============================================================
# Output informativo
# ============================================================

print("Input generati correttamente.")
print()

print(f"Numero di elementi selezionati : {SIZE}")
print(f"Soglia cardinalità             : {THRESHOLD}")
# print(f"Cardinalità                    : {cardinality}")

print()

print(f"Limite inferiore Tb            : {TB}")
print(f"Limite superiore Ta            : {TA}")

print()

print(f"Seed utilizzato                : {RANDOM_SEED}")

# print("Prime 20 labels:")
# print(selected_labels[:20].tolist())