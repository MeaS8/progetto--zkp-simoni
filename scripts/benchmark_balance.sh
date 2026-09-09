#!/bin/bash

set -u

echo "============================================"
echo "        BALANCE BENCHMARK"
echo "============================================"

# Dimensioni ridotte
SIZES=(100 200 300 400)

RESULTS_DIR="results/balance"
CSV_FILE="$RESULTS_DIR/benchmark.csv"

mkdir -p "$RESULTS_DIR"
mkdir -p "keys/balance"
mkdir -p "proofs/balance"

echo "size,Tb,Ta,constraints,wires,witness_time,setup_time,proof_time,verify_time,witness_bytes,proof_bytes,zkey_bytes,verification" > "$CSV_FILE"


for SIZE in "${SIZES[@]}"; do

    TB=$((SIZE * 2 / 100))
    TA=$((SIZE * 20 / 100))

    echo ""
    echo "============================================"
    echo " SIZE = $SIZE"
    echo " Tb   = $TB"
    echo " Ta   = $TA"
    echo "============================================"


    # ==================================================
    # 1. PREPROCESSING
    # ==================================================

    echo ""
    echo "[1/7] Preprocessing MNIST..."

    python3 python/preprocessing_dataset.py "$SIZE" "$((SIZE * 90 / 100))"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Preprocessing fallito per SIZE=$SIZE"
        continue
    fi


    # ==================================================
    # 2. COMPILAZIONE
    # ==================================================

    echo ""
    echo "[2/7] Compilazione circuito SIZE=$SIZE..."

    rm -rf build/balance
    mkdir -p build/balance

    sed "s/Balance(1000, 10)/Balance($SIZE, 10)/" \
        circuits/balance.circom \
        > build/balance/balance.circom

    circom build/balance/balance.circom \
        --r1cs \
        --wasm \
        --sym \
        -l node_modules/circomlib/circuits \
        -o build/balance

    if [ $? -ne 0 ]; then
        echo "[ERROR] Compilazione fallita per SIZE=$SIZE"
        continue
    fi

    R1CS="build/balance/balance.r1cs"
    WASM="build/balance/balance_js/balance.wasm"
    WITNESS="build/balance/witness.wtns"


    # ==================================================
    # 3. R1CS INFO
    # ==================================================

    echo ""
    echo "[3/7] Lettura informazioni R1CS..."

    R1CS_INFO=$(snarkjs r1cs info "$R1CS" 2>&1)

    echo "$R1CS_INFO"

    CONSTRAINTS=$(echo "$R1CS_INFO" |
        sed -n 's/.*# of Constraints: \([0-9][0-9]*\).*/\1/p' |
        head -n 1)

    WIRES=$(echo "$R1CS_INFO" |
        sed -n 's/.*# of Wires: \([0-9][0-9]*\).*/\1/p' |
        head -n 1)


    # ==================================================
    # 4. WITNESS
    # ==================================================

    echo ""
    echo "[4/7] Generazione witness..."

    WITNESS_TIME_FILE=$(mktemp)

    /usr/bin/time -p \
        snarkjs wtns calculate \
        "$WASM" \
        inputs/balance_input.json \
        "$WITNESS" \
        > /dev/null 2> "$WITNESS_TIME_FILE"

    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "[ERROR] Witness generation fallita per SIZE=$SIZE"
        cat "$WITNESS_TIME_FILE"
        rm -f "$WITNESS_TIME_FILE"
        continue
    fi

    WITNESS_TIME=$(awk '/^real/ {print $2}' "$WITNESS_TIME_FILE")

    rm -f "$WITNESS_TIME_FILE"

    echo "Witness time: ${WITNESS_TIME}s"


    # Controllo witness
    snarkjs wtns check \
        "$R1CS" \
        "$WITNESS"

    if [ $? -ne 0 ]; then
        echo "[ERROR] Witness non valida"
        continue
    fi


    # ==================================================
    # 5. GROTH16 SETUP
    # ==================================================

    echo ""
    echo "[5/7] Setup Groth16..."

    KEY_DIR="keys/balance/size_${SIZE}"

    mkdir -p "$KEY_DIR"

    ZKEY_0000="$KEY_DIR/balance_0000.zkey"
    ZKEY="$KEY_DIR/balance_final.zkey"
    VKEY="$KEY_DIR/verification_key.json"


    if [ ! -f "$ZKEY" ]; then

        echo "Creo Groth16 zKey..."

        SETUP_TIME_FILE=$(mktemp)

        /usr/bin/time -p \
            snarkjs groth16 setup \
            "$R1CS" \
            keys/balance/ptau/pot16_final_phase2.ptau \
            "$ZKEY_0000" \
            > /dev/null 2> "$SETUP_TIME_FILE"

        STATUS=$?

        if [ $STATUS -ne 0 ]; then
            echo "[ERROR] Groth16 setup fallito"
            cat "$SETUP_TIME_FILE"
            rm -f "$SETUP_TIME_FILE"
            continue
        fi

        SETUP_TIME=$(awk '/^real/ {print $2}' "$SETUP_TIME_FILE")
        rm -f "$SETUP_TIME_FILE"


        echo "Contributo alla zKey..."

        snarkjs zkey contribute \
            "$ZKEY_0000" \
            "$ZKEY" \
            --name="Balance contribution SIZE=$SIZE" \
            <<< "benchmark-$SIZE"

        if [ $? -ne 0 ]; then
            echo "[ERROR] zKey contribution fallita"
            continue
        fi

        rm -f "$ZKEY_0000"

    else

        echo "Setup già presente: riutilizzo le chiavi."
        SETUP_TIME="NA"

    fi


    # Verification key
    if [ ! -f "$VKEY" ]; then

        snarkjs zkey export verificationkey \
            "$ZKEY" \
            "$VKEY"

        if [ $? -ne 0 ]; then
            echo "[ERROR] Export verification key fallito"
            continue
        fi

    fi


    # ==================================================
    # 6. PROOF
    # ==================================================

    echo ""
    echo "[6/7] Generazione proof..."

    PROOF_DIR="proofs/balance/size_${SIZE}"

    mkdir -p "$PROOF_DIR"

    PROOF="$PROOF_DIR/proof.json"
    PUBLIC="$PROOF_DIR/public.json"


    PROOF_TIME_FILE=$(mktemp)

    /usr/bin/time -p \
        snarkjs groth16 prove \
        "$ZKEY" \
        "$WITNESS" \
        "$PROOF" \
        "$PUBLIC" \
        > /dev/null 2> "$PROOF_TIME_FILE"

    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        echo "[ERROR] Proof generation fallita"
        cat "$PROOF_TIME_FILE"
        rm -f "$PROOF_TIME_FILE"
        continue
    fi

    PROOF_TIME=$(awk '/^real/ {print $2}' "$PROOF_TIME_FILE")

    rm -f "$PROOF_TIME_FILE"

    echo "Proof time: ${PROOF_TIME}s"


    # ==================================================
    # 7. VERIFICATION
    # ==================================================

    echo ""
    echo "[7/7] Verifica proof..."

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


    # ==================================================
    # FILE SIZES
    # ==================================================

    WITNESS_BYTES=$(stat -f%z "$WITNESS")
    PROOF_BYTES=$(stat -f%z "$PROOF")
    ZKEY_BYTES=$(stat -f%z "$ZKEY")


    # ==================================================
    # SALVATAGGIO
    # ==================================================

    echo "$SIZE,$TB,$TA,$CONSTRAINTS,$WIRES,$WITNESS_TIME,$SETUP_TIME,$PROOF_TIME,$VERIFY_TIME,$WITNESS_BYTES,$PROOF_BYTES,$ZKEY_BYTES,$VERIFICATION" \
        >> "$CSV_FILE"


    echo ""
    echo "============================================"
    echo " RISULTATO SIZE=$SIZE"
    echo "============================================"

    echo "Constraints : $CONSTRAINTS"
    echo "Wires       : $WIRES"
    echo "Witness     : ${WITNESS_TIME}s"
    echo "Setup       : ${SETUP_TIME}s"
    echo "Proof       : ${PROOF_TIME}s"
    echo "Verify      : ${VERIFY_TIME}s"
    echo "Witness     : ${WITNESS_BYTES} bytes"
    echo "Proof       : ${PROOF_BYTES} bytes"
    echo "zKey        : ${ZKEY_BYTES} bytes"
    echo "Verification: $VERIFICATION"

done


echo ""
echo "============================================"
echo "       BENCHMARK COMPLETATO"
echo "============================================"

echo ""
echo "Risultati salvati in:"
echo "$CSV_FILE"

echo ""
cat "$CSV_FILE"