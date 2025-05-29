#include <assert.h>
#include <stdio.h>

// Forward declaration of the function to test
long fibonacci(int n);

void test_fibonacci_base_cases() {
    assert(fibonacci(0) == 0);
    assert(fibonacci(1) == 1);
    printf("Base cases passed\n");
}

void test_fibonacci_small_values() {
    assert(fibonacci(2) == 1);
    assert(fibonacci(3) == 2);
    assert(fibonacci(4) == 3);
    assert(fibonacci(5) == 5);
    printf("Small values passed\n");
}

void test_fibonacci_larger_values() {
    assert(fibonacci(6) == 8);
    assert(fibonacci(7) == 13);
    assert(fibonacci(8) == 21);
    assert(fibonacci(9) == 34);
    assert(fibonacci(10) == 55);
    printf("Larger values passed\n");
}

int main() {
    printf("Running Fibonacci unit tests...\n");
    
    test_fibonacci_base_cases();
    test_fibonacci_small_values();
    test_fibonacci_larger_values();
    
    printf("All tests passed!\n");
    return 0;
} 