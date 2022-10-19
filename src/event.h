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
	unsigned int timeslot;
	
} event_t;

#endif

