obj-y = src/main.o src/boot.o

all-y = smos.bin
all: $(all-y)

CFLAGS := -O2 -g

BIOS_CFLAGS += $(autodepend-flags) -Wall
BIOS_CFLAGS += -m32
BIOS_CFLAGS += -march=i386
BIOS_CFLAGS += -mregparm=3
BIOS_CFLAGS += -fno-stack-protector -fno-delete-null-pointer-checks
BIOS_CFLAGS += -ffreestanding
BIOS_CFLAGS += -Isrc/include

dummy := $(shell mkdir -p .deps)
autodepend-flags = -MMD -MF .deps/cc-$(patsubst %/,%,$(dir $*))-$(notdir $*).d
-include .deps/*.d

.PRECIOUS: %.o
%.o: %.c
	$(CC) $(CFLAGS) $(BIOS_CFLAGS) -c -s $< -o $@
%.o: %.S
	$(CC) $(CFLAGS) $(BIOS_CFLAGS) -c -s $< -o $@

smos.bin.elf: $(obj-y) src/flat.lds
	mkdir -p target
	$(LD) -T src/flat.lds -o target/smos.bin.elf $(obj-y)

smos.bin: smos.bin.elf
	mkdir -p target
	objcopy -O binary target/smos.bin.elf target/smos.bin

clean:
	rm -f $(obj-y) $(all-y) target/smos.bin.elf
	rm -rf target
	rm -rf .deps

dasm:
	objdump -D -b binary -m i8086 target/smos.bin

info:
	objdump -t target/smos.bin.elf
# default: build
#
# build: target/boot.o
#
# .PHONY: clean
#
# target/boot.o: src/boot/boot.asm
# 		mkdir -p target
# 		# nasm -f bin -o target/smos.bin src/boot/boot.asm
# 		nasm -o target/smos.bin src/boot/boot.asm
#
run: $(all-y)
		qemu-system-x86_64 -s -S -monitor stdio -drive format=raw,file=target/smos.bin
		# gdb -> set architecture i386:x86-64:intel -> target remote localhost:1234
		# qemu-system-i386 -drive format=raw,file=target/smos.bin
#
# clean:
# 	rm -rf target
