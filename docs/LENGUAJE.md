# Lenguaje de prueba del Analizador Sintáctico (Mini-C)

Este documento especifica el lenguaje que el analizador sintáctico
([src/parser.y](../src/parser.y)) reconoce, para usarlo al escribir programas de
prueba y al explicar la gramática en la presentación.

Es el mismo **Mini-C** de la Tarea 2 (subconjunto de C): el analizador léxico
([src/lexer.l](../src/lexer.l)) conserva exactamente los mismos tokens, pero ahora
en lugar de imprimirlos se los **entrega al parser**, que verifica que estén en un
orden válido según una gramática.

## 1. Tokens (los entrega el lexer)

| Token | Ejemplos |
|---|---|
| Palabras reservadas | `if else while for return int float char void` |
| `identificador` | `contador`, `_x1` |
| `entero` / `decimal` | `42` / `3.14` |
| `cadena` | `"hola\n"` |
| Operadores | `+ - * / % = == != < > <= >= && \|\| !` |
| Símbolos | `{ } ( ) ; ,` |
| `caracter invalido` | `@`, `$`, `#`, cadena sin cerrar (el parser lo reporta como error) |

Comentarios `// ...` y `/* ... */` y los espacios se descartan en el lexer; el parser nunca los ve.

## 2. Gramática libre de contexto

Notación: `{ x }` = cero o más, `[ x ]` = opcional, `'x'` = token literal.
Los no terminales están en minúscula, los terminales entre comillas o en español.

```
programa     → { item }
item         → decl_func | sentencia

decl_func    → tipo identificador '(' [ params ] ')' bloque
params       → 'void' | param { ',' param }
param        → tipo var_nombre
tipo         → 'int' | 'float' | 'char' | 'void'

bloque       → '{' { sentencia } '}'
sentencia    → decl_var
             | expr ';'
             | ';'
             | bloque
             | 'if' '(' expr ')' sentencia [ 'else' sentencia ]
             | 'while' '(' expr ')' sentencia
             | 'for' '(' [expr] ';' [expr] ';' [expr] ')' sentencia
             | 'return' [ expr ] ';'

decl_var     → tipo declarador { ',' declarador } ';'
declarador   → var_nombre [ '=' expr ]
var_nombre   → [ '*' ] identificador

expr         → identificador '=' expr                 (asignación)
             | expr OP expr                           (OP binario, ver sección 3)
             | ( '-' | '!' ) expr
             | '(' expr ')'
             | identificador '(' [ args ] ')'         (llamada)
             | identificador | entero | decimal | cadena
args         → expr { ',' expr }
```

Notas de diseño:

- `programa → { item }` permite **sentencias sueltas a nivel global** (no solo
  declaraciones y funciones), así los programas de la Tarea 2 siguen siendo
  válidos tal cual.
- La `*` de `var_nombre` solo sirve para poder escribir `char *msg = "hola";`;
  no hay aritmética de punteros ni tipos de puntero en la gramática.
- La gramática es **LALR(1)** y tiene **0 conflictos** (`%expect 0` en
  `parser.y` hace que Bison falle si apareciera alguno).

## 3. Precedencia y asociatividad (de menor a mayor)

La gramática de `expr` es ambigua a propósito (`expr OP expr`); la ambigüedad
se resuelve con las declaraciones `%left/%right` de Bison, no reescribiendo la
gramática en un nivel por operador.

| Nivel | Operadores | Asociatividad |
|---|---|---|
| 1 | `=` | derecha (`a = b = c` → `a = (b = c)`) |
| 2 | `\|\|` | izquierda |
| 3 | `&&` | izquierda |
| 4 | `==` `!=` | izquierda |
| 5 | `<` `>` `<=` `>=` | izquierda |
| 6 | `+` `-` | izquierda |
| 7 | `*` `/` `%` | izquierda |
| 8 | `-` unario, `!` | derecha |

Ejemplo: `a + b * 2` se agrupa como `a + (b * 2)`; el árbol lo muestra con
`Binaria +` como padre de `Binaria *`.

### El "else colgante" (*dangling else*)

`if (a) if (b) x = 1; else x = 2;` admite dos lecturas: el `else` podría ser
del `if` interno o del externo. El parser tendría un conflicto *shift/reduce*
al ver `else`. Se resuelve como en C: **el `else` se une al `if` más cercano**,
dándole al token `else` más precedencia que a la regla "if sin else"
(`%nonassoc IFX` < `%nonassoc ELSE`, con `%prec IFX` en la regla corta).

## 4. Salida de `parser.exe`

Una línea por registro (la GUI solo lee y dibuja esto):

```
NODO|profundidad|etiqueta      un nodo del árbol, en preorden (solo si no hubo errores)
ERROR|linea|columna|mensaje    un error sintáctico o léxico
RESULTADO|OK                   análisis exitoso
RESULTADO|ERRORES|n            n errores encontrados
```

El árbol es un **árbol sintáctico simplificado**: omite los tokens de
puntuación (`;`, `(`, `{`, `,`...) y conserva los nodos que importan:
`Programa`, `DeclVar`, `DeclFunc`, `Params`, `Bloque`, `If`, `While`, `For`
(con `Init`/`Cond`/`Paso`), `Return`, `ExprSent`, `Asignacion`, `Binaria <op>`,
`Unaria <op>`, `Llamada`, y las hojas (`variable: x`, `entero: 5`...).

## 5. Manejo de errores

Hay dos clases de error que llegan al parser:

- **Sintáctico**: los tokens son válidos pero no están en un orden permitido
  (falta un `;`, un `)` sin cerrar, un `else` sin `if`...). El mensaje indica
  qué se encontró y, cuando son pocas opciones, qué se esperaba.
- **Léxico**: el lexer entrega un token `caracter invalido` (por ejemplo `@` o
  una cadena sin cerrar), que ninguna regla de la gramática acepta, así que
  también se reporta como error (con el lexema).

**Posición**: un error se reporta en el **token que no encaja**, no donde
estaba el descuido real. Si falta el `;` al final de la línea 1, el error se
marca al inicio de la línea 2 (donde aparece el token inesperado). Es el
comportamiento normal de un parser LR.

**Recuperación (modo pánico)**: ante un error, el parser descarta tokens hasta
encontrar el siguiente `;` (regla `sentencia → error ';'`) y continúa, para
reportar varios errores en una misma pasada. Consecuencia: el resto de una
sentencia dañada se salta sin analizar, así que dos errores en la misma
sentencia cuentan como uno. Si hay errores no se dibuja árbol (sería parcial y
engañoso).

## 6. Ejemplo válido

[tests/ejemplos/valido.txt](../tests/ejemplos/valido.txt): declaraciones con
inicializador, función con parámetros, `for`, `if/else`, `while`, `return`,
llamada a función y un `else` colgante. Resultado: `RESULTADO|OK` y el árbol
completo.

## 7. Ejemplo con errores

[tests/ejemplos/errores.txt](../tests/ejemplos/errores.txt):

```c
int x = (5 + 2;            // 1: falta ')'
float z = 3.14 @ 2;        // 2: caracter invalido
int f(int a) {
    return a +;            // 4: falta el operando derecho
}
else x = 1;                // 6: else sin if
char *s = "sin cerrar      // 7: cadena sin cerrar (error léxico)
int ok = 1;
int y = 3                  // 10: falta ';' (se detecta al llegar al fin de archivo)
```

Genera 6 errores, uno por línea defectuosa, con su posición; el análisis
continúa después de cada uno. (La línea 8 `int ok = 1;` queda dentro de la
zona que el modo pánico descarta tras el error de la línea 7.)

## 8. Fuera del alcance

Análisis semántico (tipos, variables declaradas, `return` consistente con el
tipo de la función), arreglos, structs, punteros reales, `switch`/`do-while`/
`break`, y funciones anidadas. Este analizador solo verifica **la forma** del
programa, no su significado.
