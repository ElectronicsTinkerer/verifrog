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
extern hashtable_t *sym_table;
extern int table_width;

// TB ticks information relative
// to design's clock
extern unsigned int tick_size;
extern char *tick_units;


static void generate_schedule_file(FILE *);

#endif

