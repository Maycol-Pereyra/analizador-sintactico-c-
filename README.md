# Analizador Sintáctico - Mini-C (Flex + Bison + Tkinter)

Analizador sintáctico construido con **Flex** (lexer) y **Bison** (parser LALR(1)),
con una GUI de escritorio en Python/Tkinter (sin consola) que muestra el
**árbol sintáctico** y los **errores** con su línea y columna.

Continúa la Tarea 2 (analizador léxico): mismo lenguaje Mini-C, pero ahora los
tokens se le entregan a un parser que valida su orden según una gramática.

Documentación del lenguaje de prueba (gramática BNF, precedencia, errores,
ejemplos): [docs/LENGUAJE.md](docs/LENGUAJE.md).
Guion de la exposición: [docs/PRESENTACION.md](docs/PRESENTACION.md).

## Arquitectura

```
codigo fuente (.txt)
      |
      v
parser.exe  (src/lexer.l --[win_flex]--> lex.yy.c  \
             src/parser.y --[win_bison]-> parser.tab.c/.h  --[cl.exe]--> parser.exe)
      |  stdout: NODO|prof|etiqueta, ERROR|linea|col|mensaje, RESULTADO|...
      v
gui/app.py (Tkinter) -- ejecuta parser.exe oculto, dibuja árbol y errores
```

`yyparse()` (Bison) pide tokens a `yylex()` (Flex) uno por uno; las acciones de
cada regla de `parser.y` construyen los nodos del árbol, que `main()` imprime
al terminar si no hubo errores.

## Requisitos

- Windows con Visual Studio (Community/Build Tools): se usa `cl.exe`.
- Python 3.10+ (Tkinter incluido).
- `tools/win_flex.exe`, `tools/win_bison.exe` y `tools/data/` (skeletons de
  Bison) ya vienen en el repo ([winflexbison](https://github.com/lexxmark/winflexbison) 2.5.25).

## Build

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1
```

Genera `parser.exe` (entregable, ya commiteado) y `parser.output` (estados LALR
y reporte de conflictos de Bison, útil para la presentación). El aviso
`'vswhere.exe' is not recognized` durante la compilación es inofensivo.

## Ejecutar la app gráfica

```powershell
python gui\app.py
```

Escribe o abre un programa Mini-C y pulsa **Analizar** (F5):

- Pestaña **Árbol sintáctico**: árbol expandible/colapsable.
- Pestaña **Errores**: lista con línea/columna; doble clic salta a esa posición
  en el editor. Las líneas con error se resaltan en rojo.

## Tests

```powershell
python gui\test_parse.py
```

Prueba el formato de salida y corre `parser.exe` de punta a punta sobre
[tests/ejemplos/valido.txt](tests/ejemplos/valido.txt) (0 errores) y
[tests/ejemplos/errores.txt](tests/ejemplos/errores.txt) (6 errores, uno por línea defectuosa).

## Estructura del repo

```
src/lexer.l           lexer Flex: reconoce tokens y se los retorna al parser
src/parser.y          gramática Bison + construcción del árbol + main()
build.ps1             win_bison + win_flex + cl.exe -> parser.exe
gui/app.py            GUI Tkinter
gui/test_parse.py     tests (parseo de la salida y ejecución real de parser.exe)
tests/ejemplos/       programas Mini-C de prueba (valido, errores, lexico_valido)
docs/                 LENGUAJE.md (gramática) y PRESENTACION.md (guion)
tools/                win_flex, win_bison y su carpeta data/
parser.exe            ejecutable compilado (entregable)
```
