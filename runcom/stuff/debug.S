// Usage:
//
// f DX:CX                 load one CHS sector to 0000:7C00
// t                       trace one step
// g <address>             go to adrs
// d <address>             display 16 bytes, CR for next 16 bytes...
// e <address> <words>...  enter memory byte/word/dword
// m <segment>             self move
// + <segment>             default segment offset
//
// Example:
// m 0FC0                  move debugger to 0FC0:0000 0FE0:0000
// f 1			   read floppy boot sector to 0000:7C00
// f 80 1		   read hard disk master boot sector to 0000:7C00
// g 7C0E		   ...

#define REGS32		16 bytes	display 32 bits datas for AX..DI
#define ADJESDI		17 bytes	add segment overflow support for e and d
#define AUTOMOVE	 6 bytes	move code in a 'safe' location in startup

.macro pushib val
	.byte	0x6A, \val-_start
.endm

	.text
	.code16
	.org	0

	.globl	_start
_start:
	jmp	init		# the start code will be overwritten by the input buffer

ismove:
moveself:
	movw	%di, %es	# move code to %di:0
	pushw	%di
	pushib	setvectors	# and jmp into (%di:setvectors) with retf
	xorw	%di, %di
	xorw	%si, %si
	movw	$_end-_start, %cx
	rep	movsb
	retf

setvectors:
	xorw	%si, %si	# set interrupt vectors in 0 segment
	movw	%si, %ds
	movb	$0x7D, %cl	# skip nmi
hooklp:				# interrupts: 0=div0 1=step 2=nmi 3=brk 4=ov 5=bound 6=invalid
	pushw	%cs
	pushib	dbgstart	# set %cs:dbgstart
	popl	(%si)		# to interrupt vector
skiphook:
	lodsl			# %si += 4
	shrb	$1,%cl
	jnc	skiphook
	jnz	hooklp		# note %cx will be cleared: SP will be untouched
	jmp	dbgstartz	# registers are already pushed by startup code

# interrupt entry point: the registers [FLAGS CS IP] are already pushed
dbgstart:
	pushw	%ds
	pushw	%es
#define SEGREGSZ	6
#ifdef REGS32
#define REGSZ	32
	pushal		#    [FLAGS CS IP DS ES] EAX ECX EDX EBX ESP EBP ESI EDI [SS]
#define USER_SP		REGSZ+SEGREGSZ-24(%bp)
#else
#define REGSZ	16
	pushaw		#    [FLAGS CS IP DS ES] AX CX DX BX SP BP SI DI [SS]
#define USER_SP		REGSZ+SEGREGSZ-14(%bp)
#endif
#define USER_FLAGS_HIGH	REGSZ+SEGREGSZ+5(%bp)
#define USER_IP		REGSZ+SEGREGSZ(%bp)
#define USER_CSIP	REGSZ+SEGREGSZ(%bp)
	pushw	%ss
	movw	$10, %cx	# adjust SP with [FLAGS CS IP DS ES] size
dbgstartz:
	movw	%sp, %bp
	cld
	pushw	%cs
	popw	%ds
	addw	%cx, USER_SP	# adjust SP or not...
	or	$1, USER_FLAGS_HIGH	# set TF
dbgregslp:
	call	dbgputcr
	movw	$break, %si
	lodsw
	lesw	USER_CSIP, %di
	decw	%di
	cmp	%ah, %es:(%di)
	jne	notbrk
	stosb
	decw	USER_IP
notbrk:
	movb	%ah, -2(%si)
	subw	%si, %bp
	movw	$13, %cx
regslp:
	call	putreg		# display register name and value
	loop	regslp
	movw	(%bp,%si), %dx	# get flags
#ifdef REGS32
	pushw	%dx
#else
	pushw	%si
#endif
	movb	$13, %cl
	stc			# add trailing =
	rcrw	%cl, %dx
nextbit:
	lodsb
	shlw	$1, %dx
	call	dbgputcbit	# display active flags bits
	loop	nextbit
#ifdef REGS32
	popw	%ax
	call	putax		# display flags only
#else
	popw	%si
	movb	$8, %cl
stacklp:
	lodsw			# si += 2
	call	putr16		# display flags and the beginning of the stack
	loop	stacklp
#endif
	movw	%sp, %bp
	call	getadrs
	cmpb	$'m', %al
	je	ismove
	cmpb	$'+', %al
	jne	not_offset
	movw	%di, offset_value
not_offset:
	cmpb	$'f', %al	# f DX:CX
	jne	not_floppy_load
	movw	%di, %cx
	movw	%es, %dx
	pushw	$0
	popw	%es
	movw	$0x0201, %ax
	movw	$0x7C00, %bx
	pushw	%bx
	int	$0x13
	popw	%di
	jnc	dump
godbgregslp:
	jmp	dbgregslp
not_floppy_load:
	cmpb	$'d', %al
	jne	notdump
dump:
	call	dbgputcr
	movw	%es, %ax
	call	putax
	movw	%di, %ax
	call	putax
	movw	$16, %cx
dhex:
	movb	%es:(%di), %ah
#ifdef ADJESDI
	call	incESDI
#else
	incw	%di
#endif
	movb	$0x01, %dh	# the data has 2 digits
	call	putx
	loop	dhex
	int	$0x16
	cmpb	$13, %al
	je	dump
notdump:
	cmpb	$'t', %al
	je	done2
	cmpb	$'g', %al
	je	isgo
	cmpb	$'e', %al
	jne	godbgregslp
nextval:
	call	getval
	jcxz	godbgregslp
	xchgb	%dl, %dh
mextmsb:
	stosb
	xchgw	%ax, %dx
	xchgb	%al, %dh
#ifdef ADJESDI
	call	adjustESDI
#endif
	decw	%cx
	loop	mextmsb
	jmp	nextval

isgo:
	jcxz	done
setbreak:
#define OPCODE_BRK     0xCC
	movb	$OPCODE_BRK, %al
	xchgb	%al, %es:(%di)
	movb	%al, break

done:
	andb	$0xfe, USER_FLAGS_HIGH	# clear TF
step:
done2:
	popw	%ax  	# %ss
#ifdef REGS32
	popal
#else
	popaw
#endif
	popw	%es
	popw	%ds
	iret

#ifdef ADJESDI
adjustESDI:
	decw	%di
incESDI:
	incw	%di
	jnz	esok
	pushw	%es
	popw	%bx
	addb	$0x10, %bh
	pushw	%bx
	popw	%es
esok:
	ret
#endif

putreg:
	call	dbgput2c
	movb	$'=', %al
	call	dbgputc
putr16:
#ifdef REGS32
	movl	-2(%bp,%si), %eax
	movw	$0x0FF0, %dx	# check bits 5..12
	shrw	%cl, %dx
	jnc	putax		# 16 bits register ?
	incw	%bp		# a 32 bits register, not 16 bits
	incw	%bp
	movb	$0x7F, %dh	# the data has 8 digits
	jmp	putxlp
#else
	movw	-2(%bp,%si), %ax
#endif
putax:
	movb	$0x07, %dh	# the data has 4 digits
putx:
#ifdef REGS32
	roll	$16, %eax	# display low 16 bits
#endif
putxlp:  
#ifdef REGS32
	roll	$4, %eax
#else
	rolw	$4, %ax
#endif
	pushw	%ax
	andb	$0xf, %al
	addb	$0x90, %al
	daa
	adcb	$0x40, %al
	daa
	call	dbgputc
	popw	%ax
	shrb	$1, %dh
	jc	putxlp
dbgputcbit:
	jc	dbgputc  
	mov	$0x20, %al
dbgputc:
	movw	$7, %bx
	mov	$0xE, %ah
	int	$0x10
	xchgw	%ax, %bx
	ret

# get value in DX:AX, last char in BL, CX is digits count.
getval:
	xorl	%edx, %edx
	xorw	%cx, %cx
getvallp:
gotspc:
	lodsb
	movb	%al, %bl
	cmpb	$0x20, %al	# space ?
	jne	notspc
	jcxz	gotspc
notspc:
	sub	$'0', %al
	cmpb	$10, %al		# in 0..9 ?
	jb	isx
	sub	$'a'-'0'-10, %al
	cmpb	$16, %al		# in a..f ?
	jnb	gotval
isx:
	shll	$4, %edx
	orb	%al, %dl
	incw	%cx
	jmp	getvallp
gotval:
	pushl	%edx
	popw	%ax
	popw	%dx
	ret

# get address in ES:DI, first char in AL.
getadrs:
	call	getline
	lodsb
	pushw	%ax
	call	getval
	shlw	$12, %dx
	.byte	0x81, 0xC2	# addw	$0, %dx
offset_value:
	.word	0
	cmpb	$':', %bl
	pushw	%dx
	jne	retesdi
	popw	%dx
	pushw	%ax
	call	getval
retesdi:
	xchgw	%ax, %di
	popw	%es
	popw	%ax
	ret

getline:
	call	dbgputcr
getlinebs:
	cmpw	$buffer, %si
	je	getc
	decw	%si
getlinelp:
	call	dbgputc
getc:
	int	$0x16
	cmpb	$8, %al
	je	getlinebs
	orb	$0x20, %al
	movb	%al, (%si)
	inc	%si
	cmpb	$0x2D, %al
	jne	getlinelp
dbgputcr:
	movw	$crlf, %si
dbgput2c:
	call	dbgput1c
dbgput1c:
	lodsb
	jmp	dbgputc

break:
	.byte	OPCODE_BRK	# current opcode
	.byte	OPCODE_BRK	# read only
regs:
	.ascii	"ss"
	.ascii	"di"  
	.ascii	"si"  
	.ascii	"bp"  
	.ascii	"sp"  
	.ascii	"bx"  
	.ascii	"dx"  
	.ascii	"cx"  
	.ascii	"ax"  
	.ascii	"es"
	.ascii	"ds"  
	.ascii	"ip"  
	.ascii	"cs"  
	.ascii	"oditsz?a?p c="	# flags bits
crlf:
	.byte	13,10
_end:
buffer:
init:
	pushf
	pushw	$0		# fake interrupt stack frame
	pushw	$0x7C00
	pushw	%ds
	pushw	%es
#ifdef REGS32
	pushal
#else
	pushaw
#endif
	pushw	%ss
	call	mov_ip_to_ax
mov_ip_to_ax:
	popw	%ax		# %ax will have _start offset
	subw	$mov_ip_to_ax-_start, %ax
	shrw	$4, %ax		# _start MUST be aligned on paragraph
	movw	%cs, %bx
	addw	%bx, %ax	# normalize %cs to have _start=0
	pushw	%ax
#ifdef AUTOMOVE
	cld			# ensure movsb will work
	movw	%ax, %ds
	movw	$0x0FC0, %di	# move (and jump) to 0FC0:0000
	pushib  moveself
#else
	pushib	setvectors	# jmp to setvectors
#endif
	retf

	.org	510
	.byte	0x55, 0xAA

