
open Types

let string_of_loc (l,c) = "[l:"^string_of_int l^";c:"^string_of_int c^"]"

let rec string_of_term : term -> string = function
  | Kind        -> "Kind"
  | Type        -> "Type"
  | DB  n       -> string_of_int n
  | GVar (m,v)  -> m^"."^v
  | LVar n      -> "var"^string_of_int n
  | App args    -> "(" ^ String.concat " " (List.map string_of_term args) ^ ")"
  | Lam (a,f)   -> "(\ "^string_of_term a^" => "^string_of_term f^")"
  | Pi  (a,b)   -> "(" ^ string_of_term a^" -> "^string_of_term b ^")" 

let rec string_of_pat2 = function
  | Joker               -> "_"
  | Var v               -> v
  | Pattern ((m,v),arr) -> "("^m^"."^v^" "^String.concat " " (List.map string_of_pat2 (Array.to_list arr))^")"


let dump_gdt id g = 
  let rec aux = function
    | Leaf te                     -> Global.print_v ("Leaf : "^string_of_term te^"\n")
    | Switch (c,cases,def)        ->
        begin
          Global.print_v ("Switch ( "^string_of_int c ^") [\n");
          List.iter (fun ((m,v),g) -> Global.print_v ("Case "^m^"."^v^": ") ; aux g ) cases ;
          (match def with
             | None       -> ()
             | Some g     -> (Global.print_v "Def: " ; aux g) ) ;
          Global.print_v ("]\n")
        end
  in
    Global.print_v (" --------> GDT FOR "^id^"\n");
    aux g;
    Global.print_v " <-------- \n"

let dump_pMat id pm =
  let aux l = 
    Global.print_v " [ ] " ;
    Array.iter (fun p -> Global.print_v (string_of_pat2 p^"\t")) l.li;
    Global.print_v (" --> "^string_of_term l.te^"\n")
  in
    Global.print_v (" --------> PMAT FOR "^id^"\n");
    Array.iter aux pm ;
    Global.print_v " <-------- \n"

