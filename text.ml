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

let header = "$Id: text.ml,v 1.61 2004-07-22 18:55:06 thakur Exp $"


open Misc
open Parse_opts
open Element
open Lexstate
open Latexmacros
open Stack
open Length

exception Error of string;;
type block = string


let r_quote = String.create 1
;;

let quote c =
  (r_quote.[0] <- c ; r_quote)
;;

let r_translate = String.create 1
;;

let iso_translate = function
| '�' -> "!"
| '�' -> "cent"
| '�' -> "pound"
| '�' -> "curren"
| '�' -> "yen"
| '�' -> "I"
| '�' -> "paragraphe"
| '�' -> "trema"
| '�' -> "copyright"
| '�' -> "a"
| '�' -> "<<"
| '�' -> "not"
| '�' -> "-"
| '�' -> "registered"
| '�' -> "-"
| '�' -> "degre"
| '�' -> "plus ou moins"
| '�' -> "carre"
| '�' -> "cube"
| '�' -> "'"
| '�' -> "mu"
| '�' -> ""
| '�' -> "."
| '�' -> ""
| '�' -> "1"
| '�' -> "eme"
| '�' -> ">>"
| '�' -> "1/4"
| '�' -> "1/2"
| '�' -> "3/4"
| '�' -> "?"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "A"
| '�' -> "AE"
| '�' -> "C"
| '�' -> "E"
| '�' | '�' | '�' -> "E"
| '�' | '�' | '�' | '�' -> "I"
| '�' -> "D"
| '�' -> "N"
| '�' | '�' | '�' | '�' | '�' -> "O"
| '�' -> "x"
| '�' -> "0"
| '�' | '�' | '�' | '�' -> "U"
| '�' -> "Y"
| '�' -> "P"
| '�' -> "ss"
| '�' | '�' | '�' | '�' | '�' | '�' -> "a"
| '�' -> "ae"
| '�' -> "c"
| '�' | '�' | '�' | '�' -> "e"
| '�' | '�' | '�' | '�' -> "i"
| '�' -> "o"
| '�' -> "n"
| '�' | '�' | '�' | '�' | '�' -> "o"
| '�' -> "/"
| '�' -> "o"
| '�' | '�' | '�' | '�' -> "u"
| '�' -> "y"
| '�' -> "y"
| '�' -> "y"
| c   -> (r_translate.[0] <- c ; r_translate)
;;

let iso c =
  if !Parse_opts.iso || !Lexstate.raw_chars then
    (r_translate.[0]<-c; r_translate)
  else
    iso_translate c
;;

let iso_buff = Out.create_buff ()

let iso_string s =
  if !Parse_opts.iso then begin
    for i = 0 to String.length s - 1 do
      Out.put iso_buff (iso_translate s.[i])
    done ;
    Out.to_string iso_buff
  end else
    s


let failclose s = raise (Misc.Close s)
;;


(* output globals *)
type status = {
    mutable nostyle : bool ;
    mutable active : text list ;
    mutable out : Out.t;
    mutable temp : bool
  };;


type stack_item =
  Normal of string * string * status
| Freeze of (unit -> unit)
;;

exception PopFreeze
;;

let push_out s (a,b,c) = push s (Normal (a,b,c))
;;

let pretty_stack s =
  Stack.pretty
   (function
     | Normal (s,args,_) -> "["^s^"]-{"^args^"} "
     | Freeze _   -> "Freeze ") s
;;

let rec pop_out s = match pop s with
  Normal (a,b,c) -> a,b,c
| Freeze f       -> raise PopFreeze
;;

let free_list = ref [];;

let out_stack = Stack.create "out_stack";;

let pblock () =
  if empty out_stack then "" else
  match top out_stack with
  | Normal (s,_,_) -> s
  | _ -> ""
and parg () =
  if empty out_stack then "" else
  match top out_stack with
  | Normal (_,a,_) -> a
  | _ -> ""
;;

let free out =
  out.nostyle<-false;
  out.active<-[];
  Out.reset out.out;
  free_list := out :: !free_list
;;




let cur_out = ref { nostyle = false;
                    active=[];
                    out=Out.create_null();
		    temp=false
};;

let set_out out =  
  !cur_out.out <- out
;;

let newstatus nostyle p a t = match !free_list with
  [] ->
    { nostyle = nostyle;
      active = a;
      out = Out.create_buff ();
      temp = t;
    } 
| e::reste ->
    free_list:=reste;
    e.nostyle <- nostyle;
    e.active <- a;
    e.temp <- t;
    assert (Out.is_empty e.out);
    e
;;

type saved_out = status * stack_item Stack.saved

let save_out () = !cur_out, Stack.save out_stack

and restore_out (a,b) =
  if !cur_out != a then begin
    free !cur_out ;
    Stack.finalize out_stack
      (function
        | Normal (_,_,out) -> out == a
        | _ -> false)
      (function
        | Normal (_,_,out) -> if out.temp then free out
        | _ -> ())
  end ;  
  cur_out := a ;
  Stack.restore out_stack b


type align_t = Left | Center | Right

type flags_t = {
    mutable pending_par : int option;
    mutable empty : bool;
    (* Listes *)
    mutable nitems : int;
    mutable dt : string;
    mutable dcount : string;
    
    mutable last_closed : string;
    (* Alignement et formattage *)
    mutable align : align_t;
    mutable in_align : bool;
    mutable hsize : int;
    mutable x : int;
    mutable x_start : int;
    mutable x_end : int;
    mutable last_space : int;
    mutable first_line : int;
    mutable underline : string;
    mutable nocount : bool ;
    mutable in_table : bool;
    
    (* Maths *)
    mutable vsize : int;
  }
;;

let flags = {
  pending_par = None;
  empty = true;
  nitems = 0;
  dt = "";
  dcount = "";
  last_closed = "rien";
  align = Left;
  in_align = false;
  hsize = !Parse_opts.width;
  x = 0;
  x_start = 0;
  x_end = !Parse_opts.width - 1;
  last_space = 0;
  first_line = 2;
  underline = "";
  nocount = false ;
  in_table = false;
  vsize = 0;
} ;;

let copy_flags f = {f with vsize = flags.vsize}

and set_flags f {
  pending_par = pending_par ;
  empty = empty ;
  nitems = nitems ;
  dt = dt ;
  dcount = dcount ;
  last_closed = last_closed ;
  align = align ;
  in_align = in_align ;
  hsize = hsize ;
  x = x ;
  x_start = x_start ;
  x_end = x_end ;
  last_space = last_space ;
  first_line = first_line ;
  underline = underline ;
  nocount = nocount ;
  in_table = in_table ;
  vsize = vsize
}  =
  f.pending_par <- pending_par ;
  f.empty <- empty ;
  f.nitems <- nitems ;
  f.dt <- dt ;
  f.dcount <- dcount ;
  f.last_closed <- last_closed ;
  f.align <- align ;
  f.in_align <- in_align ;
  f.hsize <- hsize ;
  f.x <- x ;
  f.x_start <- x_start ;
  f.x_end <- x_end ;
  f.last_space <- last_space ;
  f.first_line <- first_line ;
  f.underline <- underline ;
  f.nocount <- nocount ;
  f.in_table <- in_table ;
  f.vsize <- vsize


type stack_t = {
  s_nitems : int Stack.t ;
  s_dt : string Stack.t ;
  s_dcount : string Stack.t ;
  s_x : (int * int * int * int * int * int) Stack.t ;
  s_align : align_t Stack.t ;
  s_in_align : bool Stack.t ;
  s_underline : string Stack.t ;
  s_nocount : bool Stack.t ;
  s_in_table : bool Stack.t ;
  s_vsize : int Stack.t ;
  s_active : Out.t Stack.t ;
  s_pending_par : int option Stack.t ;
  s_after : (string -> string) Stack.t
} 

let stacks = {
  s_nitems = Stack.create "nitems" ;
  s_dt = Stack.create "dt" ;
  s_dcount = Stack.create "dcount" ;
  s_x = Stack.create "x" ;
  s_align = Stack.create "align" ;
  s_in_align = Stack.create "in_align" ;
  s_underline = Stack.create "underline" ;
  s_nocount = Stack.create "nocount" ;
  s_in_table = Stack.create "in_table" ;
  s_vsize = Stack.create "vsize" ;
  s_active = Stack.create "active" ;
  s_pending_par = Stack.create "pending_par" ;
  s_after = Stack.create "after"
} 

type saved_stacks = {
  ss_nitems : int Stack.saved ;
  ss_dt : string Stack.saved ;
  ss_dcount : string Stack.saved ;
  ss_x : (int * int * int * int * int * int) Stack.saved ;
  ss_align : align_t Stack.saved ;
  ss_in_align : bool Stack.saved ;
  ss_underline : string Stack.saved ;
  ss_nocount : bool Stack.saved ;
  ss_in_table : bool Stack.saved ;
  ss_vsize : int Stack.saved ;
  ss_active : Out.t Stack.saved ;  
  ss_pending_par : int option Stack.saved ;
  ss_after : (string -> string) Stack.saved
} 

let save_stacks () =
{
  ss_nitems = Stack.save stacks.s_nitems ;
  ss_dt = Stack.save stacks.s_dt ;
  ss_dcount = Stack.save stacks.s_dcount ;
  ss_x = Stack.save stacks.s_x ;
  ss_align = Stack.save stacks.s_align ;
  ss_in_align = Stack.save stacks.s_in_align ;
  ss_underline = Stack.save stacks.s_underline ;
  ss_nocount = Stack.save stacks.s_nocount ;
  ss_in_table = Stack.save stacks.s_in_table ;
  ss_vsize = Stack.save stacks.s_vsize ;
  ss_active = Stack.save stacks.s_active ;
  ss_pending_par = Stack.save stacks.s_pending_par ;
  ss_after = Stack.save stacks.s_after
}

and restore_stacks 
{
  ss_nitems = saved_nitems ;
  ss_dt = saved_dt ;
  ss_dcount = saved_dcount ;
  ss_x = saved_x ;
  ss_align = saved_align ;
  ss_in_align = saved_in_align ;
  ss_underline = saved_underline ;
  ss_nocount = saved_nocount ;
  ss_in_table = saved_in_table ;
  ss_vsize = saved_vsize ;
  ss_active = saved_active ;
  ss_pending_par = saved_pending_par ;
  ss_after = saved_after
} =
  Stack.restore stacks.s_nitems saved_nitems ;
  Stack.restore stacks.s_dt saved_dt ;
  Stack.restore stacks.s_dcount saved_dcount ;
  Stack.restore stacks.s_x saved_x ;
  Stack.restore stacks.s_align saved_align ;
  Stack.restore stacks.s_in_align saved_in_align ;
  Stack.restore stacks.s_underline saved_underline ;
  Stack.restore stacks.s_nocount saved_nocount ;
  Stack.restore stacks.s_in_table saved_in_table ;
  Stack.restore stacks.s_vsize saved_vsize ;
  Stack.restore stacks.s_active saved_active ;
  Stack.restore stacks.s_pending_par saved_pending_par ;
  Stack.restore stacks.s_after saved_after

let check_stack what =
  if not (Stack.empty what)  && not !silent then begin
    prerr_endline
      ("Warning: stack "^Stack.name what^" is non-empty in Html.finalize") ;
  end
;;

let check_stacks () = match stacks with
{
  s_nitems = nitems ;
  s_dt = dt ;
  s_dcount = dcount ;
  s_x = x ;
  s_align = align ;
  s_in_align = in_align ;
  s_underline = underline ;
  s_nocount = nocount ;
  s_in_table = in_table ;
  s_vsize = vsize ;
  s_active = active ;
  s_pending_par = pending_par ;
  s_after = after
} ->
  check_stack nitems ;
  check_stack dt ;
  check_stack dcount ;
  check_stack x ;
  check_stack align ;
  check_stack in_align ;
  check_stack underline ;
  check_stack nocount ;
  check_stack in_table ;
  check_stack vsize ;
  check_stack active ;
  check_stack pending_par ;
  check_stack after

let line = String.create (!Parse_opts.width +2);;

type saved = string * flags_t * saved_stacks * saved_out

let check () =
  let saved_flags = copy_flags flags
  and saved_stacks = save_stacks ()
  and saved_out = save_out () in
  String.copy line, saved_flags, saved_stacks, saved_out

  
and hot (l,f,s,o) =
  String.blit  l 0 line 0 (String.length l) ;
  set_flags flags f ;
  restore_stacks s ;
  restore_out o

let stop () =
  Stack.push stacks.s_active !cur_out.out ;
  Stack.push stacks.s_pending_par flags.pending_par ;
  !cur_out.out <- Out.create_null ()

and restart () =
  !cur_out.out <- Stack.pop stacks.s_active ;
  flags.pending_par <- Stack.pop stacks.s_pending_par

let do_do_put_char c =
  Out.put_char !cur_out.out c;;

let do_do_put  s =
  Out.put !cur_out.out s;;


let do_put_line s =
  (* Ligne a formatter selon flags.align, avec les parametres courants.*)
  (* soulignage eventuel *)
  let taille = String.length s in
  let length = if s.[taille-1]='\n' then taille-1 else taille in
  let soul = ref false in
  for i = 0 to length - 1 do
    soul := !soul || s.[i] <> ' ';
  done;
  soul := !soul && s<>"\n" && flags.underline <> "";

  let ligne = match flags.align with
  | Left -> s
  | Center ->
      let sp = (flags.hsize - (length -flags.x_start))/2 in
      String.concat "" [String.make sp ' '; s]
  | Right ->
      let sp = flags.hsize - length + flags.x_start in
      String.concat "" [ String.make sp ' '; s]
  in
  if !verbose > 3 then prerr_endline ("line :"^ligne);
  do_do_put ligne;


  if !soul then begin
    let souligne =
      let l = String.make taille ' ' in
      let len = String.length flags.underline in
      if len = 0 then raise (Misc.Fatal ("cannot underline with nothing:#"
					 ^String.escaped flags.underline^"#"^
					 (if  (flags.underline <> "") then "true" else "false"
					   )));
      for i = flags.x_start to length -1 do
	l.[i]<-flags.underline.[(i-flags.x_start) mod len]
      done;
      if taille <> length then l.[length]<-'\n';
      match flags.align with
      | Left -> l
      | Center ->
	  let sp = (flags.hsize - length)/2 +flags.x_start/2 in
	  String.concat "" [String.make sp ' '; l]
      | Right ->
	  let sp = (flags.hsize - length) + flags.x_start in
	  String.concat "" [ String.make sp ' '; l]
    in
    if !verbose >3 then prerr_endline ("line underlined:"^souligne); 
 
    do_do_put souligne;
  end
;;

let do_flush () =
  if !verbose>3 && flags.x >0 then
    prerr_endline ("flush :#"^(String.sub line 0 (flags.x))^"#");
  if flags.x >0 then do_put_line (String.sub line 0 (flags.x)) ;
  flags.x <- -1;
;;
  
let do_put_char_format c =
  if !verbose > 3 then
    prerr_endline ("caracters read : '"^Char.escaped c^"', x="^string_of_int flags.x^", length ="^string_of_int (flags.hsize));

  if c=' ' then  flags.last_space <- flags.x;
  if flags.x =(-1) then begin
    (* La derniere ligne finissait un paragraphe : on indente *)
    flags.x<-flags.x_start + flags.first_line;   
    for i = 0 to flags.x-1 do
      line.[i]<-' ';
    done;
    flags.last_space<-flags.x-1;
  end;
  line.[flags.x]<-c;
  if c='\n' then begin
	(* Ligne prete *)
    if !verbose > 2 then
      prerr_endline("line not cut :["^line^"]");
    do_put_line (String.sub line 0 (flags.x +1));
    flags.x <- -1;
  end else
    flags.x<-flags.x + 1;
  if flags.x>(flags.x_end +1) then begin (* depassement de ligne *)
    if (flags.x - flags.last_space) >= flags.hsize then begin
	  (* On coupe brutalement le mot trop long *)
      if !verbose > 2 then
	prerr_endline ("line cut :"^line);
      warning ("line too long");
      line.[flags.x-1]<-'\n';
	  (* La ligne est prete et complete*)
      do_put_line (String.sub line 0 (flags.x));
      for i = 0 to flags.x_start-1 do line.[i]<-' ' done;
      line.[flags.x_start]<-c;
      flags.x<-flags.x_start + 1;
      flags.last_space<-flags.x_start-1;
    end else begin
      if !verbose > 2 then begin
	prerr_endline ("Line and the beginning of the next word :"^line);
	prerr_endline ("x ="^string_of_int flags.x);
	prerr_endline ("x_start ="^string_of_int flags.x_start);
	prerr_endline ("x_end ="^string_of_int flags.x_end);
	prerr_endline ("hsize ="^string_of_int flags.hsize);
	prerr_endline ("last_space ="^string_of_int flags.last_space);
	prerr_endline ("line size ="^string_of_int (String.length line));
      end;
	  (* On repart du dernier espace *)
      let reste = 
	let len = flags.x - flags.last_space -1 in
	if len = 0 then ""
	else
	  String.sub line (flags.last_space +1) len
      in
	  (* La ligne est prete et incomplete*)
      line.[flags.last_space]<-'\n';
      do_put_line (String.sub line 0 (flags.last_space+1));
      
      for i = 0 to flags.x_start-1 do line.[i]<-' ' done;
      for i = flags.x_start to (flags.x_start+ String.length reste -1) do
	line.[i]<- reste.[i-flags.x_start];
      done;
      flags.x<- flags.x_start + (String.length reste);
      flags.last_space <- flags.x_start-1;
    end;
  end;
;;  

let do_put_char c =
  if !verbose>3 then
    prerr_endline ("put_char:|"^String.escaped (String.make 1 c)^"|");
  if !cur_out.temp || (Out.is_null !cur_out.out) 
  then do_do_put_char c
  else do_put_char_format c
;;

let finit_ligne () =
  if !verbose>3 then prerr_endline "ending the line.";
  if flags.x >0 then do_put_char '\n'
;;

let do_unskip () =
  if !cur_out.temp || (Out.is_null !cur_out.out) then
    Out.unskip !cur_out.out
  else begin
    while flags.x > flags.x_start && line.[flags.x-1] = ' ' do
      flags.x <- flags.x - 1
    done ;
    flags.last_space <-  flags.x ;
    while
      flags.last_space >=  flags.x_start &&
      line.[flags.last_space] <> ' '
    do
      flags.last_space <- flags.last_space - 1
    done;
    if flags.x = flags.x_start && !cur_out.temp then
      Out.unskip !cur_out.out    
  end


let do_put s =
  if !verbose>3 then
    prerr_endline ("put:|"^String.escaped s^"|");
    for i = 0 to String.length s - 1 do
      do_put_char s.[i]
    done
;;


let get_last_closed () = flags.last_closed;;
let set_last_closed s = flags.last_closed<-s;;

(* Gestion des styles : pas de style en mode texte *)

let is_list = function
  | "UL" | "DL" | "OL" -> true
  | _ -> false
;;

let get_fontsize () = 3;;

let nostyle () =
  !cur_out.nostyle<-true
;;

let clearstyle () =
  !cur_out.active<-[]
;;

let open_mod m =
  if m=(Style "CODE") then begin 
    do_put "`";
    !cur_out.active <- m::!cur_out.active
  end;
;;

let do_close_mod = function
  |  Style "CODE" ->
      do_put "'";
  | _ -> ()
;;

let close_mod () = match !cur_out.active with
  [] -> ()
| (Style "CODE" as s)::reste ->
    do_close_mod s;
    !cur_out.active <- reste
| _ -> ()
;;

let erase_mods ml = ()
;;

let rec open_mods = function
  | [] -> ()
  | s::reste -> open_mod s; open_mods reste
;;

let close_mods () = 
  List.iter do_close_mod !cur_out.active;
  !cur_out.active <- []
;;

let par = function (*Nombre de lignes a sauter avant le prochain put*)
  | Some n as p->
      begin
	flags.pending_par <-
	  (match pblock() with
	  | "QUOTE" | "QUOTATION" -> Some (n-1)
	  | _ -> Some n);
	if !verbose> 2 then
	  prerr_endline
	    ("par: last_close="^flags.last_closed^
	     " r="^string_of_int n);
      end
  | _ -> ()


let forget_par () = 
  let r = flags.pending_par in
  flags.pending_par <- None;
  r
;;

let flush_par n =
  flags.pending_par <- None;
  let p = n in
  do_put_char '\n' ;
  for i=1 to p-1 do
    do_put_char '\n'
  done;
  if !verbose >2 then
    prerr_endline
      ("flush_par : last_closed="^flags.last_closed^
       "p="^string_of_int p);
  flags.last_closed<-"rien"
;;

let try_flush_par () =
  match flags.pending_par with
  | Some n -> flush_par n
  | _ -> ()
;;

let do_pending () =
  begin match flags.pending_par with
  | Some n -> flush_par n
  | _ -> ()
  end;
  flags.last_closed <- "rien";
;;

(* Blocs *)

let try_open_block s args =
  (* Prepare l'environnement specifique au bloc en cours *)
  if !verbose > 2 then
    prerr_endline ("=> try_open ``"^s^"''");

  push stacks.s_x
    (flags.hsize,flags.x,flags.x_start,flags.x_end,
    flags.first_line,flags.last_space);

  push stacks.s_align flags.align;
  push stacks.s_in_align flags.in_align;

  if is_list s then begin
    do_put_char '\n';
    push stacks.s_nitems flags.nitems;
    flags.nitems <- 0;
    flags.x_start <- flags.x_start + 3;
    flags.first_line <- -2;    
    flags.hsize <- flags.x_end - flags.x_start+1;
    
    if not flags.in_align then begin
      flags.align <- Left
    end;
    if s="DL" then begin
      push stacks.s_dt flags.dt;
      push stacks.s_dcount flags.dcount;
      flags.dt <- "";
      flags.dcount <- "";
    end;
  end else begin match s with
  | "ALIGN" ->
      begin
	finit_ligne ();	
	flags.in_align<-true;
	flags.first_line <-2;
	match args with
	  "LEFT" -> flags.align <- Left
	| "CENTER" -> flags.align <- Center
	| "RIGHT" -> flags.align <- Right
	| _ -> raise (Misc.ScanError "Invalid argument in ALIGN");
      end
  |  "HEAD" ->
      begin
	finit_ligne ();
	flags.first_line <-0 ;
	push stacks.s_underline flags.underline;
	flags.underline <- args;
      end
  | "QUOTE" ->
      begin
	finit_ligne ();
	flags.in_align<-true;
	flags.align <- Left;
	flags.first_line<-0;
	flags.x_start<- flags.x_start + 20 * flags.hsize / 100;
	flags.hsize <- flags.x_end - flags.x_start+1;
      end
  | "QUOTATION" ->
      begin
	finit_ligne ();
	flags.in_align<-true;
	flags.align <- Left;
	flags.first_line<-2;
	flags.x_start<- flags.x_start + 20 * flags.hsize / 100;
	flags.hsize <- flags.x_end - flags.x_start+1;
      end
  | "PRE" ->
      flags.first_line <-0;
      finit_ligne ();
      do_put "<<";
      flags.first_line <-2;
  | "INFO" ->
      push stacks.s_nocount flags.nocount ;
      flags.nocount <- true ;
      flags.first_line <-0
  | "INFOLINE" ->
      push stacks.s_nocount flags.nocount ;
      flags.nocount <- true ;
      flags.first_line <-0 ;
      finit_ligne ()
  | _ -> ()
  end ;

  if !verbose > 2 then
    prerr_endline ("<= try_open ``"^s^"''")
;;
    
let try_close_block s =
  let (h,x,xs,xe,fl,lp) = pop stacks.s_x in
  flags.hsize<-h; 
  flags.x_start<-xs;
  flags.x_end<-xe;
  flags.first_line <-fl;

  if (is_list s) then begin
    finit_ligne();
    flags.nitems <- pop  stacks.s_nitems;
    if s="DL" then begin
      flags.dt <- pop stacks.s_dt;
      flags.dcount <- pop stacks.s_dcount
    end
  end else begin match s with
  | "ALIGN" | "QUOTE" | "QUOTATION" ->
	finit_ligne ()
  | "HEAD" ->
      finit_ligne();
      let u = pop stacks.s_underline in
      flags.underline <- u
  | "PRE" ->
      flags.first_line <-0;
      do_put ">>\n";
      flags.first_line <-fl
  | "INFO"|"INFOLINE"->
      flags.nocount <- pop stacks.s_nocount
  | _ -> ()
  end ;
  let a = pop stacks.s_align in
  flags.align <- a;
  let ia = pop  stacks.s_in_align in
  flags.in_align <- ia
;;

let open_block s args =
  (* Cree et se place dans le bloc de nom s et d'arguments args *)
  if !verbose > 2 then
    prerr_endline ("=> open_block ``"^s^"''");
  let bloc,arg =
    if s="DIV" && args="ALIGN=center" then
      "ALIGN","CENTER"
    else s,args
  in
  push_out out_stack (bloc,arg,!cur_out);
  try_flush_par ();
  (* Sauvegarde de l'etat courant *)
  
  if !cur_out.temp || s="TEMP" || s="AFTER" then begin
    cur_out :=
      newstatus
	!cur_out.nostyle
	!cur_out.active
	[] true;
  end;
  try_open_block bloc arg;
  if !verbose > 2 then
    prerr_endline ("<= open_block ``"^bloc^"''")
;;

let force_block s content =  
  if !verbose > 2 then
    prerr_endline ("   force_block ``"^s^"''");
  let old_out = !cur_out in
  try_close_block s;
  let ps,pa,pout = pop_out out_stack in
  if ps <>"DELAY" then begin
    cur_out:=pout;
    if ps = "AFTER" then begin
        let f = pop stacks.s_after in
        Out.copy_fun f old_out.out !cur_out.out          
    end else if !cur_out.temp then
      Out.copy old_out.out !cur_out.out;
    flags.last_closed<- s;
    if !cur_out.temp then
      free old_out;
  end else raise ( Misc.Fatal "text: unflushed DELAY")
;;

let close_block s =
  (* Fermeture du bloc : recuperation de la pile *)
  if !verbose > 2 then
    prerr_endline ("=> close_block ``"^s^"''");
  let bloc =  if s = "DIV" then "ALIGN" else s in
  force_block bloc "";
  if !verbose > 2 then
    prerr_endline ("<= close_block ``"^bloc^"''");
;;



let insert_block tag arg =  match arg with
| "LEFT" -> flags.align <- Left
| "CENTER" -> flags.align <- Center
| "RIGHT" -> flags.align <- Right
| _ -> raise (Misc.ScanError "Invalid argument in ALIGN");

and insert_attr _ _ = ()
;;


(* Autres *)

(* Listes *)
let set_dt s = flags.dt <- s

and set_dcount s = flags.dcount <- s
;;

let do_item isnum =
  if !verbose > 2 then begin
    prerr_string "do_item: stack=";
    pretty_stack out_stack
  end;
  let mods = !cur_out.active in
  if flags.nitems = 0 then begin let _ = forget_par () in () end ;
  try_flush_par () ;
  flags.nitems<-flags.nitems+1;
  if isnum then
    do_put ("\n"^(string_of_int flags.nitems)^". ")
  else
    do_put "\n- "
;;

let item () = do_item false
and nitem () = do_item true
;;

    
let ditem scan arg =
  if !verbose > 2 then begin
    prerr_string "ditem: stack=";
    pretty_stack out_stack
  end;
  
  let mods = !cur_out.active in
  let true_scan =
    if flags.nitems = 0 then begin
      let _ = forget_par() in ();
      ( fun arg -> scan arg)
    end else scan in
  
  try_flush_par();
  flags.nitems<-flags.nitems+1;
  do_put_char '\n';
  if flags.dcount <> "" then scan("\\refstepcounter{"^flags.dcount^"}");
  true_scan ("\\makelabel{"^arg^"}") ;
  do_put_char ' '
;;



let erase_block s = 
  if not !cur_out.temp then close_block s
  else begin
    if !verbose > 2 then begin
      Printf.fprintf stderr "erase_block: %s" s;
      prerr_newline ()
    end ;
    try_close_block s ;
    let ts,_,tout = pop_out out_stack in
    if ts <> s then
      failclose ("erase_block: "^s^" closes "^ts);
    free !cur_out ;
    cur_out := tout
  end
;;

let to_string f =
  open_block "TEMP" "";
  f () ;
  let r = Out.to_string !cur_out.out in
  close_block "TEMP";
  r
;;

let open_group ss =  
  open_block "" "";
  open_mod (Style ss);
;;

let open_aftergroup f =
  open_block "AFTER" "" ;
  push stacks.s_after f
;;

let close_group () =
  close_mod ();
  close_block "";
;;


let put s =
  if !verbose > 3 then
    Printf.fprintf stderr "put: %s\n" s ;
  do_pending ();
  do_put s
;;

let put_char c =
  if !verbose > 3 then
    Printf.fprintf stderr "put_char: %c\n" c ;
  do_pending ();
  do_put_char c
;;

let flush_out () =
  Out.flush !cur_out.out
;;

let skip_line () =
  if !verbose > 2 then
    prerr_endline "skip_line" ;
  put_char '\n'
;;

let loc_name s1 = ()
;;

let open_chan chan =
  free !cur_out;
  !cur_out.out<- Out.create_chan chan
;;

let close_chan () =
  Out.close !cur_out.out;
  !cur_out.out <- Out.create_buff()
;;


let to_style f =
  !cur_out.active<-[];
  open_block "TEMP" "";
  f ();
  let r = !cur_out.active in
  erase_block "TEMP";
  r
;;

let get_current_output () =
  Out.to_string !cur_out.out
;;

let finalize check =
  if check then
    check_stacks () ;
  finit_ligne () ;
  Out.close !cur_out.out ;
  !cur_out.out <- Out.create_null ()
;;




let unskip () = do_unskip ()

let put_separator () = put " "
;;

let put_tag tag = ()
;;

let put_nbsp () =  put " "
;;

let put_open_group () =
  ()
;;

let put_close_group () =
  ()
;;

let put_in_math s =
  put s
;;


(*--------------*)
(*-- TABLEAUX --*)
(*--------------*)

type align = Top | Middle | Bottom | Base of int
and wrap_t = Wtrue | Wfalse | Fill
;;


type cell_t = {
    mutable ver : align;
    mutable hor : align_t;
    mutable h : int;
    mutable w : int;
    mutable wrap : wrap_t;
    mutable span : int; (* Nombre de colonnes *)
    mutable text : string;
    mutable pre  : string; (* bordures *)
    mutable post : string;
    mutable pre_inside  : int list;
    mutable post_inside : int list;
  } 
;;

type cell_set = Tabl of cell_t Table.t | Arr of cell_t array
;;

type row_t = {
    mutable haut : int;
    mutable cells : cell_set;
  } 
;;

type table_t = {
    mutable lines : int;
    mutable cols : int;
    mutable width : int;
    mutable taille : int Table.t;
    mutable tailles : int array;
    mutable table : row_t Table.t;
    mutable line : int;
    mutable col : int;
    mutable in_cell : bool;
  } 
;;

let ptailles chan table =
  let t = table.tailles in
  Printf.fprintf chan  "[" ;
  for i = 0 to Array.length t-1 do
    Printf.fprintf chan "%d; " t.(i)
  done ;
  Printf.fprintf chan  "]"

let ptaille chan table =
  let t = Table.to_array table.taille in
  Printf.fprintf chan  "[" ;
  for i = 0 to Array.length t-1 do
    Printf.fprintf chan "%d; " t.(i)
  done ;
  Printf.fprintf chan  "]"

let cell = ref {
  ver = Middle;
  hor = Left;
  h = 0;
  w = 0;
  wrap = Wfalse;
  span = 1;
  text = "";
  pre  = "";
  post = "";
  pre_inside  = [];
  post_inside = [];
} 
;;

let row= ref {
  haut = 0;
  cells = Tabl (Table.create  !cell)
} 
;;

let table =  ref {
  lines = 0;
  cols = 0;
  width = 0;
  taille = Table.create 0;
  tailles = Array.create 0 0;
  table = Table.create {haut = 0; cells = Arr (Array.create 0 !cell)};
  line = 0;
  col = 0;
  in_cell = false;
} 
;;

let table_stack = Stack.create "table_stack";;
let row_stack = Stack.create "row_stack";;
let cell_stack = Stack.create "cell_stack";;

let multi = ref []
and multi_stack = Stack.create "multi_stack";;


let open_table border _ =
  (* creation d'une table : on prepare les donnees : creation de l'environnement qvb, empilage du precedent. *)
  push table_stack !table;
  push row_stack !row;
  push cell_stack !cell;
  push stacks.s_in_table flags.in_table;
  push multi_stack !multi;
  push stacks.s_align flags.align;

  if !verbose>2 then prerr_endline "=> open_table";
  
  finit_ligne ();
  open_block "" "";
  flags.first_line <- 0;

  table := {
    lines = 0;
    cols = 0;
    width = 0;
    taille = Table.create 0;
    tailles = Array.create 0 0;
    table = Table.create {haut = 0; cells = Arr (Array.create 0 !cell)};
    line = -1;
    col = -1;
    in_cell = false;
  };
    
  row := {
    haut = 0;
    cells = Tabl (Table.create  !cell)
  };

  cell :=  {
    ver = Middle;
    hor = Left;
    h = 0;
    w = 0;
    wrap = Wfalse;
    span = 1;
    text = "";
    pre  = "";
    post = "";
    pre_inside  = [];
    post_inside = [];
  };

  multi := [];
  flags.in_table<-true;
;;

let register_taille table =
  let old = table.tailles
  and cur = Table.trim table.taille in
  let old_len = Array.length old
  and cur_len = Array.length cur in
  let dest = 
    if cur_len > old_len then begin
      let t = Array.create cur_len 0 in
      Array.blit old 0 t 0 old_len ;
      t
    end else
      old in
  for i=0 to cur_len-1 do
    dest.(i) <- max dest.(i) cur.(i)
  done ;
  table.tailles <- dest

let new_row () =
  if !verbose> 2 then begin
    Printf.eprintf "=> new_row, line =%d, tailles=%a\n"
      !table.line ptailles !table
  end ;
  if !table.col> !table.cols then !table.cols<- !table.col;
  !table.col <- -1;
  !table.line <- !table.line +1;
  Table.reset !table.taille ;

  let _ =match !row.cells with
  | Tabl t -> Table.reset t
  | _-> raise (Error "invalid table type in array")
  in
  !cell.pre <- "";
  !cell.pre_inside <- [];
  !row.haut<-0;
  if !verbose>2 then prerr_endline ("<= new_row, line ="^string_of_int !table.line)
;;

let change_format format = match format with 
  Tabular.Align {Tabular.vert=v ; Tabular.hor=h ; Tabular.wrap=w ; Tabular.width=size} ->
    !cell.ver <- 
      (match v with
      | "" -> Base 50
      | "middle" -> Base 50
      | "top" -> Top
      | "bottom" -> Bottom
      |	s -> 
	  let n =
	    try
	      int_of_string s
	    with (Failure fail) -> raise (Misc.Fatal ("open_cell, invalid vertical format :"^v));
	  in
	  if n>100 || n<0 then raise (Misc.Fatal ("open_cell, invalid vertical format :"^v));
	  Base n);
    !cell.hor <-
      (match h with
      | "" -> Left
      | "center" -> Center
      | "left" -> Left
      | "right" -> Right
      | _-> raise (Misc.Fatal ("open_cell, invalid horizontal format :"^h)));
    !cell.wrap <- (if w then Wtrue else Wfalse);
    if w then
      !cell.w <- 
	(match size with
	| Length.Char l -> l
	| Length.Pixel l -> l / Length.font
	| Length.Percent l -> l * !Parse_opts.width / 100              
	| Length.Default -> !cell.wrap <- Wfalse; warning "cannot wrap column with no width"; 0
        | Length.No s ->
            raise (Misc.Fatal ("No-length ``"^s^"'' in out-manager")))
    else !cell.w <- 0;
| _       ->  raise (Misc.Fatal ("as_align"))
;;

let open_cell format span insides =
  open_block "TEMP" "";
    
  (* preparation du formattage : les flags de position sont sauvegardes par l'ouverture du bloc TEMP *)
      

   (* remplir les champs de formattage de cell *)
  !table.col <- !table.col+1;
  if !verbose>2 then prerr_endline ("open_cell, col="^string_of_int !table.col);

  change_format format;
  !cell.span <- span - insides;
  if !table.col > 0 && !cell.span=1 then begin
    !cell.pre <- "";
    !cell.pre_inside <- [];
  end;
  !cell.post <- "";
  !cell.post_inside <- [];
  open_block "" "";
  if !cell.w > String.length line then raise ( Error "Column too wide");
  if (!cell.wrap=Wtrue) then begin (* preparation de l'alignement *)
    !cur_out.temp <- false;
    flags.x_start <- 0;
    flags.x_end <- !cell.w-1;
    flags.hsize <- !cell.w;
    flags.first_line <- 0;
    flags.x <- -1;
    flags.last_space <- -1;
    push stacks.s_align flags.align;
    push stacks.s_in_align flags.in_align;
    flags.in_align <- true;
    flags.align <- Left;
  end;
;;


let close_cell content =
  if !verbose>2 then prerr_endline "=> force_cell";
  if (!cell.wrap=Wtrue) then begin
    do_flush ();
    flags.in_align <- pop stacks.s_in_align;
    flags.align <- pop stacks.s_align;
  end;
  force_block "" content;
  !cell.text<-Out.to_string !cur_out.out;
  close_block "TEMP";
  if !verbose>2 then prerr_endline ("cell :#"^ !cell.text^
				    "#,pre :#"^ !cell.pre^
				    "#,post :#"^ !cell.post^
				    "#");
  (* il faut remplir les champs w et h de cell *)
  if (!cell.wrap = Wfalse ) then !cell.w <- 0;
  !cell.h <- 1;
  let taille = ref 0 in
  for i = 0 to (String.length !cell.text) -1 do
    if !cell.text.[i]='\n' then begin
      !cell.h<- !cell.h+1;
      if (!cell.wrap = Wfalse) && (!taille > !cell.w) then begin
	!cell.w <- !taille;
      end;
      taille:=0;
    end else begin
      taille:=!taille+1;
    end;
  done;
  if (!cell.wrap = Wfalse) && (!taille > !cell.w) then !cell.w <- !taille;
  !cell.w <- !cell.w + (String.length !cell.pre) + (String.length !cell.post);
  if !verbose>2 then prerr_endline ("size : width="^string_of_int !cell.w^
				    ", height="^string_of_int !cell.h^
				    ", span="^string_of_int !cell.span);
  let _ = match !row.cells with
  | Tabl t ->
      Table.emit t { ver = !cell.ver;
		     hor = !cell.hor;
		     h = !cell.h;
		     w = !cell.w;
		     wrap = !cell.wrap;
		     span = !cell.span;
		     text = !cell.text;
		     pre  = !cell.pre;
	     post = !cell.post;
		     pre_inside  = !cell.pre_inside;
		     post_inside = !cell.post_inside;
		   }
  | _ -> raise (Error "Invalid row type")
  in

  (* on a la taille de la cellule, on met sa largeur au bon endroit, si necessaire.. *)
  (* Multicolonne : Il faut mettre des zeros dans le tableau pour avoir la taille minimale des colonnes atomiques. Puis on range start,end dans une liste que l'on regardera a la fin pour ajuster les tailles selon la loi : la taille de la multicolonne doit etre <= la somme des tailles minimales. Sinon, il faut agrandir les colonnes atomiques pour que ca rentre. *)
  if !cell.span = 1 then begin
    Table.emit !table.taille !cell.w
  end else if !cell.span = 0 then begin
    Table.emit !table.taille 0;
  end else begin
    for i = 1 to !cell.span do
      Table.emit !table.taille 0
    done;
    multi := (!table.col,!table.col + !cell.span -1,!cell.w) :: !multi;
  end;
  !table.col <- !table.col + !cell.span -1;
  if !cell.h> !row.haut then !row.haut<- !cell.h;
  !cell.pre <- "";
  !cell.pre_inside <- [];
  if !verbose>2 then prerr_endline "<= force_cell";
;;

let do_close_cell () = close_cell ""
;;

let open_cell_group () = !table.in_cell <- true;

and close_cell_group () = !table.in_cell <- false;

and erase_cell_group () = !table.in_cell <- false;
;;


let erase_cell () =
  if !verbose>2 then prerr_endline "erase cell";
  if (!cell.wrap=Wtrue) then begin
    flags.in_align <- pop stacks.s_in_align;
    flags.align <- pop stacks.s_align;
  end;
  erase_block "";
  let _ = Out.to_string !cur_out.out in
  erase_block "TEMP";
  !table.col <- !table.col -1;
  !cell.pre <- "";
  !cell.pre_inside <- [];
;;

let erase_row () =
  if !verbose > 2 then prerr_endline "erase_row" ;  
  !table.line <- !table.line -1

and close_row erase =
  if !verbose> 2  then
    Printf.eprintf "close_row tailles=%a, taille=%a\n"
      ptailles !table ptaille !table ;
  register_taille !table ;
  Table.emit !table.table
     { haut = !row.haut;
     cells = Arr (Table.trim 
		    (match !row.cells with
		    | Tabl t -> t
		    | _-> raise (Error "Invalid row type")))}; 
;;


let center_format =
  Tabular.Align  {Tabular.hor="center" ; Tabular.vert = "top" ;
		   Tabular.wrap = false ; Tabular.pre = "" ; 
		   Tabular.post = "" ; Tabular.width = Length.Default} 
;;


let make_border s =
  if !verbose> 2 then prerr_endline ("Adding border after column "^string_of_int !table.col^" :'"^s^"'");
  
  if (!table.col = -1) || not ( !table.in_cell) then
    !cell.pre <- !cell.pre ^ s
  else
    !cell.post <- !cell.post ^ s
;;

let make_inside s multi =
  if !verbose>2 then prerr_endline ("Adding inside after column "^string_of_int !table.col^" :'"^s^"'");
  
  if (!table.col = -1) || not ( !table.in_cell) then begin
    let start = String.length !cell.pre in
    !cell.pre <- !cell.pre ^ s;
    for i = start to String.length !cell.pre -1 do
      !cell.pre_inside <- i::!cell.pre_inside;
    done;
  end else begin
    let start = String.length !cell.post in
    !cell.post <- !cell.post ^ s;
    for i = start to String.length !cell.post -1 do
      !cell.post_inside <- i::!cell.post_inside;
    done;
  end;
;;


let make_hline w noborder =
  new_row();
  open_cell center_format 0 0;
  close_mods ();
  !cell.w <- 0;
  !cell.wrap <- Fill;
  put_char '-';
  close_cell "";
  close_row ();
;;

let text_out j hauteur height align =
  match align with
  | Top ->    (j < height)
  | Middle -> ((j >= (hauteur-height)/2) && (j <= ((hauteur-height)/2)+height-1))
  | Bottom -> (j >= hauteur - height)
  | Base i -> 
      if ( hauteur * i) >= 50 * ( 2*hauteur - height ) 
      then (j >= hauteur - height) (* Bottom *)
      else if ( hauteur * i) <= height * 50
      then (j < height) (* Top *)
      else ((100*j >= i*hauteur - 50*height) && (100*j < i*hauteur + 50*height)) (* Elsewhere *)
;;
(* dis si oui ou non on affiche la ligne de cette cellule, etant donne l'alignement vertical.*)

let put_ligne texte pos align width taille wrap=
(* envoie la ligne de texte apres pos, sur out, en alignant horizontalement et en completant pour avoir la bonne taille *)
  let pos_suiv = try 
    String.index_from texte pos '\n'
  with
  | Not_found -> String.length texte
  | Invalid_argument _ ->
      let l = String.length texte in
      assert (pos=l) ;
      l
  in
  let s = String.sub texte pos (pos_suiv - pos) in
  let t,post= 
    if wrap=Wtrue then String.length s,0
    else width,width - String.length s in

  let ligne = match align with
  | Left -> String.concat "" 
	[s; String.make (taille-t+post) ' ']
  | Center -> String.concat ""
	[String.make ((taille-t)/2) ' ';
	  s;
	  String.make (taille - t + post- (taille-t)/2) ' '] 
  | Right -> String.concat ""
	[String.make (taille-t) ' ';
	  s;
	  String.make (post) ' ']
   in
  if !verbose>2 then prerr_endline ("line sent :#"^ligne^"#");
  do_put ligne;
  pos_suiv + 1
;;


let put_border s inside j =
  for i = 0 to String.length s -1 do
    if j=0 || not (List.mem i inside) then do_put_char s.[i]
    else do_put_char ' ';
  done;
;;

let rec somme debut fin =
  let r = ref 0 in
  for k = debut to fin do
    r := !r + !table.tailles.(k)
  done ;
  !r
;;


let calculate_multi () = 
  (* Finalisation des multi-colonnes : on les repasse toutes pour ajuster les tailles eventuellement *)
  let rec do_rec = function
      [] -> ()
    | (debut,fin,taille_mini) :: reste -> begin
	let taille = somme debut fin in
	if !verbose>3 then prerr_endline ("from "^string_of_int debut^
					  " to "^string_of_int fin^
					  ", size was "^string_of_int taille^
					  " and should be at least "^string_of_int taille_mini);
	if taille < taille_mini then begin (* il faut agrandir *)
	  if !verbose>3 then prerr_endline ("ajusting..");
	  for i = debut to fin do
	    if taille = 0
	    then
	      !table.tailles.(debut) <- taille_mini
	    else
	      let t = !table.tailles.(i) * taille_mini in
	      !table.tailles.(i) <- (t / taille
				       + ( if 2*(t mod taille) >= taille then 1 else 0));
	      
	  done; (* Attention : on agrandit aussi les colonnes p !! *)
	end;
	do_rec reste;
    end
  in
  if !verbose>2 then prerr_endline "Finalizing multi-columns.";
  do_rec !multi;
  if !verbose>2 then prerr_endline "Finalized multi-columns.";
;;


let close_table () =
  if !verbose>2 then begin
    prerr_endline "=> close_table";
    pretty_stack out_stack
  end;

  register_taille !table ;

  let tab = Table.trim !table.table in
  (* il reste a formatter et a flusher dans la sortie principale.. *)
  !table.lines<-Array.length tab;
  if !verbose>2 then prerr_endline ("lines :"^string_of_int !table.lines);

  calculate_multi ();

  !table.width <- somme 0 (Array.length !table.tailles -1);
  finit_ligne();

  if !table.width > flags.hsize then warning ("overfull line in array : array too wide");

  for i = 0 to !table.lines - 1 do
    let ligne = match tab.(i).cells with
    | Arr a -> a
    | _-> raise (Error "Invalid row type:table")
    in
    (* affichage de la ligne *)
    (* il faut envoyer ligne apres ligne dans chaque cellule, en tenant compte de l'alignement vertical et horizontal..*)
    if !verbose> 2 then prerr_endline ("line "^string_of_int i^", columns:"^string_of_int (Array.length ligne)^", height:"^string_of_int tab.(i).haut);
    let pos = Array.create (Array.length ligne) 0 in
    !row.haut <-0;
    for j = 0 to tab.(i).haut -1 do
      if not ( i=0 && j=0) then do_put_char '\n';
      let col = ref 0 in
      for k = 0 to Array.length ligne -1 do
	begin
	  (* ligne j de la cellule k *)          
	  if ligne.(k).wrap = Fill then ligne.(k).span <- Array.length !table.tailles;
	  let taille_borders = (String.length ligne.(k).pre) + (String.length ligne.(k).post) in
	  let taille = (somme !col (!col + ligne.(k).span-1)) - taille_borders in
	  if !verbose> 2 then prerr_endline ("cell to output:"^
					    ligne.(k).pre^
					    ligne.(k).text^
					    ligne.(k).post^
					    ", taille="^string_of_int taille);
	  
	  put_border ligne.(k).pre ligne.(k).pre_inside j;

	  if (text_out j tab.(i).haut ligne.(k).h ligne.(k).ver) 
	      && (ligne.(k).wrap <> Fill )then begin
	    pos.(k) <- 
	      put_ligne 
		ligne.(k).text 
		pos.(k) 
		ligne.(k).hor
		(ligne.(k).w - taille_borders)
		taille
		ligne.(k).wrap
	  end else 
	    if ligne.(k).wrap = Fill then do_put (String.make taille ligne.(k).text.[0])
	    else do_put (String.make taille ' ');
	  col := !col + ligne.(k).span;
	  put_border ligne.(k).post ligne.(k).post_inside j;
	end;
      done;
      if !col< Array.length !table.tailles -1 then begin
	let len = !table.width - (somme 0 (!col-1)) in
	do_put ( String.make len ' ');
      end;
    done;
  done;

  flags.align <- pop stacks.s_align;
  table := pop table_stack;
  row := pop row_stack;
  cell := pop cell_stack;
  multi := pop multi_stack;
  flags.in_table <- pop stacks.s_in_table;
  close_block "";
  if not (flags.in_table) then finit_ligne ();
  if !verbose>2 then prerr_endline "<= close_table"
;;


(* Info *)


let infomenu arg = ()
;;

let infonode opt num arg = ()
and infoextranode num arg text = ()
;;

(* Divers *)

let is_blank s =
  let b = ref true in
  for i = 0 to String.length s do
    b := !b && s.[i]=' '
  done;
  !b
;;

let is_empty () =
  flags.in_table && (Out.is_empty !cur_out.out) && (flags.x= -1);;

let image arg n = 
    if arg <> "" then begin
    put arg;
    put_char ' '
  end
;;

let horizontal_line s width height =  
  if flags.in_table then begin
    Printf.eprintf "HR: %s %s %s\n" s (Length.pretty width) (Length.pretty height) ;
    if false &&  not (Length.is_zero width || Length.is_zero height) then begin
      !cell.w <- 0;
      !cell.wrap <- Fill;
      put_char '-'
    end
  end else begin
    open_block "INFO" "";
    finit_ligne ();
    let taille = match width with
    | Char x -> x
    | Pixel x -> x / Length.font
    | Percent x -> (flags.hsize -1) * x / 100
    | Default   -> flags.hsize - 1
    | No s      -> raise (Fatal ("No-length ``"^s^"'' in out-manager")) in
    let ligne = String.concat "" 
	[(match s with
	|	"right" -> String.make (flags.hsize - taille -1) ' '
	|	"center" -> String.make ((flags.hsize - taille)/2) ' '
	|	_ -> "");
	  String.make taille '-'] in
    put ligne;
    finit_ligne ();
    close_block "INFO";
  end
;;


(*------------*)
(*---MATHS ---*)
(*------------*)

let cm_format =
  Tabular.Align  {Tabular.hor="center" ; Tabular.vert = "middle" ;
		   Tabular.wrap = false ; Tabular.pre = "" ; 
		   Tabular.post = "" ; Tabular.width = Length.Default} 
;;
let lm_format =
  Tabular.Align  {Tabular.hor="left" ; Tabular.vert = "middle" ;
		   Tabular.wrap = false ; Tabular.pre = "" ; 
		   Tabular.post = "" ; Tabular.width = Length.Default} 
;;

let formated s = Tabular.Align  
    { Tabular.hor=
      (match s with
      |	"cm" | "cmm" | "cb" | "ct" -> "center"
      |       "lt" | "lb" | "lm" -> "left"
      |	_ -> "left") ;
      Tabular.vert = 
      (match s with
      | "cm" | "lm" ->"middle"
      | "lt" | "ct" -> "top"
      | "lb" | "cb" -> "bottom"
      |	"cmm" -> "45"
      | _ -> "middle") ;
      Tabular.wrap = false ; Tabular.pre = "" ; 
      Tabular.post = "" ; Tabular.width = Length.Default} 
;;



let freeze f =
  push out_stack (Freeze f) ;
  if !verbose > 2 then begin
    prerr_string "freeze: stack=" ;
    pretty_stack out_stack
  end
;;

let flush_freeze () = match top out_stack with
  Freeze f ->
    let _ = pop out_stack in
    if !verbose > 2 then begin
      prerr_string "flush_freeze" ;
      pretty_stack out_stack
    end ;
    f () ; true
| _ -> false
;;

let pop_freeze () = match top  out_stack with
  Freeze f -> 
    let _ = pop out_stack in
    f,true
| _ -> (fun () -> ()),false
;;

(* Displays *)
let open_display _ =
  open_table (!verbose>1) "";
  new_row ();
  if !verbose > 1 then make_border "{";
  open_cell cm_format 1 0;
  open_cell_group ();
;;

let open_display_varg _ = open_display ""

let close_display () =
  if not (flush_freeze ()) then begin
    if !verbose > 1 then make_border "}";
    close_cell_group ();
    close_cell ();
    close_row ();
    close_table ();
  end;
;;

let item_display () = 
  let f,is_freeze = pop_freeze () in
  if !verbose > 1 then make_border "|";
  close_cell ();
  close_cell_group ();
  open_cell cm_format 1 0;
  open_cell_group ();
  if is_freeze then freeze f;
;;

let item_display_format format =
  let f,is_freeze = pop_freeze () in
  if !verbose > 1 then make_border "|";
  close_cell ();
  close_cell_group ();
  open_cell (formated format) 1 0;
  open_cell_group ();
  if is_freeze then freeze f;
;;

let force_item_display () = item_display ()
;;

let erase_display () = 
  if !verbose > 2 then prerr_endline "erase_display" ;
  erase_cell ();
  erase_cell_group ();
  erase_row ();
  close_table ();
;;


let open_maths display =
  if !verbose >1 then
    prerr_endline "open_maths";
  if display then begin
    open_block "ALIGN" "CENTER";

    open_display "";
    flags.first_line <- 0;
    
    open_display ""
  end else open_block "" "";

and close_maths display =
  if display then begin
    close_display ();
    close_display ();
    close_block "ALIGN";
  end else close_block "";
  if !verbose>1 then
    prerr_endline "close_maths";
;;

let box_around_display scanner arg = ();;

let open_vdisplay display = 
  open_table (!verbose>1) "";

and close_vdisplay () = 
  close_table ();

and open_vdisplay_row s =
  new_row ();
  if !verbose > 0 then make_border "[";
  open_cell (formated s) 1 0;
  open_cell_group ();
  open_display "";

and close_vdisplay_row () = 
  close_display ();
  if !verbose > 0 then make_border "]";
  close_cell ();
  close_cell_group ();
  close_row ();
  if !verbose > 0 then make_hline 0 false;
;;

let insert_sup_sub () =
  let f,is_freeze = pop_freeze () in
  let ps,parg,pout = pop_out out_stack in
  if ps <> "" then failclose ("sup_sub : "^ps^" closes \"\"");
  let new_out = newstatus false [] [] true in
  push_out out_stack (ps,parg,new_out);
  close_block "";
  cur_out := pout;
  open_block "" "";
  if is_freeze then freeze f;
  open_display "";
  let s =(Out.to_string new_out.out) in
  do_put s;
  flags.empty <- (s="");
  free new_out;
;;  


let standard_sup_sub scanner what sup sub display =
  if display then begin
    insert_sup_sub ();
    let f,ff = match sup.arg,sub.arg with
    | "","" -> "cm","cm"
    |	"",_ -> change_format (formated "lt"); "lb","cm"
    |	_,"" -> change_format (formated "lm"); "lt","cmm"
    |	_,_ -> "cm","cm"
    in
    let vide= flags.empty in
    item_display_format f ;
    if sup.arg <>"" || sub.arg<>"" then begin
      open_vdisplay display;
      (*if sup<>"" || vide then*) begin
	open_vdisplay_row "lt";
	scanner sup ;
	close_vdisplay_row ();
      end;
      open_vdisplay_row "lm";
      what ();
      close_vdisplay_row ();
      if sub.arg <>"" || vide then begin
	open_vdisplay_row "lb";
	scanner sub ;
	close_vdisplay_row ();
      end;
      close_vdisplay ();
      item_display ();
    end else what ();
    close_display ();
    change_format (formated ff);
    item_display ();
  end else begin
    what ();
    if sub.arg <> "" then begin
      put "_";
      scanner sub;
    end;
    if sup.arg <> "" then begin
      put "^";
      scanner sup;
    end;
  end
    
and limit_sup_sub scanner what sup sub display =
  item_display ();
  open_vdisplay display;
  open_vdisplay_row "cm";
  scanner sup;
  close_vdisplay_row ();
  open_vdisplay_row "cm";
  what ();
  close_vdisplay_row ();
  open_vdisplay_row "cm";
  scanner sub;
  close_vdisplay_row ();
  close_vdisplay ();
  item_display ();

and int_sup_sub something vsize scanner what sup sub display =
  if something then what ();
  item_display ();
  open_vdisplay display;
  open_vdisplay_row "lm";
  scanner sup;
  close_vdisplay_row ();
  open_vdisplay_row "lm";
  put "";
  close_vdisplay_row ();
  open_vdisplay_row "lm";
  scanner sub;
  close_vdisplay_row ();
  close_vdisplay ();
  item_display ();
;;


let insert_vdisplay open_fun =
  let ps,parg,pout = pop_out out_stack in
  if ps <> "" then
    failclose ("insert_vdisplay : "^ps^" closes the cell.");
  let pps,pparg,ppout = pop_out out_stack in
  if pps <> "TEMP" then
    failclose ("insert_vdisplay : "^pps^" closes the cell2.");
  let ts,targ,tout = pop_out out_stack in
  if ts <> "" then
    failclose ("insert_vdisplay : "^ts^" closes the table.");
  
  let new_out = newstatus false [] [] tout.temp in
  push_out out_stack (ts,targ,new_out);
  push_out out_stack (pps,pparg,ppout);
  push_out out_stack (ps,parg,pout);
  close_display ();


  cur_out :=tout;
  open_display "";
  open_fun ();
  
  let s = Out.to_string new_out.out in
  put s;
  free new_out;
  []
;;



let over display lexbuf =
  if !verbose>1 then
    prerr_endline "over";
  if display then begin
    let _=insert_vdisplay 
	( fun () -> 
	  begin
	    open_vdisplay display;
	    open_vdisplay_row "cm";
	  end) in
    close_vdisplay_row ();
    make_hline 0 false;
    open_vdisplay_row "cm";
    freeze (fun () ->
      close_vdisplay_row ();
      close_vdisplay ();
      close_display (););
  end else begin
    put "/";
  end

let translate = function
  "<" -> "<"
| ">" -> ">"
| "\\{" -> "{"
| "\\}" -> "}"
| s   -> s
;;

let over_align align1 align2 display lexbuf = over display lexbuf
;;

let left delim k =
  item_display ();
  open_display "";
  close_cell_group ();
  if delim<>"." then make_border (translate delim);
  k 3 ;
  open_cell_group ();
;;

let right delim =
  let vsize = 3 in
  if delim<>"." then make_border (translate delim);
  item_display ();
  close_display ();
  vsize
;;

(*
  C'est fini, �legamment
*)

