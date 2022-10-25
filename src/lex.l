/** 
 * VeriFrog Lex Definitions
 * Zach Baldwin Fall 2022
 */

%{
#include <stdio.h>
#include <stddef.h>
#include <string.h>

#include "hashtable.h"
#include "event.h"
#include "verifrog.h"
#include "varvalpair.h"
#include "parse.tab.h"

// Pre Action Comment Check
#define PACC { if (comment_level > 0) { YY_BREAK; } }

static int _parse_const(char **, int *);
static char *_alloc_str();
extern void yyerror();

extern YYSTYPE yylval;

int wval; // Used for verilog numeric constant width returning to yyparse()
%}

/* ******************* OPTIONS ******************* */
%option stack
 // %option reentrant
 // %option bison-bridge

/* ***************** DEFINITIONS ***************** */
DECDIG      [0-9]
OCTDIG      [0-7]
BINDIG      [0-1]
HEXDIG      [0-9A-Fa-f]

/* ******************* STATES ******************** */



/* ******************** RULES ******************** */
%%
"/*"                                comment_level += 1;
"*/"                                {
    comment_level -= 1;
    if (comment_level < 0)
    {
        printf("ERROR: unbalanced block comment on line %d", linenum);
        exit(-1);
    }
};
\"[.\n\r]+\"                        { PACC; printf("STRING: %s\n", yytext); };
\/\/.*                              //printf("{COMMENT}");
\n                                  linenum += 1;

";"                                 { PACC; return yytext[0]; };
","                                 { PACC; return yytext[0]; };

"("                                 { PACC; return yytext[0]; };
")"                                 { PACC; return yytext[0]; };

"["                                 { PACC; return yytext[0]; };
"]"                                 { PACC; return yytext[0]; };

"{"                                 { PACC; return yytext[0]; };
"}"                                 { PACC; return yytext[0]; };

({DECDIG}|_)+                       {
    PACC;
    yylval.ival = (unsigned int)strtol(yytext, NULL, 10); // Base 10
    return INUM;
};
{DECDIG}+'(b|B){BINDIG}+        {

    PACC;
    int err = _parse_const(&(yylval.str), &wval);
    if (err == 1) {
        printf("ERROR: constant (%s) is not the correct number of bits on line %d\n",
               yytext, linenum);
        yyerror();
    } else if (err) {
        printf("ERROR: unhandled error from _parse_const()\n");
    }
    
    return VERNUM;
};
{DECDIG}+'(o|O){OCTDIG}+        {

    PACC;
    int err = _parse_const(&(yylval.str), &wval);
    if (err == 1) {
        printf("ERROR: constant (%s) is not the correct number of bits on line %d\n",
               yytext, linenum);
        yyerror();
    } else if (err) {
        printf("ERROR: unhandled error from _parse_const()\n");
    }
    
    return VERNUM;
};
{DECDIG}+'(d|D){DECDIG}+        {

    PACC;
    int err = _parse_const(&(yylval.str), &wval);
    if (err == 1) {
        printf("ERROR: constant (%s) is not the correct number of bits on line %d\n",
               yytext, linenum);
        yyerror();
    } else if (err) {
        printf("ERROR: unhandled error from _parse_const()\n");
    }
    
    return VERNUM;
};
{DECDIG}+'(h|H){HEXDIG}+        {

    PACC;
    int err = _parse_const(&(yylval.str), &wval);
    if (err == 1) {
        printf("ERROR: constant (%s) is not the correct number of bits on line %d\n",
               yytext, linenum);
        yyerror();
    } else if (err) {
        printf("ERROR: unhandled error from _parse_const()\n");
    }
    
    return VERNUM;
};
"="                                 { PACC; return yytext[0]; };
":"                                 { PACC; return yytext[0]; };

"=="                                { PACC; return EQ; };
"!="                                { PACC; return NEQ; };
"=>"                                { PACC; return IMPLIES; };

tick                                { PACC; return TICK; };
always                              { PACC; return ALWAYS; };
set                                 { PACC; return SET; };
expect                              { PACC; return EXPECT; };
input                               { PACC; return INPUT; };
output                              { PACC; return OUTPUT; };
drain                               { PACC; return DRAIN; };
alias                               { PACC; return ALIAS; };
module                              { PACC; return MODULE; };
"@"                                 { PACC; return yytext[0]; };

[A-Za-z_][0-9A-Za-z_]*              {
    
    PACC;
    yylval.str = _alloc_str();
    return IDENT;
};

[ \t]+                              // Eat up whitespace

<INITIAL>.                          {
    PACC;
    printf("Unrecognized character: %s on line %d\n", yytext, linenum);
    return YYUNDEF;
};

%%


/* ***************** SUBROUTINES ***************** */

/**
 * Parse a verilog-like number and return it in ascii
 * string binary form. Reports an ERROR if the length
 * of the value is wider than that which is specified.
 * Assumes that there are no invalid characters in 
 * the input string
 * 
 * @param binstr The string in which to store the
 *               resultant binary conversion
 * @param width The integer in which to store the
 *               prefix width number of the verilog
 *               constant value
 * @return Error code:
 *         0 = Success
 *         1 = Incorrect number of bits specified
 *         3 = Unknown error
 */
static int _parse_const(char **binstr, int *width)
{
    // Get number of bits in number
    long int size, i, j, t;
    char *delim, *p;
    size = strtol(yytext, &delim, 10); // Base 10
    *width = (int) size;
    
    *binstr = malloc((sizeof(*binstr) * size) + 1);

    // Ensure that leading zeros are included
    memset(*binstr, '0', size-1);

    // And that the string is properly terminated
    (*binstr)[size] = '\0';

    // Skip the delimiter and get the number base
    switch (*(++delim)) {
    case 'B':
    case 'b':
        // printf("size: %d, yyleng: %d, delim: %d, yytext: %d, total: %d, delim: %c\n",
               // size, yyleng, delim, yytext, yyleng - (delim - yytext), *delim);
        if (size != yyleng - (delim + 1 - yytext)) {
            return 1;
        }
        strncpy(*binstr, delim+1, size + 1);
        break;

    case 'O':
    case 'o':
        // Go from lsb to msb
        p = yytext + yyleng;
        i = size - 1;
        while (--p != delim) {
            t = (*p) - '0'; // Get raw value
            for (j = 0; j < 3; ++j) {
                if (i < 0 && (t & 0x1)) {
                    return 1;
                } else if (i >= 0) {
                    (*binstr)[i] = '0' | (t & 0x1);
                }
                --i;
                t >>= 1;
            }
        }
        break;

    case 'D':
    case 'd':
        // Dec to bin is hard...
        // Just using a limited-width method for now
        t = strtol(delim+1, NULL, 10);

        if (size > 8 * sizeof(t)) {
            printf("ERROR: Unhandled decimal width. Try using a different number base on line %d\n",
                   linenum);
            return 3;
        }

        i = size - 1;
        // Convert to binary
        for (j = 0; j < 8*sizeof(t); ++j) {
            if (i < 0 && (t & 0x1)) {
                return 1;
            } else if (i >= 0) {
                (*binstr)[i] = '0' | (t & 0x1);
            }
            --i;
            t >>= 1;
        }
        break;

    case 'H':
    case 'h':
        // Go from lsb to msb
        p = yytext + yyleng;
        i = size - 1;
        while (--p != delim) {
            // Get raw value (assumes value is a valid hex
            // char - case insensitive)
            if ((*p) < 'A') {
                t = (*p) - '0';
            } else {
                t = ((*p) & 0x0f) + 9;
            }

            // Convert to binary
            for (j = 0; j < 4; ++j) {
                if (i < 0 && (t & 0x1)) {
                    return 1;
                } else if (i >= 0) {
                    (*binstr)[i] = '0' | (t & 0x1);
                }
                --i;
                t >>= 1;
            }
        }
        break;
        
    default:
        printf("ERROR: Flex is broken!\n");
        return 3;
    }
    
    return 0;
}


/**
 * Malloc & copy yytext
 * 
 * @return Pointer to a heap-allocated copy of yytext
 */
static char *_alloc_str()
{
    // printf("Allocating yytext\n"); // DEBUG
    char *str = malloc(sizeof(*(yylval.str)) * yyleng);
    if (str)
    {
        strcpy(str, yytext);
        // printf("YYTEXT: '%s' STR: '%s'\n", yytext, str); // DEBUG
    }
    else
    {
        printf("Unable to allocate yytext '%s'\n", yytext); // DEBUG
        str = NULL;
    }
    return str;
}


/* ************** PUBLIC FUNCTIONS *************** */

