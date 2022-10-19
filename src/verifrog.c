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

int main ( int argc, char *argv[] ) {

	if ( argc < 2 ) {
		printf( "ERROR: need an input file\n" );
		exit( EXIT_FAILURE );
	}
			
	printf ( "Input file '%s'\n", argv[1] );

	// Setup input file
	yyin = fopen ( argv[1], "r" );

	yyparse();

	exit ( EXIT_SUCCESS );
}

