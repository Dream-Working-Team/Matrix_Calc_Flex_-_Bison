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
    | programa sentencia PUNTO_COMA
    | programa error PUNTO_COMA
    ;

sentencia:
    expr {
        printf("=== Resultado ===\n");
        matrix_print($1);
        matrix_free($1);
    }
    | IDENTIFICADOR ASIGNACION expr {
        symbol_set($1, $3);
        printf("=== Variable '%s' asignada ===\n", $1);
        matrix_print($3);
        free($1);
        matrix_free($3);
    }
    ;

expr:
    NUMERO {
        $$ = matrix_create(1, 1);
        if ($$ != NULL) {
            $$->datos[0][0] = $1;
        } else {
            yyerror("Falló la creación de matriz escalar");
            $$ = NULL;
        }
    }
    
    | IDENTIFICADOR {
        $$ = symbol_get($1);
        free($1);
    }

    | matriz_plana {
        $$ = $1;
    }
    
    | matriz_anidada {
        $$ = $1;
    }
    
    | expr MAS expr {
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if (!matrix_validate_add_sub($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else {
            $$ = matrix_add($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
    }
    
    | expr MENOS expr {
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if (!matrix_validate_add_sub($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else {
            $$ = matrix_sub($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
    }
    
    | expr ASTERISCO expr {
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if (!matrix_validate_mul($1, $3)) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else {
            $$ = matrix_mul($1, $3);
            matrix_free($1);
            matrix_free($3);
        }
    }
    
    | DET_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        if ($3 == NULL) {
            $$ = NULL;
        } else if (!matrix_validate_square($3)) {
            $$ = NULL;
            matrix_free($3);
        } else {
            double det = matrix_det($3);
            $$ = matrix_create(1, 1);
            if ($$ != NULL) {
                $$->datos[0][0] = det;
            }
            matrix_free($3);
        }
    }
    
    | INV_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        if ($3 == NULL) {
            $$ = NULL;
        } else if (!matrix_validate_square($3)) {
            $$ = NULL;
            matrix_free($3);
        } else {
            $$ = matrix_inv($3);
            matrix_free($3);
        }
    }
    
    | TRANS_FUNC PARENT_IZQ expr PARENT_DER %prec FUNCIONES {
        if ($3 == NULL) {
            $$ = NULL;
        } else {
            $$ = matrix_trans($3);
            matrix_free($3);
        }
    }
    
    | PARENT_IZQ expr PARENT_DER {
        $$ = $2;
    }
    ;

/* Notación plana: [elem, elem; elem, elem] */
matriz_plana:
    CORCHETE_IZQ lista_filas CORCHETE_DER {
        $$ = $2;
    }
    ;

lista_filas:
    fila {
        $$ = $1;
    }
    | lista_filas PUNTO_COMA fila {
        if ($1 == NULL || $3 == NULL) {
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
        $$ = $1;
    }
    ;

lista_elementos:
    NUMERO {
        $$ = matrix_create(1, 1);
        if ($$ != NULL) {
            $$->datos[0][0] = $1;
        }
    }
    | lista_elementos COMA NUMERO {
        if ($1 == NULL) {
            $$ = NULL;
        } else {
            Matrix* temp = matrix_create(1, $1->columnas + 1);
            if (temp == NULL) {
                $$ = NULL;
                matrix_free($1);
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
        $$ = $2;
    }
    ;

lista_expresiones:
    fila_anidada {
        $$ = $1;
    }
    | lista_expresiones COMA fila_anidada {
        if ($1 == NULL || $3 == NULL) {
            $$ = NULL;
            matrix_free($1);
            matrix_free($3);
        } else if ($1->columnas != $3->columnas) {
            fprintf(stderr, "Error semántico en línea %d: Las filas de la matriz "
                    "anidada tienen diferentes anchos (%d vs %d)\n",
                    yylineno, $1->columnas, $3->columnas);
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
        $$ = $2;
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

void yyerror(const char* mensaje) {
    fprintf(stderr, "Error sintáctico en línea %d: %s\n", yylineno, mensaje);
}

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    printf("==============================================\n");
    printf("  CALCULADORA DE MATRICES - Versión 1.2\n");
    printf("==============================================\n");
    printf("Ingrese expresiones matriciales (Ctrl+D para salir):\n\n");
    
    int resultado = yyparse();
    
    symbol_free_all();
    
    if (resultado == 0) {
        printf("\n=== Procesamiento completado exitosamente ===\n");
    } else {
        printf("\n=== El procesamiento terminó con errores ===\n");
    }
    
    return resultado;
}
