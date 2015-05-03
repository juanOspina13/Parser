CREATE OR REPLACE package body SYSTEM.rpn_util2 is
  var_buf varchar2(200);
  acumulador number:=0;
  initial_expression varchar2(200):='';
  tmp_exp varchar2(200);  
  query_vars varchar2(2000);
  nombresito     JO_VARIABLES.nombre%type;
  temporal number:=0;
  str_tmp varchar2(200):='';
  TYPE var IS TABLE OF  JO_VARIABLES%rowtype;
  TYPE array_numeros IS TABLE OF number;
  numeros_temporales array_numeros;
  funciones_variables VAR;
  MI_VAR VAR;
  str_llamado_funciones varchar2(1024); 
   
  c number;
  fdbk PLS_INTEGER;
  OP_MINUS      constant binary_integer := 1; -- -
  OP_PLUS       constant binary_integer := 2; -- +
  OP_MUL        constant binary_integer := 3; -- *
  OP_DIV        constant binary_integer := 4; -- /
  OP_EXP        constant binary_integer := 5; -- ^
  OP_MOD        constant binary_integer := 6; -- %
  OP_EQ         constant binary_integer := 7; -- =
  OP_LT         constant binary_integer := 8; -- <
  OP_GT         constant binary_integer := 9; -- >
  OP_LE         constant binary_integer := 10; -- <=
  OP_GE         constant binary_integer := 11; -- >=
  OP_NE         constant binary_integer := 12; -- !=
  OP_AND        constant binary_integer := 13; -- AND
  OP_OR         constant binary_integer := 14; -- OR
  OP_NOT        constant binary_integer := 15; -- NOT
  OP_UMINUS     constant binary_integer := 16; -- -

  T_LEFT        constant binary_integer := 30; -- (
  T_RIGHT       constant binary_integer := 31; -- )
  T_COMMA       constant binary_integer := 32; -- ,
  T_AT          constant binary_integer := 33; -- @
  T_DOT         constant binary_integer := 34; -- .
  T_EOF         constant binary_integer := -1; -- end-of-file

  T_NUMBER      constant binary_integer := 40;
  T_IDENT       constant binary_integer := 41;
  T_FUNC        constant binary_integer := 42;
  T_PROP        constant binary_integer := 43;
  T_CONST       constant binary_integer := 44;

  c_ora20001    constant varchar2(100) := 'Compilation error at position %d : separator misplaced or parentheses mismatched';
  c_ora20002    constant varchar2(100) := 'Compilation error at position %d : parentheses mismatched';
  c_ora20005    constant varchar2(100) := 'Error at position %d : unexpected symbol ''%s'' instead of ''%s''';
  c_ora20006    constant varchar2(100) := 'Error at position %d : function ''%s'' does not take any argument';
  c_ora20007    constant varchar2(100) := 'Error at position %d : function ''%s'' expects %d argument%s';
  c_ora20008    constant varchar2(100) := 'Error at position %d : unexpected symbol ''%s''';
  c_ora20009    constant varchar2(100) := 'Lexical error at position %d : invalid character ''%s''';
  
  c_pi          constant binary_double := 4*atan(1d);

  type oprec    is record (argc simple_integer := 0, prec simple_integer := 0, assoc simple_integer := 0);
  type opmap    is table of oprec          index by binary_integer;
  type fnmap    is table of simple_integer index by varchar2(30);
  type tmap     is table of varchar2(256)  index by binary_integer;
  
  type keymap   is table of binary_double  index by varchar2(30);
  type stack    is table of binary_double;

  op   opmap;
  fnc  fnmap;
  prop fnmap;
  tm   tmap;

  function initop(p_argc simple_integer, p_prec simple_integer, p_assoc simple_integer) return oprec
  is
    r oprec;
  begin
   DBMS_OUTPUT.ENABLE(1000000);
    r.argc := p_argc;
    r.prec := p_prec;
    r.assoc := p_assoc;
    return r;
  end;

  procedure init is
  CURSOR cu_funciones IS
    SELECT * FROM JO_VARIABLES WHERE VAR_TYPE like 'T_FUNC';  
  begin
    open cu_funciones;
    fetch cu_funciones bulk collect into funciones_variables;
    
    for i in funciones_variables.first .. funciones_variables.last 
    LOOP
        fnc(funciones_variables(i).nombre):=funciones_variables(i).numero_argumentos;
        --dbms_output.put_line('nombre '||funciones_variables(i).nombre||' '|| funciones_variables(i).numero_argumentos);
    END LOOP;
    -- operator argument count, precedence and associativity (0=left, 1=right)
    op(OP_OR)     := initop(2,0,0);
    op(OP_AND)    := initop(2,1,0);
    op(OP_NOT)    := initop(1,2,1);
    op(OP_EQ)     := initop(2,3,0);
    op(OP_LT)     := initop(2,3,0);
    op(OP_LE)     := initop(2,3,0);
    op(OP_GT)     := initop(2,3,0);
    op(OP_GE)     := initop(2,3,0);
    op(OP_NE)     := initop(2,3,0);
    op(OP_PLUS)   := initop(2,4,0);
    op(OP_MINUS)  := initop(2,4,0);
    op(OP_MUL)    := initop(2,5,0);
    op(OP_DIV)    := initop(2,5,0);
    op(OP_MOD)    := initop(2,5,0);
    op(OP_UMINUS) := initop(1,7,1);
    op(OP_EXP)    := initop(2,10,1);
    
    tm(T_LEFT)  := '(';
    tm(T_RIGHT) := ')';
    tm(T_IDENT) := '<identifier>';
    tm(T_DOT)   := '.';
    tm(T_PROP)  := '<property>';
    tm(T_EOF)   := '<eof>';
    
  end ;

  function tokenize (p_expr in varchar2) return st_array deterministic
  is
    
    str    varchar2(4000) := p_expr;
    i      simple_integer := 0;
    pos    simple_integer := 0;
    c      varchar2(1 char);
    token  varchar2(30);
    ttype  binary_integer;
    st     st_array := st_array();
    
    procedure push (p_type in binary_integer, p_token in varchar2, p_position in binary_integer default null) is
    begin
      st.extend;
      st(st.last) := 
           st_token(
             p_type
           , case when p_type = T_NUMBER then to_char(to_number(p_token)) else p_token end
           , case when p_type = T_NUMBER then to_binary_double(p_token) end
           , nvl(p_position, i)
           );
      ttype := p_type;
    end;
    
    function peek return st_token is
    begin
      return st(st.last);
    end;
    
    function getc return varchar2 is
    begin
      i := i + 1;
      return substr(str, i, 1);
    end;
    
    procedure error (p_token in varchar2, p_pos in simple_integer) is
    begin
      raise_application_error(-20100, utl_lms.format_message(c_ora20009, p_pos, p_token));
    end;
    
  begin
   
    c := getc;
    while c is not null loop
      token := null;
      case c
        when ' ' then
          null;
        when chr(9) then
          null;
        when chr(10) then
          null;
        when chr(13) then
          null;
        when '(' then
          push(T_LEFT, c);
        when ')' then
          push(T_RIGHT, c);
        when '+' then
          push(OP_PLUS, c);
        when '*' then
          push(OP_MUL, c);
        when '-' then
          if ttype in (T_IDENT, T_NUMBER, T_RIGHT, T_PROP, T_FUNC) then
            ttype := OP_MINUS;
          else
            ttype := OP_UMINUS;
          end if;
          push(ttype, c);
        when '/' then
          push(OP_DIV, c);
        when '%' then
          push(OP_MOD, c);
        when '^' then
          push(OP_EXP, c);
        when '=' then
          push(OP_EQ, c);
        when ',' then
          push(T_COMMA, c);
          
        when '!' then
          token := c;
          c := getc;
          if c = '=' then
            token := token || c;
            push(OP_NE, token, i-1);
          else 
            error(token, i-1);
          end if;
          
        when '<' then
          token := c;
          ttype := OP_LT;
          pos := i;
          c := getc;
          if c = '=' then
            token := token || c;
            ttype := OP_LE;
            c := getc;
          end if;
          push(ttype, token, pos);
          continue;
          
        when '>' then
          token := c;
          ttype := OP_GT;
          pos := i;
          c := getc;
          if c = '=' then
            token := token || c;
            ttype := OP_GE;
            c := getc;
          end if;
          push(ttype, token, pos);
          continue;
        
        else
         
          case  
          when c between '0' and '9' then
            token := c;
            --ttype := T_NUMBER;
            pos := i;
            c := getc;
            while c between '0' and '9' loop
              token := token || c;
              c := getc;
            end loop;
            if c = '.' then
              token := token || c;
              c := getc;
              while c between '0' and '9' loop
                token := token || c;
                c := getc;
              end loop;
            end if;
            push(T_NUMBER, token, pos);
            continue;

          when c between 'A' and 'Z' then
           
            token := c;
            pos := i;
            c := getc;
            while c between 'A' and 'Z'
               or c between '0' and '9'
               or c = '_' 
            loop
              token := token || c;
              c := getc;
            end loop;
            dbms_output.put_line(token);
            if fnc.exists(token) then
              ttype := T_FUNC;
            elsif prop.exists(token) and peek().type = T_DOT then
              ttype := T_PROP;
            elsif token in ('NULL','PI') then
              ttype := T_CONST;
            else
              ttype := 
                case token
                  when 'AND' then OP_AND
                  when 'OR'  then OP_OR
                  when 'NOT' then OP_NOT
                  else T_IDENT
                end;
            end if;
            
            push(ttype, token, pos);
            continue; 
          
          else
           
            error(c, i);
            
          end case;
          
      end case;
      
      c := getc;
      
    end loop;
    
    return st;
  
  end;


  procedure parse (st in st_array)
  is
    i         simple_integer := 0;
    ttype     binary_integer;
    pos       binary_integer;
    curr      varchar2(30);
    fn_name   varchar2(30);
    token     varchar2(30);
    
    error_message varchar2(2048);
    parse_exception  exception;

    procedure error (msg in varchar2) is
    begin
      error_message := msg;
      raise parse_exception;
    end;

    procedure next_token is
    begin
      if i < st.count then
        i := i + 1;
        ttype := st(i).type;
        token := st(i).strval;
        pos := st(i).position;
      else
        pos := pos + length(token);
        ttype := T_EOF;
        token := tm(T_EOF);
      end if;
    end;

    function accept (t in binary_integer) return boolean is
    begin
      if ttype = t then
        curr := token;
        next_token;
        return true;
      else
        return false;
      end if;
    end;
    
    procedure expect (t in binary_integer) is
    begin
      if not accept(t) then
        -- Error at position %d : unexpected symbol '%s' instead of '%s'
        error(utl_lms.format_message(c_ora20005, pos, token, tm(t)));
      end if;
    end;
    
    procedure expr;
     
    -- boolean_factor ::= expr [ relational_op expr ]
    procedure boolean_factor is
    begin
      expr;
      if ttype in (OP_EQ, OP_NE, OP_LT, OP_LE, OP_GT, OP_GE) then
        next_token;
        expr;
      end if;
    end;

    -- boolean_term ::= boolean_factor { "and" boolean_factor }
    procedure boolean_term is
    begin
      boolean_factor;
      while ttype = OP_AND loop
        next_token;
        boolean_factor;
      end loop;
    end;
    
    -- boolean_expr ::= [ "not" ] boolean_term { "or" boolean_term }
    procedure boolean_expr is
    begin
      if ttype = OP_NOT then
        next_token;
      end if;
      boolean_term;
      while ttype = OP_OR loop
        next_token;
        boolean_term;
      end loop;
    end;
    
    -- expr_list ::= boolean_expr { "," boolean_expr }
    function expr_list return pls_integer is
      cnt simple_integer := 0;
    begin     
      boolean_expr;
      cnt := cnt + 1;
      while ttype = T_COMMA loop
        next_token;
        boolean_expr;
        cnt := cnt + 1;
      end loop;
      return cnt;
    end;

    -- base ::= number | identifier | function [ "(" expr_list ")" ] | "(" boolean_expr ")" | constant | property_expr
    procedure base is
      cnt       pls_integer;
      arg_count pls_integer;
    begin
      if accept(T_NUMBER) then
        null;
      elsif accept(T_IDENT) then
        null;
      elsif accept(T_FUNC) then
        fn_name := curr;
        arg_count := fnc(fn_name);
        
        if arg_count != 0 then
          expect(T_LEFT);
          cnt := expr_list;
          expect(T_RIGHT);          
          if cnt != arg_count then
            -- Error at position %d : function '%s' expects %d argument(s), found %d
            error(utl_lms.format_message(c_ora20007, pos-1, fn_name, arg_count, case when arg_count > 1 then 's' end));
          end if;
          
        elsif accept(T_LEFT) then            
          -- Function '%s' does not take any argument
          error(utl_lms.format_message(c_ora20006, pos, fn_name));
        end if;
          
      elsif accept(T_LEFT) then
        boolean_expr;
        expect(T_RIGHT);
      elsif accept(T_CONST) then 
        null;
      -- property
      /*
      elsif accept(T_AT) then
        expect(T_IDENT);
        expect(T_DOT);
        expect(T_PROP);
        */
      else
        -- Error at position %d : unexpected symbol '%s'
        error(utl_lms.format_message(c_ora20008, pos, token));
      end if;
    end; 

    -- factor ::= base { "^" base }
    procedure factor is
    begin
      base;
      while ttype = OP_EXP 
      loop
        next_token;
        base;
      end loop;
    end;

    -- term ::= factor { ( "*" | "/" | "%" ) factor }
    procedure term is
    begin
      factor;
      while ttype in (OP_MUL, OP_DIV, OP_MOD) 
      loop
        next_token;
        factor;
      end loop;
    end; 
    
    -- expr ::= [ "-" ] term { ( "+" | "-" ) term }
    procedure expr is
    begin
      if ttype = OP_UMINUS then
        next_token;
      end if;
      term;
      while ttype = OP_PLUS or ttype = OP_MINUS loop
        next_token;
        term;
      end loop;
    end;

  begin

    next_token;
    expr;
    expect(T_EOF);
    
  exception
    when parse_exception then
      raise_application_error(-20100, error_message);
  end;


  function compile (p_expr in varchar2, p_options in number default VALIDATE)
  return st_array deterministic
  is
    expr    varchar2(4000) := upper(p_expr);
    

    st      st_stack := st_stack();
    output  st_stack := st_stack();
    token   st_token;
    top     st_token;
    pos     binary_integer;
    
    tlist   st_array := tokenize(expr);

  begin
  initial_expression :=upper(p_expr);
    
 dbms_output.enable;
    if p_options = VALIDATE then
      parse(tlist);
    end if;

    for i in 1 .. tlist.count loop

      token := tlist(i);

      case
        when token.type = T_NUMBER then
        dbms_output.put_line('entro a T_NUMBER');
      
      --  dbms_output.put_line(token.strval||'case T_NUMBER'); 
        output.push(token);
           

        when token.type = T_COMMA then
        dbms_output.put_line('entro a T_COMMA');
      
       -- dbms_output.put_line(token.strval||' case COMMA'); 
           loop
             if st.isEmpty then
               pos := token.position;
               raise_application_error(-20100, utl_lms.format_message(c_ora20001, pos));
             end if;
             top := st.peek;
             exit when top.type = T_LEFT;
             output.push(top);
             st.pop;
           end loop;

        when token.type between OP_MINUS and OP_UMINUS then
        dbms_output.put_line('entro a OP_MINUS');
      
          loop
             exit when st.isEmpty;
             top := st.peek;
             if op.exists(top.type)
                and (
                    ( op(token.type).assoc = 0 and op(token.type).prec <= op(top.type).prec )
                 or op(token.type).prec < op(top.type).prec
                )
             then
               output.push(top);
               st.pop;
             else
               exit;
             end if;
           end loop;

           st.push(token);

        when token.type = T_IDENT then
        dbms_output.put_line('entro a T_IDENT');
      
        query_vars :='SELECT * FROM JO_VARIABLES WHERE NOMBRE like '''||token.strval||'''';
        EXECUTE IMMEDIATE (query_vars) BULK COLLECT INTO MI_VAR; 
        FOR i IN MI_VAR.FIRST .. MI_VAR.LAST LOOP
            IF MI_VAR(I).precedence=0 THEN
                 IF MI_VAR(i).VAR_TYPE='T_NUMBER' THEN
                    token.type:=T_NUMBER; 
                 END IF;
            token.strval:= MI_VAR(i).expression;
            token.numval:= TO_NUMBER(MI_VAR(i).expression);
            output.push(token);
            
            ELSE
                tmp_exp:='('||MI_VAR(I).expression||')';
                initial_expression:=  REPLACE(initial_expression,MI_VAR(I).nombre,tmp_exp);
                  
                  --initial_expression:=  REPLACE(initial_expression,MI_VAR(I).nombre,MI_VAR(I).expression);
                  
                  return compile(initial_expression);
            END IF;
        END LOOP;
        
            
        when token.type = T_FUNC then
        dbms_output.put_line('entro a func');
           if fnc(token.strval) = 0 then
             output.push(token);
           else
             st.push(token);
           end if;

        when token.type = T_LEFT then
        dbms_output.put_line('entro a T_LEFT');
      
        --dbms_output.put_line(token.strval||' case T_LEFT'); 
        

           st.push(token);

        when token.type = T_RIGHT then
        dbms_output.put_line('entro a T_RIGHT');
      
        --put_line(token.strval||' case T_RIGHT'); 
        

          loop
            if st.isEmpty then
               pos := token.position;
               raise_application_error(-20100, utl_lms.format_message(c_ora20002, pos));
            end if;
            top := st.peek;
            exit when top.type = T_LEFT;
            output.push(top);
            st.pop;
          end loop;

          st.pop;

          if not(st.isEmpty) then
            top := st.peek;

            if top.type = T_FUNC then
              output.push(top);
              st.pop;
            end if;
          end if;
          
        when token.type = T_CONST then
         dbms_output.put_line('entro a T_CONST');
      
          output.push(token);
          
        when token.type = T_PROP then
         dbms_output.put_line('entro a T_PROP');
      
          output.push(token);

        else
          null;

      end case;

    end loop;

    loop
      exit when st.isEmpty;
      top := st.peek;
      if top.type = T_LEFT then
        pos := top.position;
        raise_application_error(-20100, utl_lms.format_message(c_ora20002, pos));
      end if;
      output.push(top);
      st.pop;
    end loop;
    return output.tlist;

  end;


  function eval (
    tlist in st_array
  , vars in kv_table default kv_table()
  , ctx_dt in date default null
  , flag in number default NULL_INF_OR_NAN
  )
  return binary_double 
  deterministic
  is
    r     stack := stack();
    i     binary_integer := 0;
    j     binary_integer := 0;

    v     keymap;

    token st_token;
    opcnt binary_integer := 0;
    tmp   binary_double := 0;

  begin
    
    while i < tlist.count loop

      i := i + 1;

      token := tlist(i);

      if token.type = T_IDENT then
       dbms_output.put_line('entro a T_IDENT');
        
        r.extend;
        j := j + 1;
        tmp := v(token.strval);
        
      elsif token.type = T_NUMBER then
      dbms_output.put_line('entro a T_NUMBER');
       
        r.extend;
        j := j + 1;
        tmp := token.numval;
        
      elsif token.type = T_CONST then 
        dbms_output.put_line('entro a T_CONST');
       
        r.extend;
        j := j + 1;

        case token.strval
          when 'NULL' then
            tmp := null;
          when 'PI' then
            tmp := c_pi;
        end case;       
        
      elsif token.type = T_FUNC then
      dbms_output.put_line(token.strval||' entro a T_FUNC');
        for i in funciones_variables.first .. funciones_variables.last LOOP 
        dbms_output.put_line('LOOP'||funciones_variables(i).nombre);
            if token.strval=funciones_variables(i).nombre THEN
                dbms_output.put_line('existe la funcion'||token.strval||' '||funciones_variables(i).numero_argumentos);
                str_llamado_funciones:=token.strval||'(';
                for k in 1..funciones_variables(i).numero_argumentos LOOP
                    --numeros_temporales(j):=js;
                    acumulador:=TO_NUMBER(k);
                    if acumulador>0 then
                        --dbms_output.put_line('acum=>'||acumulador||' value=>'||r(acumulador));
 
                        if acumulador=1 then
                            --dbms_output.put_line('se supone que es '||SUBSTR(r(acumulador), 0, 1));
                            str_llamado_funciones:=str_llamado_funciones||SUBSTR(r(acumulador), 0, 1)||',';
                        else
                        --dbms_output.put_line('se supone que es '||SUBSTR(r(acumulador), 0, 1));
                            
                            str_llamado_funciones:=str_llamado_funciones||SUBSTR(r(acumulador), 0, 1);

                        end if;                    
                        
                    --elseif acumulador=0 then
                     --   dbms_output.put_line(r(acumulador));
                    end if;
                  --  dbms_output.put_line('num_temp'||acumulador||' j vale=>'||j);
                END LOOP;
                str_llamado_funciones:=str_llamado_funciones||')';
            END IF; ---:=funciones_variables(i).numero_argumentos;
          --  tmp := JUAN(r(j-1), r(j));
        END LOOP;
        dbms_output.put_line(str_llamado_funciones);
        EXECUTE IMMEDIATE 'SELECT '||str_llamado_funciones||' FROM dual' into tmp;
         dbms_output.put_line(tmp);
         
       -- tmp := JUAN(r(j-1), r(j));
        /*case token.strval
        
          when 'JUAN' then
          tmp := JUAN(r(j-1), r(j));
           when 'IF' then
            tmp := case when r(j-2) = 1 then r(j-1) else r(j) end;
          when 'ISNULL' then
            tmp := case when r(j) is null then 1 else 0 end;
          when 'NULLIF' then
            tmp := nullif(r(j-1), r(j));
          when 'IFNULL' then
            tmp := nvl(r(j-1), r(j));
          when 'ABS' then
            tmp := abs(r(j));
          when 'MAX' then
            tmp := greatest(r(j-1), r(j));
          when 'MIN' then
            tmp := least(r(j-1), r(j));
          when 'COS' then
            tmp := cos(r(j));
          when 'SIN' then
            tmp := sin(r(j));
          when 'TAN' then
            tmp := tan(r(j));
          when 'SQRT' then
            tmp := sqrt(r(j));
          when 'EXP' then
            tmp := exp(r(j));
          when 'LN' then
            tmp := ln(r(j));
          when 'LOG' then
            tmp := log(r(j-1), r(j));
          when 'CEIL' then
            tmp := ceil(r(j));
          when 'FLOOR' then
            tmp := floor(r(j));
          when 'ROUND' then
            tmp := round(r(j-1), r(j));
          -- date & time functions
          when 'FHOUR' then
            tmp := to_binary_double(to_char(ctx_dt, 'HH24'));
          when 'FWEEKDAY' then
            tmp := to_binary_double(to_char(ctx_dt, 'D'));
          when 'FDAY' then
            tmp := to_binary_double(to_char(ctx_dt, 'DD'));
          when 'FMONTH' then
            tmp := to_binary_double(to_char(ctx_dt, 'MM'));
          when 'FYEAR' then
            tmp := to_binary_double(to_char(ctx_dt, 'YYYY'));
          when 'FYEARDAY' then
            tmp := to_binary_double(to_char(ctx_dt, 'DDD'));
          when 'FHOURBETWEEN' then
            tmp := case when r(j-1) <= r(j) then 
                     case when to_number(to_char(ctx_dt, 'HH24')) between r(j-1) and r(j) then 1 else 0 end
                   else
                     case when to_number(to_char(ctx_dt, 'HH24')) >= r(j-1) 
                            or to_number(to_char(ctx_dt, 'HH24')) <= r(j)
                       then 1 
                       else 0 
                     end
                   end;

          -- add new operator/function implementation here
          --when '<FOO>' then
          --  tmp := foo(r(j-1), ..., r(j)) ;
          
        end case;
        */
        opcnt := fnc(token.strval)-1;

        if opcnt = -1 then
          r.extend;
          j := j + 1;
        else
          r.trim(opcnt);
          j := j - opcnt;
        end if;
             
      else
      -- Operators
      
        case token.type
          when OP_PLUS then
            tmp := r(j-1) + r(j);
          when OP_MINUS then
            tmp := r(j-1) - r(j);
          when OP_MUL then
            tmp := r(j-1) * r(j);
          when OP_DIV then
            tmp := r(j-1) / r(j);
          when OP_EXP then
            tmp := r(j-1) ** r(j);
          when OP_MOD then
            tmp := mod(r(j-1), r(j));
          when OP_UMINUS then
            tmp := - r(j);
          when OP_EQ then
            tmp := case when r(j-1) = r(j) then 1 else 0 end;
          when OP_LT then
            tmp := case when r(j-1) < r(j) then 1 else 0 end;
          when OP_LE then
            tmp := case when r(j-1) <= r(j) then 1 else 0 end;
          when OP_GT then
            tmp := case when r(j-1) > r(j) then 1 else 0 end;
          when OP_GE then
            tmp := case when r(j-1) >= r(j) then 1 else 0 end;
          when OP_NE then
            tmp := case when r(j-1) != r(j) then 1 else 0 end;
          when OP_AND then
            tmp := case when r(j-1) = 1 and r(j) = 1 then 1 else 0 end;
          when OP_OR then
            tmp := case when r(j-1) = 1 or r(j) = 1 then 1 else 0 end;
          when OP_NOT then
            tmp := case when r(j) = 1 then 0 else 1 end;

        end case;

        opcnt := op(token.type).argc - 1;

        if opcnt = -1 then
          r.extend;
          j := j + 1;
        else
          r.trim(opcnt);
          j := j - opcnt;
        end if;

      end if;

      r(j) := tmp;

    end loop;

    return case when flag = KEEP_INF_OR_NAN
                  or ( flag = NULL_INF_OR_NAN
                       and not(tmp is nan or tmp is infinite) )
           then tmp end ;

  end ;
  
begin
  init;

end rpn_util2;
/