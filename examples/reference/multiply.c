// test_mul.c
void main() {
    volatile int a = 6; // volatile prevents compiler from optimizing it away
    volatile int b = 7;
    volatile int result = a * b;

    // Stop here so we can inspect 'result' in the waveform/simulation
    while(1); 
}