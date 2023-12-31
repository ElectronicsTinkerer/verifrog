/**
 * VeriFrog language main file
 * 
 * Zach Baldwin
 * 2022-10-18
 */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "hashtable.h"
#include "literal.h"
#include "verifrog.h"
#include "varvalpair.h"
#include "event.h"
#include "parse.tab.h"
#include "lex.yy.h"

unsigned int linenum = 1;
int comment_level = 0;
event_t *sch_head = NULL;
hashtable_t *input_table = NULL;
hashtable_t *output_table = NULL;
hashtable_t *sym_table = NULL;
int table_width = 0;
int current_tick = -1;
int max_tick = 0;
int input_offset = 0;
int output_offset = 0;
char *module_name = NULL;
literal_t *literals = NULL;

char *clock_net = NULL;
unsigned int tick_size = 0;
char *tick_units = NULL;
int use_clk_port = 0;

extern void yyerror();

static void generate_schedule_file(FILE *);
static void generate_tb_file(FILE *of);

static char *input_file, *dat_file, *tb_file;


int main ( int argc, char *argv[] )
{
    if ( argc < 2 ) {
        printf("ERROR: need an input file\n");
        exit(EXIT_FAILURE);
    }
            
    printf("Input file '%s'\n", argv[1]);

    // Setup input file
    input_file = argv[1];
    yyin = fopen(input_file, "r");

    if (!yyin) {
        printf("ERROR: unable to open input file\n");
        exit(EXIT_FAILURE);
    }

    // Set up symbol table
    hashtable_init(&input_table);
    hashtable_init(&output_table);
    
    yyparse();

    if (!module_name) {
        printf("ERROR: no module defined\n");
        yyerror();
    }
    
    if (!sch_head) {
        printf("No events scheduled!\n");
    } else {

        FILE *of;

        // Generation of event data file
        if (argc >= 3) {
            dat_file = argv[2];
        } else {
            dat_file = "vf.dat";
        }
        
        of = fopen(dat_file, "w");

        if (!of) {
            printf("ERROR: Unable to open output file '%s'\n",
                   dat_file);
            exit(EXIT_FAILURE);
        }

        generate_schedule_file(of);

        fclose(of);

        // Generation of test bench file
        if (argc >= 4) {
            tb_file = argv[3];
        } else {
            tb_file = "tb_vf.v";
        }

        of = fopen(tb_file, "w");

        if (!of) {
            printf("ERROR: Unable to open output file '%s'\n",
                tb_file);
            exit(EXIT_FAILURE);
        }

        generate_tb_file(of);

        fclose(of);
    }

    // Free symbol table
    hashtable_itr_t *i = hashtable_create_iterator(input_table);
    hashtable_entry_t *s;
    
    if (!i) {
        printf("WARN: Unable to create iterator to free input table\n");
        printf("      Leaking memory...\n");
    } else {
        s = hashtable_iterator_next(i);
        while (s) {
            free(((symbol_t*)(s->value))->sym);
            // s is free'd in hash table destroy fn
            s = hashtable_iterator_next(i);
        }
    }

    hashtable_iterator_free(&i);

    i = hashtable_create_iterator(output_table);
    
    if (!i) {
        printf("WARN: Unable to create iterator to free output table\n");
        printf("      Leaking memory...\n");
    } else {
        s = hashtable_iterator_next(i);
        while (s) {
            free(((symbol_t*)(s->value))->sym);
            // s is free'd in hash table destroy fn
            s = hashtable_iterator_next(i);
        }
    }

    hashtable_iterator_free(&i);

    // Free hash tables themselves
    hashtable_destroy(&input_table);
    hashtable_destroy(&output_table);

    exit ( EXIT_SUCCESS );
}


/**
 * Generate the scheduled event table file
 * 
 * @param *of File pointer to output file
 * @return none
 */
static void generate_schedule_file(FILE *of) {

    printf("Tick = %d %s (%s)\n", tick_size, tick_units, clock_net);

    // Buffers for input and output bit vectors
    // Note that the set (input) buffer is not reset
    // after each tick whereas the expect (output)
    // buffer is. This means signals stay at their set
    // values until the programmer says otherwise.
    // Expect values must be explicitly declared in
    // each expect block
    char *input_bv  = malloc((sizeof(*input_bv) * input_offset) + 1);
    char *output_bv = malloc((sizeof(*output_bv) * output_offset) + 1);
    char *output_mask = malloc((sizeof(*output_mask) * output_offset) + 1);
    input_bv[input_offset]   = '\0';
    output_bv[output_offset] = '\0';
    memset(input_bv, '0', input_offset);
    
    // Go through all events and output them to the file
    varval_t *v, *vt;
    event_t *et;
    symbol_t *s;
    int tick = 0;
    while(sch_head) {

        // Reset the expect and mask vectors
        memset(output_bv, '0', output_offset);
        memset(output_mask, '0', output_offset);

        // Needed so that empty ticks still are generated
        if (tick == sch_head->tick) {   
        
            printf("SCHED: @ %d ticks\n", sch_head->tick);
            v = sch_head->sets;
            while (v) {
                printf("  S - %s = %s;\n",
                       v->var, v->val);
                s = (symbol_t*)hashtable_sget(input_table, v->var);
                printf("    --> %d, %d\n", s->offset, s->width);
            
                // Set the characters in the bit vectors
                memcpy(input_bv + input_offset - (s->width + s->offset),
                       v->val, s->width);
            
                // Free the var-val pair and get the next in the list
                vt = v->n;
                varval_destroy(&v);
                v = vt;
            }
            v = sch_head->xpcts;
            while (v) {
                printf("  E - %s = %s;\n",
                       v->var, v->val);
                s = (symbol_t*)hashtable_sget(output_table, v->var);
            
                // Set the characters in the bit vectors
                memcpy(output_bv + output_offset - (s->width + s->offset),
                       v->val, s->width);
            
                // Set the bits in the expect mask
                memset(output_mask + output_offset - (s->width + s->offset),
                       '1', s->width);

                // Free the var-val pair and get the next in the list
                vt = v->n;
                varval_destroy(&v);
                v = vt;
            }

            // Free the event and get the next
            et = sch_head->n;
            event_destroy(&sch_head);
            sch_head = et;
        }
        fprintf(of, "%s_%s_%s\n", output_mask, output_bv, input_bv);

        ++tick;
    }
}



/**
 * Generate the content of the test bench file
 * 
 * @param *of The file to save the test bench to
 * @return none
 */
void generate_tb_file(FILE *of) {

    //////////////////////////
    //      File Header     // 
    //////////////////////////

    char *env_host, *env_arch;
    char *user;
    char *time_str;
    time_t rawtime;
    struct tm *timeinfo;

    // Get some info about the system
    env_host = getenv("HOSTNAME");
    env_arch = getenv("HOSTTYPE");
    user = getenv("USER");

    if (!env_host) {
        // Falback
        env_host = getenv("NAME");
        if (!env_host) {
            env_host = "<unknown>";
        }
    }
    if (!env_arch) {
        // Fallback
        env_arch = getenv("MACHTYPE");
        if (!env_arch) {
            env_arch = "???";
        }
    }
    if (!user) {
        // Fallback
        user = getenv("USERNAME");
        if (!user) {
            user = "<unknown>";
        }
    }
    
    // Get UTC time string
    time(&rawtime);
    timeinfo = gmtime(&rawtime);
    time_str = asctime(timeinfo);

    // Generate the header
    fprintf(of, "\
/**\n\
 * TEST BENCH GENERATED WITH THE VERIFROG TB GENERATOR\n\
 *\n\
 * hostname:          %s (%s)\n\
 * user:              %s\n\
 * run time:          %s\
 *\n\
 * input file:        %s\n\
 * test bench file:   %s\n\
 * data file:         %s\n\
 *\n\
 * module under test: %s\n\
 */\n",
            env_host, env_arch,
            user,
            time_str,
            input_file, tb_file, dat_file,
            module_name
        );

    //////////////////////////
    // Module instantiation // 
    //////////////////////////

    hashtable_itr_t *i;
    hashtable_entry_t *e;
    symbol_t *sym;
    char delim;
    int it_empty = hashtable_is_empty(input_table);
    int ot_empty = hashtable_is_empty(output_table);

    fprintf(of, "`timescale %d%s/%d%s\n",
            tick_size/10,
            tick_units,
            tick_size/100,
            tick_units
        );
    fprintf(of, "module tb_%s();\n", module_name);
    fprintf(of, "    integer __tick;\n");
    fprintf(of, "    integer __dat_file;\n");
    fprintf(of, "    integer __scan_handle;\n");
    fprintf(of, "    integer __error_count;\n");
    fprintf(of, "    reg __vfliclk;\n");
    fprintf(of, "    reg %s;\n", clock_net);
    fprintf(of, "    reg [%d:0] __raw_data;\n",
            input_offset + (2 * output_offset) - 1);
    fprintf(of, "    wire [%d:0] __inputs;\n", input_offset - 1);
    fprintf(of, "    wire [%d:0] __outputs;\n", output_offset - 1);
    fprintf(of, "    assign __inputs = __raw_data[%d:%d];\n",
            input_offset - 1,
            0
        );
    
    // Go through all signals and instantiate them
    // INPUTS
    i = hashtable_create_iterator(input_table);

    if (!i) {
        printf("ERROR: unable to set up input iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;
        fprintf(of, "    wire [%d:0] %s;\n    assign %s = __inputs[%d:%d];\n",
                sym->width - 1,
                sym->sym,
                sym->sym,
                sym->offset + sym->width - 1,
                sym->offset
            );
    }

    hashtable_iterator_free(&i);

    // OUTPUTS
    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;
        fprintf(of, "    wire [%d:0] %s;\n    assign __outputs[%d:%d] = %s;\n",
                sym->width - 1,
                sym->sym,
                sym->offset + sym->width - 1,
                sym->offset,
                sym->sym
            );
    }

    hashtable_iterator_free(&i);


    //////////////////////////
    //  LITERAL INCLUSIONS  // 
    //////////////////////////

    literal_t *l;
    while (literals) {
        l = literals->n;
        fprintf(of, "// LITERAL TEXT BEGIN\n%s\n//LITERAL TEXT END\n",
                literals->text);
        free(literals->text);
        free(literals);
        literals = l;
    }


    //////////////////////////
    //   UNIT UNDER TEST    // 
    //////////////////////////

    // MODULE (UUT)
    fprintf(of, "    %s UUT(\n", module_name);
    
    if (use_clk_port) {
        fprintf(of, "        .%s(%s)%c\n",
                clock_net,
                clock_net,
                (ot_empty && it_empty) ? ' ' : ','
            );
    }
    
    // INPUTS
    i = hashtable_create_iterator(input_table);

    if (!i) {
        printf("ERROR: unable to set up input port iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i) || !ot_empty) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "        .%s(__inputs[%d:%d])%c\n",
                sym->sym,
                sym->offset + sym->width - 1,
                sym->offset,
                delim
            );
    }

    hashtable_iterator_free(&i);

    // OUTPUTS
    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output port iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i)) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "        .%s(%s)%c\n",
                sym->sym,
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);

    // End instantiation
    fprintf(of, "    );\n");


    //////////////////////////
    //     Clock Setup      // 
    //////////////////////////

    fprintf(of,
"\
    initial begin\n\
        __vfliclk <= 1'b0;\n\
        %s <= 1'b0;\n\
        __tick = 0;\n\
        __error_count = 0;\n\
        forever begin\n\
            #%d __vfliclk <= ~__vfliclk;\n\
            #%d %s <= __vfliclk;\n\
            if (__vfliclk == 1'b1) begin\n\
                __tick = __tick + 1;\n\
            end\n\
        end\n\
    end\n\
",
            clock_net,
            tick_size/4,
            tick_size/4,
            clock_net
        );

    //////////////////////////
    //       Stimulus       // 
    //////////////////////////

    fprintf(of,
"\
    initial begin\n\
        __dat_file = $fopen(\"%s\", \"r\");\n\
        if (__dat_file == 0) begin\n\
            $display(\"ERROR: Unable to open stimulus file\");\n\
            $finish();\n\
        end\n\
    end\n\
\n\
    always @(posedge __vfliclk) begin\n\
        __scan_handle = $fscanf(__dat_file, \"%%b\\n\", __raw_data);\n\
\n\
        if ((__raw_data[%d:%d] & __outputs) !== __raw_data[%d:%d]) begin\n\
            __error_count = __error_count + 1;\n\
            $display(\"ERROR: unexpected value! at tick %%0d\", __tick);\n\
            $display(\"\
",
            dat_file,
            input_offset + (output_offset * 2) - 1,
            input_offset + output_offset,
            input_offset + output_offset - 1,
            input_offset
        );

    // Generate "ERROR" status message

    // Message component of message
    i = hashtable_create_iterator(input_table);

    if (!i) {
        printf("ERROR: unable to set up input status iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i) || !ot_empty) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "%s: %%b%c ",
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);

    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output status iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i)) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "%s: %%b%c ",
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);

    // Net component of message
    fprintf(of, "\",\n");
    
    i = hashtable_create_iterator(input_table);

    if (!i) {
        printf("ERROR: unable to set up input net iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i) || !ot_empty) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "                %s%c\n",
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);

    // Outputs
    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output net iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i)) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "                %s%c\n",
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);

    fprintf(of, "            );\n");
    
    //////////////////////////
    //    Expected Values   // 
    //////////////////////////
    
    // Expected values
    fprintf(of, "            $display(\"EXPECTED: ");
    
    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output expected status iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i)) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "%s: %%b%c ",
                sym->sym,
                delim
            );
    }

    hashtable_iterator_free(&i);
    
    fprintf(of, "\",\n");
    
    i = hashtable_create_iterator(output_table);

    if (!i) {
        printf("ERROR: unable to set up output net iterator!\n");
        yyerror();
    }

    while (hashtable_iterator_has_next(i)) {
        e = hashtable_iterator_next(i);
        sym = (symbol_t*)e->value;

        if (hashtable_iterator_has_next(i)) {
            delim = ',';
        } else {
            delim = ' ';
        }
        fprintf(of, "                __raw_data[%d:%d]%c\n",
                input_offset + sym->offset + sym->width - 1,
                input_offset + sym->offset,
                delim
            );
    }

    hashtable_iterator_free(&i);

    // End the stimulus check
    fprintf(of,
"\
            );\n\
            // $stop();\n\
        end\n\
\n\
        if ($feof(__dat_file)) begin\n\
            if (__error_count == 0) begin\n\
                $display(\">>> TESTING COMPLETE - PASS <<<\");\n\
            end\n\
            else begin\n\
                $display(\">>> TESTING COMPLETE - FAIL <<<\");\n\
            end\n\
            $finish();\n\
        end\n\
    end\n\
"
        );

    //////////////////////////
    //       ENDMODULE      // 
    //////////////////////////

    fprintf(of, "endmodule\n");
}

