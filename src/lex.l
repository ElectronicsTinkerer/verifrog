/** 
 * Lake Lex Definitions
 * Zach Baldwin Summer 2022 
 */

%{
#include <stdio.h>
#include <stddef.h>
#include <string.h>

#include "hashtable.h"
#include "cstate.h"
#include "ast.h"
#include "lake.h"
#include "lakeparse.tab.h"

/* #define YY_USER_ACTION { if (yyextra->comment_level > 0) { YY_BREAK; } } */
    
// Pre Action Comment Check
#define PACC { if (yyextra->comment_level > 0) { YY_BREAK; } }
    
ival_t _parse_bin(char*);
ival_t _parse_oct(char*);
ival_t _parse_dec(char*);
ival_t _parse_hex(char*);
%}

/* ******************* OPTIONS ******************* */
%option stack
%option reentrant
%option bison-bridge
%option extra-type="cstate_t*"

/* 
 * Resulting yylex def:
 * int yylex( YYSTYPE * lvalp, yyscan_t scanner );
 */


/* ***************** DEFINITIONS ***************** */
DECDIG      [0-9]
OCTDIG      [0-7]
BINDIG      [0-1]
HEXDIG      [0-9A-Fa-f]

/* ******************* STATES ******************** */
%x INCLUDE
%x STRING

/* ******************** RULES ******************** */
%%
"#include"                          { PACC; yy_push_state(INCLUDE, yyscanner); };

<INITIAL>\"                         { PACC; yy_push_state(STRING, yyscanner); cstate_newStringLiteral(yyextra); };
<STRING>\\\"                        { PACC; cstate_appendString(yyextra, "\\\""); };
<STRING>\r                          // Ignore CR
<STRING>\n                          { PACC; yyextra->linenum += 1; cstate_appendString(yyextra, "\n"); };
<STRING>[^\"]                       { PACC; cstate_appendCharString(yyextra, yytext[0]); };
<STRING>\"                          {
    PACC;

    cstate_appendCharString(yyextra, '\0'); // Terminate string

    yylval->str = malloc(
        sizeof(*(yyextra->str_literal_buf)) * yyextra->str_index);
    
    if (yylval->str)
    {
        strcpy(yylval->str, yyextra->str_literal_buf);
        printf("STR: '%s' STR: '%s'\n",
               yyextra->str_literal_buf, yylval->str); // DEBUG
    }
    else
    {
        printf("ERROR: failed allocation for string literal\n");
        yylval->str = NULL; // redundant?
    }
    
    yy_pop_state(yyscanner);
    
    return STR;
};


<INCLUDE>[ \t\"]+                     // Eat up whitespace
<INCLUDE>[^ \t]+\"                  { // Remainder of line, excluding whitespace, is file name

    PACC;
         
    // Remove the trailing " from the string
    yytext[yyleng-1] = '\0';

    // If not an absolute path then prepend the current include directory
    cstate_pushFile(yyextra);
    cstate_setCurrentFile(yyextra, yytext);
    yyin = fopen(yyextra->inc_path_buf, "r");
    
    if (!yyin)
    {
        printf("ERROR: '%s' could not be found or opened\n",
               yyextra->inc_path_buf);
        exit(1);
    }
    else
    {
        char *path = yyextra->inc_path_buf;
        unsigned long htkey = hashtable_hash_string(path);

        // If the path is already in the HT, just get a pointer to it
        // Otherwise, we need to allocate for a new path.
        if(!(path = hashtable_get(yyextra->ftable, htkey)))
        {
            path = malloc(sizeof(*(yyextra->inc_path_buf))
                          * strlen(yyextra->inc_path_buf));
            if (path == NULL)
            {
                printf("ERROR: failed allocating include path\n");
                exit(1);
            }
            strcpy(path, yyextra->inc_path_buf);
            hashtable_put(yyextra->ftable, htkey, path);
        }
        printf("DEBUG: '%s' opened\n", path);    
        yypush_buffer_state(yy_create_buffer(yyin, YY_BUF_SIZE, yyscanner), yyscanner);
        yy_pop_state(yyscanner);
    }
  }

"/*"                                yyextra->comment_level += 1;
"*/"                                {
    yyextra->comment_level -= 1;
    if (yyextra->comment_level < 0)
    {
        printf("ERROR: unbalanced block comment on line %d", yyextra->linenum);
        exit(-1);
    }
};
\"[.\n\r]+\"                        { PACC; printf("STRING: %s\n", yytext); };
\/\/.*                              //printf("{COMMENT}");
tyydb                               { PACC; printf("TOKEN DEBUG: CL: %d\n", yyextra->comment_level); };
\n                                  yyextra->linenum += 1;

";"                                 { PACC; return yytext[0]; };
","                                 { PACC; return yytext[0]; };

"("                                 { PACC; return yytext[0]; };
")"                                 { PACC; return yytext[0]; };

"["                                 { PACC; return yytext[0]; };
"]"                                 { PACC; return yytext[0]; };

"{"                                 { PACC; return yytext[0]; };
"}"                                 { PACC; return yytext[0]; };

'.'                                 { PACC; yylval->ival = yytext[1]; return NUM; }; // Char literal
\%({BINDIG}|_)+                     { PACC; yylval->ival = _parse_bin(yytext+1); return NUM; };
\&({OCTDIG}|_)+                     { PACC; yylval->ival = _parse_oct(yytext+1); return NUM; };
\$({HEXDIG}|_)+                     { PACC; yylval->ival = _parse_hex(yytext+1); return NUM; };
({DECDIG}|_)+                       { PACC; yylval->ival = _parse_dec(yytext); return NUM; };

"+"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"-"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"*"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"/"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"!"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"~"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"&&"                                { PACC; yylval->ival = LAND; return LAND; };
"&"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"||"                                { PACC; yylval->ival = LOR; return LOR; };
"|"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
"^^"                                { PACC; yylval->ival = LXOR; return LXOR; };
"^"                                 { PACC; yylval->ival = yytext[0]; return yytext[0]; };
">>"                                { PACC; yylval->ival = RSHF; return RSHF; };
">>>"                               { PACC; yylval->ival = ARSHF; return ARSHF; };
"<<"                                { PACC; yylval->ival = LSHF; return LSHF; };

"+="                                { PACC; yylval->ival = ADDASGN; return ADDASGN; };
"-="                                { PACC; yylval->ival = SUBASGN; return SUBASGN; };
"*="                                { PACC; yylval->ival = MULTASGN; return MULTASGN; };
"/="                                { PACC; yylval->ival = DIVASGN; return DIVASGN; };
"&="                                { PACC; yylval->ival = ANDASGN; return ANDASGN; };
"|="                                { PACC; yylval->ival = ORASGN; return ORASGN; };
"^="                                { PACC; yylval->ival = XORASGN; return XORASGN; };
"<<="                               { PACC; yylval->ival = LSHFASGN; return LSHFASGN; };
">>="                               { PACC; yylval->ival = RSHFASGN; return RSHFASGN; };
">>>="                              { PACC; yylval->ival = ARSHFASGN; return ARSHFASGN; };
"="                                 { PACC; return yytext[0]; };
":"                                 { PACC; return yytext[0]; };

"<="                                { PACC; yylval->ival = LE; return LE; };
">="                                { PACC; yylval->ival = GE; return GE; };
"=="                                { PACC; yylval->ival = EQ; return EQ; };
"!="                                { PACC; yylval->ival = NEQ; return NEQ; };
"<"                                 { PACC; yylval->ival = LT; return LT; };
">"                                 { PACC; yylval->ival = GT; return GT; };

func                                { PACC; return FUNC; };
void                                { PACC; return VOID; };
u8                                  { PACC; return T_U8; };
i8                                  { PACC; return T_I8; };
u16                                 { PACC; return T_U16; };
i16                                 { PACC; return T_I16; };
u32                                 { PACC; return T_U32; };
i32                                 { PACC; return T_I32; };
auto                                { PACC; return AUTO; };
 /* dpage                               { PACC; return DPAGE; }; */
 /* stack                               { PACC; return STACK; }; */

 /* flow constructs */

ret                                 { PACC; return RET; };
asm                                 { PACC; return ASM; };
if                                  { PACC; return IF; };
elif                                { PACC; return ELIF; };
else                                { PACC; return ELSE; };
again                               { PACC; return AGAIN; };
until                               { PACC; return UNTIL; };
while                               { PACC; return WHILE; };
for                                 { PACC; return FOR; };
break                               { PACC; return BREAK; };
breakon                             { PACC; return BREAKON; };
switch                              { PACC; return SWITCH; };
"@"                                 { PACC; return yytext[0]; };

[A-Za-z_][0-9A-Za-z_]*              {
    
    PACC;
    printf("Allocating yytext\n"); // DEBUG
    yylval->str = malloc(sizeof(*(yylval->str)) * yyleng);
    if (yylval->str)
    {
        strcpy(yylval->str, yytext);
        printf("YYTEXT: '%s' STR: '%s'\n", yytext, yylval->str); // DEBUG
    }
    else
    {
        yylval->str = NULL;
    }
    return IDENT;
};

<<EOF>>                             {
    yypop_buffer_state(yyscanner);

    printf("DEBUG: '%s' closed\n", yyextra->inc_path_buf);

    // Done if stack empty or no buffer present
    if (cstate_popFile(yyextra) || !YY_CURRENT_BUFFER)
    {
        yyterminate();
    }
};

[ \t]+                              // Eat up whitespace

<INITIAL>.                          {
    PACC;
    printf("Unrecognized character: %s on line %d of %s\n", yytext, yyextra->linenum, yyextra->inc_path_buf);
    return YYUNDEF;
};

%%

/* ***************** SUBROUTINES ***************** */

ival_t _parse_bin(char *s)
{
    ival_t i = 0;
    for(;*s != 0; ++s)
    {
        if (*s != '_')
        {
            i <<= 1;
            i += (*s) & 0x1;
        }
    }
    return i;
}

ival_t _parse_oct(char *s)
{
    ival_t i = 0;
    for(;*s != 0; ++s)
    {
        if (*s != '_')
        {
            i <<= 3;
            i += (*s) & 0x7;
        }
    }
    return i;
}

ival_t _parse_dec(char *s)
{
    ival_t i = 0;
    for(;*s != 0; ++s)
    {
        if (*s != '_')
        {
            i *= 10;
            i += (*s) & 0xf;
        }
    }
    return i;
}

ival_t _parse_hex(char *s)
{
    ival_t i = 0;
    char t;
    for(;*s != 0; ++s)
    {
        if (*s != '_')
        {
            i <<= 4;
            t = (*s) & 0xf;
            if (*s <= '9') { i += t; }
            else           { i += t + 9; }
        }
    }
    return i;
}



/* ************** PUBLIC FUNCTIONS *************** */

