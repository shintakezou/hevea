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

let header = "$Id: version.ml,v 1.146 2006-09-22 16:09:51 maranget Exp $" 
let real_version = "1.08+18"
let release_date = "2006-09-18"

let version =
  try
   let _ = String.index real_version '+' in
   real_version^" of "^release_date
  with
  | Not_found -> real_version
