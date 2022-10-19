/**
 * VeriFrog language main file header
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#include <stdio.h>
#include <stdlib.h>

#include "verifrog.h"
#include "event.h"
#include "parse.tab.h"
#include "lex.yy.h"

unsigned int linenum = 1;
int comment_level = 0;
event_t *sch_head = NULL;

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
	
    yyparse();

	if ( !sch_head ) {
		printf("No events scheduled!\n");
	} else {
		for (; sch_head; sch_head = sch_head->n) {
			// Go through all events and output them to the file
		}
	}

    exit ( EXIT_SUCCESS );
}

