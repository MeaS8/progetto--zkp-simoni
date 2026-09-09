pragma circom 2.2.3;

include "comparators.circom";

template Cardinality(SIZE) {

    // Input privati
    signal input labels[SIZE];
    signal input enabled[SIZE];

    // Input pubblico
    signal input threshold;

    // Somme parziali interne
    signal partial[SIZE];

    // Ogni enabled deve essere 0 oppure 1
    for (var i = 0; i < SIZE; i++) {
        enabled[i] * (1 - enabled[i]) === 0;
    }

    // Somme parziali
    partial[0] <== enabled[0];

    for (var i = 1; i < SIZE; i++) {
        partial[i] <== partial[i - 1] + enabled[i];
    }

    // Verifica: cardinality >= threshold
    // 16 bit permettono di rappresentare valori fino a 65535
    component check = GreaterEqThan(16);

    check.in[0] <== partial[SIZE - 1];
    check.in[1] <== threshold;

    // La disuguaglianza deve essere soddisfatta
    check.out === 1;
}

// Il valore viene sostituito automaticamente
// dallo script di benchmark/setup.
component main {public [threshold]} = Cardinality(1000);