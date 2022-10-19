/**
 * VeriFrog variable/value pair data structure
 * 
 * Zach Baldwin
 * Fall 2022
 */

#ifndef VERIFROG_VARVALPAIR_H
#define VERIFROG_VARVALPAIR_H

typedef struct varval_t {
	char *var;
	char *val; // Could be a string representing an expression!
	struct varval_t *n;
} varval_t;

#endif

