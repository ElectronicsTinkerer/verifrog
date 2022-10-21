/**
 * VeriFrog event definitions header
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#ifndef VERIFROG_EVENT_H
#define VERIFROG_EVENT_H

typedef struct event_t {
	struct event_t *n;
	struct event_t *p;
	unsigned int tick;
	struct varval_t *sets;
	struct varval_t *xpcts;
} event_t;

#endif

