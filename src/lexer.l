%{
#include <stdio.h>
#include <string.h>
#include "parser.tab.h"

static int col = 1;

/* Entrega el token al parser: guarda lexema y posicion, y avanza la columna. */
static int tok(int t) {
    yylval.s = strdup(yytext);
    yylloc.first_line = yylineno;
    yylloc.first_column = col;
    col += (int)yyleng;
    return t;
}
%}

%option noyywrap
%option yylineno
%option nounistd

%%

"if"                          { return tok(IF); }
"else"                        { return tok(ELSE); }
"while"                       { return tok(WHILE); }
"for"                         { return tok(FOR); }
"return"                      { return tok(RETURN); }
"int"                         { return tok(INT); }
"float"                       { return tok(FLOAT); }
"char"                        { return tok(CHAR); }
"void"                        { return tok(VOID); }

[a-zA-Z_][a-zA-Z0-9_]*        { return tok(ID); }

[0-9]+\.[0-9]+                { return tok(DECIMAL); }
[0-9]+                        { return tok(ENTERO); }

\"([^\"\\\n]|\\.)*\"          { return tok(CADENA); }

"=="                          { return tok(EQ); }
"!="                          { return tok(NE); }
"<="                          { return tok(LE); }
">="                          { return tok(GE); }
"&&"                          { return tok(AND); }
"||"                          { return tok(OR); }
[-+*/%=<>!{}(),;]             { return tok(yytext[0]); }

"//"[^\n]*                    { /* comentario de linea: se descarta */ }
"/*"([^*]|\*+[^*/])*\*+"/"    {
    /* comentario de bloque: se descarta, pero la columna debe seguir correcta */
    char *nl = strrchr(yytext, '\n');
    if (nl) col = (int)(yytext + yyleng - nl); else col += yyleng;
}

\"([^\"\\\n]|\\.)*            { return tok(ERROR_LEX); }   /* cadena sin cerrar */

\n                            { col = 1; }
[ \t\r]+                      { col += (int)yyleng; }

.                             { return tok(ERROR_LEX); }

<<EOF>>                       { yylloc.first_line = yylineno; yylloc.first_column = col; return 0; }

%%
