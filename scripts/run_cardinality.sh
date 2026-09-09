#!/bin/bash

set -e

SIZE=$1
THRESHOLD=$2

if [ -z "$SIZE" ] || [ -z "$THRESHOLD" ]; then
    echo "Uso: ./scripts/run_cardinality.sh SIZE THRESHOLD"
    echo "Esempio: ./scripts/run_cardinality.sh 1000 900"
    exit 1
fi

CIRCUIT_DIR="build/cardinality"
INPUT="inputs/cardinality_input.json"
WASM="$CIRCUIT_DIR/cardinality_js/cardinality.wasm"
R1CS="$CIRCUIT_DIR/cardinality.r1cs"
WITNESS="$CIRCUIT_DIR/witness.wtns"

ZKEY="keys/cardinality/cardinality_final.zkey"
VKEY="keys/cardinality/verification_key.json"

PROOF_DIR="proofs/cardinality"
RESULTS_DIR="results"

PROOF="$PROOF_DIR/proof.json"
PUBLIC="$PROOF_DIR/public.json"
RESULT="$RESULTS_DIR/cardinality_${SIZE}.json"

mkdir -p "$CIRCUIT_DIR"
mkdir -p "$PROOF_DIR"
mkdir -p "$RESULTS_DIR"

echo "============================================"
echo "       CARDINALITY ZK-SNARK PIPELINE"
echo "============================================"
echo "SIZE      = $SIZE"
echo "THRESHOLD = $THRESHOLD"
echo "============================================"
echo

# ------------------------------------------------
# 1. PREPROCESSING
# ------------------------------------------------

echo "[1/8] Preprocessing MNIST..."

START=$(python3 -c 'import time; print(time.time())')

python3 python/preprocessing_dataset.py "$SIZE"

END=$(python3 -c 'import time; print(time.time())')
PREPROCESS_TIME=$(python3 -c "print(round($END-$START, 4))")

echo "       ✓ completato in ${PREPROCESS_TIME}s"
echo

# ------------------------------------------------
# 2. COMPILAZIONE CIRCUITO
# ------------------------------------------------

echo "[2/8] Compilazione circuito..."

rm -rf "$CIRCUIT_DIR"
mkdir -p "$CIRCUIT_DIR"

START=$(python3 -c 'import time; print(time.time())')

circom circuits/cardinality.circom \
    --r1cs --wasm --sym \
    -l node_modules/circomlib/circuits \
    -o "$CIRCUIT_DIR"

END=$(python3 -c 'import time; print(time.time())')
COMPILE_TIME=$(python3 -c "print(round($END-$START, 4))")

echo "       ✓ completato in ${COMPILE_TIME}s"
echo

# ------------------------------------------------
# 3. INFORMAZIONI R1CS
# ------------------------------------------------

echo "[3/8] Analisi R1CS..."

R1CS_INFO=$(snarkjs r1cs info "$R1CS")

echo "$R1CS_INFO"

CONSTRAINTS=$(echo "$R1CS_INFO" | grep "# of Constraints" | awk '{print $5}')
WIRES=$(echo "$R1CS_INFO" | grep "# of Wires" | awk '{print $5}')

echo
echo "       Constraints : $CONSTRAINTS"
echo "       Wires       : $WIRES"
echo

# ------------------------------------------------
# 4. GENERAZIONE WITNESS
# ------------------------------------------------

echo "[4/8] Generazione witness..."

START=$(python3 -c 'import time; print(time.time())')

snarkjs wtns calculate \
    "$WASM" \
    "$INPUT" \
    "$WITNESS"

END=$(python3 -c 'import time; print(time.time())')
WITNESS_TIME=$(python3 -c "print(round($END-$START, 4))")

echo "       ✓ completato in ${WITNESS_TIME}s"
echo

# ------------------------------------------------
# 5. VERIFICA WITNESS
# ------------------------------------------------

echo "[5/8] Verifica witness..."

snarkjs wtns check \
    "$R1CS" \
    "$WITNESS"

echo "       ✓ WITNESS IS CORRECT"
echo

# ------------------------------------------------
# 6. GENERAZIONE PROOF
# ------------------------------------------------

echo "[6/8] Generazione Groth16 proof..."

START=$(python3 -c 'import time; print(time.time())')

snarkjs groth16 prove \
    "$ZKEY" \
    "$WITNESS" \
    "$PROOF" \
    "$PUBLIC"

END=$(python3 -c 'import time; print(time.time())')
PROOF_TIME=$(python3 -c "print(round($END-$START, 4))")

echo "       ✓ proof generata in ${PROOF_TIME}s"
echo

# ------------------------------------------------
# 7. VERIFICA PROOF
# ------------------------------------------------

echo "[7/8] Verifica Groth16 proof..."

START=$(python3 -c 'import time; print(time.time())')

snarkjs groth16 verify \
    "$VKEY" \
    "$PUBLIC" \
    "$PROOF"

END=$(python3 -c 'import time; print(time.time())')
VERIFY_TIME=$(python3 -c "print(round($END-$START, 4))")

echo "       ✓ PROOF IS VALID"
echo "       ✓ verifica completata in ${VERIFY_TIME}s"
echo

# ------------------------------------------------
# 8. RISULTATI
# ------------------------------------------------

echo "[8/8] Salvataggio risultati..."

python3 - "$RESULT" "$SIZE" "$THRESHOLD" "$CONSTRAINTS" "$WIRES" \
    "$PREPROCESS_TIME" "$COMPILE_TIME" "$WITNESS_TIME" \
    "$PROOF_TIME" "$VERIFY_TIME" <<'PY'

import json
import sys
import os

output_file = sys.argv[1]

data = {
    "circuit": "cardinality",
    "size": int(sys.argv[2]),
    "threshold": int(sys.argv[3]),
    "constraints": int(sys.argv[4]),
    "wires": int(sys.argv[5]),
    "times": {
        "preprocessing": float(sys.argv[6]),
        "compilation": float(sys.argv[7]),
        "witness_generation": float(sys.argv[8]),
        "proof_generation": float(sys.argv[9]),
        "proof_verification": float(sys.argv[10])
    },
    "proof_valid": True
}

with open(output_file, "w") as f:
    json.dump(data, f, indent=4)

print(f"       ✓ risultati salvati in {output_file}")

PY

echo
echo "============================================"
echo "          PIPELINE COMPLETATA"
echo "============================================"
echo "Circuito : $CIRCUIT_DIR/"
echo "Witness  : $WITNESS"
echo "Proof    : $PROOF"
echo "Public   : $PUBLIC"
echo "Results  : $RESULT"
echo "============================================"