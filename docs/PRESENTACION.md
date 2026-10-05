# Guion para la presentación en clase

Guion de apoyo para exponer el analizador sintáctico. Pensado para hablar con
la pantalla compartida (editor + GUI), sin diapositivas. Duración estimada:
~15 minutos. Cada sección dice **qué mostrar** y **qué decir**.

---

## 1. Introducción — qué es el análisis sintáctico (2 min)

**Mostrar:** el diagrama de [README.md](../README.md#arquitectura).

**Decir:**

> En la tarea anterior hicimos el análisis léxico: convertir el texto en
> **tokens**. Pero una lista de tokens válidos no es un programa válido:
> `int = ; x 5` son tokens perfectos y no significan nada. El **análisis
> sintáctico** (parsing) verifica que los tokens vengan en un orden permitido
> por la **gramática** del lenguaje, y construye el **árbol sintáctico** que
> muestra cómo se agrupan.
>
> Es la segunda fase de un compilador: el lexer lee caracteres y entrega
> tokens; el parser lee tokens y entrega un árbol (o errores).

---

## 2. Gramática libre de contexto (3 min)

**Mostrar:** [docs/LENGUAJE.md](LENGUAJE.md), sección 2.

**Decir:**

> Las expresiones regulares del lexer no alcanzan para esto: no pueden contar
> ni anidar. No hay regex que verifique que los paréntesis están balanceados.
> Para eso se usan las **gramáticas libres de contexto**: reglas de la forma
> `no_terminal → secuencia de terminales y no terminales`. Por ejemplo:
>
> `sentencia → 'while' '(' expr ')' sentencia`
>
> es **recursiva** — una sentencia puede contener otra sentencia — y esa
> recursión es justo lo que permite anidar bloques y expresiones.
>
> Una **derivación** es aplicar reglas desde el símbolo inicial (`programa`)
> hasta obtener exactamente la lista de tokens. El **árbol sintáctico** es el
> registro de qué reglas se aplicaron.

---

## 3. Arquitectura: Flex + Bison (2 min)

**Mostrar:** [src/lexer.l](../src/lexer.l) y [src/parser.y](../src/parser.y), lado a lado.

**Decir:**

> Mismo enfoque que la tarea anterior: generadores en vez de escribirlo a mano.
> **Flex** genera el lexer a partir de `lexer.l`; **Bison** genera el parser a
> partir de `parser.y`, que contiene la gramática. La diferencia con la
> tarea 2 es que el lexer ya no imprime tokens: cada vez que reconoce uno,
> *retorna* su tipo al parser (`return tok(IF);`), y el parser lo pide con
> `yylex()` cada vez que necesita el siguiente.
>
> `parser.exe` toma un archivo, lo analiza, e imprime en texto el árbol o los
> errores. La interfaz gráfica en Python solo ejecuta ese `.exe` y dibuja el
> resultado, igual que en la tarea anterior.

---

## 4. Cómo funciona Bison por dentro: LALR(1) (3-4 min)

**Mostrar:** `parser.output` (se genera con `build.ps1`), buscar un par de
`State` y la sección "Grammar".

**Decir:**

> Bison genera un parser **LALR(1)**: lee los tokens de izquierda a derecha
> (**L**eft-to-right), construye una derivación por la derecha *al revés*
> (de ahí que se llame "ascendente" o *bottom-up*), y mira **1** token de
> anticipación (*lookahead*). "LA" viene de *look-ahead* LR: una versión compacta
> de las tablas LR(1).
>
> Funciona con una **pila** y una **tabla de estados** (en `parser.output` hay
> unos 120). En cada paso hace una de dos cosas:
>
> - **Shift (desplazar)**: mete el token siguiente en la pila.
> - **Reduce (reducir)**: cuando lo de arriba de la pila coincide con el lado
>   derecho de una regla, lo reemplaza por el lado izquierdo, y en ese momento
>   se ejecuta la acción en C que construye el nodo del árbol.
>
> Ejemplo con `a + b * 2`: se desplaza `a`, `+`, `b`; al ver `*` el parser
> decide *desplazar* (porque `*` tiene más precedencia que `+`) en vez de
> reducir `a + b`. Así termina `b * 2` agrupado primero.

**Si preguntan por los estados:** abrir `parser.output`; cada `State N` lista
sus ítems (`regla: ... . ...`, el punto es "hasta dónde he leído") y las
acciones `shift`/`reduce` según el lookahead.

---

## 5. Ambigüedad y precedencia (3 min)

**Mostrar:** `%left` / `%right` y `%nonassoc IFX` en `parser.y` (líneas 58-67).

**Decir:**

> La regla `expr → expr '+' expr | expr '*' expr` es **ambigua**: `a + b * 2`
> tiene dos árboles posibles. Podría reescribir la gramática con un nivel por
> operador, pero Bison permite resolverlo declarando **precedencia y
> asociatividad**: `%left '+'`, luego `%left '*'` más abajo (= mayor
> precedencia). `%right '='` hace que `a = b = c` sea `a = (b = c)`.
>
> El ejemplo clásico es el **else colgante**: en
> `if (a) if (b) x = 1; else x = 2;` ¿el `else` es del `if` interno o del
> externo? Es un conflicto *shift/reduce*. Lo resuelvo como C: el `else` se une
> al `if` más cercano, con `%prec IFX`.

**Demo en vivo (recomendada):**

> Comento `%prec IFX` en la regla corta del `if` y recompilo.

```bash
powershell -ExecutionPolicy Bypass -File build.ps1
```

> Bison falla con `shift/reduce conflicts: 1 found, 0 expected` — por eso
> puse `%expect 0`: la gramática debe tener cero conflictos. *(Revertir el
> cambio y recompilar después.)*

---

## 6. Manejo de errores (2 min)

**Mostrar:** la regla `error ';'` en `sentencia` y la función `yyerror`.

**Decir:**

> Cuando el parser encuentra un token que no encaja, llama a `yyerror` y
> reporta línea, columna y qué esperaba. Pero no se detiene: tengo una regla
> especial `sentencia → error ';'`. Con ella el parser entra en **modo
> pánico**: descarta tokens hasta el siguiente `;`, se "resincroniza", y sigue
> analizando. Así puede reportar varios errores en una sola pasada, en vez de
> parar en el primero.
>
> Un detalle importante: el error se marca en el token donde el parser se dio
> cuenta, no donde estaba el descuido. Si falto un `;` al final de una línea,
> lo detecta en el primer token de la línea siguiente.

---

## 7. Demo en vivo con la GUI (3-4 min)

**Mostrar:** abrir la GUI.

```bash
python gui\app.py
```

**Decir mientras haces la demo:**

> Abro un programa válido...

*(botón "Abrir archivo...", elegir [tests/ejemplos/valido.txt](../tests/ejemplos/valido.txt), clic en "Analizar")*

> ...y la pestaña "Árbol sintáctico" muestra la estructura: el programa
> contiene declaraciones y funciones; cada función tiene sus parámetros y su
> bloque; dentro, un `for` con inicio, condición y paso. Vean cómo `b * 2`
> queda *dentro* de la suma, por la precedencia. *(Expandir/colapsar nodos.)*
>
> Ahora uno con errores...

*(abrir [tests/ejemplos/errores.txt](../tests/ejemplos/errores.txt), "Analizar")*

> ...la pestaña "Errores" lista cada uno con su línea y columna, las líneas
> defectuosas se marcan en rojo en el editor, y con **doble clic** en un error
> salta a esa posición. Noten que reporta los seis y no se corta en el
> primero.

*(Opcional: escribir en vivo `if (a) if (b) x = 1; else x = 2;` y mostrar que el
`else` queda bajo el `If` interno.)*

---

## 8. Cierre (30 seg)

> En resumen: describí el lenguaje con una gramática libre de contexto, Bison
> generó el parser LALR(1) que la implementa, el lexer de la tarea anterior
> le alimenta los tokens, y la GUI muestra el árbol sintáctico y los errores.
> El código, la documentación del lenguaje y el ejecutable están en el
> repositorio de GitHub.

---

## Preguntas frecuentes

- **"¿Por qué no basta con expresiones regulares?"** — Las regex no pueden
  contar ni anidar (paréntesis balanceados, bloques dentro de bloques). Eso
  exige una gramática libre de contexto y un autómata **con pila**.
- **"¿Qué diferencia hay entre top-down y bottom-up?"** — Un parser
  descendente (recursivo) parte del símbolo inicial y predice qué regla usar;
  uno ascendente (LALR, el de Bison) parte de los tokens y va reduciendo hasta
  llegar al símbolo inicial. LALR(1) acepta más gramáticas que LL(1).
- **"¿Qué es un conflicto shift/reduce?"** — El parser, con la pila y el
  lookahead actuales, tiene dos acciones válidas (desplazar o reducir) y no sabe
  cuál. Indica ambigüedad en la gramática; se resuelve con precedencia o
  reescribiendo reglas.
- **"¿Verifica tipos o variables no declaradas?"** — No, eso es análisis
  **semántico**, la fase siguiente. Aquí solo se valida la forma.
- **"¿Por qué un error se marca en la línea siguiente?"** — Porque el parser
  solo se da cuenta al leer un token que no puede continuar la derivación
  actual; ver sección 6.
- **"¿Por qué Python para la GUI?"** — Tkinter viene incluido y permite hacer
  la interfaz con poco código; el análisis en sí es 100% Flex/Bison/C.
