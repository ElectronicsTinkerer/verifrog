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
extern hashtable_t *input_table;
extern hashtable_t *output_table;
extern hashtable_t *sym_table;
extern int table_width;
extern int current_tick;
extern int max_tick;
extern int input_offset;
extern int output_offset;
extern literal_t *literals;

// Module information
extern char *module_name;

// TB ticks information relative
// to design's clock
extern char *clock_net;
extern unsigned int tick_size;
extern char *tick_units;
extern int use_clk_port;

// Lookup tables


#endif

