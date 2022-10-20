/**
 * VeriFrog Symbol definition header
 * 
 * Zach Baldwin
 * Fall 2022
 */

#ifndef VERIFROG_SYMBOL_H
#define VERIFROG_SYMBOL_H

typedef struct symbol_t {
	char *sym;
	int offset; // Bit offset from start of bit vector
	int width;
} symbol_t;

#endif

