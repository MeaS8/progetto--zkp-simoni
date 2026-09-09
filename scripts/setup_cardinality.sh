#!/bin/bash

set -e

SIZE=$1

if [ -z "$SIZE" ]; then
    echo "Uso: ./scripts/setup_cardinality.sh SIZE"
    exit 1
fi

echo "============================================"
echo "       CARDINALITY GROTH16 SETUP"
echo "============================================"
echo "SIZE = $SIZE"
echo "============================================"

PTAU_DIR="keys/cardinality/ptau/size_${SIZE}"
KEY_DIR="keys/cardinality/size_${SIZE}"

# Il benchmark genera questo file
R1CS="build/cardinality/cardinality.r1cs"

mkdir -p "$PTAU_DIR"
mkdir -p "$KEY_DIR"


# ============================================================
# Calcolo automatico del POWER
# ============================================================

CONSTRAINT_ESTIMATE=$((2 * SIZE + 100))

POWER=1

while [ $((2 ** POWER)) -lt "$CONSTRAINT_ESTIMATE" ]; do
    POWER=$((POWER + 1))
done

echo "POWER = $POWER"
echo "Powers of Tau: 2^$POWER"
echo


# ============================================================
# Controllo R1CS
# ============================================================

if [ ! -f "$R1CS" ]; then

    echo "[ERROR] R1CS non trovato:"
    echo "        $R1CS"
    echo
    echo "Assicurati che il circuito sia stato compilato prima del setup."

    exit 1
fi


# ============================================================
# 1. Powers of Tau
# ============================================================

echo "[1/6] Creazione Powers of Tau..."

snarkjs powersoftau new bn128 "$POWER" \
    "$PTAU_DIR/pot${POWER}_0000.ptau" \
    -v


# ============================================================
# 2. Contribution
# ============================================================

echo
echo "[2/6] Contribution Powers of Tau..."

snarkjs powersoftau contribute \
    "$PTAU_DIR/pot${POWER}_0000.ptau" \
    "$PTAU_DIR/pot${POWER}_0001.ptau" \
    --name="Cardinality contribution SIZE=$SIZE" \
    -v


# ============================================================
# 3. Verifica Powers of Tau
# ============================================================

echo
echo "[3/6] Verifica Powers of Tau..."

snarkjs powersoftau verify \
    "$PTAU_DIR/pot${POWER}_0001.ptau"


# ============================================================
# 4. Preparazione Phase 2
# ============================================================

echo
echo "[4/6] Preparazione Phase 2..."

snarkjs powersoftau prepare phase2 \
    "$PTAU_DIR/pot${POWER}_0001.ptau" \
    "$PTAU_DIR/pot${POWER}_final.ptau"


# ============================================================
# 5. Groth16 setup
# ============================================================

echo
echo "[5/6] Groth16 setup..."

snarkjs groth16 setup \
    "$R1CS" \
    "$PTAU_DIR/pot${POWER}_final.ptau" \
    "$KEY_DIR/cardinality_0000.zkey"


# ============================================================
# 6. Contribution + verifica zKey
# ============================================================

echo
echo "[6/6] Contribution e verifica zKey..."

snarkjs zkey contribute \
    "$KEY_DIR/cardinality_0000.zkey" \
    "$KEY_DIR/cardinality_final.zkey" \
    --name="Cardinality zkey contribution SIZE=$SIZE" \
    -v

snarkjs zkey verify \
    "$R1CS" \
    "$PTAU_DIR/pot${POWER}_final.ptau" \
    "$KEY_DIR/cardinality_final.zkey"

snarkjs zkey export verificationkey \
    "$KEY_DIR/cardinality_final.zkey" \
    "$KEY_DIR/verification_key.json"



# ============================================================

echo
echo "============================================"
echo "       SETUP COMPLETATO"
echo "============================================"
echo "R1CS          : $R1CS"
echo "Powers of Tau : $PTAU_DIR"
echo "zKey          : $KEY_DIR/cardinality_final.zkey"
echo "Verification  : $KEY_DIR/verification_key.json"
echo "============================================"