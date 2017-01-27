.extern main
.code16gcc
#include "assembly.h"

#define ABS(x) (x-_start+0x7c00)
#define EXT_C(sym) _ ## sym

	/* Print message string */
#define MSG(x)	movw $ABS(x), %si; call message
#define MSG32(x)	movw $ABS(x), %si; call message32

.section .init
ENTRY(start)
	jmp	pm_entry

/*
 * message: write the string pointed to by %si
 *
 *   WARNING: trashes %si, %ax, and %bx
 */

	/*
	 * Use BIOS "int 10H Function 0Eh" to write character in teletype mode
	 *	%ah = 0xe	%al = character
	 *	%bh = page	%bl = foreground color (graphics modes)
	 */
1:
	movw	$0x0001, %bx
	movb	$0xe, %ah
	int	$0x10		/* display a byte */
message:
	lodsb
	cmpb	$0, %al
	jne	1b	/* if not end of string, jmp to display */
	ret

notification_string:	.string "Small OS "
enterpro_string:	.string "Enter Protected "
beginpro_string:	.string "Enter begin Protected "

pm_entry:

	# mov $0x07C0, %ax		# Set up 4K stack space after this bootloader
	# add $288, %ax		# (4096 + 512) / 16 bytes per paragraph
	# mov %ax, %ss
	# mov $4096, %sp

	# mov $0x07C0, %ax		# Set data segment to where we're loaded
	# mov %ax, %dx


	# hlt
	cli		/* we're not safe here! */

	/*
	 * This is a workaround for buggy BIOSes which don't pass boot
	 * drive correctly. If GRUB is installed into a HDD, check if
	 * DL is masked correctly. If not, assume that the BIOS passed
	 * a bogus value and set DL to 0x80, since this is the only
	 * possible boot drive. If GRUB is installed into a floppy,
	 * this does nothing (only jump).
	 */
boot_drive_check:
	jmp	1f
	testb	$0x80, %dl
	jnz	1f
	movb	$0x80, %dl
1:

	/*
	 * ljmp to the next instruction because some bogus BIOSes
	 * jump to 07C0:0000 instead of 0000:7C00.
	 */
	ljmp	$0, $ABS(real_start)

real_start:

	/* set up %ds and %ss as offset from 0 */
	xorw	%ax, %ax
	movw	%ax, %ds
	movw	%ax, %ss
	movw	%ax, %es

	/* set up the REAL stack */
	movl	(0x2000 - 0x10), %ebp
	movl	%ebp, %esp
	sti

	mov $0x0B, %ah
	mov $0, %bh
	mov $4, %bl
	int $0x10
	MSG(notification_string)

        call real_to_prot

	.code32
ENTRY(start32)
	# MSG32(beginpro_string)
	call (0x7C00 + main)
	jmp .

	/*
	 *  These next two routines, "real_to_prot" and "prot_to_real" are structured
	 *  in a very specific way.  Be very careful when changing them.
	 *
	 *  NOTE:  Use of either one messes up %eax and %ebp.
	 */

ENTRY(real_to_prot)
	.code16
	cli

	/* load the GDT register */
	data32 addr32	lgdt	ABS(gdtdesc)

	/* turn on protected mode */
	movl	%cr0, %eax
	orl	$0x1, %eax
	movl	%eax, %cr0

	/* jump to relocation, flush prefetch queue, and reload %cs */
	data32 ljmp	$0x8, $ABS(protcseg)

	/*
	 *  The ".code32" directive only works in GAS, the GNU assembler!
	 *  This gets out of "16-bit" mode.
	 */
	.code32

protcseg:
	/* reload other segment registers */

	movw	$0x10, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs
	movw	%ax, %ss

	/* put the return address in a known safe location */
	movl	(%esp), %eax
	movl	%eax, (0x2000 - 0x10)

	/* get protected mode stack */
	movl	(0x68000-0x10), %eax
	movl	%eax, %esp
	movl	%eax, %ebp

	/* get return address onto the right stack */
	movl	(0x2000 - 0x10), %eax
	movl	%eax, (%esp)

	/* zero %eax */
	xorl	%eax, %eax

	/* return on the old (or initialized) stack! */
	ret

5:
	movw	$0x0001, %bx
	movb	$0xe, %ah
	int	$0x10		/* display a byte */
message32:
	lodsb
	cmpb	$0, %al
	jne	5b	/* if not end of string, jmp to display */
	ret
# gdt32:
#         .quad 0
#         .quad 0x00cf9b000000ffff // flat 32-bit code segment
#         .quad 0x00cf93000000ffff // flat 32-bit data segment
#         .quad 0x000f9b0f0000ffff // 64K 16-bit code segment at 0xF0000
#         .quad 0x000f93000000ffff // 64K 16-bit data segment at 0x0
# gdt32_end:

# gdt32_descr:
#         .word gdt32_end - gdt32 - 1
#         .long 0xffffff80 + gdt32 - pm_entry
# ENTRY_END(pm_entry)
.p2align	2	/* force 4-byte alignment */
GLOBAL(gdt)
	.word	0, 0
	.byte	0, 0, 0, 0

	/* code segment */
	.word	0xFFFF, 0
	.byte	0, 0x9A, 0xCF, 0

	/* data segment */
	.word	0xFFFF, 0
	.byte	0, 0x92, 0xCF, 0

	/* 16 bit real mode CS */
	.word	0xFFFF, 0
	.byte	0, 0x9E, 0, 0

	/* 16 bit real mode DS */
	.word	0xFFFF, 0
	.byte	0, 0x92, 0, 0


/* this is the GDT descriptor */
GLOBAL(gdtdesc)
	.word	0x27			/* limit */
	.long	ABS(gdt)			/* addr */

	.fill (510-(.-start)), 1, 0	# Pad remainder of boot sector with 0s
BootMagic:  .int 0xAA55		# The standard PC boot signature
