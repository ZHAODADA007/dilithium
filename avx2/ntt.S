#include "consts.h"
.include "shuffle.inc"

.macro k_reduction in,out,zeta
vpsrld		%xmm\zeta,%ymm\in,%ymm13     # t = a >> k
vpand		%ymm1,%ymm13,%ymm14          # low = t AND 0xFFFF
vpsrld		$16,%ymm13,%ymm13            # high = t >> 16
vpsubd		%ymm13,%ymm14,%ymm\out       # low - high
.endm

.macro butterfly l,h,zh
vpaddd		%ymm\zh,%ymm\l,%ymm12
vpsubd		%ymm\zh,%ymm\l,%ymm\l
vmovdqa		%ymm12,%ymm\h
.endm

.macro levels0t3 off
/* level 0 */
vpbroadcastd	(_ZETAS+0)*4(%rsi),%ymm2
vmovdqa		_8XFFFF*4(%rsi),%ymm1

vmovdqa		  0+32*\off(%rdi),%ymm4
vmovdqa		128+32*\off(%rdi),%ymm5
vmovdqa		256+32*\off(%rdi),%ymm6
vmovdqa	 	384+32*\off(%rdi),%ymm7
vmovdqa		512+32*\off(%rdi),%ymm8
vmovdqa		640+32*\off(%rdi),%ymm9
vmovdqa		768+32*\off(%rdi),%ymm10
vmovdqa	 	896+32*\off(%rdi),%ymm11

k_reduction	8,13,2
butterfly	4,8,13
k_reduction	9,13,2
butterfly	5,9,13
k_reduction	10,13,2
butterfly	6,10,13
k_reduction	11,13,2
butterfly	7,11,13

/* level 1 */
vpbroadcastd	(_ZETAS+1)*4(%rsi),%ymm2
k_reduction	6,13,2
butterfly	4,6,13
k_reduction	7,13,2
butterfly	5,7,13

vpbroadcastd	(_ZETAS+2)*4(%rsi),%ymm2
k_reduction	10,13,2
butterfly	8,10,13
k_reduction	11,13,2
butterfly	9,11,13

/* level 2 */
vpbroadcastd	(_ZETAS+3)*4(%rsi),%ymm2
k_reduction	5,13,2
butterfly	4,5,13
k_reduction	7,13,2
butterfly	6,7,13

vpbroadcastd	(_ZETAS+4)*4(%rsi),%ymm2
k_reduction	9,13,2
butterfly	8,9,13
k_reduction	11,13,2
butterfly	10,11,13

/* level 3 */
vpbroadcastd	(_ZETAS+5)*4(%rsi),%ymm2
k_reduction	7,13,2
butterfly	4,7,1
k_reduction	6,13,2
butterfly	5,6,10

vpbroadcastd	(_ZETAS+6)*4(%rsi),%ymm2
k_reduction	11,13,2
butterfly	8,11,13
k_reduction	9,13,2
butterfly	10,9,11

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
.global cdecl(ntt_avx)
cdecl(ntt_avx):
levels0t3	0
levels0t3	1
levels0t3	2
levels0t3	3
ret

.section .note.GNU-stack,"",@progbits
