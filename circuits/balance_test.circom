pragma circom 2.2.3;

include "comparators.circom";

template Balance(SIZE, NUM_CLASSES) {

    // ==================================================
    // INPUT
    // ==================================================

    // Input privati
    signal input labels[SIZE];
    signal input enabled[SIZE];

    // Input pubblici
    signal input Tb;
    signal input Ta;


    // ==================================================
    // SOMME PARZIALI
    // ==================================================

    // partial[c][i] contiene il numero di elementi
    // della classe c nei primi i elementi.
    signal partial[NUM_CLASSES][SIZE + 1];


    // ==================================================
    // COMPONENTI
    // ==================================================

    // Controllo che enabled[i] sia 0 oppure 1
    // Il vincolo viene imposto direttamente sotto.

    // Controllo validità delle label
    component validLabel[SIZE];

    // Confronto labels[i] == c
    component equality[SIZE][NUM_CLASSES];

    // Controllo count[c] >= Tb
    component lower[NUM_CLASSES];

    // Controllo count[c] <= Ta
    component upper[NUM_CLASSES];


    // ==================================================
    // CONTROLLO ENABLED
    // ==================================================

    for (var i = 0; i < SIZE; i++) {

        enabled[i] * (1 - enabled[i]) === 0;
    }


    // ==================================================
    // INIZIALIZZAZIONE
    // ==================================================

    for (var c = 0; c < NUM_CLASSES; c++) {

        partial[c][0] <== 0;
    }


    // ==================================================
    // CONTROLLO LABEL
    // ==================================================

    for (var i = 0; i < SIZE; i++) {

        // La label deve essere < NUM_CLASSES
        //
        // Per MNIST:
        // 0 <= label < 10

        validLabel[i] = LessThan(4);

        validLabel[i].in[0] <== labels[i];
        validLabel[i].in[1] <== NUM_CLASSES;

        // Il controllo è richiesto solo per
        // gli elementi effettivamente utilizzati.

        enabled[i] * (1 - validLabel[i].out) === 0;
    }


    // ==================================================
    // CONTEGGIO DELLE CLASSI
    // ==================================================

    for (var i = 0; i < SIZE; i++) {

        for (var c = 0; c < NUM_CLASSES; c++) {

            // Verifica:
            //
            // labels[i] == c

            equality[i][c] = IsEqual();

            equality[i][c].in[0] <== labels[i];
            equality[i][c].in[1] <== c;


            // Somma parziale:
            //
            // partial[c][i+1] =
            //     partial[c][i]
            //     + enabled[i] * equality[i][c].out

            partial[c][i + 1] <==
                partial[c][i]
                + enabled[i] * equality[i][c].out;
        }
    }


    // ==================================================
    // VERIFICA DEL BILANCIAMENTO
    // ==================================================

    for (var c = 0; c < NUM_CLASSES; c++) {

        // count[c] >= Tb

        lower[c] = GreaterEqThan(16);

        lower[c].in[0] <== partial[c][SIZE];
        lower[c].in[1] <== Tb;

        lower[c].out === 1;


        // count[c] <= Ta

        upper[c] = LessEqThan(16);

        upper[c].in[0] <== partial[c][SIZE];
        upper[c].in[1] <== Ta;

        upper[c].out === 1;
    }
}


// ==================================================
// MAIN
// ==================================================

component main {public [Tb, Ta]} = Balance(100, 10);