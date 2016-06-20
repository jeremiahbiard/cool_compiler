63:03afdbd66e7929b125f8597834fa83a4
/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

int comment_depth = 0;
%}

/*
 * Define names for regular expressions here.
 */

LINE_COMMENT	"--"
OPEN_COMMENT	"(*"
CLOSE_COMMENT	"*)"

DARROW          =>
LE		<=
ASSIGN		<-

INT		[0-9]+
BFALSE		f(?i:alse)
BTRUE		t(?i:rue)
CLASS		(?i:class)
ELSE		(?i:else)
FI		(?i:fi)
IF		(?i:if)
IN		(?i:in)
INHERITS	(?i:inherits)
LET		(?i:let)
LOOP		(?i:loop)
POOL		(?i:pool)
THEN		(?i:then)
WHILE		(?i:while)
CASE		(?i:case)
ESAC		(?i:esac)
OF		(?i:of)
NEW		(?i:new)
ISVOID		(?i:isvoid)
NOT		(?i:not)
T_ID		[[:upper:]][[:alnum:]_]*
O_ID		[[:lower:]][[:alnum:]_]*
SYMBOL		[~\<=\.:\*/+\-;\,(){}@]
ws		[ \t\f\r\v]+

%x STRING
%x BLOCK_COMMENT
%x NULL_STRING
%x ESC_NULL
%%

 /*
  *  Nested comments
  */

{OPEN_COMMENT} {
	comment_depth = 1;
	BEGIN(BLOCK_COMMENT);
}

<BLOCK_COMMENT>{

.

{OPEN_COMMENT}	comment_depth++; 

{CLOSE_COMMENT} {
			comment_depth--;
			if (comment_depth == 0) {
				BEGIN(INITIAL);
			}
		}

\n	curr_lineno++;

<<EOF>> {
		cool_yylval.error_msg = "no matching closing comment";
		BEGIN(INITIAL);
		return (ERROR);
	}

}

{LINE_COMMENT}	{	// eat single comment lines
	register int c;

	for (;;) {
		while ((c = yyinput()) != '\n' && c != EOF)
			;
		curr_lineno++;
		break;
	}
	
}

{CLOSE_COMMENT} {	// Dangling end comment
	cool_yylval.error_msg = "Unmatched *)";
	return ERROR;
}

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return (DARROW); }
{ASSIGN}		{ return (ASSIGN); }
{LE}			{ return (LE); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{BFALSE}		{ 
				cool_yylval.boolean = false;
				return (BOOL_CONST);
			}

{BTRUE}			{ 
				cool_yylval.boolean = true;
				return (BOOL_CONST); 
			}

{CLASS}			{ return (CLASS); }
{ELSE}			{ return (ELSE); }
{IF}			{ return (IF); }
{FI}			{ return (FI); }
{INHERITS}		{ return (INHERITS); }
{IN}			{ return (IN); }
{LET}			{ return (LET); }
{LOOP}			{ return (LOOP); }
{POOL}			{ return (POOL); }
{THEN}			{ return (THEN); }
{WHILE}			{ return (WHILE); }
{CASE}			{ return (CASE); }
{ESAC}			{ return (ESAC); }
{OF}			{ return (OF); }
{NEW}			{ return (NEW); }
{ISVOID}		{ return (ISVOID); }
{NOT}			{ return (NOT); }

{SYMBOL}		{ return (int) yytext[0]; } 

{T_ID} {
	cool_yylval.symbol = idtable.add_string(yytext);
    	return (TYPEID);
}

{O_ID} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return (OBJECTID);
}

{INT} {
	cool_yylval.symbol = inttable.add_string(yytext);
	return (INT_CONST);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */

\" { string_buf_ptr = string_buf; BEGIN(STRING); }

<STRING>{

\" 	{ /* saw closing quote - all done */
		BEGIN(INITIAL);
        	*string_buf_ptr = '\0';
		if (string_buf_ptr >= string_buf + MAX_STR_CONST) {
        		cool_yylval.error_msg = "String constant too long";
        		return (ERROR);
    		} else {
        		cool_yylval.symbol = stringtable.add_string(string_buf);
        		return (STR_CONST);
		}
        }

\n	{ /* unterminated string constant */
		curr_lineno++;
		cool_yylval.error_msg = "unterminated string constant";
		BEGIN(INITIAL);
		return (ERROR);
	}


\\b  *string_buf_ptr++ = '\b'; 
\\t  *string_buf_ptr++ = '\t'; 
\\n  *string_buf_ptr++ = '\n';
\\f  *string_buf_ptr++ = '\f';
\\\0  BEGIN ESC_NULL; 

<ESC_NULL>{


\"	{
		cool_yylval.error_msg = "String contains escaped null character.";
		return ERROR;
	}

}

	{	/* Null char */
		BEGIN (NULL_STRING);
	}

\\(.|\n) 	{ *string_buf_ptr++ = yytext[1]; }

[^"\\\n]	{
		char *yptr = yytext;

		while (*yptr)
			*string_buf_ptr++ = *yptr++;
		}



<<EOF>>	{ /* EOF in string constant */
		cool_yylval.error_msg = "EOF in string constant";
		BEGIN(INITIAL);
		return ERROR;
	}

}	// End of STRING 

<NULL_STRING>{

\"	{	
		cool_yylval.error_msg = "String contains null character.";
		BEGIN(INITIAL);
    		return (ERROR);
	}

\n	{
		curr_lineno++;
		cool_yylval.error_msg = "String contains null character.";
		BEGIN(INITIAL);
		return (ERROR);
	}

.
		
}

\n	{ curr_lineno++; }

{ws}    // Ignore whitespace



. {
    /* Invalid token */
    cool_yylval.error_msg = yytext;
    return ERROR;
}

%%

