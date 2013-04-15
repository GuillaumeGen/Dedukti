open Types
open Printf

  (* *********** Utils *********** *)

let iteri f lst = 
  let i = ref 0 in
    List.iter (fun a -> f !i a ; incr i) lst

(* *********** Lua Code Generation *********** *)

let rec gen_code = function
  | Kind                -> assert false
  | Type                -> fprintf !Global.out "{ ctype=true }"
  | GVar (m,v)          -> fprintf !Global.out "app0(%s.%s_c)" m v
  | Var v               -> fprintf !Global.out "%s_c" v 
  | App (f,a)           -> 
      begin
        fprintf !Global.out  "app( " ;
        gen_code f ;
        fprintf !Global.out  " , " ;
        gen_code a ;
        fprintf !Global.out  " )"
      end
  | Lam (v,_,te)        -> 
      begin
        fprintf !Global.out "{ clam_f = function (%s_c) return " v ; 
        gen_code te ;
        fprintf !Global.out " end }"
      end
  | Pi (v0,ty,te)       ->
      let arg = match v0 with Some v -> v^"_c" | None -> "dummy" in
        begin
          fprintf !Global.out "{ cpi_cty = ";
          gen_code ty ;
          fprintf !Global.out " ; cpi_f = function (%s) return "  arg ;
          gen_code te ;
          fprintf !Global.out " end }"
        end

let rec gen_lazy_code = function
  | GVar (m,v)          -> fprintf !Global.out "{ clazy = function() return app0(%s.%s_c) end }" m v
  | App (f,a) as c      -> 
      begin
        fprintf !Global.out  "{ clazy = function() return " ;
        gen_code c ;
        fprintf !Global.out  " end }"
      end
  | Pi (v0,ty,te)       ->
      let arg = match v0 with Some v -> v^"_c" | None -> "dummy" in
        begin
          fprintf !Global.out "{ cpi_cty = ";
          gen_lazy_code ty ;
          fprintf !Global.out " ; cpi_f = function (%s) return "  arg ;
          gen_code te ;
          fprintf !Global.out " end }"
        end
  | c                   -> gen_code c

(* *********** Lua Term Generation *********** *)

let rec gen_term = function
  | Kind                -> assert false
  | Type                -> fprintf !Global.out "{ ttype=true }"
  | GVar (m,v)          -> fprintf !Global.out "%s.%s_t" m v
  | Var v               -> fprintf !Global.out "%s_t" v
  | App (f,a)           -> 
      begin 
        fprintf !Global.out "{ tapp_f = " ; 
        gen_term f ; 
        fprintf !Global.out " ; tapp_a = " ; 
        gen_term a ; 
        fprintf !Global.out " ; tapp_ca = " ; 
        gen_lazy_code a ;
        fprintf !Global.out " }"
      end
  | Lam (v,None,te)     -> 
      begin
        fprintf !Global.out "{ tlam_f =  function (%s_t, %s_c) return " v v ; 
        gen_term te;
        fprintf !Global.out " end }";
      end
  | Lam (v,Some ty,te)  -> 
      begin
        fprintf !Global.out "{ tlam_tty = ";
        gen_term ty;
        fprintf !Global.out " ; tlam_cty = " ;
        gen_lazy_code ty ;
        fprintf !Global.out " ; tlam_f =  function (%s_t, %s_c) return " v v ; 
        gen_term te;
        fprintf !Global.out " end }";
      end
  | Pi  (ov,ty,t)       -> 
      let args = match ov with None -> "dummy1,dummy2" | Some v -> ( v^"_t,"^v^"_c" ) in
        begin 
          fprintf !Global.out "{ tpi_tty = " ;
          gen_term ty ; 
          fprintf !Global.out " ; tpi_cty = " ; 
          gen_lazy_code ty ;
          fprintf !Global.out " ; tpi_f = function (%s) return " args ;
          gen_term t;
          fprintf !Global.out " end }"
      end

(* ************** Declarations *************** *)

let rec iskind = function
  | Type          -> true
  | Pi (_,_,t)    -> iskind t
  | _             -> false

let generate_decl_check gname loc ty =
  fprintf !Global.out "\nprint_debug(\"%s\tChecking declaration %s\t\t\")\n" (Debug.string_of_loc loc) gname ;
  (if iskind ty then fprintf !Global.out "chkkind(" else fprintf !Global.out "chktype(") ;
  gen_term ty ;
  fprintf !Global.out ")\n"

let generate_decl_code id =
  fprintf !Global.out "%s.%s_c = { cid = \"%s.%s\" ; args = { } }\n" !Global.name id !Global.name id
  (*; fprintf !Global.out "assert(is_code(%s.%s_c))\n" !Global.name id 
  ; fprintf !Global.out "print(\"--> \" .. string_of_code(%s.%s_c) .. \"\\n\")\n" !Global.name id *)

let generate_decl_term id ty =
  fprintf !Global.out "%s.%s_t = { tbox_cty = " !Global.name id ;
  gen_lazy_code ty ;
  fprintf !Global.out " }\n" 
  (*; fprintf !Global.out "assert(is_term(%s.%s_t))\n" !Global.name id 
  ; fprintf !Global.out "print(\"--> \" .. string_of_term(%s.%s_t) .. \"\\n\")\n" !Global.name id *)

(* ************** Definitions *************** *)

let generate_def_check gname loc te ty = 
  fprintf !Global.out "\nprint_debug(\"%s\tChecking definition %s\t\t\")\n" (Debug.string_of_loc loc) gname ;
  fprintf !Global.out "chk( " ;
  gen_term te ;
  fprintf !Global.out " , " ;
  gen_code ty ;
  fprintf !Global.out ")\n"

let generate_def_term id te = 
  fprintf !Global.out "%s.%s_t = " !Global.name id ;
  gen_term te ;
  fprintf !Global.out "\n"

let generate_def_code id te = 
  fprintf !Global.out "%s.%s_c = " !Global.name id ;
  (*gen_lazy_code te ;*) gen_code te ;
  fprintf !Global.out "\n"

(* ***************** Pattern Matching Generation ************ *)

let rec dots_to_joker = function
  | Pat (id,dots,pats)  -> 
      let d = Array.length dots in
      let pats2 = Array.init (d+Array.length pats) (
        fun i ->
          if i<d then Joker 
          else dots_to_joker (pats.(i-d))
      ) in
        Pat (id,[||],pats2)
  | p                   -> p

let new_pMat rules : pMat = 
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
                 | Joker                -> ()
                 | Id _                 -> ()
                 | Pat (_,_,pats)       ->
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

          for i=0 to pred arity     do l.(i) <- i::pm.loc.(c)                 done;
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
          | Joker | Id _  -> (
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
    ) (List.rev p) (*get rid of rev?*)

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
            | Joker   ->  if !first then (fprintf !Global.out "dummy" ; first:=false) else fprintf !Global.out ", dummy" 
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
          | Joker               -> aux (i+1)
          | Id _                -> aux (i+1)
          | Pat (id,_,p)        -> Some (i,id)
            else None
    in aux 0

let partition (mx:pattern array array) (c:int) : (id*int*int list) list =
    let lst = ref [] in
    let checked = Array.make (Array.length mx) false in
      for i=pred (Array.length mx) downto 0 do
        if checked.(i) then ()
        else (
          assert (c < Array.length mx.(i));
          match mx.(i).(c) with
            | Joker             -> () 
            | Id _              -> () 
            | Pat (cst,_,pats)  ->
                let l = ref [] in
                  begin
                    for j=0 to pred (Array.length mx) do
                      match mx.(j).(c) with
                        | Joker             -> l := j::!l
                        | Id _              -> l := j::!l
                        | Pat (cst2,_,pats)    ->
                            if (cst=cst2 && i!=j) then ( l := j::!l ; checked.(j) <- true )
                            else ()
                    done ;
                    lst := (cst,Array.length pats,i::!l)::!lst ;
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
            gen_code te
        end
    | Some (c,_)     -> 
        begin
          assert (c < Array.length pm.loc);
          let bo  = ref true in
          let par = partition pm.p c in
            List.iter ( 
              fun ((m,cst),arity,lst) ->
                (if !bo then bo := false else fprintf !Global.out "\nelse") ;
                fprintf !Global.out "if " ;
                print_path pm.loc.(c) ;
                fprintf !Global.out ".cid == \"%s.%s\" then\n" m cst ; 
                match specialize pm c arity lst with
                  | None        -> ( fprintf !Global.out "return " ; gen_code (snd pm.a.(match lst with z::_ -> z | _ -> assert false)) )
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
  | Joker               -> assert false (*TODO*)
  | Id v                -> fprintf !Global.out "%s_c" v
  | Pat ((m,c),dots,pats)   ->
      begin
        (*let first = ref true in*)
        let arity = Array.length dots + Array.length pats  in
          if arity = 0 then
            fprintf !Global.out "app0(%s.%s_c) " m c
          else
            begin 
              for i=1 to arity do fprintf !Global.out "app( " done ;
              fprintf !Global.out "app0(%s.%s_c)" m c ; 
              Array.iter ( 
                fun t -> 
                  fprintf !Global.out " , " ; 
                  gen_code t ; 
                  fprintf !Global.out " ) " 
              ) dots ;
              Array.iter ( 
                fun t -> 
                  fprintf !Global.out " , " ; 
                  gpcode t ; 
                  fprintf !Global.out " ) " 
              ) pats ;
            end
      end

let rec gpterm = function 
  | Joker               -> assert false (*TODO*)
  | Id v                -> fprintf !Global.out "%s_t" v
  | Pat ((m,c),dots,pats)   -> 
      let arity = Array.length dots + Array.length pats in
        for i=1 to arity do fprintf !Global.out " { tapp_f = " done ;
        fprintf !Global.out "%s.%s_t " m c ;
        Array.iter (
          fun d -> 
            fprintf !Global.out " ; tapp_a = " ;
            gen_term d ;
            fprintf !Global.out " ; tapp_ca = " ;
            gen_lazy_code d ;
            fprintf !Global.out " } "
        ) dots ;
        Array.iter (
          fun p -> 
            fprintf !Global.out " ; tapp_a = " ;
            gpterm p ;
            fprintf !Global.out " ; tapp_ca = { clazy = function() return " ; (*gpcode_lazy*)
            gpcode p ;
            fprintf !Global.out " end } } "
        ) pats

(* Env *)

let gen_env ((id,loc),te) =
  fprintf !Global.out "\nprint_debug(\"%s\tChecking variable %s\t\t\")\n" (Debug.string_of_loc loc) id ;
  (if iskind te then fprintf !Global.out "chkkind(" else fprintf !Global.out "chktype(");
  gen_term te ;
  (*fprintf !Global.out ")\nlocal %s_c = { cid = \"%s\" ; args = { } }\n" id id ; 
  fprintf !Global.out "local %s_t = { tbox_cty = " id ; FIXME*)
  fprintf !Global.out ")\n%s_c = { cid = \"%s\" ; args = { } }\n" id id ; 
  fprintf !Global.out "%s_t = { tbox_cty = " id ;
  gen_lazy_code te ;
  fprintf !Global.out " }\n" 
  (*; fprintf !Global.out "assert(is_code(%s_c))\n" id 
  ; fprintf !Global.out "assert(is_term(%s_t))\n" id *)

(* Rules*)

let generate_rule_check id i (loc,ctx,dots,pats,te) =
  fprintf !Global.out "\ndo";
  List.iter gen_env ctx ; 
  fprintf !Global.out "\nprint_debug(\"%s\tChecking rule %i for %s\t\t\")\n" (Debug.string_of_loc loc) (i+1) id ;
  fprintf !Global.out "local ty = type_synth( ";
  gpterm (Pat ((!Global.name,id),dots,pats));
  fprintf !Global.out ")\n";
  (*fprintf !Global.out "assert(is_code(ty))\n";*) 
  fprintf !Global.out "chk( ";
  gen_term te ;
  fprintf !Global.out ", ty )\nend\n"

let generate_rules_code id rules = 
  assert ( Array.length rules > 0 );
  let (_,_,dots,pats,te) = rules.(0) in
  let arity = Array.length dots + Array.length pats in
    if arity=0 then
      begin
        fprintf !Global.out "%s.%s_c = { cid=\"%s.%s\" ; arity = 0 ; args = { } ; f = function() return " !Global.name id !Global.name id ;
        gen_code te ;
        fprintf !Global.out " end }\n"
      end
    else
      begin
        fprintf !Global.out "%s.%s_c = { cid=\"%s.%s\" ; arity = %i ; args = { } ; f = function(" !Global.name id !Global.name id arity ;
        fprintf !Global.out "y1" ;
        (for i=2 to arity do fprintf !Global.out ", y%i" i  done );
        fprintf !Global.out ")\n" ;
        (for i=1 to arity do fprintf !Global.out "local y%i = force2(y%i)\n" i i done );
        cc (new_pMat rules) ;
        fprintf !Global.out "\nend }\n" 
      end

(* External symbol checks *)

let rec ext_check_term = function
  | Kind | Type | Var _                         -> ()
  | Lam (_,None,a)                              -> ext_check_term a
  | App (a,b) | Lam (_,Some a,b) | Pi (_,a,b)   -> ( ext_check_term a ; ext_check_term b )
  | GVar (m,_)                                  -> if Global.is_checked m then fprintf !Global.out "check_ext(%s,'[ Lua ]  %s is undefined.')\n" m m

let rec ext_check_pat = function
  | Joker | Id _        -> ()
  | Pat (_,te,pats)     -> ( Array.iter ext_check_term te ; Array.iter ext_check_pat pats )

let ext_check_rule (_,env,dots,pats,te) =
  List.iter (fun e -> ext_check_term (snd e)) env ;
  Array.iter ext_check_term dots ;
  Array.iter ext_check_pat pats ;
  ext_check_term te

(* Entry Points *)
 
let mk_require dep = 
  fprintf !Global.out "require(\"%s\")\n" dep

let prelude _ =
  (*fprintf !Global.out "--[[ Code for module %s ]]\n" !Global.name ;*)
  ( if !Global.lua_path <> "" then 
      fprintf !Global.out "package.path = '%s/?.lua;' .. package.path \n" !Global.lua_path ) ;
  if !Global.do_not_check then
    begin
      fprintf !Global.out "require('dedukti')\n" ;
      List.iter mk_require !Global.libs ;
      fprintf !Global.out "%s = { }\n" !Global.name
    end
  else
    begin
      fprintf !Global.out "require('dedukti')\n" ;
      List.iter mk_require !Global.libs ;
      fprintf !Global.out "debug_infos = %B\n" (not !Global.quiet) ;
      (*fprintf !Global.out "local %s = { }\n\n" !Global.name*)
      fprintf !Global.out "%s = { }\n\n" !Global.name
    end

let exit _ =
  fprintf !Global.out "\nos.exit(1)\n" 
       
let mk_declaration id loc ty =
  ( if !Global.check_ext then ext_check_term ty ) ;
  ( if !Global.do_not_check then () else generate_decl_check id loc ty ) ;
  generate_decl_code id ;
  generate_decl_term id ty

let mk_definition id loc te ty =
  ( if !Global.check_ext then ext_check_term te ) ;
  ( if not !Global.do_not_check then ( ext_check_term ty ; generate_def_check id loc te ty ) ) ;
  generate_def_code id te ;
  generate_def_term id te 

let mk_opaque id loc te ty = 
  ( if !Global.check_ext then ext_check_term ty ) ;
  ( if not !Global.do_not_check then ( ext_check_term te ; generate_def_check id loc te ty ) ) ;
  generate_decl_code id ;
  generate_decl_term id ty 

let mk_typecheck loc te ty = 
  ( if !Global.check_ext then ( ext_check_term ty ; ext_check_term te ) ) ;
  ( if not !Global.do_not_check then generate_def_check "_" loc te ty )

let mk_rules id rs = 
  ( if !Global.check_ext then Array.iter ext_check_rule rs ) ;
  if !Global.do_not_check then () else Array.iteri (generate_rule_check id) rs ;
  generate_rules_code id rs
