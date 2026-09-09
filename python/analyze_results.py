import os
import pandas as pd
import matplotlib.pyplot as plt


RESULTS_DIR = "results/cardinality"
CSV_FILE = os.path.join(RESULTS_DIR, "benchmark.csv")
PLOTS_DIR = os.path.join(RESULTS_DIR, "plots")


os.makedirs(PLOTS_DIR, exist_ok=True)


print("============================================")
print("       CARDINALITY RESULTS ANALYSIS")
print("============================================")


# --------------------------------------------------
# Caricamento dati
# --------------------------------------------------

if not os.path.exists(CSV_FILE):
    print(f"[ERROR] File non trovato: {CSV_FILE}")
    print("Esegui prima:")
    print("./scripts/benchmark_cardinality.sh")
    exit(1)


df = pd.read_csv(CSV_FILE)


print("")
print("Dati caricati:")
print(df.to_string(index=False))


# --------------------------------------------------
# Conversione byte -> KB
# --------------------------------------------------

df["witness_kb"] = df["witness_bytes"] / 1024
df["proof_kb"] = df["proof_bytes"] / 1024
df["zkey_kb"] = df["zkey_bytes"] / 1024


# --------------------------------------------------
# Funzione generica per i grafici
# --------------------------------------------------

def create_plot(x, y, xlabel, ylabel, title, filename):
    plt.figure()

    plt.plot(df[x], df[y], marker="o")

    plt.xlabel(xlabel)
    plt.ylabel(ylabel)
    plt.title(title)

    plt.grid(True)

    plt.tight_layout()

    output = os.path.join(PLOTS_DIR, filename)

    plt.savefig(output, dpi=200)

    plt.close()

    print(f"[OK] Creato: {output}")


# --------------------------------------------------
# 1. Constraints
# --------------------------------------------------

create_plot(
    "size",
    "constraints",
    "Numero di elementi",
    "Numero di constraint",
    "R1CS constraints vs dataset size",
    "constraints_vs_size.png"
)


# --------------------------------------------------
# 2. Wires
# --------------------------------------------------

create_plot(
    "size",
    "wires",
    "Numero di elementi",
    "Numero di wires",
    "R1CS wires vs dataset size",
    "wires_vs_size.png"
)


# --------------------------------------------------
# 3. Witness generation
# --------------------------------------------------

create_plot(
    "size",
    "witness_time",
    "Numero di elementi",
    "Tempo (s)",
    "Witness generation time",
    "witness_time_vs_size.png"
)


# --------------------------------------------------
# 4. Proof generation
# --------------------------------------------------

create_plot(
    "size",
    "proof_time",
    "Numero di elementi",
    "Tempo (s)",
    "Groth16 proof generation time",
    "proof_time_vs_size.png"
)


# --------------------------------------------------
# 5. Verification
# --------------------------------------------------

create_plot(
    "size",
    "verify_time",
    "Numero di elementi",
    "Tempo (s)",
    "Groth16 verification time",
    "verification_time_vs_size.png"
)


# --------------------------------------------------
# 6. Dimensioni file
# --------------------------------------------------

plt.figure()

plt.plot(
    df["size"],
    df["witness_kb"],
    marker="o",
    label="Witness"
)

plt.plot(
    df["size"],
    df["proof_kb"],
    marker="o",
    label="Proof"
)

plt.plot(
    df["size"],
    df["zkey_kb"],
    marker="o",
    label="zKey"
)

plt.xlabel("Numero di elementi")
plt.ylabel("Dimensione (KB)")
plt.title("Dimensione degli artefatti")

plt.legend()
plt.grid(True)

plt.tight_layout()

output = os.path.join(
    PLOTS_DIR,
    "file_sizes_vs_size.png"
)

plt.savefig(output, dpi=200)

plt.close()

print(f"[OK] Creato: {output}")


# --------------------------------------------------
# Tabella riassuntiva
# --------------------------------------------------

summary = df[
    [
        "size",
        "threshold",
        "constraints",
        "wires",
        "witness_time",
        "proof_time",
        "verify_time",
        "witness_bytes",
        "proof_bytes",
        "zkey_bytes",
        "verification"
    ]
]

SUMMARY_FILE = os.path.join(
    RESULTS_DIR,
    "benchmark_summary.csv"
)

summary.to_csv(
    SUMMARY_FILE,
    index=False
)


print("")
print("============================================")
print("       ANALISI COMPLETATA")
print("============================================")

print("")
print("Grafici:")
print(PLOTS_DIR)

print("")
print("Tabella:")
print(SUMMARY_FILE)

print("")
print("============================================")