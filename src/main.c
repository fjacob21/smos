#include "ioport.h"

int __attribute__ ((section (".text.startup"))) main(void)
{
	__asm__ ("mov $0x0B, %ah\n\t"
	"mov $0, %bh\n\t"
	"mov $1, %bl\n\t"
	"int $0x10\n\t"
	"jmp ."
	  );
	return 0;
}
