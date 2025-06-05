#include "consts.h"
#include "params.h"

.macro k_reduction in,out,zeta
vpsrld      %xmm\zeta,%ymm\in,%ymm13     # t = a >> k
vpand       %ymm1,%ymm13,%ymm14          # low = t AND 0xFFFF
vpsrld      $16,%ymm13,%ymm13            # high = t >> 16
vpsubd      %ymm13,%ymm14,%ymm\out       # low - high
.endm

.macro pointwise_mul a0,a1,b0,b1,out0,out1
# Multiply a0*b0, a1*b1
vpmulld     %ymm\a0,%ymm\b0,%ymm12       # a0 * b0
vpmulld     %ymm\a1,%ymm\b1,%ymm13       # a1 * b1
k_reduction 12,\out0,15                  # Reduce a0 * b0
k_reduction 13,\out1,15                  # Reduce a1 * b1

# Compute (a0 + a1)*(b0 + b1)
vpaddd      %ymm\a0,%ymm\a1,%ymm12       # a0 + a1
vpaddd      %ymm\b0,%ymm\b1,%ymm13       # b0 + b1
vpmulld     %ymm12,%ymm13,%ymm12         # (a0 + a1)*(b0 + b1)
k_reduction 12,14,15                     # Reduce p3

# Compute p3 - p1 - p2
vpsubd      %ymm\out0,%ymm14,%ymm14      # p3 - p1
vpsubd      %ymm\out1,%ymm14,%ymm14      # p3 - p1 - p2
.endm

.text
.global cdecl(pointwise_acc_avx)
cdecl(ppointwise_acc_avx):
# Load constants
vmovdqa     _8XFFFF*4(%rcx),%ymm1        # Mask 0xFFFF
vpxor       %ymm15,%ymm15,%ymm15         # Set shift = 0 for K-Reduction

# Load polynomials (16 coefficients, 64 bytes)
vmovdqa     (%rsi),%ymm2                 # a0: a[0..7]
vmovdqa     32(%rsi),%ymm3               # a1: a[8..15]
vmovdqa     (%rdx),%ymm4                 # b0: b[0..7]
vmovdqa     32(%rdx),%ymm5               # b1: b[8..15]

# Karatsuba multiplication
pointwise_mul 2,3,4,5,6,7

# Store results
vmovdqa     %ymm6,(%rdi)                 # c[0..7]
vmovdqa     %ymm7,32(%rdi)               # c[8..15]

ret

# Note: Toom-Cook (Toom-3) implementation for 16 points would split into 3 parts:
# - Divide polynomials into a2*x^12 + a1*x^6 + a0, evaluate at points (0, 1, -1, 2, infinity).
# - Perform 5 pointwise multiplications, interpolate results.
# - For 16 coefficients, Karatsuba is more efficient due to lower overhead.
# - Toom-3 pseudo-code:
#   a0 = a[0..5], a1 = a[6..11], a2 = a[12..15] (pad zeros)
#   Evaluate a(x) at x = 0, 1, -1, 2, inf
#   Multiply pointwise at each evaluation point
#   Interpolate to reconstruct c(x)
#   Apply K-Reduction to each coefficient.

.section .note.GNU-stack,"",@progbits
