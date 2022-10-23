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
static void _schedule_event(varval_t *, int, int);
static event_t *_get_last_event();
void _insert_xpcts(event_t *, varval_t *);
void _insert_sets(event_t *, varval_t *);
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
%token EQ NEQ NET DRAIN ALIAS

%nterm start
// %nterm condblk
%nterm<vv> varval varvalblk

// Parsing ruleset definitions
%%
start:
    %empty
    {
        printf("DEBUG: Confuzing empty...\n");
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
                yyerror();
            }

            s->sym = $3;
            s->width = $4;
            hashtable_sput(sym_table, $3, s);
        }
    };
    | start ALIAS IDENT[new] IDENT[old]
    {
        if (hashtable_contains_skey(sym_table, $3)) {
            printf("WARN: multiple define net: '%s' on line %d [ignoring...]\n",
                   $3, linenum);
        } else {
            symbol_t *s = (symbol_t*)hashtable_sget(sym_table, $old);
            if (!s) {
                printf("ERROR: Symbol not defined before alias! '%s'\n", $old);
                yyerror();
            }

            hashtable_sput(sym_table, $new, s);
        }
    };
    // | start ALWAYS '{' condblk '}'
      // IMPLIES '{' varvalblk '}'
    // {
        // printf("ALWAYS");
        // _schedule_event($
    // };
    | start SET '{' varvalblk[vvset] '}'
    {
        max_tick = current_tick++;
        printf("SET (%d)\n", current_tick);
        _schedule_event($vvset, current_tick, 1);
    };
    | start EXPECT '(' INUM[vvcycle] ')' '{' varvalblk[vvxpt] '}'
    {
        printf("EXPECT (%d)\n", current_tick + $vvcycle);
        _schedule_event($vvxpt, current_tick + $vvcycle, 0);
    };
    | start DRAIN
    {
        current_tick = _get_last_event()->tick;
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
 * 
 * @param *vvl var-val pair list to add
 * @param tick The scheduler tick of the event to modify
 * @param sched_set 1 = SETs
 *                  0 = EXPECTs
 * @return 
 */
static void _schedule_event(varval_t *vvl, int tick, int sched_set) {

    // Don't schedule NULL events
    if (!vvl) {
        return;
    }
    
    event_t *e;
    event_t *m = NULL;

    for (e = sch_head; e && e->tick < tick; e = e->n) {
        /* SEEK */
    }

    // If an event for this tick does not exist, create a new event
    if (!e || e->tick != tick) {
        m = malloc(sizeof(*m));
        if (!m) {
            printf("ERROR: failed allocating event (sets)\n");
            yyerror();
        }
        m->tick = tick;
        m->p = NULL;
        m->n = NULL;
        m->sets = NULL;
        m->xpcts = NULL;
    }

    // If no events in list, create a new one
    if (!e) {
        printf("INFO: creating new tick (sets)\n");
        if (!sch_head) {
            sch_head = m;
        } else {
            event_t *l = _get_last_event();
            l->n = m;
            m->p = l;
        }
        e = m;
    }
    // Otherwise, insert the event
    else {
        printf("INFO: updating existing tick (sets)\n");
        if (e->tick != tick) { // Implies that e->tick > tick
            if (!e->p) {
                sch_head = m;
            }
                
            // Insert m before e
            m->p = e->p;
            m->n = e;
            e->p = m;
            if (m->p) {
                m->p->n = m;
            }
            e = m;
        }
    }

    // Insert each set into the sets list of the event
    if (sched_set) {
        _insert_sets(e, vvl);
    } else {
        _insert_xpcts(e, vvl);
    }
}



/**
 * Insert all sets from the sets list to the event's sets list
 * 
 * @param *e The event to which esets should be added
 * @param *sets The sets list
 * @return none
 */
void _insert_sets(event_t *e, varval_t *sets) {
    varval_t *i = sets;
    varval_t *j, *p, *q;
    int found = 0;
    while (i) {
        printf("SS: %s\n", i->var);
        for (j = e->sets; j && !found; j = j->n) {
            if (!strcmp(j->var, i->var)) {
                printf("WARN: Multiple values for '%s' at time %d on line %d\n",
                       j->var, e->tick, linenum);
                found = 1;
            }
        }
        if (!found) {
            // Insert at beginning of list
            p = e->sets;
            e->sets = i;
            q = i->n;
            i->n = p;
            i = q;
        } else {
            i = i->n;
        }
        found = 0;
    }
}


/**
 * Insert all xpcts from the xpcts list to the event's xpcts list
 * 
 * @param *e The event to which expcts should be added
 * @param *xpcts The xpcts list
 * @return none
 */
void _insert_xpcts(event_t *e, varval_t *xpcts) {
    varval_t *i = xpcts;
    varval_t *j, *p, *q;
    int found = 0;
    while (i) {
        printf("SS: %s\n", i->var);
        for (j = e->xpcts; j && !found; j = j->n) {
            if (!strcmp(j->var, i->var)) {
                printf("WARN: Multiple values for '%s' at time %d on line %d\n",
                       j->var, e->tick, linenum);
                found = 1;
            }
        }
        if (!found) {
            // Insert at beginning of list
            p = e->xpcts;
            e->xpcts = i;
            q = i->n;
            i->n = p;
            i = q;
        } else {
            i = i->n;
        }
        found = 0;
    }
}
    
event_t *_get_last_event() {
    event_t *i;
    for (i = sch_head; i && i->n; i = i->n) {
        /* SEEK */
    }
    return i;
}

void yyerror() {
    printf("YYERROR!\n");
    exit(EXIT_FAILURE);
}


