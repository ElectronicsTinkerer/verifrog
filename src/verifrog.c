/**
 * VeriFrog language main file
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
hashtable_t *input_table = NULL;
hashtable_t *output_table = NULL;
hashtable_t *sym_table = NULL;
int table_width = 0;
int current_tick = -1;
int max_tick = 0;
int input_offset = 0;
int output_offset = 0;

char *clock_net = NULL;
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
    hashtable_init(&input_table);
    hashtable_init(&output_table);
    
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

	// TODO: Free symbol table

    exit ( EXIT_SUCCESS );
}


/**
 * Generate the scheduled event table file
 * 
 * @param *of File pointer to output file
 * @return none
 */
static void generate_schedule_file(FILE *of) {

	printf("Tick = %d %s (%s)\n", tick_size, tick_units, clock_net);

	// Buffers for input and output bit vectors
	// Note that the set (input) buffer is not reset
	// after each tick whereas the expect (output)
	// buffer is. This means signals stay at their set
	// values until the programmer says otherwise.
	// Expect values must be explicitly declared in
	// each expect block
	char *input_bv  = malloc((sizeof(*input_bv) * input_offset) + 1);
	char *output_bv = malloc((sizeof(*output_bv) * output_offset) + 1);
	input_bv[input_offset]   = '\0';
	output_bv[output_offset] = '\0';
	
	// Go through all events and output them to the file
	varval_t *v, *vt;
	event_t *et;
	while(sch_head) {
		// Reset the expect vector
		memset(output_bv, (int)'0', output_offset);
		
		printf("SCHED: @ %d ticks\n", sch_head->tick);
		v = sch_head->sets;
		while (v) {
			printf("  S - %s = %s;\n",
				   v->var, v->val);
			symbol_t *s = (symbol_t*)hashtable_sget(sym_table, v->var);
			printf("    --> %d, %d\n", s->offset, s->width);
			// TODO: set the characters in the bit vectors
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

