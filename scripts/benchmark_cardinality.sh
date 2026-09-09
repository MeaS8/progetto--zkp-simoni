#!/bin/bash

set -u

echo "============================================"
echo "      CARDINALITY BENCHMARK"
echo "============================================"

SIZES=(100 500 1000 2000 4000)

RESULTS_DIR="results/cardinality"
CSV_FILE="$RESULTS_DIR/benchmark.csv"

mkdir -p "$RESULTS_DIR"

echo "size,threshold,constraints,wires,witness_time,proof_time,verify_time,witness_bytes,proof_bytes,zkey_bytes,verification" > "$CSV_FILE"


for SIZE in "${SIZES[@]}"; do

    THRESHOLD=$((SIZE * 90 / 100))

    echo ""
    echo "============================================"
    echo " SIZE      = $SIZE"
    echo " THRESHOLD = $THRESHOLD"
    echo "============================================"


    # ==================================================
    # 1. PREPROCESSING
    # ==================================================

    echo ""
    echo "[1/6] Preprocessing MNIST..."

    python3 python/preprocessing_dataset.py "$SIZE" "$THRESHOLD"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Preprocessing fallito per SIZE=$SIZE"
        continue
    fi


    # ==================================================
    # 2. COMPILAZIONE CIRCUITO
    # ==================================================

    echo ""
    echo "[2/6] Compilazione circuito SIZE=$SIZE..."

    rm -rf build/cardinality
    mkdir -p build/cardinality

    sed "s/Cardinality(1000)/Cardinality($SIZE)/" \
        circuits/cardinality.circom \
        > build/cardinality/cardinality.circom

    circom build/cardinality/cardinality.circom \
        --r1cs \
        --wasm \
        --sym \
        -l node_modules/circomlib/circuits \
        -o build/cardinality

    if [ $? -ne 0 ]; then
        echo "[ERROR] Compilazione fallita per SIZE=$SIZE"
        continue
    fi

    R1CS="build/cardinality/cardinality.r1cs"
    WASM="build/cardinality/cardinality_js/cardinality.wasm"
    WITNESS="build/cardinality/witness.wtns"

    echo "R1CS   : $R1CS"
    echo "WASM   : $WASM"


    # ==================================================
    # 3. R1CS INFO
    # ==================================================

    echo ""
    echo "[3/6] Lettura informazioni R1CS..."

    # snarkjs scrive le informazioni su stderr,
    # quindi catturo stdout + stderr.
    R1CS_INFO=$(snarkjs r1cs info "$R1CS" 2>&1)

    echo "$R1CS_INFO"

    CONSTRAINTS=$(echo "$R1CS_INFO" | \
        sed -n 's/.*# of Constraints: \([0-9][0-9]*\).*/\1/p' | \
        head -n 1)

    WIRES=$(echo "$R1CS_INFO" | \
        sed -n 's/.*# of Wires: \([0-9][0-9]*\).*/\1/p' | \
        head -n 1)

    if [ -z "$CONSTRAINTS" ]; then
        echo "[ERROR] Impossibile leggere il numero di constraints"
        continue
    fi

    if [ -z "$WIRES" ]; then
        echo "[ERROR] Impossibile leggere il numero di wires"
        continue
    fi

    echo ""
    echo "Constraints: $CONSTRAINTS"
    echo "Wires      : $WIRES"


    # ==================================================
    # 4. WITNESS
    # ==================================================

    echo ""
    echo "[4/6] Generazione witness..."

    WITNESS_TIME_FILE=$(mktemp)

    /usr/bin/time -p \
        snarkjs wtns calculate \
        "$WASM" \
        inputs/cardinality_input.json \
        "$WITNESS" \
        > /dev/null 2> "$WITNESS_TIME_FILE"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Witness generation fallita per SIZE=$SIZE"
        rm -f "$WITNESS_TIME_FILE"
        continue
    fi

    WITNESS_TIME=$(awk '/^real/ {print $2}' "$WITNESS_TIME_FILE")

    rm -f "$WITNESS_TIME_FILE"

    echo "Witness time: ${WITNESS_TIME}s"


    # Verifica witness

    snarkjs wtns check \
        "$R1CS" \
        "$WITNESS"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Witness non valido"
        continue
    fi


    # ==================================================
    # 5. GROTH16 SETUP
    # ==================================================

    echo ""
    echo "[5/6] Setup Groth16..."

    KEY_DIR="keys/cardinality/size_${SIZE}"

    ZKEY="$KEY_DIR/cardinality_final.zkey"
    VKEY="$KEY_DIR/verification_key.json"

    if [ ! -f "$ZKEY" ] || [ ! -f "$VKEY" ]; then

        echo "Setup non presente: lo creo..."

        ./scripts/setup_cardinality.sh "$SIZE"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Setup fallito per SIZE=$SIZE"
            continue
        fi

    else

        echo "Setup già presente: riutilizzo le chiavi."

    fi


    # Controllo esplicito che il setup abbia creato la zkey

    if [ ! -f "$ZKEY" ]; then
        echo "[ERROR] ZKey non trovata:"
        echo "$ZKEY"
        continue
    fi

    if [ ! -f "$VKEY" ]; then
        echo "[ERROR] Verification key non trovata:"
        echo "$VKEY"
        continue
    fi


    # ==================================================
    # 6. PROOF + VERIFICATION
    # ==================================================

    echo ""
    echo "[6/6] Generazione proof..."

    PROOF_DIR="proofs/cardinality/size_${SIZE}"

    mkdir -p "$PROOF_DIR"

    PROOF="$PROOF_DIR/proof.json"
    PUBLIC="$PROOF_DIR/public.json"


    # --------------------------------------------------
    # PROOF
    # --------------------------------------------------

    PROOF_TIME_FILE=$(mktemp)

    /usr/bin/time -p \
        snarkjs groth16 prove \
        "$ZKEY" \
        "$WITNESS" \
        "$PROOF" \
        "$PUBLIC" \
        > /dev/null 2> "$PROOF_TIME_FILE"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Proof generation fallita"
        rm -f "$PROOF_TIME_FILE"
        continue
    fi

    PROOF_TIME=$(awk '/^real/ {print $2}' "$PROOF_TIME_FILE")

    rm -f "$PROOF_TIME_FILE"

    echo "Proof time: ${PROOF_TIME}s"


    # --------------------------------------------------
    # VERIFICATION
    # --------------------------------------------------

    VERIFY_TIME_FILE=$(mktemp)

    /usr/bin/time -p \
        snarkjs groth16 verify \
        "$VKEY" \
        "$PUBLIC" \
        "$PROOF" \
        > /dev/null 2> "$VERIFY_TIME_FILE"

    VERIFY_STATUS=$?

    VERIFY_TIME=$(awk '/^real/ {print $2}' "$VERIFY_TIME_FILE")

    rm -f "$VERIFY_TIME_FILE"


    if [ $VERIFY_STATUS -eq 0 ]; then
        VERIFICATION="OK"
    else
        VERIFICATION="FAIL"
    fi

    echo "Verification: $VERIFICATION"
    echo "Verify time : ${VERIFY_TIME}s"


    # ==================================================
    # FILE SIZES
    # ==================================================

    WITNESS_BYTES=$(stat -f%z "$WITNESS")
    PROOF_BYTES=$(stat -f%z "$PROOF")
    ZKEY_BYTES=$(stat -f%z "$ZKEY")


    # ==================================================
    # SALVATAGGIO RISULTATI
    # ==================================================

    echo "$SIZE,$THRESHOLD,$CONSTRAINTS,$WIRES,$WITNESS_TIME,$PROOF_TIME,$VERIFY_TIME,$WITNESS_BYTES,$PROOF_BYTES,$ZKEY_BYTES,$VERIFICATION" \
        >> "$CSV_FILE"


    # ==================================================
    # RISULTATO
    # ==================================================

    echo ""
    echo "============================================"
    echo " RISULTATO SIZE=$SIZE"
    echo "============================================"

    echo "Constraints : $CONSTRAINTS"
    echo "Wires       : $WIRES"
    echo "Witness     : ${WITNESS_TIME}s"
    echo "Proof       : ${PROOF_TIME}s"
    echo "Verify      : ${VERIFY_TIME}s"
    echo "Witness     : ${WITNESS_BYTES} bytes"
    echo "Proof       : ${PROOF_BYTES} bytes"
    echo "zKey        : ${ZKEY_BYTES} bytes"
    echo "Verification: $VERIFICATION"

    echo "============================================"

done


# ==================================================
# FINE
# ==================================================

echo ""
echo "============================================"
echo "       BENCHMARK COMPLETATO"
echo "============================================"

echo ""
echo "Risultati salvati in:"
echo "$CSV_FILE"

echo ""
cat "$CSV_FILE"