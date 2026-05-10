# 🧮 Calculadora de Matrices

## 🎯 Propósito

Este proyecto implementa un **compilador/interprete** para una calculadora de matrices utilizando herramientas estándar de desarrollo de compiladores: **Flex** (analizador léxico) y **Bison** (analizador sintáctico) con **C puro**.

El programa procesa expresiones matriciales desde un archivo de entrada o stdin, validando semánticamente las operaciones y mostrando los resultados formateados.

---

## ⚙️ Cómo Funciona

### 🏗️ Arquitectura del Compilador

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Entrada       │────▶│   Flex (.l)     │────▶│   Bison (.y)    │
│  (stdin/file)  │     │   Lexer         │     │   Parser        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │   Ejecución    │
                                               │   Semántica    │
                                               │   (C)          │
                                               └─────────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────────┐
                                               │   Salida        │
                                               │   (resultados)  │
                                               └─────────────────┘
```

### Flujo de Procesamiento

1. **Análisis Léxico (Flex)**: Tokeniza el texto de entrada reconociendo números, operadores, delimitadores y palabras clave (DET, INV, TRANS).

2. **Análisis Sintáctico (Bison)**: Construye el árbol de análisis verificando la gramática de expresiones matriciales.

3. **Análisis Semántico (C)**: Valida las dimensiones de las matrices antes de ejecutar operaciones:
   - Suma/Resta: misma dimensión
   - Multiplicación: columnas(A) = filas(B)
   - DET/INV: matriz cuadrada

4. **Ejecución**: Realiza los cálculos y libera memoria.

---

## Archivos del Proyecto

| Archivo | Descripción |
|---------|-------------|
| `matcalc.l` | 📝 Analizador léxico (Flex) - 115 líneas |
| `matcalc.y` | 📝 Analizador sintáctico (Bison) + código C - 400+ líneas |
| `Makefile` | 🛠️ Automatización de compilación |
| `.gitignore` | 🙈 Configuración de archivos ignorados por Git |
| `prueba1_valida.txt` | ✅ Casos válidos - notación plana básica |
| `prueba2_valida.txt` | ✅ Casos válidos - notación anidada |
| `prueba3_valida.txt` | ✅ Casos válidos - mixtura y encadenamiento |
| `prueba4_error_lexico.txt` | ❌ Errores léxicos/sintácticos |
| `prueba5_error_semantico.txt` | ❌ Errores semánticos |
| `test_det.txt` | 🧪 Pruebas de determinante |
| `test_scalar.txt` | 🧪 Pruebas con escalares |
| `test_vars.txt` | 🧪 Pruebas de variables |
| `README.md` | 📖 Este documento |

---

## 👥 Autores

- **👴 Andres Tortolero**
- **👨‍💻 Ramon Gomez**

---

## 📝 Notaciones Soportadas

### 1. Notación Plana (estilo MATLAB)
```
[elemento, elemento; fila, fila]
```
- Elementos separados por coma (,)
- Filas separadas por punto y coma (;)
- Ejemplo: `[1, 2, 3; 4, 5, 6]` → matriz 2×3

### 2. Notación Anidada (estilo JavaScript/Python)
```
[[fila1], [fila2], ...]
```
- Cada fila es una expresión entre corchetes
- Filas separadas por coma (,)
- Ejemplo: `[[1, 2], [3, 4]]` → matriz 2×2

### 3. Mixtura
Ambas notaciones pueden combinarse en la misma expresión:
```
[[1, 2], [3, 4]] + [5, 6; 7, 8]
```

---

## ⚡ Operaciones Soportadas

| Operador | Descripción | Requisitos |
|----------|-------------|------------|
| `+` | ➕ Suma de matrices | Mismas dimensiones |
| `-` | ➖ Resta de matrices | Mismas dimensiones |
| `*` | ✖️ Multiplicación | columnas(A) = filas(B) |
| `DET(M)` | 🔍 Determinante | Matriz cuadrada |
| `INV(M)` | 🔄 Matriz inversa | Matriz cuadrada no singular |
| `TRANS(M)` | 📐 Transpuesta | Cualquier matriz 2D |

---

## 🚀 Cómo Ejecutar

### 🏗️ Compilación

```bash
# Opción 1: Manual
flex -o matcalc.lex.c matcalc.l
bison -d -y -o matcalc.tab.c matcalc.y
gcc -o matcalc matcalc.lex.c matcalc.tab.c -lm

# Opción 2: Con Makefile (recomendado)
make
```

### Ejecución

```bash
# Desde archivo
./matcalc < prueba1_valida.txt

# Desde entrada estándar (escribiendo manualmente)
./matcalc
[1, 2; 3, 4] + [5, 6; 7, 8];

# Con Makefile
make prueba1
```

---

## Casos de Uso y Resultados Esperados

---

### PRUEBA 1: Notación plana con operaciones básicas
**Archivo**: `prueba1_valida.txt`

**Contenido**:
```
[1, 2, 3; 4, 5, 6] + [10, 20, 30; 40, 50, 60];
[1, 2; 3, 4] * [5, 6; 7, 8];
DET([1, 2; 3, 4]);
TRANS([1, 2, 3; 4, 5, 6]);
```

**Resultado esperado**:
```
==============================================
  CALCULADORA DE MATRICES - Versión 1.0
==============================================
Ingrese expresiones matriciales (Ctrl+D para salir):

=== Resultado ===
[11.00	22.00	33.00]
[44.00	55.00	66.00]

=== Resultado ===
[19.00	22.00]
[43.00	50.00]

=== Resultado ===
[-2.00]

=== Resultado ===
[1.00	4.00]
[2.00	5.00]
[3.00	6.00]

=== Procesamiento completado exitosamente ===
```

---

### PRUEBA 2: Notación anidada con funciones
**Archivo**: `prueba2_valida.txt`

**Contenido**:
```
[[1, 2], [3, 4]] + [[5, 6], [7, 8]];
[[1, 0], [0, 1]] * [[2, 3], [4, 5]];
DET([[3, 2], [1, 4]]);
INV([[4, 7], [2, 6]]);
TRANS([[1, 2, 3]]);
```

**Resultado esperado**:
```
==============================================
  CALCULADORA DE MATRICES - Versión 1.0
==============================================
Ingrese expresiones matriciales (Ctrl+D para salir):

=== Resultado ===
[6.00	8.00]
[10.00	12.00]

=== Resultado ===
[2.00	3.00]
[4.00	5.00]

=== Resultado ===
[10.00]

=== Resultado ===
[0.60	-0.70]
[-0.20	0.40]

=== Resultado ===
[1.00]
[2.00]
[3.00]

=== Procesamiento completado exitosamente ===
```

---

### PRUEBA 3: Mixtura de notaciones y encadenamiento
**Archivo**: `prueba3_valida.txt`

**Contenido**:
```
[[1, 2], [3, 4]] + [5, 6; 7, 8];
[1, 2] * [[1], [2]];
DET([1, 2, 3; 4, 5, 6; 7, 8, 9]);
INV([[2, 1], [1, 1]]) * [[3], [4]];
TRANS([[1, 2], [3, 4]]) + [[10, 20], [30, 40]];
```

**Resultado esperado**:
```
==============================================
  CALCULADORA DE MATRICES - Versión 1.0
==============================================
Ingrese expresiones matriciales (Ctrl+D para salir):

=== Resultado ===
[6.00	8.00]
[10.00	12.00]

=== Resultado ===
[5.00]

=== Resultado ===
[0.00]

=== Resultado ===
[11.00]
[7.00]

=== Resultado ===
[11.00	22.00]
[33.00	44.00]

=== Procesamiento completado exitosamente ===
```

---

### PRUEBA 4: Errores léxicos y sintácticos
**Archivo**: `prueba4_error_lexico.txt`

**Contenido**:
```
[1, 2, @ 3; 4, 5, 6];
[1, 2, 3; 4, 5];
DET([1, 2; 3, 4];
[1, 2; 3, 4] ++ [5, 6; 7, 8];
```

**Resultado esperado** (errores detectados):
```
==============================================
  CALCULADORA DE MATRICES - Versión 1.0
==============================================
Ingrese expresiones matriciales (Ctrl+D para salir):

Error léxico en línea 1: Carácter '@' no reconocido
Error sintáctico en línea 2:...

Error semántico en línea 2: Las filas de la matriz plana...
Error sintáctico en línea 3:...
Error sintáctico en línea 4:...

=== El procesamiento terminó con errores ===
```

---

### PRUEBA 5: Errores semánticos
**Archivo**: `prueba5_error_semantico.txt`

**Contenido**:
```
[1, 2, 3] + [4, 5, 6, 7];
[1, 2] * [3, 4, 5];
[1, 2; 3, 4] * [5, 6, 7];
DET([1, 2, 3; 4, 5, 6]);
INV([1, 2; 3, 4; 5, 6]);
```

**Resultado esperado**:
```
==============================================
  CALCULADORA DE MATRICES - Versión 1.0
==============================================
Ingrese expresiones matriciales (Ctrl+D para salir):

Error semántico en línea 1: Dimensiones incompatibles para operación +/-, 1x3 vs 1x4

Error semántico en línea 2: Dimensiones incompatibles para multiplicación, 1x2 * 1x3

Error semántico en línea 3: Dimensiones incompatibles para multiplicación, 2x2 * 1x3

Error semántico en línea 4: La matriz 2x3 no es cuadrada para esta operación

Error semántico en línea 5: La matriz 3x2 no es cuadrada para esta operación

=== Procesamiento completado exitosamente ===
```

---

## Validaciones Semánticas

| Operación | Condición de Error | Mensaje |
|-----------|-------------------|---------|
| `A + B` | `filas(A) ≠ filas(B)` o `cols(A) ≠ cols(B)` | "Dimensiones incompatibles para operación +/-, AxB vs CxD" |
| `A - B` | `filas(A) ≠ filas(B)` o `cols(A) ≠ cols(B)` | "Dimensiones incompatibles para operación +/-, AxB vs CxD" |
| `A * B` | `cols(A) ≠ filas(B)` | "Dimensiones incompatibles para multiplicación, AxB * CxD (columnas de A debe igualar filas de B)" |
| `DET(M)` | `filas ≠ columnas` | "La matriz AxB no es cuadrada para esta operación" |
| `INV(M)` | `filas ≠ columnas` o `det(M) ≈ 0` | "La matriz AxB no es cuadrada..." o "Matriz singular, no se puede calcular la inversa" |

---

## Gestión de Memoria

El programa implementa las siguientes buenas prácticas:

- **Asignación dinámica**: Las matrices se crean con `malloc` según sus dimensiones.
- **Liberación inmediata**: Después de cada operación, los operandos se liberan para evitar fugas de memoria.
- **Liberación al salir**: El resultado final se libera después de ser mostrado.

---

## Dependencias

- **Flex** 2.6.x o superior
- **Bison** 3.x
- **GCC** con soporte C99/C11
- **math.h** para funciones matemáticas (`fabs`)

---

## Autores

Proyecto desarrollado como trabajo académico para el curso de **Traductores e Interpretadores**.

**Versión**: 1.0