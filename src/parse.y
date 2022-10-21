%code requires {
#include "varvalpair.h"
#include "event.h"
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
            $2->n = $1;
        }
    };
    | varvalblk varval ','
    {
        $$ = $2;
        if ($1) {
            $2->n = $1;
        }
    };

varval:
    IDENT '=' VERNUM
    {
        if (hashtable_contains_skey(sym_table, $1)) {
            $$ = malloc(sizeof(*$$));
            $$->var = $1;
            $$->val = $3;
            $$->n = NULL;
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

    // -----------------
    // SCHEDULE THE SETS
    // -----------------
    
    event_t *e;
    for (e = sch_head; e && e->tick >= current_tick; e = e->n) {
        /* SEEK */
    }

    event_t *m;
    // If an event for this tick does not exist, create a new event
    if (!e || e->tick != current_tick) {
        m = malloc(sizeof(*m));
        if (!m) {
            printf("ERROR: failed allocating event (sets)\n");
            yyerror();
        }
    } else {
        m = e;
    }

    // If no events in list, create a new one
    if (!e) {
        printf("INFO: creating new tick (sets)\n");
        sch_head = m;
        m->p = NULL;
        m->n = NULL;
        m->tick = current_tick;
        m->sets = sets;
    }
    // Otherwise, insert the event
    else {
        printf("INFO: updating existing tick (sets)\n");
        m->p = e;
        m->n = e->n;
        e->n = m;

        // Insert each set into the sets list of the existing event
        varval_t *i = sets;
        varval_t *j, *p;
        int found = 0;
        while (i) {
            for (j = e->sets; j && !found; j = j->n) {
                if (strcmp(j->var, i->var)) {
                    printf("WARN: Multiple values for '%s' at time %d on line %d\n",
                           j->var, current_tick, linenum);
                    found = 1;
                }
            }
            if (!found) {
                // Insert at beginning of list
                p = e->sets;
                e->sets = i;
                i->n = p;
            }
            printf("SP: %s\n", i->var);
            i = i->n; 
            found = 0;
        }
    }


    // -----------------
    // SCHEDULE THE EXPECTS
    // -----------------
    
    for (e = sch_head;
         e && e->tick >= current_tick + delay;
         e = e->n) {
        /* SEEK */
    }

    // If an event for this tick does not exist, create a new event
    if (!e || e->tick != current_tick + delay) {
        m = malloc(sizeof(*m));
        if (!m) {
            printf("ERROR: failed allocating event (expects)\n");
            yyerror();
        }
    } else {
        m = e;
    }

    // If no events in list, create a new one
    if (!e) {
        printf("INFO: creating new tick (expects)\n");
        sch_head = m; // TODO: Find end of ll and append this to it
        m->p = NULL;
        m->n = NULL;
        m->tick = current_tick + delay;
        m->xpcts = xpcts;
    }
    // Otherwise, insert the event
    else {
        printf("INFO: updating existing tick (expects)\n");
        m->p = e;
        m->n = e->n;
        e->n = m;

        // Insert each expect into the expects list of the existing event
        varval_t *i = xpcts;
        varval_t *j, *p;
        int found = 0;
        while (i) {
            for (j = e->xpcts; j && !found; j = j->n) {
                if (strcmp(j->var, i->var)) {
                    printf("WARN: Multiple values for '%s' at time %d on line %d\n",
                           j->var, current_tick + delay, linenum);
                    found = 1;
                }
            }
            if (!found) {
                // Insert at beginning of list
                p = e->xpcts;
                e->xpcts = i;
                i->n = p;
            }
            printf("SS: %s\n", i->var);
            i = i->n;
            found = 0;
        }
    }

    ++current_tick;
}


void yyerror() {
    printf("YYERROR!\n");
    exit(EXIT_FAILURE);
}


