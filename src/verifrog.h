/**
 * VeriFrog language main file header
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#ifndef VERIFROG_H
#define VERIFROG_H

#include "event.h"

extern unsigned int linenum;
extern int comment_level;
extern event_t *sch_head;

// TB ticks information relative
// to design's clock
extern unsigned int tick_size;
extern char *tick_units;

#endif

