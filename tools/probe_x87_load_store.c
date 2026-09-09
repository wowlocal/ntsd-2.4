/* Research-only x86 x87 load/store witness. Run on x86 hardware or explicitly
 * identify translation (e.g. Rosetta). This does not execute the Windows game.
 * The FLDQ/FSTPQ operand types are the ones at421a48/421a4f/421a5a/421a5d. */
#include <stdint.h>
#include <stdio.h>
#if defined(__APPLE__)
#include <sys/sysctl.h>
#endif
int main(void) {
    const uint64_t words[] = {0, 1, 0x000fffffffffffffULL, 0x0010000000000000ULL,
        0x3fb999999999999aULL, 0x7fefffffffffffffULL, 0x7ff0000000000000ULL,
        0x7ff0000000000001ULL, 0x7ff7ffffffffffffULL, 0x7ff8000000000000ULL,
        0x7ff8000000000001ULL, 0x7fffffffffffffffULL};
    int translated = 0;
#if defined(__APPLE__)
    size_t length = sizeof(translated);
    if (sysctlbyname("sysctl.proc_translated", &translated, &length, NULL, 0)) translated = 0;
#endif
    printf("{\"translated\":%s,\"cases\":[", translated ? "true" : "false");
    int first = 1;
    for (unsigned i = 0; i < sizeof(words)/sizeof(words[0]); ++i) {
        for (unsigned sign = 0; sign < 2; ++sign) {
            uint64_t input = words[i] | (uint64_t)sign << 63, output = 0;
            uint16_t cw = 0x23f, status;
            __asm__ volatile("fninit\n\tfldcw %3\n\tfldl %2\n\tfstpl %0\n\tfnstsw %1"
                : "=m"(output), "=m"(status) : "m"(input), "m"(cw) : "st");
            printf("%s{\"input\":\"%016llx\",\"output\":\"%016llx\",\"cw\":%u,\"sw\":%u}",
                first ? "" : ",", (unsigned long long)input, (unsigned long long)output, cw, status);
            first = 0;
        }
    }
    __asm__ volatile("fninit");
    puts("]}"); return 0;
}
