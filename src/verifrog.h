/**
 * VeriFrog language main file header
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#ifndef VERIFROG_H
#define VERIFROG_H

extern unsigned int linenum;
extern int comment_level;
extern struct event_t *sch_head;
extern hashtable_t *sym_table;
extern int table_width;
extern int current_tick;
extern int max_tick;

// TB ticks information relative
// to design's clock
extern unsigned int tick_size;
extern char *tick_units;


static void generate_schedule_file(FILE *);

#endif

