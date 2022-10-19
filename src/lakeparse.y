%code requires {
    typedef void *yyscan_t;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
    
#include "cstate.h"
#include "hashtable.h"
#include "ast.h"
#include "lake.h"
    // Redundant include for using yytoken_kind_t
#include "lakeparse.tab.h" 

extern void yyerror();
extern int yylex();

static astnode_t *trace_parent(astnode_t *);
static int get_const_size(cstate_t *, ival_t);
static int get_auto_size(yytoken_kind_t, astnode_t *);
static int get_largest_size(astnode_t *, astnode_t *);
static astnode_t *new_ast_op(cstate_t *, ival_t, astnode_t *,
                             astnode_t *);
static const char *get_token_name(int); // yysymbol_kind_t
%}

// Declarations (Optional type definitions)
// YYSTYPE
%union {
    char *str;
    ival_t ival;
    astnode_t *astnode;
}


// Add args to yyparse and yylex
%define api.pure full
%parse-param    { cstate_t *cs };
%param          { yyscan_t scanner };

%define parse.error custom

/*
 * Resulting func defs:
 * int yylex   ( YYSTYPE *lvalp, yyscan_t scanner );
 * int yyparse ( cstate_t *cs, yyscan_t scanner );
 */


// Token defs
%token FUNC
%token RET ASM
%token UNTIL WHILE SWITCH
%token AGAIN FOR BREAK BREAKON // CURRENTLY UNUSED
%token IF ELIF ELSE // TODO
%token '@'
%token<ival> DPAGE STACK       // CURRENTLY UNUSED
%token<ival> VOID T_U8 T_I8 T_U16 T_I16 T_U32 T_I32 AUTO
%token<ival> NUM
%token<str> IDENT
%token<str> STR
%right ':'                      /* Indirect Assignment */
%right '='                      /* Assignment */
%right<ival> ANDASGN XORASGN ORASGN   /* &= ^= |= */
%right<ival> RSHFASGN ARSHFASGN       /* >>= >>>= */
%right<ival> ADDASGN SUBASGN LSHFASGN /* += -= <<= */
%right<ival> MULTASGN DIVASGN         /* *= /= */
%left<ival> LOR                 /* Logical OR */
%left<ival> LXOR                /* Logical XOR */
%left<ival> LAND                /* Logical AND */
%left<ival> '|'                 /* Bitwise OR */
%left<ival> '^'                 /* Bitwise XOR */
%left<ival> '&'                 /* Bitwise AND */
%left<ival> EQ NEQ              /* Equality comparisons */
%left<ival> LT LE GT GE         /* Comparison */
%left<ival> LSHF RSHF ARSHF     /* Shifts */
%left<ival> '-' '+'
%left<ival> '*' '/'
%precedence NEG                 /* Unary minus */
%precedence<ival> BNOT '!'      /* Bitwise and Logical negation */
/* %right PREINCR PREDECR          /\* ++ -- *\/ */
/* %left POSTINCR POTSDECR         /\* ++ -- *\/ */
%left '.'                       /* Member access */


%nterm<ival> functype vartype paramtype
%nterm<ival> modassign
%nterm<astnode> while switch switch_body until
%nterm<astnode> funcall callarg
%nterm<astnode> exp constval
%nterm<astnode> block statement assignment
%nterm<astnode> params paramlist paramdef
%nterm<astnode> vardecl globdecl
%nterm<astnode> start



// Parsing ruleset definitions
%%
start:
    %empty                                          {
        printf("Confuzing empty...\n");
        $$ = NULL;
    };
    | start FUNC functype IDENT[name] '(' params ')' block  {

        printf("Func decl: '%s'\n", $name); // DEBUG
        $$ = new_ast_node(
            (int)FUNC,
            $functype,
            $name,
            0,
            $1,
            NULL,
            $params,
            $block,
            cs
            );

        $block->parent = $$;

        if ($$->parent)
        {
            $$->parent->next = $$;
        }
        else
        {
            // First thing defined, make it the start
            cs->ast->head = $$;
        }
    };
    | start globdecl                                {

        printf("Global Decl: '%s'\n", $2->ident); // DEBUG
        if ($1)
        {
            $2->parent = $1;
            $1->next = $2;
        }
        else
        {
            // First thing defined, make it the start
            cs->ast->head = $2;
        }
        $$ = $2;
    };
    ;

functype:
    VOID                                            { $$ = VOID; };
    | T_U8                                          { $$ = T_U8; };
    | T_I8                                          { $$ = T_I8; };
    | T_U16                                         { $$ = T_U16; };
    | T_I16                                         { $$ = T_I16; };
    | T_U32                                         { $$ = T_U32; };
    | T_I32                                         { $$ = T_I32; };
    ;

vartype:
    AUTO                                            { $$ = AUTO; };
    | T_U8                                          { $$ = T_U8; };
    | T_I8                                          { $$ = T_I8; };
    | T_U16                                         { $$ = T_U16; };
    | T_I16                                         { $$ = T_I16; };
    | T_U32                                         { $$ = T_U32; };
    | T_I32                                         { $$ = T_I32; };
    ;

paramtype:
    T_U8                                            { $$ = T_U8; };
    | T_I8                                          { $$ = T_I8; };
    | T_U16                                         { $$ = T_U16; };
    | T_I16                                         { $$ = T_I16; };
    | T_U32                                         { $$ = T_U32; };
    | T_I32                                         { $$ = T_I32; };
    ;

params:
    %empty                                          { $$ = NULL; };
    | paramlist                                     { $$ = $1; };
    ;

paramlist:
    paramdef                                        { $$ = $1; };
    | paramlist ',' paramdef                        {

        // Insert param def to beginning of list
        if ($1->parent)
        {
            $3->parent = $1->parent;
            $1->parent->next = $3;
        }
        $1->parent = $3;
        $3->next = $1;
        $$ = $3;
      };
    ;

paramdef:
    paramtype[type] IDENT[ident]                    {

        $$ = new_ast_node(
            (int)NTS_paramdef,
            $type,
            $ident,
            0,
            NULL, NULL, NULL, NULL,
            cs
            );
    };
    ;

exp:
    constval                                        { $$ = $1; };
    | '-' constval %prec NEG                        {
        $$ = $2;
        $2->ival = -$2->ival; // Negate value
    };
    | '~' exp[rexp] %prec BNOT                      {
        $$ = new_ast_op(cs, '~', NULL, $rexp);
    };
    | funcall                                       { $$ = $1; };
    | IDENT                                         {
        
        $$ = new_ast_node(
            (int)IDENT,
            0,
            $1,
            0,
            NULL, NULL, NULL, NULL,
            cs
            );
    };
    | '(' exp ')'                                   { $$ = $2; };
    | '[' vartype ',' exp[rexp] ']'                 {
        $$ = new_ast_node(
            (int)NTS_indaccess,
            $vartype,
            NULL,
            0,
            NULL, NULL, NULL, $rexp,
            cs
            );
    };
    | exp[lexp] '+' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '-' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '*' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '/' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '|' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '&' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] '^' exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] ARSHF exp[rexp]             {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] RSHF exp[rexp]              {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LSHF exp[rexp]              {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] GT exp[rexp]                {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LT exp[rexp]                {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] NEQ exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] EQ exp[rexp]                {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] GE exp[rexp]                {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LE exp[rexp]                {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LAND exp[rexp]              {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LOR exp[rexp]               {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    | exp[lexp] LXOR exp[rexp]              {
        $$ = new_ast_op(cs, $2, $lexp, $rexp);
    };
    ;


funcall:
    IDENT '(' callarg ')'                           {
        
        $$ = new_ast_node(
            (int)NTS_funcall,
            0,
            $1, // Func name
            0,
            NULL, NULL, $callarg, NULL,
            cs
            );
    };
    ;

callarg:
    %empty                                          { $$ = NULL; };
    | exp                                           { $$ = $1; };
    | callarg ',' exp                               {

        // Insert arg at beginning of list
        if ($1->parent)
        {
            $3->parent = $1->parent;
            $1->parent->next = $3;
        }
        $1->parent = $3;
        $3->next = $1;
        $$ = $3;
      };
    ;

constval:
    NUM                                             {
        $$ = new_ast_node(
            (int)NTS_constval,
            get_const_size(cs, $1),
            NULL,
            $1,
            NULL, NULL, NULL, NULL,
            cs
            );
    };
    | STR                                           {
        $$ = new_ast_node(
            (int)NTS_constval,
            T_U32,
            $1,
            0,
            NULL, NULL, NULL, NULL,
            cs
            );
      };
    ;

block:
    '{' statement '}'                               {
        
        $$ = new_ast_node(
            (int)NTS_block,
            0,
            NULL,
            0,
            NULL, NULL, NULL, trace_parent($statement),
            cs
            );
    };
    | '{' ':' IDENT statement '}'                               {
        
        $$ = new_ast_node(
            (int)NTS_block,
            0,
            $IDENT,
            0,
            NULL, NULL, NULL, trace_parent($statement),
            cs
            );
    };
    ;

/*
 * Statements are kinda funky:
 * The returned value is actually the last element in the list,
 * meaning that you must trace the list back up until the parent
 * is null.
 */
statement:
    %empty                                          { $$ = NULL; };
    | statement block                               {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement vardecl                             {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement assignment                          {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement while                               {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement until                               {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement switch                              {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement funcall ';'                         {
        
        $$ = $2;
        if ($1)
        {
            $1->next = $2;
        }
        $2->parent = $1;
    };
    | statement RET exp ';'                         {

        $$ = new_ast_node(
            (int)RET,
            0,
            NULL,
            0,
            $1, NULL, NULL, $3,
            cs
            );
        
        if ($1)
        {
            $1->next = $$;
        }
    };
    | statement RET ';'                             {

        $$ = new_ast_node(
            (int)RET,
            0,
            NULL,
            0,
            $1, NULL, NULL, NULL,
            cs
            );
        
        if ($1)
        {
            $1->next = $$;
        }
    };
    | statement ASM STR ';'                         {

        $$ = new_ast_node(
            (int)ASM,
            0,
            $3,
            0,
            $1, NULL, NULL, NULL,
            cs
            );
            
        if ($1)
        {
            $1->next = $$;
        }
    };
    | statement IF '(' exp ')' block                {

        $$ = new_ast_node(
            (int)IF,
            0,
            NULL,
            0,
            $1, NULL, $exp, $block,
            cs
            );
            
        if ($1)
        {
            $1->next = $$;
        }
    };
    | statement ELIF '(' exp ')' block              {

        {
            $$ = new_ast_node(
                (int)ELSE,
                0,
                NULL,
                0,
                $1, NULL, NULL, NULL,
                cs
                );

            astnode_t *ifn = new_ast_node(
                (int)IF,
                0,
                NULL,
                0,
                $$, NULL, $exp, $block,
                cs
                );

            if ($$)
            {
                $$->rchild = ifn;
            }
        }
        
        if ($1)
        {
            $1->next = $$;
        }
    };
    | statement ELSE block              {

        $$ = new_ast_node(
            (int)ELSE,
            0,
            NULL,
            0,
            $1, NULL, NULL, $block,
            cs
            );
            
        if ($1)
        {
            $1->next = $$;
        }
    };
    ;

assignment:
    IDENT '=' exp ';'                               {
        
        $$ = new_ast_node(
            (int)NTS_assignment,
            0,
            $1,
            0,
            NULL, NULL, NULL, $exp,
            cs
            );
    };
    | IDENT modassign exp ';'                       {

        {
            // Create a node for the identifier
            astnode_t *varid = new_ast_node(
                (int)IDENT,
                0,
                $1,
                0,
                NULL, NULL, NULL, NULL,
                cs
                );

            // Then create an operator on that identifier
            astnode_t *op = new_ast_op(cs, $2, varid, $3);

            // Then perform the assignment
            $$ = new_ast_node(
                (int)NTS_assignment,
                0,
                $1,
                0,
                NULL, NULL, NULL, op,
                cs
                );
        }
    };
    | exp[lexp] ':' '=' exp[rexp] ';'               {

        // Indirect assign
        $$ = new_ast_node(
            (int)NTS_indassign,
            0,
            NULL,
            0,
            NULL, NULL, $lexp, $rexp,
            cs
            );
    };
    ;

modassign:
    ADDASGN                                         { $$ = '+'; };
    | SUBASGN                                       { $$ = '-'; };
    | MULTASGN                                      { $$ = '*'; };
    | DIVASGN                                       { $$ = '/'; };
    | ANDASGN                                       { $$ = '&'; };
    | ORASGN                                        { $$ = '|'; };
    | XORASGN                                       { $$ = '^'; };
    | LSHFASGN                                      { $$ = LSHF; };
    | RSHFASGN                                      { $$ = RSHF; };
    | ARSHFASGN                                     { $$ = ARSHF; };
    ;

vardecl:
    vartype IDENT ';'                               {
        
        $$ = new_ast_node(
            (int)NTS_vardecl,
            $vartype,
            $2,
            0,
            NULL, NULL, NULL, NULL,
            cs
            );
    };
    | vartype IDENT '=' exp ';'                     {
        $$ = new_ast_node(
            (int)NTS_vardecl,
            get_auto_size($vartype, $exp),
            $2,
            0,
            NULL, NULL, NULL, $exp,
            cs
            );
    };
;


globdecl:
    vartype IDENT ';'                               {
        $$ = new_ast_node(
            (int)NTS_globdecl,
            $vartype,
            $2,
            0,
            NULL, NULL, NULL, NULL,
            cs
            );
    };
    | vartype IDENT '=' exp ';'                     {
        $$ = new_ast_node(
            (int)NTS_globdecl,
            get_auto_size($vartype, $exp),
            $2,
            0,
            NULL, NULL, NULL, $exp,
            cs
            );
    };
;

/* if: */
/* ; */

switch:
    SWITCH '(' exp ')' '{' switch_body '}'          {

        $$ = new_ast_node(
            (int)NTS_switch,
            0,
            NULL,
            0,
            NULL, NULL, $exp, trace_parent($switch_body),
            cs
            );
    };
;

/*
 * Switch bodys are strange as well: you must 
 *  trace to the parent like statements.
 */
switch_body:
    %empty                                          {
         // Optimize out during semantics
        $$ = NULL;
    };
    | switch_body '@' NUM ':' block                 {

        $$ = new_ast_node(
            (int)NTS_case,
            0,
            NULL,
            $3,
            $1, NULL, NULL, $block,
            cs
            );

        if ($1)
        {
            $1->next = $$;
        }
    
    };
;

while:
    WHILE '(' exp ')' block                         {

        $$ = new_ast_node(
            (int)NTS_while,
            0,
            NULL,
            0,
            NULL, NULL, $exp, $block,
            cs
        );
    };
;

/* for: */
/* ; */

until:
    UNTIL '(' exp ')' block                     {

        $$ = new_ast_node(
            (int)NTS_until,
            0,
            NULL,
            0,
            NULL, NULL, $exp, $block,
            cs
            );
    };
;

/* break: */
/* ; */

/* continue: */
/* ; */


%%

// Additional C source code

/**
 * Trace a node linked list to its head
 * 
 * @param *n A node in a list
 * @return A pointer the list's first (head) node.
 *         returns null if n is null.
 */
static astnode_t *trace_parent(astnode_t *n)
{
    while (n && n->parent)
    {
        n = n->parent;
    }
    return n;
}


/**
 * Get the minimum data type size to hold the value i
 * 
 * @param *cs current parse state
 * @param i The value to fit to a data type
 * @return The minimum data type which can hold the value i
 */
static yytoken_kind_t get_const_size(cstate_t *cs, ival_t i)
{
    // Unsigned
    if (i >= 0)
    {
        if (i <= 255)
        {
            return T_U8;
        }
        else if (i > 255 && i <= 65535)
        {
            return T_U16;
        }
        else if (i > 65535 && i < (uint32_t)(1 << 31))
        {
            return T_U32;
        }
        else
        {
            printf("WARN: unsigned constant '%ld' outside of range. Line: %d\n", i, cs->linenum);
        }
        return T_U32;
    }
    else
    {
        if (i >= -128)
        {
            return T_I8;
        }
        else if (i >= -32768)
        {
            return T_I16;
        }
        else if (i >= -((long)1 << 31))
        {
            return T_I32;
        }
        else
        {
            printf("WARN: signed constant '%ld' outside of range. Line: %d\n", i, cs->linenum);
        }
    }
    return T_I32;
}

static int get_auto_size(yytoken_kind_t t, astnode_t *exp)
{
    if (t != AUTO)
    {
        return t;
    }
    return get_largest_size(exp, NULL);
}

/**
 * Find the largest data type in each sub tree. Does not account for
 * 'auto' or 'void' types.
 * 
 * @param *lexp The left-hand expression
 * @param *rexp The right-hand expression
 * @return The yytoken_kind_t of the largest variable type in either
 *         sub tree.
 */
static int get_largest_size(astnode_t *lexp, astnode_t *rexp)
{
    int left_lar  = T_U8;
    int right_lar = T_U8;
    
    if (lexp)
    {
        if (lexp->lchild && lexp->rchild)
        {
            left_lar = get_largest_size(lexp->lchild, lexp->rchild);
        }
        else
        {
            // Base case - get the type of the leaf
            left_lar = lexp->sec_token_kind;
        }
    }
    
    if (rexp)
    {
        if (rexp->lchild && rexp->rchild)
        {
            right_lar = get_largest_size(rexp->lchild, rexp->rchild);
        }
        else
        {
            // Base case - get the type of the leaf
            right_lar = rexp->sec_token_kind;
        }
    }

    // IF statements used so as not to rely on the ordering
    // of Bison's internal enum (Narf.)
    if (left_lar == T_U8 || left_lar == T_I8)
    {
        return right_lar;
    }
    if (left_lar == T_U32 || left_lar == T_I32)
    {
        return left_lar;
    }
    if (right_lar == T_U8 || right_lar == T_I8)
    {
        return left_lar;
    }
    return right_lar;
}


/**
 * Create a now 'op' type AST node
 * 
 * @param *cs CState of parser
 * @param operator yytoken_kind_t of the operator
 * @param *lexp Left-hand expression
 * @param *rexp Right-hand expression
 * @return A new 'op' AST node
 */
static astnode_t *new_ast_op(cstate_t *cs, ival_t operator, astnode_t *lexp,
                      astnode_t *rexp)
{ 
    return new_ast_node(
        (int)NTS_op,
        get_largest_size(lexp, rexp),
        NULL,
        operator,
        NULL, NULL, lexp, rexp,
        cs
        );
}



/**
 * Print an error message
 */
static int yyreport_syntax_error(const yypcontext_t *ctx,
                                 cstate_t *cs, yyscan_t scanner)
{
    fprintf(stderr, "%s: \x1b[0;91mSYNTAX ERROR\x1b[0m on line %d\n",
            cs->inc_path_buf, cs->linenum);
    fprintf(stderr,
            " > DEBUG: comment-level: %d\n", cs->comment_level);
    fprintf(stderr,
            " > DEBUG: unexpected token: %s\n",
            yysymbol_name(yypcontext_token(ctx)));

    // Try to get 1 expected token
    yysymbol_kind_t toks[1];
    if (!yypcontext_expected_tokens(ctx, toks, 1))
    {
        fprintf(stderr,
                " > DEBUG: expected: %s\n", get_token_name((int)toks[0]));
    }
    return 0;
}


/**
 * Get a string representation of the expected symbol
 * 
 * @param sym The symbol to be "looked up"
 * @return A string of the provided symbol
 */
static const char *get_token_name(yysymbol_kind_t sym)
{
    switch (sym)
    {
    /* case YYSYMBOL_43_: /\* + *\/ */
    /* case YYSYMBOL_45_: /\* - *\/ */
    /* case YYSYMBOL_42_: /\* * *\/ */
    /* case YYSYMBOL_47_: /\* / *\/ */
        /* return "Operator"; */
        /* break; */
    default:
        return yysymbol_name(sym);
    }
}

