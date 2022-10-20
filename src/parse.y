%code requires {
#include "event.h"
#include "varvalpair.h"
#include "symbol.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
    
#include "hashtable.h"
#include "verifrog.h"
    // Redundant include for using yytoken_kind_t
#include "parse.tab.h" 

extern void yyerror();
extern int yylex();

static const char *get_token_name(int); // yysymbol_kind_t
static void _schedule_event(varval_t *, int, varval_t *);
%}

// Declarations (Optional type definitions)
// YYSTYPE
%union {
    event_t *event;
    char *str;
    int ival;
    varval_t *vv;
}

// Add args to yyparse and yylex
%define parse.error custom

// Token defs
%token<ival> INUM
%token<str> IDENT
%token<str> VERNUM
%token TICK UNDEF ALWAYS SET EXPECT IMPLIES 
%token EQ NEQ NET

%nterm start
// %nterm condblk
%nterm<vv> varval varvalblk

// Parsing ruleset definitions
%%
start:
    %empty
    {
        printf("Confuzing empty...\n");
        sch_head = NULL;
    };
    | start TICK INUM IDENT
    {

        if (tick_size) {
            printf("WARN: tick size redefined on line %d\n", linenum);
        }
        tick_size = $3;
        tick_units = $4;
    };
    | start NET IDENT INUM
    {
        if (hashtable_contains_skey(sym_table, $3)) {
            printf("WARN: multiple define net: '%s' on line %d [ignoring...]\n",
                   $3, linenum);
        } else {
            symbol_t *s = malloc(sizeof(*s));
            if (!s) {
                printf("ERROR: could not allocate symbol! '%s'\n", $3);
            }

            s->sym = $3;
            s->width = $4;
            hashtable_sput(sym_table, $3, s);
        }
    };
    // | start ALWAYS '{' condblk '}'
      // IMPLIES '{' varvalblk '}'
    // {
        // printf("ALWAYS");
        // _schedule_event($
    // };
    | start SET '{' varvalblk[vvset] '}'
      EXPECT '(' INUM[vvcycle] ')' '{' varvalblk[vvxpt] '}'
    {
        printf("SET\n");
        _schedule_event($vvset, $vvcycle, $vvxpt);
    };
        

// condblk:
// %empty // TODO
    // ;

/* EXPECT BLOCKS are singly-linked lists of var-value pairs */
varvalblk:
    %empty
    {
        $$ = NULL;
    };
    | varvalblk varval
    {
        $$ = $2;
        if ($1) {
            $1->n = $$;
        }
    };
    | varvalblk varval ','
    {
        $$ = $2;
        if ($1) {
            $1->n = $$;
        }
    };

varval:
    IDENT '=' VERNUM
    {
        if (hashtable_contains_skey(sym_table, $1)) {
            $$ = malloc(sizeof(*$$));
            $$->var = $1;
            $$->val = $3;
        } else {
            printf("ERROR: Unknown net '%s' on line %d.\n",
                   $1, linenum);
            yyerror();
        }
    };

%%

/**
 * Print an error message
 */
static int yyreport_syntax_error(const yypcontext_t *ctx) {
    fprintf(stderr, "\x1b[0;91mSYNTAX ERROR\x1b[0m on line %d\n",
            linenum);
    fprintf(stderr,
            " > DEBUG: comment-level: %d\n", comment_level);
    fprintf(stderr,
            " > DEBUG: unexpected token: %s\n",
            yysymbol_name(yypcontext_token(ctx)));

    // Try to get 1 expected token
    yysymbol_kind_t toks[1];
    if (!yypcontext_expected_tokens(ctx, toks, 1)) {
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
static const char *get_token_name(yysymbol_kind_t sym) {
    switch (sym)
    {
    default:
        return yysymbol_name(sym);
    }
}

/**
 * Enter an event into the scheduler's list
 * @param *sets List of var-val pairs of signals to set
 * @param delay Number of cycles for expect block
 * @param *xpcts Var-val pair list
 * @return 
 */
static void _schedule_event(varval_t *sets, int delay, varval_t *xpcts) {
    printf("TODO: schedule tick\n");
}


void yyerror() {
    printf("YYERROR!\n");
    exit(EXIT_FAILURE);
}


