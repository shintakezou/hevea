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

val base : string ref

val start : unit -> unit

val put_char : char -> unit

val put : string -> unit

val dump :  string -> (Lexing.lexbuf -> 'a) -> Lexing.lexbuf -> 'a
val close_image : unit -> unit
val page : unit -> string

val finalize : unit -> unit
