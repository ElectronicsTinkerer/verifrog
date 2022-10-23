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

static char *_alloc_str();
static unsigned int _parse_bin(char*);
static unsigned int _parse_oct(char*);
static unsigned int _parse_dec(char*);
static unsigned int _parse_hex(char*);
extern void yyerror();

extern YYSTYPE yylval;
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

({DECDIG}|_)+                       { PACC; yylval.ival = _parse_dec(yytext); return INUM; };
{DECDIG}+'(b|o|d|h){HEXDIG}+        { PACC; yylval.str = _alloc_str(); return VERNUM; };
"="                                 { PACC; return yytext[0]; };
":"                                 { PACC; return yytext[0]; };

"=="                                { PACC; return EQ; };
"!="                                { PACC; return NEQ; };
"=>"                                { PACC; return IMPLIES; };

tick                                { PACC; return TICK; };
always                              { PACC; return ALWAYS; };
set                                 { PACC; return SET; };
expect                              { PACC; return EXPECT; };
net                                 { PACC; return NET; };
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

static char *_alloc_str() {
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
    
static unsigned int _parse_bin(char *s) {
    unsigned int i = 0;
    for(;*s != 0; ++s) {
        if (*s != '_') {
            i <<= 1;
            i += (*s) & 0x1;
        }
    }
    return i;
}

static unsigned int _parse_oct(char *s) {
    unsigned int i = 0;
    for(;*s != 0; ++s) {
        if (*s != '_') {
            i <<= 3;
            i += (*s) & 0x7;
        }
    }
    return i;
}

static unsigned int _parse_dec(char *s) {
    unsigned int i = 0;
    for(;*s != 0; ++s) {
        if (*s != '_') {
            i *= 10;
            i += (*s) & 0xf;
        }
    }
    return i;
}

static unsigned int _parse_hex(char *s) {
    unsigned int i = 0;
    char t;
    for(;*s != 0; ++s) {
        if (*s != '_') {
            i <<= 4;
            t = (*s) & 0xf;
            if (*s <= '9') { i += t; }
            else           { i += t + 9; }
        }
    }
    return i;
}



/* ************** PUBLIC FUNCTIONS *************** */

