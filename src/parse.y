// %code requires {
    // typedef void *yyscan_t;
// }

%{
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
    
#include "hashtable.h"
#include "event.h"
#include "verifrog.h"
    // Redundant include for using yytoken_kind_t
#include "parse.tab.h" 

extern void yyerror();
extern int yylex();

static const char *get_token_name(int); // yysymbol_kind_t
%}

// Declarations (Optional type definitions)
// YYSTYPE
%union {
    event_t *event;
    char *str;
    int ival;
}

// Add args to yyparse and yylex
%define parse.error custom

// Token defs
%token<str> NUM TIME IDENT
%token TICK UNDEF ALWAYS
%token EQ NEQ

%nterm<event>start

// Parsing ruleset definitions
%%
start:
    %empty                                          {
        printf("Confuzing empty...\n");
        $$ = NULL;
    };
    | start TICK NUM TIME                           {

        $$ = malloc(sizeof(*$$));
        if ($1) {
            $1->n = $$;
        }
        // TODO: setup tick var
        $$->p = $1;
    };
    | start ALWAYS {
        printf("ALWAYS");
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


void yyerror() {
    /** dummy */
    printf("YYERROR!\n");
}


