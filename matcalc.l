%{
/*
 * =============================================================================
 * ANALIZADOR LÉXICO PARA CALCULADORA DE MATRICES
 * =============================================================================
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Definir estructura Matrix aquí para que esté disponible antes del header */
#ifndef MATRIX_H
typedef struct {
    int filas;
    int columnas;
    double** datos;
} Matrix;
#endif

#include "matcalc.tab.h"

int yylex(void);
%}

/* Declaraciones de opciones de Flex */
%option noyywrap
%option yylineno
%option noinput
%option nounput

/* Definiciones regulares */
NUMERO          -?([0-9]+(\.[0-9]+)?|\.[0-9]+)([eE][+-]?[0-9]+)?
IDENTIFICADOR   [a-zA-Z_][a-zA-Z0-9_]*
ESPACIO         [ \t\r]+
NUEVA_LINEA     \n
COMA            ,
PUNTO_COMA      ;
MAS             \+
MENOS           \-
ASTERISCO       \*
ASIGNACION      =
CORCHETE_IZQ    \[
CORCHETE_DER    \]
PARENT_IZQ      \(
PARENT_DER      \)

%%

{ESPACIO}       { }

{NUEVA_LINEA}  { }

{COMA}         { return COMA; }

{PUNTO_COMA}   { return PUNTO_COMA; }

{MAS}          { return MAS; }

{MENOS}        { return MENOS; }

{ASTERISCO}    { return ASTERISCO; }

{ASIGNACION}   { return ASIGNACION; }

{CORCHETE_IZQ} { return CORCHETE_IZQ; }

{CORCHETE_DER} { return CORCHETE_DER; }

{PARENT_IZQ}  { return PARENT_IZQ; }
{PARENT_DER}  { return PARENT_DER; }

{NUMERO}       {
    yylval.numero = atof(yytext);
    return NUMERO;
}

{IDENTIFICADOR} {
    if (strcmp(yytext, "DET") == 0) {
        return DET_FUNC;
    } else if (strcmp(yytext, "INV") == 0) {
        return INV_FUNC;
    } else if (strcmp(yytext, "TRANS") == 0) {
        return TRANS_FUNC;
    } else {
        yylval.identificador = strdup(yytext);
        return IDENTIFICADOR;
    }
}

.               {
    fprintf(stderr, "Error léxico en línea %d: Carácter '%c' no reconocido\n", 
            yylineno, yytext[0]);
}

%%

int obtener_linea_actual(void) {
    return yylineno;
}
