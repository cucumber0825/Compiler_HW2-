/*	Definition section */
%{
#include"stdio.h"
#include"stdlib.h"
#include"string.h"
#include"declare.h"

FILE *file;

extern int end_flag;
extern int semantic_err;
extern int line_number;
extern int syntax_err;
extern int yylineno;
extern int yylex();
extern char* yytext;   // Get current token from lex
extern char buf[256];  // Get current code line from lex

/* Symbol table function - you can add new function if needed. */
int while_count = 0;
int if_count = 0;
int return_t(char *c);
int return_index(char *c);
int lookup_symbol(char* check);
int global_or_local();
void create_symbol();
void insert_symbol(char *n,int kind,int type_n,int scopp);
void insert_global(char *n,int kind,int type_n,int scopp);
void dump_symbol(int p);
void add_para(int para);
void yyerror(char *s);

struct node *global_head = NULL;
struct node *global_insert = NULL;

struct node *head_ptr = NULL;
struct node *insert_ptr = NULL;
struct node *wait_ptr = NULL;
int level_num = 0;
int global_index = 0;
int indexnum = 0;
int mul_div_flag=0;
%}

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 */

%union {
    struct Value val;
}

/* Token without return */
/* STR is string content , STRING is string type*/
%token PRINT RETURN
%token IF ELSE WHILE
%token ID SEMICOLON
%token LAND LOR
%token VOID INT FLOAT BOOL STRING


/* Token with return, which need to sepcify type */
%token <val> TRUE FALSE
%token <val> I_CONST F_CONST INC DEC
%token <val> STR '+' '-' '*' '/' '%' '='
%token <val> '<' '>' LEQ GEQ EQL NEQ
%token <val> ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN
%token <val> QUO_ASSIGN REM_ASSIGN
/* Nonterminal with return, which need to sepcify type */
%type <val> type ID expression expression_stat add_op mul_op
%type <val> INT FLOAT STRING BOOL VOID constant cmp_op post_op
%type <val> parenthesis_clause postfix_expr or_expr and_expr
%type <val> multiplication_expr addition_expr comparison_expr
%type <val> while_stat if_stat else_if_stat else_stat assign_op
/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%
program
    : program stat 
    | error
    |
;
stat
    : declaration
    | expression_stat
    | compound_stat
    | block_stat 
    | print_func
    | function_stat
    | return_stat
;
declaration
    : type ID '=' expression {
            if( !lookup_symbol($2.id_name) ){
                if(level_num) { //!=0
                    insert_symbol($2.id_name,2,$1.type_num,level_num);
                }else{ //==0
                    insert_global($2.id_name,2,$1.type_num,level_num);
                }
            }else{  //exist
                semantic_err = 1;
                char bb[22] = "Redeclared variable ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
            
            if(level_num == 0){ //global
                fprintf(file,".field public static %s ",$2.id_name);
                switch($1.type_num){
                    case 1:
                        fprintf(file,"I = %d\n",$4.i_val);
                        break;
                    case 2:
                        fprintf(file,"F = %.1f\n",$4.f_val);
                        break;
                    case 3:
                        fprintf(file,"S = %s\n",$4.str_val);
                        break;
                    case 4:
                        fprintf(file,"Z = %d\n",$4.i_val);
                        break;
                }
            }else{ //local
                if(return_t($2.id_name) == 1){
                    fprintf(file,"\tldc %d\n",$4.i_val);
                    fprintf(file,"\tistore %d\n",return_index($2.id_name));
                }else if(return_t($2.id_name) == 2){
                    fprintf(file,"\tldc %f\n",$4.f_val);
                    fprintf(file,"\tfstore %d\n",return_index($2.id_name));
                }
            }
        }
    | type ID SEMICOLON {
            if( !lookup_symbol($2.id_name) ){
                if(level_num) {
                    insert_symbol($2.id_name,2,$1.type_num,level_num);
                }else{ //==0
                    insert_global($2.id_name,2,$1.type_num,level_num);
                }
            }else{ //exist
                semantic_err = 1;
                char bb[22] = "Redeclared variable ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }

            if(level_num == 0){ //global
                fprintf(file,".field public static %s ",$2.id_name);
                switch($1.type_num){
                    case 1:
                        fprintf(file,"I\n");
                        break;
                    case 2:
                        fprintf(file,"F\n");
                        break;
                    case 3:
                        fprintf(file,"S\n");
                        break;
                    case 4:
                        fprintf(file,"Z\n");
                        break;
                }
            }else{ // local
                if(return_t($2.id_name) == 1){
                    fprintf(file,"\tldc 0\n");
                    fprintf(file,"\tistore %d\n",return_index($2.id_name));
                }else if(return_t($2.id_name) == 2){
                    fprintf(file,"\tldc 0.0\n");
                    fprintf(file,"\tfstore %d\n",return_index($2.id_name));
                }
            }
        }
;

function_stat
    : type ID '(' argument ')' block_stat { 
            printf("%d: %s",++line_number,buf);
            if( !lookup_symbol($2.id_name) ){
                if(!level_num){
                    insert_global($2.id_name,3,$1.type_num,0);
                } 
                create_symbol(); 
                dump_symbol(1);
            }else{
                semantic_err = 1;
                char bb[22] = "Redeclared function ";
                strcat(bb,$2.id_name);
                yyerror(bb);  
            }
        }
    | type ID '(' ')' block_stat { 
            printf("%d: %s",++line_number,buf);
            if( !lookup_symbol($2.id_name) ){
                if(!level_num){
                    insert_global($2.id_name,3,$1.type_num,0);
                }
                create_symbol(); 
                dump_symbol(1);
            }else{
                semantic_err = 1;
                char bb[22] = "Redeclared function ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
        }
    | ID '(' argument ')' SEMICOLON {
            if( !lookup_symbol($1.id_name) ){
                semantic_err = 1;
                char bb[22] = "Undeclared function ";
                strcat(bb,$1.id_name);
                yyerror(bb);
            }
        }
    | type ID '(' argument ')' SEMICOLON {
            if( lookup_symbol($2.id_name) ){
                semantic_err = 1;
                char bb[22] = "Redeclared function ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
        }
    | type ID '(' ')' SEMICOLON {
            if( lookup_symbol($2.id_name) ){
                semantic_err = 1;
                char bb[22] = "Redeclared function ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
        }
;

argument
    : type ID ',' argument {
            if( !lookup_symbol($2.id_name) ){
                if(level_num == 0){
                    add_para($1.type_num);
                }
                level_num++; 
                insert_symbol($2.id_name,1,$1.type_num,level_num); 
                level_num--;
            }else{
                semantic_err = 1;
                char bb[22] = "Redeclared variable ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
        }
    | type ID {
            if( !lookup_symbol($2.id_name) ){
                if(level_num == 0){
                    add_para($1.type_num);
                }
                level_num++; 
                insert_symbol($2.id_name,1,$1.type_num,level_num); 
                level_num--;
            }else{
                semantic_err = 1;
                char bb[22] = "Redeclared variable ";
                strcat(bb,$2.id_name);
                yyerror(bb);
            }
        }
    | ID ',' argument {
            if( !lookup_symbol($1.id_name) ){
                semantic_err = 1;
                char bb[22] = "Undeclared variable ";
                strcat(bb,$1.id_name);
                yyerror(bb);
            }
        }
    | ID {
            if( !lookup_symbol($1.id_name) ){
                semantic_err = 1;
                char bb[22] = "Undeclared variable ";
                strcat(bb,$1.id_name);
                yyerror(bb);
            }
        }
    | expression 
    | constant
;

return_stat
    : RETURN return_type SEMICOLON
    | RETURN SEMICOLON
;

return_type
    : ID
    | TRUE
    | FALSE
    | I_CONST
    | F_CONST
    | BOOL
;

type
    : INT { $$ = $1; }
    | FLOAT { $$ = $1; }
    | BOOL { $$ = $1; }
    | STRING { $$ = $1; }
    | VOID { $$ = $1; }
;
compound_stat
    : assign_stat
    | if_stat
    | while_stat
;
assign_stat
    : expression assign_op expression SEMICOLON {
        if( !strcmp($2.id_name,"=") ){
            if( return_t($1.id_name) == $3.type_num){
                if( $3.type_num == 1)
                    fprintf(file,"\tistore %d\n",return_index($1.id_name));
                else if( $3.type_num == 2)
                    fprintf(file,"\tfstore %d\n",return_index($1.id_name));
            }else if( return_t($1.id_name) == 1 && $3.type_num == 2){
                fprintf(file,"\tf2i\n");
                fprintf(file,"\tistore %d\n",return_index($1.id_name));
            }else if( return_t($1.id_name) == 2 && $3.type_num == 1){
                fprintf(file,"\ti2f\n");
                fprintf(file,"\tfstore %d\n",return_index($1.id_name));
            }
        }else{
            char type_buf[5] = "";
            if( !strcmp($2.id_name,"+=") ){
                strcpy(type_buf,"add");
            }else if( !strcmp($2.id_name,"-=") ){    
                strcpy(type_buf,"sub");
            }else if( !strcmp($2.id_name,"*=") ){
                strcpy(type_buf,"mul");
            }else if( !strcmp($2.id_name,"/=") ){
                strcpy(type_buf,"div");
            }else if( !strcmp($2.id_name,"%=") ){
                strcpy(type_buf,"rem");
            }
            // lvalue of operator
            if( global_or_local($1.id_name) == 2 ){ // global
                if( return_t($1.id_name) == 1 ){
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$1.id_name);
                }else if( return_t($1.id_name) == 2 ){
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$1.id_name);
                }
            }else if( global_or_local($1.id_name) == 1 ){  // local
                if( return_t($1.id_name) == 1 ){
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }else if( return_t($1.id_name) == 2 ){
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
            }
            // rvalue of operator
            if( $3.type_num == 5){ // variable
                if( global_or_local($3.id_name) == 2 ){ // global
                    if( return_t($3.id_name) == 1 ){
                        fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$3.id_name);
                    }else if( return_t($3.id_name) == 2 ){
                        fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$3.id_name);
                    }
                }else if( global_or_local($3.id_name) == 1 ){  // local
                    if( return_t($3.id_name) == 1 ){
                        fprintf(file,"\tiload %d\n",return_index($3.id_name));
                    }else if( return_t($3.id_name) == 2 ){
                        fprintf(file,"\tfload %d\n",return_index($3.id_name));
                    }
                }
                if( return_t($1.id_name) == 1){
                    fprintf(file,"\ti%s\n"
                    "\tistore %d\n",type_buf,return_index($1.id_name));
                }else if( return_t($1.id_name) == 2){
                    fprintf(file,"\tf%s\n"
                    "\tfstore %d\n",type_buf,return_index($1.id_name));
                }
            }else if( return_t($1.id_name) == 1){ // int += int
                fprintf(file,"\tldc %d\n",$3.i_val);
                fprintf(file,"\ti%s\n",type_buf);
            }else if( return_t($1.id_name) == 2){ // float += float
                if( !strcmp(type_buf,"rem") ){
                    semantic_err = 1;
                    char bb[22] = "Arithmetic errors.";
                    yyerror(bb);
                }
                fprintf(file,"\tldc %f\n",$3.f_val);
                fprintf(file,"\tf%s\n",type_buf);
            }
        }
    }
;
assign_op
    : '=' { $$ = $1;}
    | ADD_ASSIGN { $$ = $1;}
    | SUB_ASSIGN { $$ = $1;}
    | MUL_ASSIGN { $$ = $1;}
    | QUO_ASSIGN { $$ = $1;}
    | REM_ASSIGN { $$ = $1;}
;
if_stat
    : IF '(' expression ')' {
        if( !strcmp($3.id_name,"<") ){
            fprintf(file,"\tifge LABEL_GE_%d\n",if_count); 
        }else if(!strcmp($3.id_name,">")){
            fprintf(file,"\tifle LABEL_LE_%d\n",if_count);
        }else if(!strcmp($3.id_name,"<=")){  
            fprintf(file,"\tifgt LABEL_GT_%d\n",if_count);
        }else if(!strcmp($3.id_name,">=")){  
            fprintf(file,"\tiflt LABEL_LT_%d\n",if_count);
        }else if(!strcmp($3.id_name,"==")){ 
            fprintf(file,"\tifne LABEL_NE_%d\n",if_count);
        }else if(!strcmp($3.id_name,"!=")){ 
            fprintf(file,"\tifeq LABEL_EQ_%d\n",if_count);
        }
    }
    block_stat{
        fprintf(file,"\tgoto EXIT_%d\n",if_count);
        if( !strcmp($3.id_name,"<") ){
            fprintf(file,"LABEL_GE_%d:\n",if_count); 
        }else if(!strcmp($3.id_name,">")){
            fprintf(file,"LABEL_LE_%d:\n",if_count);
        }else if(!strcmp($3.id_name,"<=")){  
            fprintf(file,"LABEL_GT_%d:\n",if_count);
        }else if(!strcmp($3.id_name,">=")){  
            fprintf(file,"LABEL_LT_%d:\n",if_count);
        }else if(!strcmp($3.id_name,"==")){ 
            fprintf(file,"LABEL_NE_%d:\n",if_count);
        }else if(!strcmp($3.id_name,"!=")){
            fprintf(file,"LABEL_EQ_%d:\n",if_count);
        }
    } 
    else_if_stat else_stat {
        fprintf(file,"EXIT_%d:\n",if_count);
        if_count++;
    }
;

else_if_stat
    : else_if_stat ELSE IF '(' expression ')' {
        if( !strcmp($5.id_name,"<") ){
            fprintf(file,"\tifge LABEL_GE_%d\n",if_count); 
        }else if(!strcmp($5.id_name,">")){
            fprintf(file,"\tifle LABEL_LE_%d\n",if_count);
        }else if(!strcmp($5.id_name,"<=")){  
            fprintf(file,"\tifgt LABEL_GT_%d\n",if_count);
        }else if(!strcmp($5.id_name,">=")){  
            fprintf(file,"\tiflt LABEL_LT_%d\n",if_count);
        }else if(!strcmp($5.id_name,"==")){ 
            fprintf(file,"\tifne LABEL_NE_%d\n",if_count);
        }else if(!strcmp($5.id_name,"!=")){ 
            fprintf(file,"\tifeq LABEL_EQ_%d\n",if_count);
        }
    }
    block_stat {
        fprintf(file,"\tgoto EXIT_%d\n",if_count);
        if( !strcmp($5.id_name,"<") ){
            fprintf(file,"LABEL_GE_%d:\n",if_count); 
        }else if(!strcmp($5.id_name,">")){
            fprintf(file,"LABEL_LE_%d:\n",if_count);
        }else if(!strcmp($5.id_name,"<=")){  
            fprintf(file,"LABEL_GT_%d:\n",if_count);
        }else if(!strcmp($5.id_name,">=")){  
            fprintf(file,"LABEL_LT_%d:\n",if_count);
        }else if(!strcmp($5.id_name,"==")){ 
            fprintf(file,"LABEL_NE_%d:\n",if_count);
        }else if(!strcmp($5.id_name,"!=")){ 
            fprintf(file,"LABEL_EQ_%d:\n",if_count);
        }
    }
    | {}
;
else_stat
    : ELSE block_stat {
        fprintf(file,"\tgoto EXIT_%d\n",if_count);
    }
    | {}
;
while_stat
    : WHILE {
        fprintf(file,"LABEL_BEGIN_%d:\n",while_count);
        } 
        '(' expression ')' {
            if( !strcmp($4.id_name,"<") ){
                fprintf(file,"\tiflt LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }else if(!strcmp($4.id_name,">")){
                fprintf(file,"\tifgt LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }else if(!strcmp($4.id_name,"<=")){  // <=
                fprintf(file,"\tifle LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }else if(!strcmp($4.id_name,">=")){  // >=
                fprintf(file,"\tifge LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }else if(!strcmp($4.id_name,"==")){  // ==
                fprintf(file,"\tifeq LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }else if(!strcmp($4.id_name,"!=")){  // !=
                fprintf(file,"\tifne LABEL_TRUE_%d\n" "\tgoto LABEL_FALSE_%d\n",while_count,while_count);
            }
            fprintf(file,"LABEL_TRUE_%d:\n",while_count);
        }
        block_stat {
            fprintf(file,"\tgoto LABEL_BEGIN_%d\n"
             "LABEL_FALSE_%d:\n"
             "\tgoto EXIT_%d\n"
             "EXIT_%d:\n",while_count,while_count,while_count,while_count);
            while_count++;
        }
;
block_stat
    : lb program rb
;
lb
    : '{' { 
        if(end_flag == 1){
            fprintf(file, ".method public static main([Ljava/lang/String;)V\n"
            ".limit stack 50\n" ".limit locals 50\n");
            end_flag = 0;
        } 
        level_num++;
    }
;
rb
    : '}' {level_num--;}
;
expression_stat
    : expression SEMICOLON { $$ = $1; }
    | SEMICOLON {}
;
expression
    : or_expr { $$ = $1; }
;
constant
    : I_CONST { $$ = $1; }
    | F_CONST { $$ = $1; }
    | '-' F_CONST { $2.f_val *= -1; $$ = $2; }
    | '-' I_CONST { $2.i_val *= -1; $$ = $2; }
    | '"' STR '"' { $$ = $2; }
    | TRUE { $$ = $1; }
    | FALSE { $$ = $1; }
;
parenthesis_clause
    : constant {  $1.id_name = strdup("const"); $$ = $1; }
    | ID {
            if( !lookup_symbol($1.id_name)){
                semantic_err = 1;
                char bb[22] = "Undeclared variable ";
                strcat(bb,$1.id_name);
                yyerror(bb);
            }
            $$ = $1;
        }
    | '(' expression ')' { $$ = $2; }
;
postfix_expr
    : parenthesis_clause { $$ = $1; }
    | parenthesis_clause post_op {
        if(!strcmp($2.id_name,"++")){
            if(return_t($1.id_name) == 1){
                fprintf(file,"\tiload %d\n",return_index($1.id_name));
                fprintf(file,"\tldc 1\n" "\tiadd\n");
                fprintf(file,"\tistore %d\n",return_index($1.id_name));
            }else if(return_t($1.id_name) == 2){
                fprintf(file,"\tfload %d\n",return_index($1.id_name));
                fprintf(file,"\tldc 1\n" "\tfadd\n");
                fprintf(file,"\tfstore %d\n",return_index($1.id_name));
            }
        }else if(!strcmp($2.id_name,"--")){
            if(return_t($1.id_name) == 1){
                fprintf(file,"\tiload %d\n",return_index($1.id_name));
                fprintf(file,"\tldc 1\n" "\tisub\n");
                fprintf(file,"\tistore %d\n",return_index($1.id_name));
            }else if(return_t($1.id_name) == 2){
                fprintf(file,"\tfload %d\n",return_index($1.id_name));
                fprintf(file,"\tldc 1\n" "\tfsub\n");
                fprintf(file,"\tfstore %d\n",return_index($1.id_name));
            }
        }
        
    }
;
post_op
    : INC { $$ = $1; }
    | DEC { $$ = $1; }
;
multiplication_expr
    : postfix_expr { $$ = $1; }
    | multiplication_expr mul_op postfix_expr {
        mul_div_flag = 1;
        int cast_flag = 0;
        printf("tttt is %d %d\n",$1.type_num,$3.type_num);
        printf("id name is %s %s \n",$1.id_name,$3.id_name);
        if($1.type_num == 1 && $3.type_num == 2){  // int float
            cast_flag = 1;
        }else if($1.type_num == 2 && $3.type_num == 1){ // float int
            cast_flag = 2; 
        }else if($1.type_num == 1 && $3.type_num == 1){ // int int
            cast_flag = 3;
        }else if($1.type_num == 2 && $3.type_num == 2){ // float float
            cast_flag = 4;
        }

        if( $1.type_num != 5 && $3.type_num != 5){ // constant and constant
            if( $1.type_num == 1 ){
                fprintf(file,"\tldc %d\n",$1.i_val);
            }else if( $1.type_num == 2){
                fprintf(file,"\tldc %f\n",$1.f_val);
            }
            if(cast_flag == 1)
                fprintf(file,"\ti2f\n");
            if( $3.type_num == 1 ){
                fprintf(file,"\tldc %d\n",$3.i_val);
            }else if( $3.type_num == 2){
                fprintf(file,"\tldc %f\n",$3.f_val);
            }
            if(cast_flag == 2)
                fprintf(file,"\ti2f\n");
        }else if( $1.type_num == 5 && $3.type_num != 5){ // $1 is id , $3 is  constant
            if( return_t($1.id_name) == 1 && $3.type_num == 2){ // $1=i,$3=f
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }
                fprintf(file,"\ti2f\n");
                fprintf(file,"\tldc %f\n",$3.f_val);
                cast_flag = 1;
            }else if( return_t($1.id_name) == 2 && $3.type_num == 1){ // $1=f,$3=i
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
                fprintf(file,"\tldc %d\n",$3.i_val);
                fprintf(file,"\ti2f\n");
                cast_flag = 2;
            }else if(return_t($1.id_name) == 1 && $3.type_num == 1){ // i i
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }
                fprintf(file,"\tldc %d\n",$3.i_val);
                cast_flag = 3;
            }else if(return_t($1.id_name) == 2 && $3.type_num == 2){ // f f
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
                fprintf(file,"\tldc %f\n",$3.f_val);
                cast_flag = 4;
            }
        }else if($3.type_num == 5 && $1.type_num != 5){ // $1 constant,$3 is id
            if( $1.type_num == 1 && return_t($3.id_name) == 2){ // $1=i,$3=f
                fprintf(file,"\tldc %d\n",$1.i_val);
                fprintf(file,"\ti2f\n");
                if(global_or_local($3.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$3.id_name);
                }else if(global_or_local($3.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($3.id_name));
                }
                cast_flag = 1;
            }else if( $1.type_num == 2 && return_t($3.id_name) == 1){ // $1=f,$3=i
                fprintf(file,"\tldc %f\n",$1.f_val);
                if(global_or_local($3.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$3.id_name);
                }else if(global_or_local($3.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($3.id_name));
                }
                fprintf(file,"\ti2f\n");
                cast_flag = 2;
            }else if($1.type_num == 1 && return_t($3.id_name) == 1){ // i i
                fprintf(file,"\tldc %d\n",$1.i_val);
                if(global_or_local($3.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$3.id_name);
                }else if(global_or_local($3.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($3.id_name));
                }
                cast_flag = 3;
            }else if( $1.type_num == 2 && return_t($3.id_name) == 2){ // f f
                fprintf(file,"\tldc %f\n",$1.f_val);
                if(global_or_local($3.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$3.id_name);
                }else if(global_or_local($3.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($3.id_name));
                }
                cast_flag = 4;
            } 
        }else{ // id and id
            if( return_t($1.id_name) == 1 && return_t($3.id_name) == 2){ // $1=i,$3=f
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }
                fprintf(file,"\ti2f\n");
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$3.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($3.id_name));
                }
                cast_flag = 1;
            }else if( return_t($1.id_name) == 2 && return_t($3.id_name) == 1){ // $1=f,$3=i
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$3.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($3.id_name));
                }
                fprintf(file,"\ti2f\n");
                cast_flag = 2;
            }else if(return_t($1.id_name) == 1 && return_t($3.id_name) == 1){ // i i
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s I\n",$3.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tiload %d\n",return_index($3.id_name));
                }
                cast_flag = 3;
            }else if(return_t($1.id_name) == 2 && return_t($3.id_name) == 2){ // f f
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$1.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
                if(global_or_local($1.id_name) == 2 ){ // global
                    fprintf(file,"\tgetstatic compiler_hw3/%s F\n",$3.id_name);
                }else if(global_or_local($1.id_name) == 1){ // local
                    fprintf(file,"\tfload %d\n",return_index($3.id_name));
                }
                cast_flag = 4;
            }
        }
        // recognize operator
        char op_ins[5] = {};
        if( !strcmp($2.id_name,"*") )
            strcpy(op_ins,"mul");
        else if( !strcmp($2.id_name,"/") ){
            strcpy(op_ins,"div");
            if( $3.i_val == 0 || $3.f_val == 0.0){
                semantic_err = 1;
                char bb[22] = "Arithmetic errors.";
                yyerror(bb);
            }
        }else if( !strcmp($2.id_name,"%") ){
            strcpy(op_ins,"rem");
            if( cast_flag == 1 || cast_flag == 2 || cast_flag == 4 ){
                semantic_err = 1;
                char bb[22] = "Arithmetic errors.";
                yyerror(bb);
            }
        }

        if(cast_flag == 1){  // i f
            fprintf(file,"\tf%s\n",op_ins); 
            $3.type_num = 2;
            $$ = $3;
        }else if(cast_flag == 2){ // f i
            fprintf(file,"\tf%s\n",op_ins); 
            $1.type_num = 2;
            $$ = $1;
        }else if(cast_flag == 3){ // i i
            $1.type_num = 1;
            fprintf(file,"\ti%s\n",op_ins); 
            $$ = $1;  // return int
        }else if(cast_flag == 4){ // f f
            $1.type_num = 2;
            fprintf(file,"\tf%s\n",op_ins);
            $$ = $1;
        }
    }
;
mul_op
    : '*' { $$ = $1; }
    | '/' { $$ = $1; }
    | '%' { $$ = $1; }
;
addition_expr
    : multiplication_expr { $$ = $1; }
    | addition_expr add_op multiplication_expr {
        int cast_flag = 0;
        if($1.type_num == 1 && $3.type_num == 2){  // int float
            cast_flag = 1;
        }else if($1.type_num == 2 && $3.type_num == 1){ // float int
            cast_flag = 2; 
        }else if($1.type_num == 1 && $3.type_num == 1){ // int int
            cast_flag = 3;
        }else{ // float float
            cast_flag = 4;
        }

        if( mul_div_flag == 1 ){ // a + b * c
            if(cast_flag == 2){ // f i
                fprintf(file,"\ti2f\n");
            }
            if (global_or_local($1.id_name) == 2){ //global 
                fprintf(file,"\tgetstatic compiler_hw3/%s ",$1.id_name);
                $1.type_num = return_t($1.id_name);
                switch($1.type_num){
                    case 1:
                        fprintf(file,"I\n");
                        break;
                    case 2:
                        fprintf(file,"F\n");
                        break;
                    case 3:
                        fprintf(file,"S\n");
                        break;
                    case 4:
                        fprintf(file,"Z\n");
                        break;
                }
                if(cast_flag == 1  || return_t($1.id_name) == 1){ // i f
                    fprintf(file,"\ti2f\n");
                    if($3.type_num == 1)
                        cast_flag = 3;
                    else if($3.type_num == 2)
                        cast_flag = 1;
                }

            }else if( global_or_local($1.id_name) == 1 ){ //local
                if( return_t($1.id_name) == 1){ //int
                    fprintf(file,"\tiload %d\n",return_index($1.id_name));
                }else if( return_t($1.id_name) == 2){ //float
                    fprintf(file,"\tfload %d\n",return_index($1.id_name));
                }
                if(cast_flag == 1 || return_t($1.id_name) == 1){ 
                    fprintf(file,"\ti2f\n");
                    if($3.type_num == 1)
                        cast_flag = 3;
                    else if($3.type_num == 2)
                        cast_flag = 1;
                }
            }else if( global_or_local($1.id_name) == 0 ){ //constant
                if($1.type_num == 1){
                    fprintf(file,"\tldc %d\n",$1.i_val);
                }else if($1.type_num == 2){
                    fprintf(file,"\tldc %f\n",$1.f_val);
                }
                if(cast_flag == 1){
                    fprintf(file,"\ti2f\n");
                }
            }
        }else{ // mul_div ==0 , a + b
            switch(cast_flag){
                case 1: // i f
                    fprintf(file,"\tldc %f\n",$3.f_val);
                    fprintf(file,"\tldc %d\n",$1.i_val);
                    fprintf(file,"\ti2f\n");
                    break;
                case 2: // f i
                    fprintf(file,"\tldc %d\n",$3.i_val);
                    fprintf(file,"\tldc %f\n",$1.f_val);
                    fprintf(file,"\ti2f\n");
                    break;
                case 3: // i i 
                    fprintf(file,"\tldc %d\n",$3.i_val);
                    fprintf(file,"\tldc %d\n",$1.i_val);
                    break;
                case 4: // there is variable
                    if($1.type_num == 5 && $3.type_num != 5){ // $1 is var ,$3 is constant
                        if($3.type_num == 1){
                            fprintf(file,"\tldc %d\n",$3.i_val);
                            if( return_t($3.id_name) == 2 ){
                                fprintf(file,"\ti2f\n");
                            }
                            if( return_t($1.id_name) == 1 )
                                cast_flag = 3;
                            else if( return_t($1.id_name) == 2 )
                                cast_flag = 2;
                        }else if($3.type_num == 2){
                            fprintf(file,"\tldc %.1f\n",$3.f_val);
                            if( return_t($1.id_name) == 1 )
                                cast_flag = 1;
                            else if( return_t($1.id_name) == 2 )
                                cast_flag = 4;
                        }                 
                        if(global_or_local($1.id_name) == 2){ // global
                            fprintf(file,"\tgetstatic compiler_hw3/%s ",$1.id_name);
                            $1.type_num = return_t($1.id_name);
                            switch($1.type_num){
                                case 1:
                                    fprintf(file,"I\n");
                                    if($3.type_num == 2)
                                        fprintf(file,"\ti2f\n");
                                    break;
                                case 2:
                                    fprintf(file,"F\n");
                                    break;
                                case 3:
                                    fprintf(file,"S\n");
                                    break;
                                case 4:
                                    fprintf(file,"Z\n");
                                    break;
                            }

                        }else if(global_or_local($1.id_name) == 1){  // local
                            if( return_t($1.id_name) == 1){
                                fprintf(file,"\tiload %d\n",return_index($1.id_name));
                                if($3.type_num == 2)
                                    fprintf(file,"\ti2f\n");
                            }else if(return_t($1.id_name) == 2){
                                fprintf(file,"\tfload %d\n",return_index($1.id_name));
                            }
                        }
                    }else if($1.type_num != 5 && $3.type_num == 5){  // $1 is constant , $3 is var
                        if($1.type_num == 1){
                            fprintf(file,"\tldc %d\n",$1.i_val);
                            if( return_t($3.id_name) == 2 )
                                fprintf(file,"\ti2f\n");
                            if( return_t($3.id_name) == 1 )
                                cast_flag = 3;
                            else if( return_t($3.id_name) == 2 )
                                cast_flag = 1;
                        }else if($1.type_num == 2){
                            fprintf(file,"\tldc %.1f\n",$1.f_val);
                            if( return_t($3.id_name) == 1 )
                                cast_flag = 2;
                            else if( return_t($3.id_name) == 2 )
                                cast_flag = 4;
                        }                 
                        if(global_or_local($3.id_name) == 2){ // global
                            fprintf(file,"\tgetstatic compiler_hw3/%s ",$3.id_name);
                            $3.type_num = return_t($3.id_name);
                            switch($3.type_num){
                                case 1:
                                    fprintf(file,"I\n");
                                    if($1.type_num == 2)
                                        fprintf(file,"\ti2f\n");
                                    break;
                                case 2:
                                    fprintf(file,"F\n");
                                    break;
                                case 3:
                                    fprintf(file,"S\n");
                                    break;
                                case 4:
                                    fprintf(file,"Z\n");
                                    break;
                            }

                        }else if(global_or_local($3.id_name) == 1){  // local
                            if( return_t($3.id_name) == 1){
                                fprintf(file,"\tiload %d\n",return_index($3.id_name));
                                if($1.type_num == 2)
                                    fprintf(file,"\ti2f\n");
                            }else if(return_t($3.id_name) == 2){
                                fprintf(file,"\tfload %d\n",return_index($3.id_name));
                            }
                        }
                    }else if($1.type_num == 5 && $3.type_num == 5){  // var + var
                        if(return_t($1.id_name) == 1 && return_t($3.id_name) == 2){  // int float
                            cast_flag = 1;
                        }else if(return_t($1.id_name) == 2 && return_t($3.id_name) == 1){ // float int
                            cast_flag = 2; 
                        }else if(return_t($1.id_name) == 1 && return_t($3.id_name) == 1){ // int int
                            cast_flag = 3;
                        }else if(return_t($1.id_name) == 2 && return_t($3.id_name) == 2){ // float float
                            cast_flag = 4;
                        }
                        if(global_or_local($1.id_name) == 2){ // global
                            fprintf(file,"\tgetstatic compiler_hw3/%s ",$1.id_name);
                            $1.type_num = return_t($1.id_name);
                            switch($1.type_num){
                                case 1:
                                    fprintf(file,"I\n");
                                    if(return_t($3.id_name) == 2)
                                        fprintf(file,"\ti2f\n");
                                    break;
                                case 2:
                                    fprintf(file,"F\n");
                                    break;
                                case 3:
                                    fprintf(file,"S\n");
                                    break;
                                case 4:
                                    fprintf(file,"Z\n");
                                    break;
                            }

                        }else if(global_or_local($1.id_name) == 1){  // local
                            if( return_t($1.id_name) == 1){
                                fprintf(file,"\tiload %d\n",return_index($1.id_name));
                                if(return_t($3.id_name) == 2)
                                    fprintf(file,"\ti2f\n");
                            }else if(return_t($1.id_name) == 2){
                                fprintf(file,"\tfload %d\n",return_index($1.id_name));
                            }
                        }
                        if(global_or_local($3.id_name) == 2){ // global
                            fprintf(file,"\tgetstatic compiler_hw3/%s ",$3.id_name);
                            $3.type_num = return_t($3.id_name);
                            switch($3.type_num){
                                case 1:
                                    fprintf(file,"I\n");
                                    if(return_t($1.id_name) == 2)
                                        fprintf(file,"\ti2f\n");
                                    break;
                                case 2:
                                    fprintf(file,"F\n");
                                    break;
                                case 3:
                                    fprintf(file,"S\n");
                                    break;
                                case 4:
                                    fprintf(file,"Z\n");
                                    break;
                            }

                        }else if(global_or_local($3.id_name) == 1){  // local
                            if( return_t($3.id_name) == 1){
                                fprintf(file,"\tiload %d\n",return_index($3.id_name));
                                if(return_t($1.id_name) == 2)
                                    fprintf(file,"\ti2f\n");
                            }else if(return_t($3.id_name) == 2){
                                fprintf(file,"\tfload %d\n",return_index($3.id_name));
                            }
                        }
                    }
                    break;
            }
        }
        
        char op_ins[5] = {};
        if( !strcmp($2.id_name,"+") )
                strcpy(op_ins,"add");
        else if( !strcmp($2.id_name,"-") )
                strcpy(op_ins,"sub");
        if(cast_flag == 1){  // i f  , and result is f
            fprintf(file,"\tf%s\n",op_ins); 
            $3.type_num = 2; 
            $$ = $3;
        }else if(cast_flag == 2){ // f i , and result is f
            fprintf(file,"\tf%s\n",op_ins);
            $3.type_num = 2;  
            $$ = $1;
        }else if(cast_flag == 3){ // i i , and result is i
            fprintf(file,"\ti%s\n",op_ins); 
            $3.type_num = 1; 
            $$ = $1;  // return int
        }else if(cast_flag == 4){ // f f , and result is f
            fprintf(file,"\tf%s\n",op_ins);
            $3.type_num = 2; 
            $$ = $1;
        }
    }
;
add_op
    : '+' { $$ = $1; }
    | '-' { $$ = $1; }
;
comparison_expr
    : addition_expr { $$ = $1; }
    | comparison_expr cmp_op addition_expr {
        int type_f = 0; // two case are:$1 is int int,$2 is float float
        // load first number 
        if($1.type_num == 5){ // id type
            if(return_t($1.id_name) == 1 ){
                type_f = 1;
                fprintf(file,"\tiload %d\n",return_index($1.id_name));
            }else if(return_t($1.id_name) == 2){
                type_f = 2;
                fprintf(file,"\tfload %d\n",return_index($1.id_name));
            }
        }else if($1.type_num == 1){
            type_f = 1;
            fprintf(file,"\tldc %d\n",$1.i_val);
        }else if($1.type_num == 2){
            type_f = 2;
            fprintf(file,"\tldc %f\n",$1.f_val);
        }
        // load second number
        if($3.type_num == 5){ // id type
            if(return_t($3.id_name) == 1 ){
                fprintf(file,"\tiload %d\n",return_index($3.id_name));
            }else if(return_t($3.id_name) == 2){
                fprintf(file,"\tfload %d\n",return_index($3.id_name));
            }
        }else if($3.type_num == 1){
            fprintf(file,"\tldc %d\n",$3.i_val);
        }else if($3.type_num == 2){
            fprintf(file,"\tldc %f\n",$3.f_val);
        }
        // only i i and f f 
        if(type_f == 1){
            fprintf(file,"\tisub\n");
        }else if(type_f == 2){
            fprintf(file,"\tfsub\n");
        }
        $$ = $2;
    }
;
cmp_op
    : '<' { $$ = $1; }
    | '>' { $$ = $1; }
    | LEQ { $$ = $1; }
    | GEQ { $$ = $1; }
    | EQL { $$ = $1; }
    | NEQ { $$ = $1; }
;
and_expr
    : comparison_expr { $$ = $1; }
    | and_expr LAND comparison_expr
;
or_expr
    : and_expr { $$ = $1; }
    | or_expr LOR and_expr 
;
print_func
    : PRINT '(' ID ')' SEMICOLON {
            if( !lookup_symbol($3.id_name) ){
                semantic_err = 1;
                char bb[22] = "Undeclared variable ";
                strcat(bb,$3.id_name);
                yyerror(bb);
            }
            if( return_t($3.id_name) == 1){
                fprintf(file,"\tiload %d\n",return_index($3.id_name));
            }else if( return_t($3.id_name) == 2){
                fprintf(file,"\tfload %d\n",return_index($3.id_name));
            }else if( return_t($3.id_name) == 3){
                fprintf(file,"\taload %d\n",return_index($3.id_name));
            }
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
                "\tswap\n"
                "\tinvokevirtual java/io/PrintStream/println(");
 
            switch(return_t($3.id_name)){
                    case 1:
                        fprintf(file,"I)V\n");
                        break;
                    case 2:
                        fprintf(file,"F)V\n");
                        break;
                    case 3:
                        fprintf(file,"Ljava/lang/String;)V\n");
                        break;
            }
        }
    | PRINT '(' '"' STR '"' ')' SEMICOLON {
            fprintf(file,"\tldc \"%s\"\n",$4.str_val);
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
            "\tswap\n"
            "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
        }
    | PRINT '(' constant ')' SEMICOLON {
        if($3.type_num == 1){
            fprintf(file,"\tldc %d\n",$3.i_val);
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
            "\tswap\n"
            "\tinvokevirtual java/io/PrintStream/println(I)V\n");
        }else if($3.type_num == 2){
            fprintf(file,"\tldc %.1f\n",$3.f_val);
            fprintf(file, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n"
            "\tswap\n"
            "\tinvokevirtual java/io/PrintStream/println(F)V\n");
        }
    }
;
%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;
    file = fopen("compiler_hw3.j","w");

    fprintf(file,   ".class public compiler_hw3\n"
                    ".super java/lang/Object\n");

    yyparse();
    if( !syntax_err )
	    printf("\nTotal lines: %d \n",yylineno);
    fprintf(file, "\treturn\n" ".end method\n");
    fclose(file);
    return 0;
}

void yyerror(char *s)
{   
    if( semantic_err ) { //occur
        printf("%d: %s",++line_number,buf);
    }
    if( !strcmp(s,"syntax error") ){
        syntax_err = 1;
        printf("%d: %s",yylineno+1,buf);
        char id_buffer[10] = "";
        int ind = 0;
        for(int j = 0;j < strlen(buf);j++){
            if( buf[j] == '(')
                break;
            if( buf[j] != ' ')
                id_buffer[ind++] = buf[j];
        }
        char t[30] = "Undeclared function ";
        strcat(t,id_buffer);
        printf("\n\n|-----------------------------------------------|\n");
        printf("| Error found in line %d: %s\n", ++yylineno, buf);
        printf("| %s", t);
        printf("\n|-----------------------------------------------|\n");
        yylineno--;
    }
    printf("\n\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", ++yylineno, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
    yylineno--;
}

void create_symbol() {
    if(wait_ptr != NULL){
        head_ptr = wait_ptr;
        wait_ptr = NULL;
    }
}
void insert_symbol(char *n,int kind,int type_n,int scopp) {  //var_name,kind,typenum,scopenum
    if(insert_ptr == NULL)
        insert_ptr = (struct node*) malloc(sizeof(struct node));
    insert_ptr->index = indexnum;
    indexnum++;
    insert_ptr->name = n;
    insert_ptr->entry_type = kind;
    insert_ptr->data_type = type_n;
    insert_ptr->s_level = scopp;
    for(int i = 0 ; i < 10 ; i++)
        insert_ptr->parameter[i] = 0;
    if(wait_ptr == NULL)
        wait_ptr = insert_ptr;

    insert_ptr->next = (struct node*) malloc(sizeof(struct node));
    insert_ptr = insert_ptr->next;
}
void insert_global(char *n,int kind,int type_n,int scopp) {
    if(global_head == NULL){
        global_insert = (struct node*) malloc(sizeof(struct node));
        global_head = global_insert;
    }
    global_insert->index = global_index;
    global_index++;
    global_insert->name = n;
    global_insert->entry_type = kind;
    global_insert->data_type = type_n;
    global_insert->s_level = scopp;

    global_insert->next = (struct node*) malloc(sizeof(struct node));
    global_insert = global_insert->next;
}
int return_t(char* c){  //return var type
    int ff = 0;
    struct node *curr;
    curr = wait_ptr;
    while( curr != NULL ){
        if( ff && !curr->index)
            break;
        if( !curr->index ) // ==0
            ff = 1;
        if( !strcmp(c,curr->name) ){
            return curr->data_type;
        }
        curr = curr->next;
    }
    curr = global_head;
    while( curr != NULL ){
        if( !strcmp(c,curr->name) ){
            return curr->data_type;
        }
        if( !curr->next->next )
            return 0;
        else
            curr = curr->next;
    }
    return 0; // mot found
}
int return_index(char* c){
    int ff = 0;
    struct node *curr;
    curr = wait_ptr;
    while( curr != NULL ){
        if( ff && !curr->index)
            break;
        if( !curr->index ) // ==0
            ff = 1;
        if( !strcmp(c,curr->name) ){
            return curr->index;
        }
        curr = curr->next;
    }
    return 100; // not found
}
int global_or_local(char *check){ //if global retrun 2 , local return 1, else 0
    int ff = 0;
    struct node *curr;
    curr = wait_ptr;
    while( curr != NULL ){
        if( ff && !curr->index)
            break;
        if( !curr->index ) // ==0
            ff = 1;
        if( !strcmp(check,curr->name) ){
            return 1;
        }
        //printf("loop1 %d\n",curr->index);
        curr = curr->next;
    }
    curr = global_head;
    while( curr != NULL ){
        if( !strcmp(check,curr->name) ){
            return 2;
        }
        //printf("loop2 %s\n",curr->name);
        if( !curr->next->next )
            return 0;
        else
            curr = curr->next;
    }
    return 0;
}
int lookup_symbol(char *check) {
    int ff = 0;
    struct node *curr;
    curr = wait_ptr;
    while( curr != NULL ){
        if( ff && !curr->index)
            break;
        if( !curr->index ) // ==0
            ff = 1;
        if( !strcmp(check,curr->name) ){
            return 1;
        }
        //printf("loop1 %d\n",curr->index);
        curr = curr->next;
    }
    curr = global_head;
    while( curr != NULL ){
        if( !strcmp(check,curr->name) ){
            return 1;
        }
        //printf("loop2 %s\n",curr->name);
        if( !curr->next->next )
            return 0;
        else
            curr = curr->next;
    }
}
void add_para(int para){
    for(int j = 0 ; j < 10 ; j++){
        if(global_insert->parameter[j] == 0){
            global_insert->parameter[j] = para;
            return;
        }
    }
}
void dump_symbol(int p) {
    if(p == 0){
        printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
    }else{
        printf("\n\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
    }
    struct node *cur_ptr;
    if(p == 0)
        cur_ptr = global_head;
    else if(p == 1)
        cur_ptr = head_ptr;
    char kkk[10] = "";
    char ttt[7] = "";
    char pa[10] = "";

    //up is print table
    while( cur_ptr != NULL) {
        switch(cur_ptr->entry_type){
            case(1):
                strcpy(kkk,"parameter");
                break;
            case(2):
                strcpy(kkk,"variable");
                break;
            case(3):
                strcpy(kkk,"function");
                break;
        }
        switch(cur_ptr->data_type){
            case(0):
                strcpy(ttt,"void");
                break;
            case(1):
                strcpy(ttt,"int");
                break;
            case(2):
                strcpy(ttt,"float");
                break;
            case(3):
                strcpy(ttt,"string");
                break;
            case(4):
                strcpy(ttt,"bool");
                break;
        }
        int flag = 0;
        for(int g=0;g<10;g++){
            if(cur_ptr->parameter[g] != 0){
                if(flag){
                    strcat(pa,", ");
                }
                switch(cur_ptr->parameter[g]){
                    case(1):
                        strcat(pa,"int");
                        break;
                    case(2):
                        strcat(pa,"float");
                        break;
                    case(3):
                        strcat(pa,"string");
                        break;
                    case(4):
                        strcat(pa,"bool");
                        break;
                }
                flag = 1;
            }
        }
        if(cur_ptr->name != NULL){
            
            if( !strlen(pa)){
                printf("%-10d%-10s%-12s%-10s%-10d\n",
                cur_ptr->index, cur_ptr->name,kkk,ttt, 
                cur_ptr->s_level);
            }else{
                printf("%-10d%-10s%-12s%-10s%-10d%-s\n",
                cur_ptr->index, cur_ptr->name,kkk,ttt, 
                cur_ptr->s_level , pa);
                strcpy(pa,"");
            }
        }
        cur_ptr = cur_ptr->next;
    }
    printf("\n");
    // down is clean table
    cur_ptr = head_ptr;
    struct node *temp;
    while( cur_ptr != NULL) {
        temp = cur_ptr;
        cur_ptr = cur_ptr->next;
        free(temp);
    }
    head_ptr = NULL;
    wait_ptr = NULL;
    insert_ptr = NULL;
    indexnum = 0;
}
