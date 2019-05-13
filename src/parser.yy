%language "c++"
%require "3.0"
%defines

%define api.token.constructor
%define api.value.type variant
%define parse.assert

%code requires {
  #include <string>
  #include "parse_tree.h"
  class driver;
}

// The parsing context.
%param { driver& drv }

%locations

%define parse.trace
%define parse.error verbose

%code {
#include "driver.h"
}

%define api.token.prefix {TOK_}
%token
  END  0  "end of file"
  KW_FN   "fn"
  KW_RETURN "return"
  KW_FOR "for"
  KW_IN  "in"
  KW_WHILE "while"
  KW_LOOP "loop"
  KW_IF   "if"
  KW_ELSE  "else"
  KW_VAR   "var"
  KW_VAL  "val"
  LANGLE  "{"
  RANGLE  "}"
  LSQUARE "["
  RSQUARE "]"
  LPAREN  "("
  RPAREN  ")"
  SEMICOLON ";"
  COLON   ":"
  COMMA   ","
  DOT     "."
  REFERRENCE_OP "&"
  UNION_OP      "|"
  EQUAL "="
  QUESTION_MARK "?"
;

%token <std::string> CONST_VAR
%token <std::string> UNARY_BINARY_OP
%token <std::string> UNARY_OP
%token <std::string> BINARY_OP
%token <std::string> ASSIGN_OP
%token <std::string> IDENTIFIER "identifier"
%%
%start module_first;

module_first: module { 
    drv.parse_tree = $1;
};


%type <node_constant> constant;
constant: CONST_VAR { $$.val = $1;};

%type <node_identifier> identifier;
identifier: IDENTIFIER { $$.val = $1;};

%type <node_module> module;
module: %empty { }
      | module block { $1.blocks.push_back($2); $$ = std::move($1); };

%type <node_block> block;
block: functionBlock { $$ = $1;}

%type <node_fun_param> fun_param;
fun_param:
    LPAREN RPAREN{
        $$.empty_flag = true;
    } | 
    product_type{
        $$.empty_flag = false;
        $$.params = $1;
    }

%type <node_function_block> functionBlock;
functionBlock: KW_FN identifier fun_param type LANGLE statement_list RANGLE 
{
    $$ = node_function_block { 
        .fun_name = $2,
        .params = $3,
        .ret_type = *$4.get(),
        .statement_list = std::move(*$6)
    };
}
/*
%type <node_parameters> parameters;
parameters: 
    %empty { $$.params = std::vector<node_var_name_type>();}
    | varNameType { 
        $$.params.push_back($1);
    }
    | parameters COMMA varNameType {
        $$ = std::move($1);
        $$.params.push_back($3);
    };


%type <node_var_name_type> varNameType;
varNameType: identifier COLON type 
{
    $$ = node_var_name_type {
        .name = $1,
        .type = $3
    };
}
*/

%type <node_primary_expr> primaryExpr;
primaryExpr: 
    identifier { $$ = $1; } |
    constant { $$ = $1; } |
    LPAREN expression RPAREN { $$ = $2;};

%type <std::shared_ptr<node_post_expr>> postfixExpr;
postfixExpr:
    primaryExpr {
        auto data = std::make_shared<node_post_expr>();
        data->expr = $1;
        $$ = data;
    } |
    postfixExpr LPAREN expression_list RPAREN {
        auto data = std::make_shared<node_post_expr>();
        data->expr = node_post_call_expr {
            .callable = $1,
            .exp_list = std::move($3)
        };
        $$ = data;
    } |
    postfixExpr DOT identifier {
        auto data = std::make_shared<node_post_expr>();
        data->expr = node_post_dot_expr {
            .obj = $1,
            .attr = $3
        };
        $$ = data; 
    }|
    postfixExpr DOT identifier QUESTION_MARK{
        auto data = std::make_shared<node_post_expr>();
        data->expr = node_post_check_expr {
            .check_lable = $3,
            .check_exp = $1
        };
        $$ = data; 
    };
%type <node_unary_expr> unaryExpr;
unaryExpr: 
    postfixExpr {
        $$.post_expr = $1;
    } |
    UNARY_OP unaryExpr {
        $$ = std::move($2);
        $$.ops.push_back($1);
    } |
    UNARY_BINARY_OP unaryExpr {
        $$ = std::move($2);
        $$.ops.push_back($1);
    }|
    REFERRENCE_OP unaryExpr {
        $$ = std::move($2);
        $$.ops.push_back("*");
    };

%type <node_binary_expr> binaryExpr;
binaryExpr:
    unaryExpr {
        $$.vars.push_back($1);
    } |
    binaryExpr BINARY_OP unaryExpr {
        $$ = std::move($1);
        $$.vars.push_back($3);
        $$.ops.push_back($2);
    } |
    binaryExpr UNARY_BINARY_OP unaryExpr {
        $$ = std::move($1);
        $$.vars.push_back($3);
        $$.ops.push_back($2);
    } |
    binaryExpr REFERRENCE_OP unaryExpr{
        $$ = std::move($1);
        $$.vars.push_back($3);
        $$.ops.push_back("*");
    } |
    binaryExpr UNION_OP unaryExpr{
        $$ = std::move($1);
        $$.vars.push_back($3);
        $$.ops.push_back("|");
    } ;

%type <std::shared_ptr<node_expression>> expression;
expression:
    binaryExpr {
        auto data = std::make_shared<node_expression>();
        data->expr = $1;
        $$ = data;
    } |
    unaryExpr ASSIGN_OP expression {
        auto data = std::make_shared<node_expression>();
        data->expr = node_assign_expr {
            .lval = $1,
            .op = $2,
            .rval = $3
        };
        $$ = data;
    }|
    unaryExpr EQUAL expression {
        auto data = std::make_shared<node_expression>();
        data->expr = node_assign_expr {
            .lval = $1,
            .op = "=",
            .rval = $3
        };
        $$ = data;
    };
%type <node_expression_list> expression_list;
expression_list: 
    %empty {} |
    expression {
        $$.push_back($1);
    } |
    expression_list COMMA expression {
        $$ = std::move($1);
        $$.push_back($3);
    };

%type <node_statement> statement;
statement: 
    expression SEMICOLON {
        $$.statement = *$1;
    }|
    return_statement SEMICOLON{
        $$.statement = $1;
    }|
    for_statement{
        $$.statement = $1;
    }|
    while_statement{
        $$.statement = $1;
    }|
    if_statement{
        $$.statement = $1;
    }|
    var_def_statement SEMICOLON{
        $$.statement = $1;
    }
%type <node_var_def_statement> var_def_statement;
var_def_statement:
    KW_VAR var_list COLON type EQUAL expression
    {
        $$.is_const = false;
        $$.var_list = $2;
        $$.var_type = *$4;
        $$.initial_exp = *$6;
    }|
    KW_VAR var_list EQUAL expression
    {
        $$.is_const = false;
        $$.initial_exp = *$4;
        $$.var_list = $2;
    }|
    KW_VAL var_list EQUAL expression
    {
        $$.is_const = true;
        $$.initial_exp = *$4;
        $$.var_list = $2;
    }|
    KW_VAL var_list COLON type EQUAL expression
    {
        $$.is_const = true;
        $$.var_list = $2;
        $$.var_type = *$4;
        $$.initial_exp = *$6;
    };
%type <std::vector<node_identifier>> var_list;
var_list:
    identifier
    {
        $$ = std::vector<node_identifier>();
        $$.push_back($1);
    }|
    var_list COMMA identifier
    {
        $1.push_back($3);
        $$ = std::move($1);
    } 

%type <node_return_statement> return_statement;
return_statement:
    KW_RETURN expression{
        $$.expr = *$2;
    };
%type <node_for_statement> for_statement;
for_statement:
    KW_FOR identifier KW_IN expression LANGLE statement_list RANGLE
    {
        $$.id = $2;
        $$.for_range = *$4;
        $$.for_statement = *$6;
    };
%type <node_while_statement> while_statement;
while_statement:
    KW_WHILE expression LANGLE statement_list RANGLE
    {
        $$.while_condition = *$2;
        $$.loop_statement = *$4;
    }|
    KW_LOOP LANGLE statement_list RANGLE
    {
        $$.loop_statement = *$3;
    };
%type <node_if_statement> if_statement;
if_statement:
    KW_IF expression LANGLE statement_list RANGLE KW_ELSE LANGLE statement_list RANGLE
    {
        $$.condition = *$2;
        $$.if_statement = *$4;
        $$.else_statement = *$8;
    };
%type <std::shared_ptr<std::vector<node_statement>>> statement_list;
statement_list:
    %empty {$$ = std::make_shared<std::vector<node_statement>>();} |
    statement_list statement { $$ = $1; $$->push_back($2);};

%type <node_product_type> product_type;
product_type:
    LPAREN product_type_tuple RPAREN{
        $$ = $2;
    };
%type <node_product_type> product_type_tuple;
product_type_tuple:
    product_type_tuple COMMA identifier COLON type{
        $1.lables.push_back($3.val);
        $1.element.push_back($5);
        $$ = std::move($1);
    }|
    identifier COLON type{
        $$.lables.push_back($1.val);
        $$.element.push_back($3);
    }|
    product_type_tuple COMMA type{
        $1.lables.push_back("_"+std::to_string($1.lables.size()));
        $1.element.push_back($3);
        $$ = std::move($1);
    }|
    type{
        $$.lables.push_back("_0");
        $$.element.push_back($1);
    };    
%type <node_sum_type> sum_type;
sum_type:
    LPAREN sum_type_tuple RPAREN{
        $$ = std::move($2);
    };
%type <node_sum_type> sum_type_tuple;
sum_type_tuple:
    sum_type_tuple UNION_OP identifier COLON type{
        $$.lables.push_back($3.val);
        $$.element.push_back($5);
    }|
    identifier COLON type{
        $$.lables.push_back($1.val);
        $$.element.push_back($3);
    }|
    sum_type_tuple UNION_OP type{
        $$.lables.push_back("_"+std::to_string($$.lables.size()));
        $$.element.push_back($3);
    }|
    type{
        $$.lables.push_back("_"+std::to_string($$.lables.size()));
        $$.element.push_back($1);
    };
%type <std::shared_ptr<node_type>> type;
type:
    identifier
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = false;
        data->type_val = $1;
        $$ = data;
    }|
    identifier REFERRENCE_OP
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = true;
        data->type_val = $1;
        $$ = data;
    }|
    sum_type
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = false;
        data->type_val = $1;
        $$ = data;
    }|
    sum_type REFERRENCE_OP
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = true;
        data->type_val = $1;
        $$ = data;
    }|
    product_type
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = false;
        data->type_val = $1;
        $$ = data;
    }|
    product_type REFERRENCE_OP
    {
        auto data = std::make_shared<node_type>();
        data->is_ref = true;
        data->type_val = $1;
        $$ = data;
    };


%%

void yy::parser::error (const location_type& l, const std::string& m)
{
    std::cerr << l << ": " << m << '\n';
}
