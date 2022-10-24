/**
 * VeriFrog language main file header
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#include <stdio.h>
#include <stdlib.h>

#include "hashtable.h"
#include "verifrog.h"
#include "varvalpair.h"
#include "event.h"
#include "parse.tab.h"
#include "lex.yy.h"

unsigned int linenum = 1;
int comment_level = 0;
event_t *sch_head = NULL;
hashtable_t *sym_table = NULL;
int table_width = 0;
int current_tick = -1;
int max_tick = 0;

unsigned int tick_size = 0;
char *tick_units = NULL;


int main ( int argc, char *argv[] ) {

    if ( argc < 2 ) {
        printf ( "ERROR: need an input file\n" );
        exit ( EXIT_FAILURE );
    }
            
    printf ( "Input file '%s'\n", argv[1] );

    // Setup input file
    yyin = fopen ( argv[1], "r" );

    if ( !yyin ) {
        printf("ERROR: unable to open input file\n");
        exit ( EXIT_FAILURE );
    }

    // Set up symbol table
    hashtable_init(&sym_table);
    
    yyparse();

    if ( !sch_head ) {
        printf("No events scheduled!\n");
    } else {

        FILE *of;
        if (argc >= 3) {
            of = fopen(argv[2], "w");
        } else {
            of = fopen("vf.dat", "w");
        }

        if (!of) {
            printf("ERROR: Unable to open output file\n");
            exit(EXIT_FAILURE);
        }

		generate_schedule_file(of);

		fclose(of);
    }

    exit ( EXIT_SUCCESS );
}


/**
 * Generate the scheduled event table file
 * 
 * @param *of File pointer to output file
 * @return none
 */
static void generate_schedule_file(FILE *of) {

	printf("Tick = %d %s\n", tick_size, tick_units);
	
	// Go through all events and output them to the file
	varval_t *v, *vt;
	event_t *et;
	while(sch_head) {
		printf("SCHED: @ %d ticks\n", sch_head->tick);
		v = sch_head->sets;
		while (v) {
			printf("  S - %s = %s;\n",
				   v->var, v->val);
			vt = v->n;
			varval_destroy(&v);
			v = vt;
		}
		v = sch_head->xpcts;
		while (v) {
			printf("  E - %s = %s;\n",
				   v->var, v->val);
			vt = v->n;
			varval_destroy(&v);
			v = vt;
		}
		et = sch_head->n;
		event_destroy(&sch_head);
		sch_head = et;
	}
}

