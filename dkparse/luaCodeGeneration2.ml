open Types
open Printf

  (* *********** Utils *********** *)

let iteri f lst = 
  let i = ref 0 in
    List.iter (fun a -> f !i a ; incr i) lst

(* *********** Prelude ********** *)

let prelude _ =
  fprintf !Global.out "require('dedukti')\n" ;
  fprintf !Global.out "--[[ Code for module %s ]]\n" !Global.name ;
  fprintf !Global.out "%s = { }\n\n" !Global.name

let generate_require dep = 
  fprintf !Global.out "require(\"%s\")\n" dep

<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
=======
let prelude _ =
  (*fprintf !Global.out "--[[ Code for module %s ]]\n" !Global.name ;*)
  if !Global.do_not_check then
    begin
      fprintf !Global.out "require('dedukti2')\n" ; (*FIXME*)
      List.iter generate_require !Global.libs ;
      fprintf !Global.out "%s = { }\n" !Global.name
    end
  else
    begin
      fprintf !Global.out "require('dedukti2')\n" ; (*FIXME*)
      List.iter generate_require !Global.libs ;
      fprintf !Global.out "debug_infos = %B\n" (not !Global.quiet) ;
      fprintf !Global.out "local %s = { }\n\n" !Global.name
    end

>>>>>>> Stashed changes:dkparse/codeGeneration.ml
(* *********** Lua Code Generation *********** *)

let rec gen_code0 = function
  | Type                -> fprintf !Global.out "{ co = ctype }"
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
  | GVar v              -> 
      if Global.is_alias v then fprintf !Global.out "app0(%s.%s_c)"  !Global.name v
      else fprintf !Global.out "%s.%s_c"  !Global.name v
  | EVar v              -> fprintf !Global.out "app0(%s_c)" v
  | Var v               -> (* fprintf !Global.out "app0(%s_c)" v *) fprintf !Global.out "%s_c" v 
=======
  | GVar (m,v)          -> 
      if Global.is_alias m v then fprintf !Global.out "app0(%s.%s_c)" m v
      else fprintf !Global.out "%s.%s_c" m v
  | Var v               -> fprintf !Global.out "%s_c" v 
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
  | App (f,a)           -> 
      begin
        fprintf !Global.out  "app( " ;
        gen_code0 f ;
        fprintf !Global.out  " , " ;
        gen_code0 a ;
        fprintf !Global.out  " )"
      end
  | Lam (v,_,te)        -> 
      begin
        fprintf !Global.out "{ co = clam ; f = function (%s_c) return " v; 
        gen_code0 te ;
        fprintf !Global.out " end }"
      end
  | Pi (v0,ty,te)       ->
      let arg = match v0 with Some v -> v^"_c" | None -> "dummy" in
        begin
          fprintf !Global.out "{ co = cpi ; ctype = ";
          gen_code0 ty ;
          fprintf !Global.out " ; f = function (%s) return "  arg ;
          gen_code0 te ;
          fprintf !Global.out " end }"
        end

let gen_code te =
  fprintf !Global.out "function() return " ;
  gen_code0 te ;
  fprintf !Global.out " end"

(* *********** Lua Term Generation *********** *)

let rec gen_term = function
(*  | Kind                -> assert false *)
  | Type                -> fprintf !Global.out "{ te = ttype }"
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
  | GVar v              -> fprintf !Global.out "%s.%s_t" !Global.name v
  | EVar v              -> fprintf !Global.out "%s_t" v
=======
  | GVar (m,v)          -> fprintf !Global.out "%s.%s_t" m v 
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
  | Var v               -> fprintf !Global.out "%s_t" v
  | App (f,a)           -> 
      begin 
        fprintf !Global.out "{ te = tapp ; f = " ;  
        gen_term f ; 
        fprintf !Global.out " ; a = " ; 
        gen_term a ; 
        fprintf !Global.out " ; ca = " ; 
        gen_code a ; 
        fprintf !Global.out " }"
      end
  | Lam (v,None,te)     -> 
      begin
        fprintf !Global.out "{ te = tlam ; ttype = nil ; ctype = nil ; f =  function (%s_t, %s_c) return " v v ; 
        gen_term te;
        fprintf !Global.out " end }";
      end
  | Lam (v,Some ty,te)  -> 
      begin
        fprintf !Global.out "{ te = tlam ; ttype = ";
        gen_term ty;
        fprintf !Global.out " ; ctype = " ;
        gen_code ty ;
        fprintf !Global.out " ; f =  function (%s_t, %s_c) return " v v ; 
        gen_term te;
        fprintf !Global.out " end }";
      end
  | Pi  (ov,ty,t)       -> 
      let args = match ov with None -> "dummy1,dummy2" | Some v -> ( v^"_t,"^v^"_c" ) in
        begin 
          fprintf !Global.out "{ te = tpi ; ttype = " ;
          gen_term ty ; 
          fprintf !Global.out " ; ctype = " ; 
          gen_code ty ;
          fprintf !Global.out " ; f = function (%s) return " args ;
          gen_term t;
          fprintf !Global.out " end }"
      end

<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
(* ************** Declarations *************** *)

let rec iskind = function
  | Type          -> true
  | Pi (_,_,t)    -> iskind t
  | _             -> false

let generate_decl_check gname ty =
  fprintf !Global.out " -- [[ Type checking %s. ]]\n" gname ;
  fprintf !Global.out "chkbeg(\"%s\")\n" gname;
  (if iskind ty then fprintf !Global.out "chkkind(" else fprintf !Global.out "chktype(") ;
  gen_term ty ;
  fprintf !Global.out ")\nchkend(\"%s\")\n" gname

let generate_decl_code gname =
  fprintf !Global.out "%s_c = { co = ccon ; id = \"%s\" ; arity = 0 ; args = { } ; f = function() return nil end }\n" gname gname

let generate_decl_term gname ty =
  fprintf !Global.out "%s_t = { te = tbox ; ctype = function() return " gname ;
  gen_code0 ty ;
  fprintf !Global.out " end }\n\n"

(* ************** Definitions *************** *)

let generate_def_check gname te ty = 
  fprintf !Global.out " -- [[ Type checking %s. ]]\n" gname ;
  fprintf !Global.out "chkbeg(\"%s\")\n" gname ;
  fprintf !Global.out "chk( " ;
  gen_term te ;
  fprintf !Global.out " , " ;
  gen_code0 ty ;
  fprintf !Global.out ")\nchkend(\"%s\")\n" gname

let generate_def_term gname te = 
  fprintf !Global.out "%s_t = " gname ;
  gen_term te ;
  fprintf !Global.out "\n\n"

let generate_def_code gname te = (*FIXME normalize *)
  fprintf !Global.out "%s_c = " gname ;
  gen_code0 te ;
  fprintf !Global.out "\n\n"

=======
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
(* ***************** Pattern Matching Generation ************ *)

let new_pMat rules : pMat = 
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
    let rows = Array.length rules   in
      assert (rows>0);
      let (cols,nd) = match rules.(0) with (_,dots,pats,_) -> ( Array.length pats , Array.length dots ) in
        { p = Array.init rows (fun i -> let (_,_,pats,_) = rules.(i) in pats ) ; 
          a = Array.init rows (fun i -> let (ctx,_,_,ri) = rules.(i)   in (ctx,ri) ) ;
          loc = Array.init cols (fun i -> [i+nd]); 
        }

let specialize (pm:pMat) (c:int) (arity:int) (nb_dots:int) (lines:int list) : pMat option = 
=======
  let rows = Array.length rules   in
    assert (rows>0);
    let cols = match rules.(0) with (_,_,dots,pats,_) -> Array.length dots + Array.length pats in
      { p = Array.init rows 
              (fun i ->
                 let (_,_,dots,pats,_) = rules.(i) in
                 let nd = Array.length dots in
                   Array.init cols (fun j -> if j<nd then Joker else dots_to_joker pats.(j-nd) )
              ) ; 
        a = Array.init rows (fun i -> let (_,ctx,_,_,ri) = rules.(i)   in (ctx,ri) ) ;
        loc = Array.init cols (fun i -> [i]); 
      }

let specialize (pm:pMat) (c:int) (arity:int) (lines:int list) : pMat option = 
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
  assert (0 < Array.length pm.p);
  assert (c < Array.length pm.p.(0));
    
  let l_size = List.length lines                in                                                                                   
  let c_size = (Array.length pm.p.(0))+arity-1  in
    if c_size=0 then None
    else
      begin
        assert (l_size <= Array.length pm.p);
        let p = Array.init l_size (fun _ -> Array.make c_size (Id "dummy")) in
        let a = Array.make l_size ([],Type) in
        let l = Array.make c_size [] in
          
          iteri (fun i k -> a.(i) <- pm.a.(k) ) lines;

          iteri (
            fun i k ->
              assert (k < Array.length pm.p && c < Array.length pm.p.(k));
              (match pm.p.(k).(c) with
                 | Id _              -> ()
                 | Pat (_,_,pats)    ->
                     for j=0 to (arity-1) do
                       p.(i).(j) <- pats.(j)
                     done
              );
              for j=0 to pred c do
                p.(i).(arity+j) <- pm.p.(k).(j) 
              done;
              for j=(c+1) to pred (Array.length pm.p.(k)) do
                let tmp =pm.p.(k).(j) in
                  p.(i).(arity+j-1) <-  tmp
              done 
          ) lines; 

          for i=0 to pred arity     do l.(i) <- (i+nb_dots)::pm.loc.(c)                 done;
          for i=0 to pred c         do l.(i+arity) <- pm.loc.(i)                        done;
          for i=(c+1) to pred (Array.length pm.loc) do l.(i+arity-1) <- pm.loc.(i)      done;
          
          Some { p=p ; a=a ; loc=l; }
      end

let default (pm:pMat) (c:int) : pMat option = 
    let l_p = ref [] in
    let l_a = ref [] in
      for i=0 to pred (Array.length pm.p) do
        assert (c < Array.length pm.p.(i));
        match pm.p.(i).(c) with 
          | Id v  -> (
              l_p := pm.p.(i) :: !l_p;
              l_a := pm.a.(i) :: !l_a;
            )
          | _     -> ()
      done ;
      if !l_p=[] then None
      else 
        Some { p = Array.of_list !l_p ; 
               a = Array.of_list !l_a ; 
               loc = pm.loc ; 
        } 

let print_path p = 
    assert(p!=[]);
    iteri ( 
      fun i e ->
        if i=0 then fprintf !Global.out "y%i" (e+1) 
        else fprintf !Global.out ".args[%i]" (e+1) 
    ) (List.rev p) (*FIXME*)

let print_locals vars locs = 
  assert (Array.length vars = Array.length locs);
  if Array.length vars = 0 then ()
  else 
    begin
      let first = ref true in
        fprintf !Global.out "local ";
        Array.iter (
          function 
            | Id id   -> if !first then (fprintf !Global.out "%s_c" id ; first:=false) else fprintf !Global.out ", %s_c" id 
            | _       -> assert false
        ) vars;
        first := true;
        fprintf !Global.out " = ";
        Array.iter (fun l -> (if !first then first:=false else fprintf !Global.out ", "  ) ; print_path l ) locs ;
        fprintf !Global.out "\n"
      end
       
let getColumn arr =
    let rec aux i =
      if i < Array.length arr then
        match arr.(i) with
          | Id _                -> aux (i+1)
          | Pat (id,_,p)        -> Some (i,id)
            else None
    in aux 0

let partition (mx:pattern array array) (c:int) : (id*int*int*int list) list =
    let lst = ref [] in
    let checked = Array.make (Array.length mx) false in
      for i=pred (Array.length mx) downto 0 do
        if checked.(i) then ()
        else (
          assert (c < Array.length mx.(i));
          match mx.(i).(c) with
            | Id _              -> () 
            | Pat (cst,dots,pats)   ->
                let l = ref [] in
                  begin
                    for j=0 to pred (Array.length mx) do
                      match mx.(j).(c) with
                        | Id _              -> l := j::!l
                        | Pat (cst2,_,pats)    ->
                            if (cst=cst2 && i!=j) then ( l := j::!l ; checked.(j) <- true )
                            else ()
                    done ;
                    lst := (cst,Array.length pats,Array.length dots,i::!l)::!lst ;
                    checked.(i) <- true
                  end
        )
      done ;
      !lst 

let rec cc (pm:pMat) : unit =
  match getColumn pm.p.(0) with
    | None              -> 
        begin 
          let (ctx,te) = pm.a.(0) in
            print_locals pm.p.(0) pm.loc ;
            fprintf !Global.out "return ";
            gen_code0 te
        end
    | Some (c,n_id)     -> 
        begin
          assert (c < Array.length pm.loc);
          let bo  = ref true in
          let par = partition pm.p c in
            List.iter ( 
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
              fun (cst,arity,dots,lst) ->
=======
              fun ((m,cst),arity,lst) ->
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
                (if !bo then bo := false else fprintf !Global.out "\nelse") ;
                fprintf !Global.out "if " ;
                print_path pm.loc.(c) ;
                fprintf !Global.out ".co == ccon and " ;
                print_path pm.loc.(c) ;
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
                fprintf !Global.out ".id == \"%s.%s\" then\n" !Global.name cst ; 
                match specialize pm c arity dots lst with
=======
                fprintf !Global.out ".id == \"%s.%s\" then\n" m cst ; 
                match specialize pm c arity lst with
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
                  | None        -> ( fprintf !Global.out "return " ; gen_code0 (snd pm.a.(match lst with z::_ -> z | _ -> assert false)) )
                  | Some pm'    -> ( cc pm' )
            ) par ;

            (*DEFAULT*)
            fprintf !Global.out "\nelse\n";
            (match default pm c with
               | None           -> fprintf !Global.out "return nil"
               | Some pm'       -> ( cc pm') 
            );
            fprintf !Global.out "\nend" 
        end 

(* ************** Rules *************** *)

let rec gpcode = function
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
=======
  | Joker               -> assert false 
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
  | Id v                -> fprintf !Global.out "%s_c" v
  | Pat ((m,c),dots,pats)   ->
      begin
        let first = ref true in
        let arity = Array.length dots + Array.length pats  in
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
        fprintf !Global.out "{ co = ccon ; id = \"%s.%s\" ; arity = %i ; f = function() return %s.%s_c end ; args = { " !Global.name c arity !Global.name c ;
=======
        fprintf !Global.out "{ co = ccon ; id = \"%s.%s\" ; arity = %i ; f = function() return %s.%s_c end ; args = { " m c arity m c;
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
        Array.iter ( 
          fun t -> 
            if !first then ( gen_code t ; first := false )
            else ( fprintf !Global.out " ; " ; gen_code t )
        ) dots ;
        Array.iter ( 
          fun t -> 
            if !first then ( gpcode t ; first := false )
            else ( fprintf !Global.out " ; " ; gpcode t )
        ) pats ;
        fprintf !Global.out " } ; }"
      end

let rec gpterm = function 
<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
  | Id v                -> fprintf !Global.out "%s_t" v
  | Pat (c,dots,pats)   -> 
      let arity = Array.length dots + Array.length pats in
        for i=1 to arity do fprintf !Global.out " { te = tapp ; f = " done ;
        fprintf !Global.out "%s.%s_t " !Global.name c ;
=======
  | Joker                       -> assert false 
  | Id v                        -> fprintf !Global.out "%s_t" v
  | Pat ((m,c),dots,pats)       -> 
      let arity = Array.length dots + Array.length pats in
        for i=1 to arity do fprintf !Global.out " { te = tapp ; f = " done ; 
        fprintf !Global.out "%s.%s_t " m c  ;
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
        Array.iter (
          fun d -> 
            fprintf !Global.out " ; a = " ;
            gen_term d ;
            fprintf !Global.out " ; ca = " ;
            gen_code d ;
            fprintf !Global.out " } "
        ) dots ;
        Array.iter (
          fun p -> 
            fprintf !Global.out " ; a = " ;
            gpterm p ;
            fprintf !Global.out " ; ca = function() return " ;
            gpcode p ;
            fprintf !Global.out " end } "
        ) pats

<<<<<<< Updated upstream:dkparse/luaCodeGeneration2.ml
let gen_env (id,te) =
  fprintf !Global.out "chkbeg(\"%s\")\n" id ;
  (if iskind te then fprintf !Global.out "chkkind(" else fprintf !Global.out "chktype(");
  gen_term te ;
  fprintf !Global.out ")\nlocal %s_c = { co = ccon ; id = \"%s\" ; arity = 0 ; args = { } ; f = function() return nil end}\n" id id ; (*FIXME*)
  fprintf !Global.out "local %s_t = { te = tbox, ctype = function() return " id ;
  gen_code0 te ;
  fprintf !Global.out " end }\nchkend(\"%s\")\n" id

let generate_rule_check id i (ctx,dots,pats,te) =
  fprintf !Global.out "chkbeg(\"rule %i\")\n" (i+1) ;
  List.iter gen_env ctx ; 
  fprintf !Global.out "do\nlocal ty = type_synth(0, ";
  gpterm (Pat (id,dots,pats));
  fprintf !Global.out ")\nchk(";
  gen_term te ;
  fprintf !Global.out ", ty)\nend\nchkend(\"rule %i\")\n" (i+1)

let generate_rules_code id rules = 
  assert ( Array.length rules > 0 );
  let gname = !Global.name^"."^id in     (*FIXME*)
  let (_,dots,pats,_) = rules.(0) in
  let arity = Array.length dots + Array.length pats in
    fprintf !Global.out "\n -- [[ Compiling rules of %s. ]]\n" gname ;
    fprintf !Global.out "%s_c = { co = ccon ; id=\"%s\" ; arity = %i ; args = { } ; f =\nfunction (" gname gname arity ;
    (if arity>0 then fprintf !Global.out "y1" else ());
    (for i=2 to arity do fprintf !Global.out ", y%i" i  done );
    fprintf !Global.out ")\n" ;
    cc id (new_pMat rules) ;
    fprintf !Global.out "\nend }\n\n"
=======
let generate_rules_code id rules = 
  assert ( Array.length rules > 0 );
  let (_,_,dots,pats,_) = rules.(0) in
  let arity = Array.length dots + Array.length pats in
    (*fprintf !Global.out "\n -- [[ Compiling rules of %s. ]]\n" gname ;*)
    fprintf !Global.out "{ co = ccon ; id=\"%s.%s\" ; arity = %i ; args = { } ; f =\nfunction (" !Global.name id arity ;
    (if arity>0 then fprintf !Global.out "y1" else ());
    (for i=2 to arity do fprintf !Global.out ", y%i" i  done );
    fprintf !Global.out ")\n" ;
    cc (new_pMat rules) ;
    fprintf !Global.out "\nend }\n" 
      (*;fprintf !Global.out " print(\"%s_c = \" .. string_of_code(0,%s_c))\n" gname gname *)

let generate_rules_code2 id rules = 
  assert ( Array.length rules > 0 );
  let (_,_,dots,pats,_) = rules.(0) in
  let arity = Array.length dots + Array.length pats in
    (*fprintf !Global.out "\n -- [[ Compiling rules of %s. ]]\n" gname ;*)
    fprintf !Global.out "{ co = ccon ; id=\"%s.%s\" ; ctype = %s.%s_c.ctype ; arity = %i ; args = { } ; f =\nfunction (" !Global.name id !Global.name id arity ;
    (if arity>0 then fprintf !Global.out "y1" else ());
    (for i=2 to arity do fprintf !Global.out ", y%i" i  done );
    fprintf !Global.out ")\n" ;
    cc (new_pMat rules) ;
    fprintf !Global.out "\nend }\n" 
      (*;fprintf !Global.out " print(\"%s_c = \" .. string_of_code(0,%s_c))\n" gname gname *)
>>>>>>> Stashed changes:dkparse/codeGeneration.ml
