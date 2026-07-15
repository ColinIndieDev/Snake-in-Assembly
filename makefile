NASMFLAGS = -f elf32
LDFLAGS = -m elf_i386
TARGET = main
SRC = main.asm

all: $(TARGET)

$(TARGET): $(SRC)
	mkdir build
	nasm $(NASMFLAGS) $(SRC) -o build/$(SRC:.asm=.o)
	ld $(LDFLAGS) build/$(SRC:.asm=.o) -o build/$(TARGET)

clean:
	rm -f build/$(SRC:.asm=.o) $(TARGET)
rebuild:
	nasm $(NASMFLAGS) $(SRC) -o build/$(SRC:.asm=.o)
	ld $(LDFLAGS) build/$(SRC:.asm=.o) -o build/$(TARGET)
