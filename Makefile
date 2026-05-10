# MAKEFILE PARA CALCULADORA DE MATRICES

CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -Wextra -std=gnu99
LDFLAGS = -lm

LEX_FILE = matcalc.l
YACC_FILE = matcalc.y

LEX_C = matcalc.lex.c
YACC_C = matcalc.tab.c
YACC_H = matcalc.tab.h

TARGET = matcalc

.PHONY: all clean prueba1 prueba2 prueba3 prueba4 prueba5

all: $(TARGET)

$(LEX_C): $(LEX_FILE)
	$(LEX) -o $@ $<

$(YACC_C) $(YACC_H): $(YACC_FILE)
	$(YACC) -d -y -o $(YACC_C) $(YACC_FILE)

$(TARGET): $(LEX_C) $(YACC_C)
	$(CC) $(CFLAGS) -o $@ $(LEX_C) $(YACC_C) $(LDFLAGS)

prueba1: $(TARGET)
	./$(TARGET) < prueba1_valida.txt

prueba2: $(TARGET)
	./$(TARGET) < prueba2_valida.txt

prueba3: $(TARGET)
	./$(TARGET) < prueba3_valida.txt

prueba4: $(TARGET)
	./$(TARGET) < prueba4_error_lexico.txt

prueba5: $(TARGET)
	./$(TARGET) < prueba5_error_semantico.txt

clean:
	rm -f $(TARGET) $(LEX_C) $(YACC_C) $(YACC_H)