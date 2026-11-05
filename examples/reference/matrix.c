// void main() {
//     // REMOVED: asm volatile("li sp, 0x80000"); 
//     // The Python script now sets SP to 1024 automatically.
    
//     int a = 6;
//     int b = 7;
//     int result = a * b;
// }

int main() {
    // Input matrices
    int A[2][2] = {
        {1, 2},
        {3, 4}
    };

    int B[2][2] = {
        {5, 6},
        {7, 8}
    };

    // Output matrix
    int C[2][2];

    // Matrix multiplication
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            int sum = 0;
            for (int k = 0; k < 2; k++) {
                sum += A[i][k] * B[k][j];
            }
            C[i][j] = sum;
        }
    }

    // END OF PROGRAM — infinite loop so CPU doesn’t run into garbage
    while (1) { }

    return 0;
}
