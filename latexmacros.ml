(***********************************************************************)
(*                                                                     *)
(*                          HEVEA                                      *)
(*                                                                     *)
(*  Luc Maranget, projet PARA, INRIA Rocquencourt                      *)
(*                                                                     *)
(*  Copyright 1998 Institut National de Recherche en Informatique et   *)
(*  Automatique.  Distributed only by permission.                      *)
(*                                                                     *)
(***********************************************************************)

let header = "$Id: latexmacros.ml,v 1.19 1998-07-21 11:18:34 maranget Exp $" 
open Parse_opts
open Symb


type env =
  Style of string
| Font of int
| Color of string

let pretty_env = function
  Style s -> "Style: "^s
| Font i  -> "Font size: "^string_of_int i
| Color s  -> "Font color: "^s
;;

type action =
    Print of string
  | ItemDisplay
  | Print_arg of int
  | Print_fun of ((string -> string) * int)
  | Subst of string
  | Print_count of ((int -> string)  * int)
  | Env of env
  | Test of bool ref
  | SetTest of (bool ref * bool)
  | IfCond of bool ref * action list * action list
  | Br
;;

type pat = string list * string list
;;

let pretty_pat (_,args) =
  List.iter (fun s -> prerr_string s ; prerr_char ',') args
;;


let cmdtable =
  (Hashtbl.create 19 : (string, (pat * action list)) Hashtbl.t)
;;


let pretty_macro n acs =
   pretty_pat n ;
   match acs with
     [Subst s] -> Printf.fprintf stderr "{%s}\n" s
   | _         -> Printf.fprintf stderr "...\n"
;;

let def_macro_pat name pat action =
  if !verbose > 1 then begin
   Printf.fprintf stderr "def_macro %s = " name;
   pretty_macro pat action
  end ;
  try
    Hashtbl.find cmdtable name ;
    if not !silent then begin
      Location.print_pos () ;
      prerr_string "Ignoring definition of: "; prerr_endline name
    end
  with
    Not_found ->
      Hashtbl.add cmdtable name (pat,action)
;;

let redef_macro_pat name pat action =
  if !verbose > 1 then begin
   Printf.fprintf stderr "redef_macro %s = " name;
   pretty_macro pat action
  end ;
  try
    let _ = Hashtbl.find cmdtable name in
    Hashtbl.add cmdtable name (pat,action)
  with
    Not_found -> begin
      if not !silent then begin
        Location.print_pos () ;
        prerr_string "Defining a macro with \\renewcommand: ";
        prerr_endline name
      end ;
      Hashtbl.add cmdtable name (pat,action)
  end
;;
let provide_macro_pat name pat action =
  if !verbose > 1 then begin
   Printf.fprintf stderr "provide_macro %s = " name;
   pretty_macro pat action
  end ;
  try
    let _ = Hashtbl.find cmdtable name in
    Hashtbl.add cmdtable name (pat,action)
  with
    Not_found -> begin
      if !verbose > 1 then begin
        Location.print_pos () ;
        prerr_string "Providing non existing: "; prerr_endline name
      end ;
      Hashtbl.add cmdtable name (pat,action)
  end
;;

let make_pat opts n =
  let n_opts = List.length opts in
  let rec do_rec r i =
    if i <=  n_opts  then r
    else do_rec (("#"^string_of_int i)::r) (i-1) in
  opts,do_rec [] n
;;

let def_macro name nargs body =
  def_macro_pat name (make_pat [] nargs) body
and redef_macro name nargs body =
  redef_macro_pat name (make_pat [] nargs) body
;;
     
let def_env name body1 body2 =
 def_macro ("\\"^name) 0 body1 ;
 def_macro ("\\end"^name) 0 body2
;;

let def_env_pat name pat b1 b2 =
  def_macro_pat ("\\"^name) pat b1 ;
  def_macro ("\\end"^name) 0 b2
;;

let unregister name =  Hashtbl.remove cmdtable name
;;

let find_macro name =
  try
    Hashtbl.find cmdtable name
  with Not_found -> begin
    if not !silent then begin
      Location.print_pos () ;
      prerr_string "Unknown macro: "; prerr_endline name
    end ;
    (([],[]),[])
  end
;;

(* for conditionals *)
let display = ref false
and in_math = ref false
and alltt = ref false
and french = ref (match !language with Francais -> true | _ -> false)
and optarg = ref false
and styleloaded = ref false
;;


let extract_if name =
  let l = String.length name in
  if l <= 3 || String.sub name 0 3 <> "\\if" then
    raise (Failure ("Bad newif: "^name)) ;
  String.sub name 3 (l-3)
;;

let newif_ref name cell =
  def_macro ("\\if"^name) 0 [Test cell] ;
  def_macro ("\\"^name^"true") 0 [SetTest (cell,true)] ;
  def_macro ("\\"^name^"false") 0 [SetTest (cell,false)]
;;

newif_ref "silent" silent;
newif_ref "math" in_math ;
newif_ref "display" display ;
newif_ref "french" french ;
newif_ref "optarg" optarg;
newif_ref "styleloaded" styleloaded;
def_macro ("\\iftrue") 0 [Test (ref true)];
def_macro ("\\iffalse") 0 [Test (ref false)]
;;

let newif name = 
  let name = extract_if name in
  let cell = ref false in
  newif_ref name cell
;;


(* Base LaTeX macros *)

let def_style name style =
  def_env name [Env style] []
;;

exception NotEnv
;;

let rec as_env_rec name r =
  try match Hashtbl.find cmdtable name with
    _,[Subst s] ->
      List.fold_right as_env_rec
        (Save.macro_names (Lexing.from_string s)) r
  | _,[Env env] -> env :: r
  | _,_         -> raise NotEnv
  with Not_found -> raise NotEnv
;;

let as_env name = as_env_rec name []
;;

   

def_style "tt" (Style "TT");
def_style "bf" (Style  "B");
def_style "em" (Style "EM");
def_style "it" (Style "I");
def_style "tiny" (Font 1);
def_style "footnotesize" (Font 2);
def_style "scriptsize" (Font 2);
def_style "small" (Font 3);
def_style "normalsize" (Font 3);
def_style "large" (Font 4);
def_style "Large" (Font 5);
def_style "LARGE" (Font 5);
def_style "huge" (Font 6);
def_style "Huge" (Font 7);


def_style "purple" (Color "purple");
def_style "silver" (Color "silver");
def_style "gray" (Color "gray");
def_style "white" (Color "white");
def_style "maroon" (Color "maroon");
def_style "red" (Color "red");
def_style "fuchsia" (Color "fuchsia");
def_style "green" (Color "green");
def_style "lime" (Color "lime");
def_style "olive" (Color "olive");
def_style "yellow" (Color "yellow");
def_style "navy" (Color "navy");
def_style "blue" (Color "blue");
def_style "teal" (Color "teal");
def_style "aqua" (Color "aqua");
();;


def_env "program" [] [];
def_env "alltt" [] []
;;

let no_dot = function
  "." -> ""
| s   -> s in
def_macro "\\bgroup" 0 [Subst "{"] ;
def_macro "\\egroup" 0 [Subst "}"] ;
def_macro "\\textunderline" 1
  [Subst "{" ; Env (Style "U") ; Print_arg 0 ; Subst "}"];
def_macro "\\ref" 1
  [Print "<A href=\"#"; Subst "\\@print{#1}" ; Print "\">" ;
   Print_fun (Aux.rget,0) ; Print "</A>"];
def_macro "\\pageref" 1 [Print "<A href=\"#"; Print_arg 0; Print "\">X</A>"];

def_macro "\\@bibref" 1  [Print_fun (Aux.bget,0)] ;

let check_in = function
  "\\in" -> "\\notin"
| "="    -> "\\neq"
| "\\subset" -> "\\notsubset"
| s      -> "\\neg"^s in
def_macro "\\not" 1 [Print_fun (check_in,0)];
def_macro_pat "\\makebox" (["" ; ""],["#1"]) [Subst "\\warning{makebox}\\mbox{#3}"] ;
def_macro_pat "\\framebox" (["" ; ""],["#1"]) [Subst "\\warning{framebox}\\fbox{#3}"] ;


(*
let spaces = function
  ".5ex" -> ""
| _      -> "~" in
def_macro "\\hspace" 1 [Print_fun (spaces,0)];
*)
(* Maths *)
def_macro "\\alpha" 0 [Print alpha];
def_macro "\\beta" 0 [Print beta];
def_macro "\\gamma" 0 [Print gamma];
def_macro "\\delta" 0 [Print delta];
def_macro "\\epsilon" 0 [Print epsilon];
def_macro "\\varepsilon" 0 [Print varepsilon];
def_macro "\\zeta" 0 [Print zeta];
def_macro "\\eta" 0 [Print eta];
def_macro "\\theta" 0 [Print theta];
def_macro "\\vartheta" 0 [Print vartheta];
def_macro "\\iota" 0 [Print iota];
def_macro "\\kappa" 0 [Print kappa];
def_macro "\\lambda" 0 [Print lambda];
def_macro "\\mu" 0 [Print mu];
def_macro "\\nu" 0 [Print nu];
def_macro "\\xi" 0 [Print xi];
def_macro "\\pi" 0 [Print pi];
def_macro "\\varpi" 0 [Print varpi];
def_macro "\\rho" 0 [Print rho];
def_macro "\\varrho" 0 [Print varrho];
def_macro "\\sigma" 0 [Print sigma];
def_macro "\\varsigma" 0 [Print varsigma];
def_macro "\\tau" 0 [Print tau];
def_macro "\\upsilon" 0 [Print upsilon];
def_macro "\\phi" 0 [Print phi];
def_macro "\\varphi" 0 [Print varphi];
def_macro "\\chi" 0 [Print chi];
def_macro "\\psi" 0 [Print psi];
def_macro "\\omega" 0 [Print omega];

def_macro "\\Gamma" 0 [Print upgamma];
def_macro "\\Delta" 0 [Print updelta];
def_macro "\\Theta" 0 [Print uptheta];
def_macro "\\Lambda" 0 [Print uplambda];
def_macro "\\Xi" 0 [Print upxi];
def_macro "\\Pi" 0 [Print uppi];
def_macro "\\Sigma" 0 [Print upsigma];
def_macro "\\Upsilon" 0 [Print upupsilon];
def_macro "\\Phi" 0 [Print upphi];
def_macro "\\Psi" 0 [Print uppsi];
def_macro "\\Omega" 0 [Print upomega];
();;

def_macro "\\pm" 0 [Print pm];;
def_macro "\\mp" 0 [Print mp];;
def_macro "\\times" 0 [Print times];;
def_macro "\\div" 0 [Print div];;
def_macro "\\ast" 0 [Print ast];;
def_macro "\\circ" 0 [Print circ];;
def_macro "\\bullet" 0 [Subst "{\\@incsize{1}" ; Print bullet ; Subst "}"];;
def_macro "\\cap" 0 [Print cap];;
def_macro "\\cup" 0 [Print cup];;
def_macro "\\sqcap" 0 [Print sqcap];;
def_macro "\\sqcup" 0 [Print sqcup];;
def_macro "\\vee" 0 [Print vee];;
def_macro "\\wedge" 0 [Print wedge];;
def_macro "\\setminus" 0 [Print setminus];;
def_macro "\\bigtriangleup" 0 [Print bigtriangleup];;
def_macro "\\bigtriangledown" 0 [Print bigtriangledown];;
def_macro "\\triangleleft" 0 [Print triangleleft];;
def_macro "\\triangleright" 0 [Print triangleright];;
def_macro "\\lhd" 0 [Print triangleleft];;
def_macro "\\rhd" 0 [Print triangleright];;
def_macro "\\leq" 0 [Print leq];;
def_macro "\\subset" 0 [Print subset];;
def_macro "\\notsubset" 0 [Print notsubset];;
def_macro "\\subseteq" 0 [Print subseteq];;
def_macro "\\sqsubset" 0
  [IfCond (display,
    [Print display_sqsubset],
    [Print "sqsubset"])];;
def_macro "\\in" 0 [Print elem];;

def_macro "\\geq" 0 [Print geq];;
def_macro "\\supset" 0 [Print supset];;
def_macro "\\supseteq" 0 [Print supseteq];;
def_macro "\\sqsupset" 0
  [IfCond (display,
     [ItemDisplay ; Print display_sqsupset ; ItemDisplay],
     [Print "sqsupset"])];;
def_macro "\\equiv" 0 [Print equiv];;
def_macro "\\ni" 0 [Print ni];;


def_macro "\\sim" 0 [Print "~"];;
def_macro "\\simeq" 0
  [IfCond (display,
     [ItemDisplay ; Print "~<BR>-" ; ItemDisplay],
     [Print "simeq"])];;
def_macro "\\approx" 0 [Print approx];;
def_macro "\\neq" 0 [Print neq];;
def_macro "\\doteq" 0
  [IfCond (display,
     [ItemDisplay ; Print ".<BR>=" ; ItemDisplay],
     [Print "doteq"])];;
def_macro "\\propto" 0 [Print propto];;
def_macro "\\perp" 0 [Print perp];;

def_macro "\\leftarrow" 0 [Print leftarrow];;
def_macro "\\Leftarrow" 0 [Print upleftarrow];;
def_macro "\\rightarrow" 0 [Print rightarrow];;
def_macro "\\Rightarrow" 0 [Print uprightarrow];;
def_macro "\\leftrightarrow" 0 [Print leftrightarrow];;
def_macro "\\Leftrightarrow" 0 [Print upleftrightarrow];;
def_macro "\\longrightarrow" 0 [Print longrightarrow];;

def_macro "\\aleph" 0 [Print aleph];;
def_macro "\\wp" 0 [Print wp];;
def_macro "\\Re" 0 [Print upre];;
def_macro "\\Im" 0 [Print upim];;
def_macro "\\prim" 0 [Print prim];;
def_macro "\\nabla" 0 [Print nabla];;
def_macro "\\surd" 0 [Print surd];;
def_macro "\\angle" 0 [Print angle];;
def_macro "\\exists" 0 [Print exists];;
def_macro "\\forall" 0 [Print forall];;
def_macro "\\partial" 0 [Print partial];;
def_macro "\\diamond" 0 [Print diamond];;
def_macro "\\clubsuit" 0 [Print clubsuit];;
def_macro "\\diamondsuit" 0 [Print diamondsuit];;
def_macro "\\heartsuit" 0 [Print heartsuit];;
def_macro "\\spadesuit" 0 [Print spadesuit];;
def_macro "\\infty" 0 [Print infty];;

def_macro "\\lfloor" 0 [Print lfloor];;
def_macro "\\rfloor" 0 [Print rfloor];;
def_macro "\\lceil" 0 [Print lceil];;
def_macro "\\rceil" 0 [Print rceil];;
def_macro "\\langle" 0 [Print langle];;
def_macro "\\rangle" 0 [Print rangle];;

def_macro "\\notin" 0 [Print notin];;

def_macro "\\uparrow" 0 [Print uparrow];;
def_macro "\\Uparrow" 0 [Print upuparrow];;
def_macro "\\downarrow" 0 [Print downarrow];;
def_macro "\\Downarrow" 0 [Print updownarrow];;

def_macro "\\oplus" 0 [Print oplus];;
def_macro "\\otimes" 0 [Print otimes];;
def_macro "\\ominus" 0 [Print ominus];;


def_macro "\\sum" 0 [IfCond (display,[Env (Font 7)],[]) ; Print upsigma];
def_macro "\\int" 0
  [IfCond (display,
    [Print display_int],
    [Print int])];
();;

let alpha_of_int i = String.make 1 (Char.chr (i-1+Char.code 'a'))
and upalpha_of_int i = String.make 1 (Char.chr (i-1+Char.code 'A'))
;;

let rec roman_of_int = function
  0 -> ""
| 1 -> "i"
| 2 -> "ii"
| 3 -> "iii"
| 4 -> "iv"
| 9 -> "ix"
| i ->
   if i < 9 then "v"^roman_of_int (i-5)
   else
     let d = i / 10 and u = i mod 10 in
     String.make d 'x'^roman_of_int u
;;

let uproman_of_int i = String.uppercase (roman_of_int i)
;;

let fnsymbol_of_int = function
  0 -> " "
| 1 -> "*"
| 2 -> "#"
| 3 -> "%"
| 4 -> "\167"
| 5 -> "\182"
| 6 -> "||"
| 7 -> "**"
| 8 -> "##"
| 9 -> "%%"
| i -> alpha_of_int (i-9)
;;

        

let aigu = function
  "a" -> "�" | "e" -> "�" | "i" | "\\i" -> "�"
| "o" -> "�" | "u" -> "�"
| "A" -> "�" | "E" -> "�" | "I" | "\\I" -> "�"
| "O" -> "�" | "U" -> "�"
| "y" -> "�" | "Y" -> "�"
| "" | " " -> "'"
| s   -> s

and grave = function
  "a" -> "�" | "e" -> "�"  | "i" -> "�"
| "o" -> "�" | "u" -> "�"  | "\\i" -> "�"
| "A" -> "�" | "E" -> "�"  | "I" -> "�"
| "O" -> "�" | "U" -> "�"  | "\\I" -> "�"
| "" | " " -> "`"
| s -> s
and circonflexe = function
  "a" -> "�" | "e" -> "�"  | "i" -> "�"
| "o" -> "�" | "u" -> "�"  | "\\i" -> "�"
| "A" -> "�" | "E" -> "�"  | "I" -> "�"
| "O" -> "�" | "U" -> "�"  | "\\I" -> "�"
| "" | " " -> "\\@print{^}"
| s -> s

and trema = function
  "a" -> "�" | "e" -> "�"  | "i" -> "�"
| "o" -> "�" | "u" -> "�"  | "\\i" -> "�"
| "A" -> "�" | "E" -> "�"  | "I" -> "�"
| "O" -> "�" | "U" -> "�"  | "\\I" -> "�"
| "" | " " -> "�"
| s -> s

and cedille = function
  "c" -> "�"
| "C" -> "�"
| s   -> s

and tilde = function
  "a" -> "�" | "A" -> "�"
| "o" -> "�" | "O" -> "�"
| "n" -> "�" | "N" -> "�"
| "" | " " -> "\\@print{~}"
| s   -> s
;;


(* Accents *)
def_macro "\\'" 1 [Print_fun (aigu,0)];
def_macro "\\`" 1 [Print_fun (grave,0)];
def_macro "\\^" 1 [Print_fun (circonflexe,0)];
def_macro "\\\"" 1 [Print_fun (trema,0)];
def_macro "\\c" 1  [Print_fun (cedille,0)];
def_macro "\\~" 1 [Print_fun (tilde,0)];

(* Counters *)
def_macro "\\arabic" 1 [Print_count (string_of_int,0)] ;
def_macro "\\alph" 1 [Print_count (alpha_of_int,0)] ;
def_macro "\\Alph" 1 [Print_count (upalpha_of_int,0)] ;
def_macro "\\roman" 1 [Print_count (roman_of_int,0)];
def_macro "\\Roman" 1 [Print_count (uproman_of_int,0)];
def_macro "\\fnsymbol" 1 [Print_count (fnsymbol_of_int,0)];
def_macro "\\uppercase" 1 [Print_fun (String.uppercase,0)];
();;

let invisible = function
  "\\nofiles"
| "\\pagebreak" | "\\nopagebreak" | "\linebreak"
| "\\nolinebreak" | "\\label" | "\\index"
| "\\vspace" | "\\glossary" | "\\marginpar"
| "\\figure" | "\\table"
| "\\nostyle" | "\\rm" | "\\tt"
| "\\bf" | "\\em" | "\\it" | "\\sl" 
| "\\tiny" | "\\footnotesize" | "\\scriptsize"
| "\\small" | "\\normalsize" | "\\large" | "\\Large" | "\\LARGE"
| "\\huge" | "\\Huge"
| "\\purple" | "\\silver" | "\\gray" | "\\white"
| "\\maroon" | "\\red" | "\\fuchsia" | "\\green"
| "\\lime" | "\\olive" | "\\yellow" | "\\navy"
| "\\blue" | "\\teal" | "\\aqua" -> true
| _ -> false
;;

let limit = function
  "\\limits"
| "\\underbrace"
| "\\sum"
| "\\prod"
| "\\coprod"
| "\\bigcap"
| "\\bigcup"
| "\\bigsqcap"
| "\\bigsqcup"
| "\\bigodot"
| "\\bigdotplus"
| "\\biguplus"
| "\\det" | "\\gcd" | "\\inf" | "\\liminf" |
   "\\limsup" | "\\max" | "\\min" | "\\Pr" | "\\sup" -> true
| _ -> false
;;

let int = function
  "\\int"
| "\\oint" -> true
| _ -> false
;;

let big = function
  "\\sum"
| "\\prod"
| "\\coprod"
| "\\int"
| "\\oint"
| "\\bigcap"
| "\\bigcup"
| "\\bigsqcap"
| "\\bigsqcup"
| "\\bigodot"
| "\\bigdotplus"
| "\\biguplus" -> true
| _ -> false
