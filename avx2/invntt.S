#include "consts.h"
.include "shuffle.inc"

.macro k_reduction_inv in,out,zeta
# Compute shift amount: if zeta <= 16, shift = 16 - zeta; else shift = 48 - zeta
vmovdqa		%ymm\zeta,%ymm15
vpcmpgtd	_8X16*4(%rsi),%ymm15,%ymm14  # zeta > 16 ?
vpaddd		_8X32*4(%rsi),%ymm15,%ymm15  # zeta + 32
vpblendvb	%ymm14,_8X16*4(%rsi),%ymm15,%ymm14  # select 16 or zeta + 32
vpsubd		%ymm\zeta,%ymm14,%ymm14      # shift = 16 - zeta or 48 - zeta

vpsrld		%xmm14,%ymm\in,%ymm13        # t = a >> shift
vpand		%ymm1,%ymm13,%ymm14          # low = t AND 0xFFFF
vpsrld		$16,%ymm13,%ymm13            # high = t >> 16
vpsubd		%ymm13,%ymm14,%ymm\out       # low - high
.endm

.macro butterfly_inv l,h,zh
vpaddd		%ymm\l,%ymm\h,%ymm12         # l' + h'
vpsubd		%ymm\l,%ymm\h,%ymm13         # h' - l'
k_reduction_inv	13,\zh,2                     # (h' - l') * 2^(16-zeta), zeta in %ymm2
vpmulld		_8XNEG1*4(%rsi),%ymm\zh,%ymm\zh # multiply by -1
vpand		%ymm1,%ymm\zh,%ymm13
vpsrld		$16,%ymm\zh,%ymm14
vpsubd		%ymm14,%ymm13,%ymm\h         # h = (h' - l') * (-2^(16-zeta))
vpsrad		$1,%ymm12,%ymm\l             # l = (l' + h') / 2
.endm

.macro levels0t3 off
/* load coefficients */
vmovdqa		  0+32*\off(%rdi),%ymm4
vmovdqa		128+32*\off(%rdi),%ymm5
vmovdqa		256+32*\off(%rdi),%ymm6
vmovdqa		384+32*\off(%rdi),%ymm7
vmovdqa		512+32*\off(%rdi),%ymm8
vmovdqa		640+32*\off(%rdi),%ymm9
vmovdqa		768+32*\off(%rdi),%ymm10
vmovdqa		896+32*\off(%rdi),%ymm11

/* level 0 (span 16) */
vpbroadcastd	(_ZETAS+6)*4(%rsi),%ymm2     # zeta = 13
k_reduction_inv	9,14,2
butterfly_inv	8,9,14
k_reduction_inv	11,14,2
butterfly_inv	10,11,14

vpbroadcastd	(_ZETAS+5)*4(%rsi),%ymm2     # zeta = 21
k_reduction_inv	6,14,2
butterfly_inv	4,6,14
k_reduction_inv	7,14,2
butterfly_inv	5,7,14

/* level 1 (span 32) */
vpbroadcastd	(_ZETAS+4)*4(%rsi),%ymm2     # zeta = 5
k_reduction_inv	9,14,2
butterfly_inv	8,9,14
k_reduction_inv	11,14,2
butterfly_inv	10,11,14

vpbroadcastd	(_ZETAS+3)*4(%rsi),%ymm2     # zeta = 5
k_reduction_inv	5,14,2
butterfly_inv	4,5,14
k_reduction_inv	7,14,2
butterfly_inv	6,7,14

/* level 2 (span 64) */
vpbroadcastd	(_ZETAS+2)*4(%rsi),%ymm2     # zeta = 9
k_reduction_inv	10,14,2
butterfly_inv	8,10,14
k_reduction_inv	11,14,2
butterfly_inv	9,11,14

vpbroadcastd	(_ZETAS+1)*4(%rsi),%ymm2     # zeta = 17
k_reduction_inv	6,14,2
butterfly_inv	4,6,14
k_reduction_inv	7,14,2
butterfly_inv	5,7,14

/* level 3 (span 128) */
vpbroadcastd	(_ZETAS+0)*4(%rsi),%ymm2     # zeta = 1
k_reduction_inv	8,14,2
butterfly_inv	4,8,14
k_reduction_inv	9,14,2
butterfly_inv	5,9,14
k_reduction_inv	10,14,2
butterfly_inv	6,10,14
k_reduction_inv	11,14,2
butterfly_inv	7,11,14

/* store coefficients */
vmovdqa		%ymm4,  0+32*\off(%rdi)
vmovdqa		%ymm5,128+32*\off(%rdi)
vmovdqa		%ymm6,256+32*\off(%rdi)
vmovdqa		%ymm7,384+32*\off(%rdi)
vmovdqa		%ymm8,512+32*\off(%rdi)
vmovdqa		%ymm9,640+32*\off(%rdi)
vmovdqa		%ymm10,768+32*\off(%rdi)
vmovdqa		%ymm11,896+32*\off(%rdi)
.endm

.text
.global cdecl(invntt_avx)
cdecl(invntt_avx):
vmovdqa		_8XFFFF*4(%rsi),%ymm1         # load mask
levels0t3	0
levels0t3	1
levels0t3	2
levels0t3	3
ret

.section .note.GNU-stack,"",@progbits
