open Basic
open Term
open Rule
open Typing
open Signature

type env_error =
  | EnvErrorType        of typing_error
  | EnvErrorSignature   of signature_error
  | KindLevelDefinition of ident
  | ParseError          of string
  | AssertError

exception EnvError of loc * env_error

let raise_as_env lc = function
  | SignatureError e -> raise (EnvError (lc, (EnvErrorSignature e)))
  | TypingError    e -> raise (EnvError (lc, (EnvErrorType      e)))
  | ex -> raise ex


(* Wrapper around Signature *)

let sg = ref (Signature.make "noname")

let init file =
  sg := Signature.make file;
  Signature.get_name !sg

let get_name () = Signature.get_name !sg

let get_signature () = !sg

let get_type lc cst =
  try Signature.get_type !sg lc cst
  with e -> raise_as_env lc e

let get_dtree lc cst =
  try Signature.get_dtree !sg None lc cst
  with e -> raise_as_env lc e

let export () =
  try Signature.export !sg
  with e -> raise_as_env dloc e

let import lc md =
  try Signature.import !sg lc md
  with e -> raise_as_env lc e

let _declare lc (id:ident) st ty : unit =
  match inference !sg ty with
  | Kind | Type _ -> Signature.add_declaration !sg lc id st ty
  | s -> raise (TypingError (SortExpected (ty,[],s)))

let is_static lc cst = Signature.is_static !sg lc cst

let _define lc (id:ident) (opaque:bool) (te:term) (ty_opt:typ option) : unit =
  let ty = match ty_opt with
    | None -> inference !sg te
    | Some ty -> ( checking !sg te ty; ty )
  in
  match ty with
  | Kind -> raise (EnvError (lc, KindLevelDefinition id))
  | _ ->
    if opaque then
      Signature.add_declaration !sg lc id Signature.Static ty
    else
      let _ = Signature.add_declaration !sg lc id Signature.Definable ty in
      let cst = mk_name (get_name ()) id in
      let rule =
        { name= Delta(cst) ;
          ctx = [] ;
          pat = Pattern(lc, cst, []);
          rhs = te ;
        }
      in
      Signature.add_rules !sg [rule]

let declare lc id st ty : unit =
  try _declare lc id st ty
  with e -> raise_as_env lc e

let define lc id op te ty_opt : unit =
  try _define lc id op te ty_opt
  with e -> raise_as_env lc e

let add_rules (rules: untyped_rule list) : (Subst.Subst.t * typed_rule) list =
  try
    let rs2 = List.map (check_rule !sg) rules in
    Signature.add_rules !sg rules;
    rs2
  with e -> raise_as_env (get_loc_rule (List.hd rules)) e

let infer ?ctx:(ctx=[]) te =
  try
    let ty = infer !sg ctx te in
    ignore(infer !sg ctx ty);
    ty
  with e -> raise_as_env (get_loc te) e

let check ?ctx:(ctx=[]) te ty =
  try check !sg ctx te ty
  with e -> raise_as_env (get_loc te) e

let _unsafe_reduction red te =
  Reduction.reduction red !sg te

let _reduction ctx red te =
  ignore(Typing.infer !sg ctx te);
  _unsafe_reduction red te

let reduction ?ctx:(ctx=[]) ?red:(red=Reduction.default_cfg) te =
  try  _reduction ctx red te
  with e -> raise_as_env (get_loc te) e

let unsafe_reduction ?red:(red=Reduction.default_cfg) te =
  try _unsafe_reduction red te
  with e -> raise_as_env (get_loc te) e

let are_convertible ?ctx:(ctx=[]) te1 te2 =
  try
    ignore(Typing.infer !sg ctx te1);
    ignore(Typing.infer !sg ctx te2);
    Reduction.are_convertible !sg te1 te2
  with e -> raise_as_env (get_loc te1) e
