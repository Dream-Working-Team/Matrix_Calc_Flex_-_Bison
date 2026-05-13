%{
/*
 * =============================================================================
 * ANALIZADOR SINTÁCTICO PARA CALCULADORA DE MATRICES
 * =============================================================================
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

/* Forward declaration de Matrix */
#ifndef MATRIX_T
typedef struct Matrix Matrix;
#endif

/* Estructura para la tabla de símbolos */
typedef struct Symbol {
    char* name;
    Matrix* matrix;
    struct Symbol* next;
} Symbol;

Symbol* symbol_table = NULL;

/* Prototipos del lexer */
extern int yylex(void);
extern int yylineno;
extern char* yytext;

/* yyerror */
void yyerror(const char* mensaje);

/* Prototipos de funciones de matrices */
Matrix* matrix_create(int filas, int columnas);
void matrix_free(Matrix* m);
void matrix_print(Matrix* m);
Matrix* matrix_copy(Matrix* m);
int matrix_validate_add_sub(Matrix* a, Matrix* b);
int matrix_validate_mul(Matrix* a, Matrix* b);
int matrix_validate_square(Matrix* m);
Matrix* matrix_add(Matrix* a, Matrix* b);
Matrix* matrix_sub(Matrix* a, Matrix* b);
Matrix* matrix_mul(Matrix* a, Matrix* b);
double matrix_det(Matrix* m);
Matrix* matrix_inv(Matrix* m);
Matrix* matrix_trans(Matrix* m);

/* Funciones de la tabla de símbolos */
void symbol_set(const char* name, Matrix* m);
Matrix* symbol_get(const char* name);
void symbol_free_all();

/* --- INICIO DE VARIABLES GLOBALES DE ESTADO --- */

/* Flag para activar/desactivar el modo depuración desde la CLI */
int modo_debug = 0;

int ultima_linea_error = -1;

/*
 * silenciar_traza: Flag global que se activa durante la recuperación en modo pánico.
 *   Sirve para suprimir la impresión de nodos residuales y repetitivos 
 *   en el árbol de sintaxis, garantizando una salida de debug limpia.
 */
int silenciar_traza = 0;

/*
 * error_en_sentencia: Flag de alcance POR SENTENCIA.
 *   Se activa (=1) cuando ocurre un error léxico, sintáctico o semántico
 *   durante el procesamiento de la sentencia actual.
 *   Bloquea la evaluación e impresión de resultados para esa sentencia.
 *   Se reinicia a 0 al finalizar cada inst_completa (tras el PUNTO_COMA).
 */
int error_en_sentencia = 0;

/*
 * total_errores: Contador GLOBAL acumulativo.
 *   Cada error (léxico, sintáctico, semántico) lo incrementa.
 *   Al final del main, determina si el mensaje es de éxito o de error.
 */
int total_errores = 0;

/* Contador para controlar el nivel de indentación en el árbol jerárquico */
int profundidad = 0;

/**
 * Función auxiliar para imprimir el árbol de sintaxis de forma jerárquica.
 * Solo imprime si modo_debug está activo y silenciar_traza es 0.
 * 
 * NOTA: Si silenciar_traza == 1, aborta inmediatamente. Esto oculta
 * de forma segura la impresión de nodos huérfanos que ocurre mientras
 * Bison hace unroll de la pila (stack unrolling) en el modo pánico.
 */
void imprimir_debug(const char* texto_token, const char* tipo_token) {
    if (!modo_debug || silenciar_traza) return;
    for (int i = 0; i < profundidad; i++) {
        printf("  ");
    }
    if (tipo_token != NULL && strlen(tipo_token) > 0) {
        printf("|-- %s (%s)\n", texto_token, tipo_token);
    } else {
        printf("|-- %s\n", texto_token);
    }
}

/* --- FIN DE DECLARACIONES GLOBALES --- */

/* Definición de la estructura Matrix */
struct Matrix {
    int filas;
    int columnas;
    double** datos;
};
%}

/* -------------------------------------------------------------
 * DECLARACIONES DE BISON
 * ------------------------------------------------------------- */
%define parse.error verbose

%union {
    double numero;
    Matrix* matriz;
    char* identificador;
    int entero;
}

%token <numero> NUMERO
%token <matriz> MATRIZ_LITERAL
%token <identificador> IDENTIFICADOR
%token <entero> DET_FUNC INV_FUNC TRANS_FUNC
%token COMA PUNTO_COMA ASIGNACION
%token CORCHETE_IZQ CORCHETE_DER
%token PARENT_IZQ PARENT_DER
%token MAS MENOS ASTERISCO

%type <matriz> expr matriz_plana matriz_anidada fila fila_anidada lista_elementos lista_filas lista_expresiones

%left MAS MENOS
%left ASTERISCO
%left FUNCIONES

%%

/*
 * =============================================================================
 * REGLAS GRAMATICALES
 * =============================================================================
 */

programa:
    /* empty */
    | programa inst_completa
    ;

/*
 * inst_completa: punto de sincronización del parser.
 *   Cada sentencia termina con PUNTO_COMA. Al finalizar (sea exitosa o con error),
 *   se reinicia error_en_sentencia = 0 para procesar la siguiente línea limpiamente.
 *   SOLO evalúa e imprime si error_en_sentencia == 0 y la matriz no es NULL.
 */
inst_completa:
    expr PUNTO_COMA {
        if (!error_en_sentencia && $1 != NULL) {
            imprimir_debug("INSTRUCCION", "REGLA");
            profundidad++;
            printf("=== Resultado para la expresión ===\n");
            matrix_print($1);
            profundidad--;
        }
        matrix_free($1);
        imprimir_debug(";", "PUNTO_COMA");
        /* Reiniciar flag de error para la siguiente sentencia */
        error_en_sentencia = 0;
    }
    | IDENTIFICADOR ASIGNACION expr PUNTO_COMA {
        if (!error_en_sentencia && $3 != NULL) {
            imprimir_debug("ASIGNACION", "REGLA");
            profundidad++;
            imprimir_debug($1, "ID");
            imprimir_debug("=", "ASIGNACION");
            symbol_set($1, $3);
            printf("=== Resultado para asignación: %s ===\n", $1);
            matrix_print($3);
            profundidad--;
        }
        free($1);
        matrix_free($3);
        imprimir_debug(";", "PUNTO_COMA");
        /* Reiniciar flag de error para la siguiente sentencia */
        error_en_sentencia = 0;
    }
    | error PUNTO_COMA {
        /*
         * Recuperación en modo pánico: Bison descarta tokens hasta encontrar
         * el PUNTO_COMA de sincronización. yyerrok limpia el estado interno
         * de error de Bison para que no siga reportando "syntax error".
         */
         
        /* a) Rehabilitamos temporalmente la traza si debug está activo para
         * imprimir el nodo de poda consolidada, reflejando el truncamiento */
        if (modo_debug) {
            silenciar_traza = 0;
            imprimir_debug("[RAMA TRUNCADA POR ERROR SINTÁCTICO]", NULL);
            imprimir_debug(";", "PUNTO_COMA_SINCRONIZADO");
        }
        
        /* b) Reiniciamos el estado de error de Bison */
        yyerrok;
        
        /* c) Reiniciamos ambos flags a 0 para que la siguiente línea 
         * se evalúe y rastree con normalidad. */
        error_en_sentencia = 0;
        silenciar_traza = 0;
    }
    ;

expr:
    NUMERO {
        char buf[64];
        snprintf(buf, sizeof(buf), "%.2f", $1);
        imprimir_debug(buf, "NUMERO");
        
        if (error_en_sentencia) {
            $$ = NULL;
        } else {
            $$ = matrix_create(1, 1);
            if ($$ != NULL) {
                $$->datos[0][0] = $1;
            } else {
                error_en_sentencia = 1;
                total_errores++;
                $$ = NULL;
            }
        }
    }
    
    | IDENTIFICADOR {
        imprimir_debug($1, "ID");
        $$ = symbol_get($1);
        if ($$ == NULL) {
            error_en_sentencia = 1;
            total_errores++;
        }
        free($1);
    }

    | matriz_plana {
        $$ = $1;
    }
    
    | matriz_anidada {
        $$ = $1;
    }
    
    | expr MAS expr {
        imprimir_debug("+", "OPERADOR_MAS");
        profundidad++;
        
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1;
            total_errores++;
        } else if (!matrix_validate_add_sub($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1;
            total_errores++;
        } else {
            printf("--- Operación: SUMA ---\n");
            $$ = matrix_add($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
        
        profundidad--;
    }
    
    | expr MENOS expr {
        imprimir_debug("-", "OPERADOR_MENOS");
        profundidad++;
        
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else if (!matrix_validate_add_sub($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else {
            printf("--- Operación: RESTA ---\n");
            $$ = matrix_sub($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
        
        profundidad--;
    }
    
    | expr ASTERISCO expr {
        imprimir_debug("*", "OPERADOR_POR");
        profundidad++;
        
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else if (!matrix_validate_mul($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else {
            printf("--- Operación: MULTIPLICACIÓN ---\n");
            $$ = matrix_mul($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
        
        profundidad--;
    }
    
    | DET_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        imprimir_debug("DET", "FUNCION");
        profundidad++;
        imprimir_debug("(", "PARENT_IZQ");
        
        if ($3 == NULL) {
            $$ = NULL;
            error_en_sentencia = 1; total_errores++;
        } else if (!matrix_validate_square($3)) {
            $$ = NULL;
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else {
            printf("--- Función: DETERMINANTE ---\n");
            double det = matrix_det($3);
            $$ = matrix_create(1, 1);
            if ($$ != NULL) {
                $$->datos[0][0] = det;
            } else {
                error_en_sentencia = 1; total_errores++;
            }
            matrix_free($3);
        }
        
        imprimir_debug(")", "PARENT_DER");
        profundidad--;
    }
    
    | INV_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        imprimir_debug("INV", "FUNCION");
        profundidad++;
        imprimir_debug("(", "PARENT_IZQ");
        
        if ($3 == NULL) {
            $$ = NULL;
            error_en_sentencia = 1; total_errores++;
        } else if (!matrix_validate_square($3)) {
            $$ = NULL;
            matrix_free($3);
            error_en_sentencia = 1; total_errores++;
        } else {
            printf("--- Función: INVERSA ---\n");
            $$ = matrix_inv($3);
            if ($$ == NULL) {
                error_en_sentencia = 1; total_errores++;
            }
            matrix_free($3);
        }
        
        imprimir_debug(")", "PARENT_DER");
        profundidad--;
    }
    
    | TRANS_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        imprimir_debug("TRANS", "FUNCION");
        profundidad++;
        imprimir_debug("(", "PARENT_IZQ");
        
        if ($3 == NULL) {
            $$ = NULL;
            error_en_sentencia = 1; total_errores++;
        } else {
            printf("--- Función: TRANSPUESTA ---\n");
            $$ = matrix_trans($3);
            if ($$ == NULL) {
                error_en_sentencia = 1; total_errores++;
            }
            matrix_free($3);
        }
        
        imprimir_debug(")", "PARENT_DER");
        profundidad--;
    }
    
    | PARENT_IZQ expr PARENT_DER {
        imprimir_debug("(", "PARENT_IZQ");
        $$ = $2;
        imprimir_debug(")", "PARENT_DER");
    }
    ;

/* Notación plana: [elem, elem; elem, elem] */
matriz_plana:
    CORCHETE_IZQ lista_filas CORCHETE_DER {
        if (error_en_sentencia) {
            $$ = NULL;
        } else {
            imprimir_debug("[", "CORCHETE_IZQ");
            profundidad++;
            $$ = $2;
            profundidad--;
            imprimir_debug("]", "CORCHETE_DER");
        }
    }
    | CORCHETE_IZQ error {
        error_en_sentencia = 1; total_errores++;
        $$ = NULL;
    }
    ;

lista_filas:
    fila {
        $$ = $1;
    }
    | lista_filas PUNTO_COMA fila {
        imprimir_debug(";", "PUNTO_COMA_FILA");
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if ($1->columnas != $3->columnas) {
            /* Validación estricta de columnas para asegurar estructura rectangular */
            fprintf(stderr, "Error: Inconsistencia en el número de columnas por fila (%d vs %d)\n",
                    $1->columnas, $3->columnas);
            error_en_sentencia = 1;
            total_errores++;
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else {
            Matrix* nueva = matrix_create($1->filas + 1, $1->columnas);
            if (nueva == NULL) {
                $$ = NULL;
                matrix_free($1);
                matrix_free($3);
            } else {
                for (int i = 0; i < $1->filas; i++) {
                    for (int j = 0; j < $1->columnas; j++) {
                        nueva->datos[i][j] = $1->datos[i][j];
                    }
                }
                for (int j = 0; j < $3->columnas; j++) {
                    nueva->datos[$1->filas][j] = $3->datos[0][j];
                }
                matrix_free($1);
                matrix_free($3);
                $$ = nueva;
            }
        }
    }
    ;

fila:
    lista_elementos {
        imprimir_debug("FILA", "REGLA");
        profundidad++;
        $$ = $1;
        profundidad--;
    }
    ;

lista_elementos:
    NUMERO {
        char buf[64];
        snprintf(buf, sizeof(buf), "%.2f", $1);
        imprimir_debug(buf, "NUMERO");
        
        $$ = matrix_create(1, 1);
        if ($$ != NULL) {
            $$->datos[0][0] = $1;
        } else {
            error_en_sentencia = 1; total_errores++;
        }
    }
    | lista_elementos COMA NUMERO {
        imprimir_debug(",", "COMA");
        char buf[64];
        snprintf(buf, sizeof(buf), "%.2f", $3);
        imprimir_debug(buf, "NUMERO");
        
        if ($1 == NULL) {
            $$ = NULL;
            error_en_sentencia = 1; total_errores++;
        } else {
            Matrix* temp = matrix_create(1, $1->columnas + 1);
            if (temp == NULL) {
                $$ = NULL;
                matrix_free($1);
                error_en_sentencia = 1; total_errores++;
            } else {
                for (int j = 0; j < $1->columnas; j++) {
                    temp->datos[0][j] = $1->datos[0][j];
                }
                temp->datos[0][$1->columnas] = $3;
                matrix_free($1);
                $$ = temp;
            }
        }
    }
    ;

/* Notación anidada: [[elem, elem], [elem, elem]] 
 * Cada fila debe estar entre corchetes para distinguir de notación plana */
matriz_anidada:
    CORCHETE_IZQ lista_expresiones CORCHETE_DER {
        imprimir_debug("[", "CORCHETE_IZQ_MATRIZ");
        profundidad++;
        $$ = $2;
        profundidad--;
        imprimir_debug("]", "CORCHETE_DER_MATRIZ");
    }
    ;

lista_expresiones:
    fila_anidada {
        $$ = $1;
    }
    | lista_expresiones COMA fila_anidada {
        imprimir_debug(",", "COMA_FILA");
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if ($1->columnas != $3->columnas) {
            /* Validación estricta de columnas para asegurar estructura rectangular */
            fprintf(stderr, "Error: Inconsistencia en el número de columnas por fila (%d vs %d)\n",
                    $1->columnas, $3->columnas);
            error_en_sentencia = 1;
            total_errores++;
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else {
            Matrix* nueva = matrix_create($1->filas + 1, $1->columnas);
            if (nueva == NULL) {
                $$ = NULL;
                matrix_free($1);
                matrix_free($3);
            } else {
                for (int i = 0; i < $1->filas; i++) {
                    for (int j = 0; j < $1->columnas; j++) {
                        nueva->datos[i][j] = $1->datos[i][j];
                    }
                }
                for (int j = 0; j < $3->columnas; j++) {
                    nueva->datos[$1->filas][j] = $3->datos[0][j];
                }
                matrix_free($1);
                matrix_free($3);
                $$ = nueva;
            }
        }
    }
    ;

/* Fila en notación anidada: [elem, elem] -必须有 corchetes */
fila_anidada:
    CORCHETE_IZQ lista_elementos CORCHETE_DER {
        imprimir_debug("[", "CORCHETE_IZQ_FILA");
        profundidad++;
        $$ = $2;
        profundidad--;
        imprimir_debug("]", "CORCHETE_DER_FILA");
    }
    ;

%%

/*
 * =============================================================================
 * FUNCIONES AUXILIARES EN C
 * =============================================================================
 */

Matrix* matrix_create(int filas, int columnas) {
    if (filas <= 0 || columnas <= 0) {
        return NULL;
    }
    
    Matrix* m = (Matrix*)malloc(sizeof(Matrix));
    if (m == NULL) {
        fprintf(stderr, "Error: Fallo al asignar memoria para estructura Matrix\n");
        return NULL;
    }
    
    m->filas = filas;
    m->columnas = columnas;
    
    m->datos = (double**)malloc(filas * sizeof(double*));
    if (m->datos == NULL) {
        free(m);
        return NULL;
    }
    
    for (int i = 0; i < filas; i++) {
        m->datos[i] = (double*)malloc(columnas * sizeof(double));
        if (m->datos[i] == NULL) {
            for (int j = 0; j < i; j++) {
                free(m->datos[j]);
            }
            free(m->datos);
            free(m);
            return NULL;
        }
        for (int j = 0; j < columnas; j++) {
            m->datos[i][j] = 0.0;
        }
    }
    
    return m;
}


void matrix_free(Matrix* m) {
    if (m == NULL) return;
    
    if (m->datos != NULL) {
        for (int i = 0; i < m->filas; i++) {
            if (m->datos[i] != NULL) {
                free(m->datos[i]);
            }
        }
        free(m->datos);
    }
    
    free(m);
}


Matrix* matrix_copy(Matrix* m) {
    if (m == NULL) return NULL;
    Matrix* copy = matrix_create(m->filas, m->columnas);
    if (copy == NULL) return NULL;
    for (int i = 0; i < m->filas; i++) {
        for (int j = 0; j < m->columnas; j++) {
            copy->datos[i][j] = m->datos[i][j];
        }
    }
    return copy;
}


void matrix_print(Matrix* m) {
    if (m == NULL) {
        printf("[ Matriz nula ]\n");
        return;
    }
    
    for (int i = 0; i < m->filas; i++) {
        printf("[");
        for (int j = 0; j < m->columnas; j++) {
            if (j > 0) printf("\t");
            printf("%.2f", m->datos[i][j]);
        }
        printf("]\n");
    }
}


int matrix_validate_add_sub(Matrix* a, Matrix* b) {
    if (a->filas != b->filas || a->columnas != b->columnas) {
        fprintf(stderr, "Error semántico en línea %d: Dimensiones incompatibles para "
                "operación +/-, %dx%d vs %dx%d\n",
                yylineno, a->filas, a->columnas, b->filas, b->columnas);
        return 0;
    }
    return 1;
}


int matrix_validate_mul(Matrix* a, Matrix* b) {
    /* Si uno es escalar (1x1), la multiplicación siempre es válida */
    if ((a->filas == 1 && a->columnas == 1) || (b->filas == 1 && b->columnas == 1)) {
        return 1;
    }
    /* De lo contrario, validación estándar de matrices */
    if (a->columnas != b->filas) {
        fprintf(stderr, "Error semántico en línea %d: Dimensiones incompatibles para "
                "multiplicación, %dx%d * %dx%d (columnas de A debe igualar filas de B)\n",
                yylineno, a->filas, a->columnas, b->filas, b->columnas);
        return 0;
    }
    return 1;
}


int matrix_validate_square(Matrix* m) {
    if (m->filas != m->columnas) {
        fprintf(stderr, "Error semántico en línea %d: La matriz %dx%d no es cuadrada "
                "para esta operación\n", yylineno, m->filas, m->columnas);
        return 0;
    }
    return 1;
}


Matrix* matrix_add(Matrix* a, Matrix* b) {
    Matrix* resultado = matrix_create(a->filas, a->columnas);
    if (resultado == NULL) return NULL;
    
    for (int i = 0; i < a->filas; i++) {
        for (int j = 0; j < a->columnas; j++) {
            resultado->datos[i][j] = a->datos[i][j] + b->datos[i][j];
        }
    }
    
    return resultado;
}


Matrix* matrix_sub(Matrix* a, Matrix* b) {
    Matrix* resultado = matrix_create(a->filas, a->columnas);
    if (resultado == NULL) return NULL;
    
    for (int i = 0; i < a->filas; i++) {
        for (int j = 0; j < a->columnas; j++) {
            resultado->datos[i][j] = a->datos[i][j] - b->datos[i][j];
        }
    }
    
    return resultado;
}


Matrix* matrix_mul(Matrix* a, Matrix* b) {
    /* Caso A es escalar */
    if (a->filas == 1 && a->columnas == 1) {
        double scalar = a->datos[0][0];
        Matrix* resultado = matrix_create(b->filas, b->columnas);
        if (resultado == NULL) return NULL;
        for (int i = 0; i < b->filas; i++) {
            for (int j = 0; j < b->columnas; j++) {
                resultado->datos[i][j] = scalar * b->datos[i][j];
            }
        }
        return resultado;
    }
    
    /* Caso B es escalar */
    if (b->filas == 1 && b->columnas == 1) {
        double scalar = b->datos[0][0];
        Matrix* resultado = matrix_create(a->filas, a->columnas);
        if (resultado == NULL) return NULL;
        for (int i = 0; i < a->filas; i++) {
            for (int j = 0; j < a->columnas; j++) {
                resultado->datos[i][j] = a->datos[i][j] * scalar;
            }
        }
        return resultado;
    }

    /* Caso estándar de multiplicación de matrices */
    Matrix* resultado = matrix_create(a->filas, b->columnas);
    if (resultado == NULL) return NULL;
    
    for (int i = 0; i < a->filas; i++) {
        for (int j = 0; j < b->columnas; j++) {
            double suma = 0.0;
            for (int k = 0; k < a->columnas; k++) {
                suma += a->datos[i][k] * b->datos[k][j];
            }
            resultado->datos[i][j] = suma;
        }
    }
    
    return resultado;
}


double matrix_det(Matrix* m) {
    if (m->filas != m->columnas) {
        return 0.0;
    }
    
    int n = m->filas;
    
    if (n == 1) {
        return m->datos[0][0];
    }
    
    if (n == 2) {
        return m->datos[0][0] * m->datos[1][1] - 
               m->datos[0][1] * m->datos[1][0];
    }
    
    double determinante = 0.0;
    int signo = 1;
    
    for (int j = 0; j < n; j++) {
        Matrix* menor = matrix_create(n - 1, n - 1);
        if (menor == NULL) return 0.0;
        
        for (int fil = 1; fil < n; fil++) {
            for (int col = 0; col < n; col++) {
                if (col < j) {
                    menor->datos[fil - 1][col] = m->datos[fil][col];
                } else if (col > j) {
                    menor->datos[fil - 1][col - 1] = m->datos[fil][col];
                }
            }
        }
        
        double det_menor = matrix_det(menor);
        determinante += signo * m->datos[0][j] * det_menor;
        
        signo = -signo;
        matrix_free(menor);
    }
    
    return determinante;
}


Matrix* matrix_inv(Matrix* m) {
    int n = m->filas;
    
    if (m->filas != m->columnas) {
        return NULL;
    }
    
    double det = matrix_det(m);
    if (fabs(det) < 1e-9) {
        fprintf(stderr, "Error semántico en línea %d: Matriz singular, "
                "no se puede calcular la inversa\n", yylineno);
        return NULL;
    }
    
    Matrix* augment = matrix_create(n, 2 * n);
    if (augment == NULL) return NULL;
    
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            augment->datos[i][j] = m->datos[i][j];
        }
    }
    
    for (int i = 0; i < n; i++) {
        augment->datos[i][n + i] = 1.0;
    }
    
    for (int i = 0; i < n; i++) {
        int max_fila = i;
        for (int k = i + 1; k < n; k++) {
            if (fabs(augment->datos[k][i]) > fabs(augment->datos[max_fila][i])) {
                max_fila = k;
            }
        }
        
        if (max_fila != i) {
            for (int j = 0; j < 2 * n; j++) {
                double temp = augment->datos[i][j];
                augment->datos[i][j] = augment->datos[max_fila][j];
                augment->datos[max_fila][j] = temp;
            }
        }
        
        double pivote = augment->datos[i][i];
        for (int j = 0; j < 2 * n; j++) {
            augment->datos[i][j] /= pivote;
        }
        
        for (int k = 0; k < n; k++) {
            if (k != i) {
                double factor = augment->datos[k][i];
                for (int j = 0; j < 2 * n; j++) {
                    augment->datos[k][j] -= factor * augment->datos[i][j];
                }
            }
        }
    }
    
    Matrix* resultado = matrix_create(n, n);
    if (resultado == NULL) {
        matrix_free(augment);
        return NULL;
    }
    
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            resultado->datos[i][j] = augment->datos[i][n + j];
        }
    }
    
    matrix_free(augment);
    return resultado;
}


Matrix* matrix_trans(Matrix* m) {
    Matrix* resultado = matrix_create(m->columnas, m->filas);
    if (resultado == NULL) return NULL;
    
    for (int i = 0; i < m->filas; i++) {
        for (int j = 0; j < m->columnas; j++) {
            resultado->datos[j][i] = m->datos[i][j];
        }
    }
    
    return resultado;
}


/* Implementación de la tabla de símbolos */
void symbol_set(const char* name, Matrix* m) {
    if (m == NULL) return;
    Symbol* s = symbol_table;
    while (s != NULL) {
        if (strcmp(s->name, name) == 0) {
            matrix_free(s->matrix);
            s->matrix = matrix_copy(m);
            return;
        }
        s = s->next;
    }
    s = (Symbol*)malloc(sizeof(Symbol));
    s->name = strdup(name);
    s->matrix = matrix_copy(m);
    s->next = symbol_table;
    symbol_table = s;
}


Matrix* symbol_get(const char* name) {
    Symbol* s = symbol_table;
    while (s != NULL) {
        if (strcmp(s->name, name) == 0) {
            return matrix_copy(s->matrix);
        }
        s = s->next;
    }
    fprintf(stderr, "Error semántico en línea %d: Variable '%s' no definida\n", 
            yylineno, name);
    return NULL;
}


void symbol_free_all() {
    Symbol* s = symbol_table;
    while (s != NULL) {
        Symbol* next = s->next;
        free(s->name);
        matrix_free(s->matrix);
        free(s);
        s = next;
    }
    symbol_table = NULL;
}


/* Función llamada por Bison al encontrar un error sintáctico */
void yyerror(const char* mensaje) {
    /* 
     * Activamos el flag silenciador inmediatamente. Esto suprimirá 
     * toda la impresión de nodos residuales de la traza de debug 
     * mientras Bison retrocede en el stack buscando un punto de sincronización.
     */
    silenciar_traza = 1;

    /* 
     * Solo reportamos el error si no hay un error previo en la misma sentencia,
     * y si no hemos reportado ya un error en esta misma línea física.
     * Esto evita la cascada de mensajes "syntax error".
     */
    if (!error_en_sentencia && ultima_linea_error != yylineno) {
        fprintf(stderr, "Error sintáctico en línea %d: %s\n", yylineno, mensaje);
        ultima_linea_error = yylineno;
    }
    /* Marcamos la sentencia actual con error para bloquear la evaluación */
    error_en_sentencia = 1; 
    /* Incrementamos el contador global para el reporte final */
    total_errores++;
}

/* Modificación de la función principal para asegurar limpieza manual del buffer si es necesario */
int main(int argc, char** argv) {
    /* Procesar argumentos para activar el modo debug */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-d") == 0 || strcmp(argv[i], "--debug") == 0) {
            modo_debug = 1;
        }
    }

    printf("==============================================\n");
    printf("  CALCULADORA DE MATRICES - Versión 1.2\n");
    if (modo_debug) {
        printf("  MODO DEPURACIÓN ACTIVADO: Traza del Árbol\n");
    }
    printf("==============================================\n");
    
    if (!modo_debug) {
        printf("Ingrese expresiones matriciales (Ctrl+D para salir):\n\n");
    } else {
        printf("Iniciando análisis jerárquico de la entrada...\n\n");
    }
    
    int resultado = yyparse();
    
    symbol_free_all();
    
    if (total_errores == 0) {
        printf("\n=== Procesamiento completado exitosamente ===\n");
    } else {
        printf("\n=== Procesamiento finalizado con errores ===\n");
    }
    
    return resultado;
}
