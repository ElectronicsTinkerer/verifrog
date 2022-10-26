/**
 * VeriFrog Literal definition header
 * 
 * Zach Baldwin
 * Fall 2022
 */

#ifndef VERIFROG_LITERAL_H
#define VERIFROG_LITERAL_H

typedef struct literal_t {
	char *text;
    int index;
    struct literal_t *n;
} literal_t;

#endif

