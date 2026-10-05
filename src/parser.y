%code requires { typedef struct Nodo Nodo; }

%code {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

/* ---- arbol sintactico ---- */
struct Nodo { char *label; Nodo **h; int n; };

static Nodo *add(Nodo *p, Nodo *c) {            /* hijo NULL = parte opcional ausente */
    if (!c) return p;
    p->h = realloc(p->h, (p->n + 1) * sizeof(Nodo *));
    p->h[p->n++] = c;
    return p;
}

static Nodo *N(const char *label, int n, ...) {
    Nodo *x = calloc(1, sizeof *x);
    va_list ap;
    x->label = strdup(label);
    va_start(ap, n);
    while (n--) add(x, va_arg(ap, Nodo *));
    va_end(ap);
    return x;
}

static Nodo *T(const char *kind, char *text) {  /* hoja: "kind: text" */
    char buf[512];
    snprintf(buf, sizeof buf, "%s: %s", kind, text);
    return N(buf, 0);
}

#define BIN(op, a, b) N("Binaria " op, 2, a, b)

static Nodo *raiz;
static int nerr = 0;

extern int yylex(void);
extern FILE *yyin;
extern char *yytext;
void yyerror(const char *msg);
}

%locations
%define parse.error verbose
%expect 0

%union { char *s; Nodo *n; }

%token <s> ID "identificador" ENTERO "entero" DECIMAL "decimal" CADENA "cadena"
%token IF "if" ELSE "else" WHILE "while" FOR "for" RETURN "return"
%token INT "int" FLOAT "float" CHAR "char" VOID "void"
%token EQ "==" NE "!=" LE "<=" GE ">=" AND "&&" OR "||"
%token ERROR_LEX "caracter invalido"

%right '='
%left OR
%left AND
%left EQ NE
%left '<' '>' LE GE
%left '+' '-'
%left '*' '/' '%'
%right '!' UMINUS
%nonassoc IFX            /* if sin else: menor que ELSE => el else se une al if mas cercano */
%nonassoc ELSE

%type <n> programa lista_items item tipo decl_func params lista_params param
%type <n> bloque lista_sent sentencia decl_var lista_decl declarador var_nombre
%type <n> if_sent expr_opt expr args lista_args

%%

programa
    : lista_items                       { raiz = $1; }
    | /* vacio */                       { raiz = N("Programa", 0); }
    ;

lista_items
    : item                              { $$ = N("Programa", 1, $1); }
    | lista_items item                  { $$ = add($1, $2); }
    ;

item
    : decl_func
    | sentencia
    ;

tipo
    : INT                               { $$ = N("tipo: int", 0); }
    | FLOAT                             { $$ = N("tipo: float", 0); }
    | CHAR                              { $$ = N("tipo: char", 0); }
    | VOID                              { $$ = N("tipo: void", 0); }
    ;

decl_func
    : tipo ID '(' params ')' bloque     { $$ = N("DeclFunc", 4, $1, T("nombre", $2), $4, $6); }
    ;

params
    : /* vacio */                       { $$ = N("Params", 0); }
    | VOID                              { $$ = N("Params", 0); }
    | lista_params
    ;

lista_params
    : param                             { $$ = N("Params", 1, $1); }
    | lista_params ',' param            { $$ = add($1, $3); }
    ;

param
    : tipo var_nombre                   { $$ = N("Param", 2, $1, $2); }
    ;

bloque
    : '{' lista_sent '}'                { $$ = $2; }
    ;

lista_sent
    : /* vacio */                       { $$ = N("Bloque", 0); }
    | lista_sent sentencia              { $$ = add($1, $2); }
    ;

sentencia
    : decl_var
    | expr ';'                          { $$ = N("ExprSent", 1, $1); }
    | ';'                               { $$ = N("Vacia", 0); }
    | bloque
    | if_sent
    | WHILE '(' expr ')' sentencia      { $$ = N("While", 2, $3, $5); }
    | FOR '(' expr_opt ';' expr_opt ';' expr_opt ')' sentencia
                                        { $$ = N("For", 4, N("Init", 1, $3), N("Cond", 1, $5), N("Paso", 1, $7), $9); }
    | RETURN ';'                        { $$ = N("Return", 0); }
    | RETURN expr ';'                   { $$ = N("Return", 1, $2); }
    | error ';'                         { yyerrok; $$ = N("Error", 0); }
    ;

if_sent
    : IF '(' expr ')' sentencia %prec IFX       { $$ = N("If", 2, $3, $5); }
    | IF '(' expr ')' sentencia ELSE sentencia  { $$ = N("If", 3, $3, $5, $7); }
    ;

decl_var
    : tipo lista_decl ';'               { $$ = N("DeclVar", 2, $1, $2); }
    ;

lista_decl
    : declarador                        { $$ = N("Declaradores", 1, $1); }
    | lista_decl ',' declarador         { $$ = add($1, $3); }
    ;

declarador
    : var_nombre
    | var_nombre '=' expr               { $$ = N("Init", 2, $1, $3); }
    ;

var_nombre
    : ID                                { $$ = T("variable", $1); }
    | '*' ID                            { $$ = T("puntero", $2); }
    ;

expr_opt
    : /* vacio */                       { $$ = NULL; }
    | expr
    ;

expr
    : ID '=' expr                       { $$ = N("Asignacion", 2, T("variable", $1), $3); }
    | expr OR expr                      { $$ = BIN("||", $1, $3); }
    | expr AND expr                     { $$ = BIN("&&", $1, $3); }
    | expr EQ expr                      { $$ = BIN("==", $1, $3); }
    | expr NE expr                      { $$ = BIN("!=", $1, $3); }
    | expr '<' expr                     { $$ = BIN("<", $1, $3); }
    | expr '>' expr                     { $$ = BIN(">", $1, $3); }
    | expr LE expr                      { $$ = BIN("<=", $1, $3); }
    | expr GE expr                      { $$ = BIN(">=", $1, $3); }
    | expr '+' expr                     { $$ = BIN("+", $1, $3); }
    | expr '-' expr                     { $$ = BIN("-", $1, $3); }
    | expr '*' expr                     { $$ = BIN("*", $1, $3); }
    | expr '/' expr                     { $$ = BIN("/", $1, $3); }
    | expr '%' expr                     { $$ = BIN("%", $1, $3); }
    | '-' expr %prec UMINUS             { $$ = N("Unaria -", 1, $2); }
    | '!' expr                          { $$ = N("Unaria !", 1, $2); }
    | '(' expr ')'                      { $$ = $2; }
    | ID '(' args ')'                   { $$ = N("Llamada", 2, T("nombre", $1), $3); }
    | ID                                { $$ = T("variable", $1); }
    | ENTERO                            { $$ = T("entero", $1); }
    | DECIMAL                           { $$ = T("decimal", $1); }
    | CADENA                            { $$ = T("cadena", $1); }
    ;

args
    : /* vacio */                       { $$ = N("Args", 0); }
    | lista_args
    ;

lista_args
    : expr                              { $$ = N("Args", 1, $1); }
    | lista_args ',' expr               { $$ = add($1, $3); }
    ;

%%

/* Bison genera los mensajes en ingles: se traducen a mano (sin tildes, la GUI no las espera). */
static void replace(char *buf, const char *from, const char *to) {
    char tmp[512], *p;
    while ((p = strstr(buf, from))) {
        snprintf(tmp, sizeof tmp, "%.*s%s%s", (int)(p - buf), buf, to, p + strlen(from));
        strcpy(buf, tmp);
    }
}

void yyerror(const char *msg) {
    char buf[512];
    snprintf(buf, sizeof buf, "%s", msg);
    replace(buf, "syntax error", "error de sintaxis");
    replace(buf, "unexpected end of file", "se encontro fin de archivo");
    replace(buf, "unexpected", "se encontro");
    replace(buf, "expecting", "se esperaba");
    replace(buf, " or ", " o ");
    nerr++;
    if (yychar == ID || yychar == ENTERO || yychar == DECIMAL || yychar == CADENA || yychar == ERROR_LEX)
        printf("ERROR|%d|%d|%s (lexema '%s')\n", yylloc.first_line, yylloc.first_column, buf, yytext);
    else
        printf("ERROR|%d|%d|%s\n", yylloc.first_line, yylloc.first_column, buf);
}

static void imprimir(Nodo *x, int depth) {
    int i;
    printf("NODO|%d|%s\n", depth, x->label);
    for (i = 0; i < x->n; i++) imprimir(x->h[i], depth + 1);
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "uso: parser.exe <archivo>\n");
        return 1;
    }
    yyin = fopen(argv[1], "r");
    if (!yyin) {
        fprintf(stderr, "no se pudo abrir: %s\n", argv[1]);
        return 1;
    }
    yyparse();
    fclose(yyin);
    if (nerr == 0) {
        imprimir(raiz, 0);
        puts("RESULTADO|OK");
    } else {
        printf("RESULTADO|ERRORES|%d\n", nerr);
    }
    return nerr ? 2 : 0;
}
