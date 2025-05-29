#include <stdio.h>

/**
 * Calculate the nth Fibonacci number
 * 
 * @param n The position in the Fibonacci sequence (0-indexed)
 * @return The nth Fibonacci number
 * 
 * TODO: Implement this function using either recursion or iteration
 * 
 * Examples:
 * fibonacci(0) should return 0
 * fibonacci(1) should return 1
 * fibonacci(5) should return 5
 * fibonacci(10) should return 55
 */
long fibonacci(int n) {
    // Your implementation here
    return 0;
}

int main() {
    int n;
    
    // Read input
    if (scanf("%d", &n) != 1) {
        fprintf(stderr, "Error reading input\n");
        return 1;
    }
    
    // Calculate and print result
    printf("%ld\n", fibonacci(n));
    
    return 0;
} 