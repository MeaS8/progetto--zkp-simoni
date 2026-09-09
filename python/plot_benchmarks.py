import csv
import os
import matplotlib.pyplot as plt


RESULTS_DIR = "results"
PLOTS_DIR = os.path.join(RESULTS_DIR, "plots")

CARDINALITY_CSV = os.path.join(
    RESULTS_DIR, "cardinality", "benchmark.csv"
)

BALANCE_CSV = os.path.join(
    RESULTS_DIR, "balance", "benchmark.csv"
)

os.makedirs(PLOTS_DIR, exist_ok=True)


def read_csv(path):
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


cardinality = read_csv(CARDINALITY_CSV)
balance = read_csv(BALANCE_CSV)


def get(data, column):
    return [float(row[column]) for row in data]


def save_plot(filename):
    plt.tight_layout()
    plt.savefig(
        os.path.join(PLOTS_DIR, filename),
        dpi=300,
        bbox_inches="tight"
    )
    plt.close()


# ==========================================================
# CARDINALITY
# ==========================================================

x = get(cardinality, "size")


# Constraints
plt.figure(figsize=(8, 5))
plt.plot(x, get(cardinality, "constraints"), marker="o")
plt.xlabel("Numero di elementi")
plt.ylabel("Constraints")
plt.title("Cardinality - Constraints")
plt.grid(True, alpha=0.3)
save_plot("cardinality_constraints.png")


# Wires
plt.figure(figsize=(8, 5))
plt.plot(x, get(cardinality, "wires"), marker="o")
plt.xlabel("Numero di elementi")
plt.ylabel("Wires")
plt.title("Cardinality - Wires")
plt.grid(True, alpha=0.3)
save_plot("cardinality_wires.png")


# Times
plt.figure(figsize=(8, 5))
plt.plot(
    x,
    get(cardinality, "witness_time"),
    marker="o",
    label="Witness"
)
plt.plot(
    x,
    get(cardinality, "proof_time"),
    marker="o",
    label="Proof"
)
plt.plot(
    x,
    get(cardinality, "verify_time"),
    marker="o",
    label="Verification"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Tempo (s)")
plt.title("Cardinality - Tempi di esecuzione")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("cardinality_times.png")


# File sizes
plt.figure(figsize=(8, 5))
plt.plot(
    x,
    [v / 1024 for v in get(cardinality, "witness_bytes")],
    marker="o",
    label="Witness"
)
plt.plot(
    x,
    [v / 1024 for v in get(cardinality, "proof_bytes")],
    marker="o",
    label="Proof"
)
plt.plot(
    x,
    [v / 1024 for v in get(cardinality, "zkey_bytes")],
    marker="o",
    label="zKey"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Dimensione (KB)")
plt.title("Cardinality - Dimensione dei file")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("cardinality_file_sizes.png")


# ==========================================================
# BALANCE
# ==========================================================

xb = get(balance, "size")


# Constraints
plt.figure(figsize=(8, 5))
plt.plot(xb, get(balance, "constraints"), marker="o")
plt.xlabel("Numero di elementi")
plt.ylabel("Constraints")
plt.title("Balance - Constraints")
plt.grid(True, alpha=0.3)
save_plot("balance_constraints.png")


# Wires
plt.figure(figsize=(8, 5))
plt.plot(xb, get(balance, "wires"), marker="o")
plt.xlabel("Numero di elementi")
plt.ylabel("Wires")
plt.title("Balance - Wires")
plt.grid(True, alpha=0.3)
save_plot("balance_wires.png")


# Times
plt.figure(figsize=(8, 5))
plt.plot(
    xb,
    get(balance, "witness_time"),
    marker="o",
    label="Witness"
)
plt.plot(
    xb,
    get(balance, "setup_time"),
    marker="o",
    label="Setup Groth16"
)
plt.plot(
    xb,
    get(balance, "proof_time"),
    marker="o",
    label="Proof"
)
plt.plot(
    xb,
    get(balance, "verify_time"),
    marker="o",
    label="Verification"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Tempo (s)")
plt.title("Balance - Tempi di esecuzione")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("balance_times.png")


# File sizes
plt.figure(figsize=(8, 5))
plt.plot(
    xb,
    [v / 1024 for v in get(balance, "witness_bytes")],
    marker="o",
    label="Witness"
)
plt.plot(
    xb,
    [v / 1024 for v in get(balance, "proof_bytes")],
    marker="o",
    label="Proof"
)
plt.plot(
    xb,
    [v / 1024 for v in get(balance, "zkey_bytes")],
    marker="o",
    label="zKey"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Dimensione (KB)")
plt.title("Balance - Dimensione dei file")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("balance_file_sizes.png")


# ==========================================================
# CONFRONTO CARDINALITY vs BALANCE
# ==========================================================

# Constraints
plt.figure(figsize=(8, 5))
plt.plot(
    x,
    get(cardinality, "constraints"),
    marker="o",
    label="Cardinality"
)
plt.plot(
    xb,
    get(balance, "constraints"),
    marker="o",
    label="Balance"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Constraints")
plt.title("Confronto - Constraints")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("comparison_constraints.png")


# Wires
plt.figure(figsize=(8, 5))
plt.plot(
    x,
    get(cardinality, "wires"),
    marker="o",
    label="Cardinality"
)
plt.plot(
    xb,
    get(balance, "wires"),
    marker="o",
    label="Balance"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Wires")
plt.title("Confronto - Wires")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("comparison_wires.png")


# Proof + verification
plt.figure(figsize=(8, 5))
plt.plot(
    x,
    get(cardinality, "proof_time"),
    marker="o",
    label="Cardinality - Proof"
)
plt.plot(
    xb,
    get(balance, "proof_time"),
    marker="o",
    label="Balance - Proof"
)
plt.plot(
    x,
    get(cardinality, "verify_time"),
    marker="o",
    linestyle="--",
    label="Cardinality - Verify"
)
plt.plot(
    xb,
    get(balance, "verify_time"),
    marker="o",
    linestyle="--",
    label="Balance - Verify"
)
plt.xlabel("Numero di elementi")
plt.ylabel("Tempo (s)")
plt.title("Confronto - Proof e Verification")
plt.legend()
plt.grid(True, alpha=0.3)
save_plot("comparison_proof_verify_times.png")


print("============================================")
print("       PLOT GENERATI")
print("============================================")
print()
print("Directory:")
print(PLOTS_DIR)
print()
print("File generati:")

for filename in sorted(os.listdir(PLOTS_DIR)):
    if filename.endswith(".png"):
        print(" -", filename)