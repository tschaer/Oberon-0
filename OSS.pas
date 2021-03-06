(* OSS.m
 * From N. Wirth: Compiler Construction
 * Revised 2005 edition from www.ethoberon.ethz.ch/WirthPubl/CBEAll.pdf
 * Ported to Oxford Oberon-2 Compiler 2.9.7 for Windows
 * 22.07.2016 TSS
 * Changes from the original:
 * - Replaced module Texts with Files, and the Reader R with a file handle F. 
 *   - Texts.OpenReader(R, T, pos) -> F := Files.Open(name, "r")
 *   - Texts.Read(R, ch) -> Files.ReadChar(F, ch)
 *   - R.eot -> Files.eof(F)
 * - Replaced output Text with stdout using module Out
 * - Procedure Mark does not report position in source
 * - Procedure Number sets a limit of 1048576 (plus one more digit)
 *)

MODULE OSS;

IMPORT Files, Out;

CONST
   IdLen* = 16;
   KW = 34;
   (* Symbols *)
   null = 0; 
   times* = 1; div* = 3; mod* = 4; and* = 5;
   plus* = 6; minus* = 7; or* = 8; eql* = 9;
   neq* = 10; lss* = 11; geq* = 12; leq = 13;
   gtr* = 14; period* = 18; comma* = 19; colon* = 20;
   rparen* = 22; rbrak* = 23; of* = 25; then* = 26;
   do* = 27; lparen* = 29; lbrak* = 30; not* = 32;
   becomes* = 33; number* = 34; ident* = 37; semicolon* = 38;
   end* = 40; else* = 41; elsif* = 42; if* = 44;
   while* = 46; array* = 54; record* = 55; const* = 57;
   type* = 58; var* = 59; procedure* = 60; begin* = 61; 
   module* = 63; eof = 64;
   
   
TYPE Ident* = ARRAY IdLen OF CHAR;

VAR 
   val*: LONGINT;
   id* : Ident;
   error* : BOOLEAN;
   ch*: CHAR;
   nkw: INTEGER;
   F: Files.File;
   keyTab: ARRAY KW OF
      RECORD
         sym: INTEGER;
         id: Ident
      END;
   
PROCEDURE Mark*(msg: ARRAY OF CHAR);
BEGIN
   Out.String(msg); 
   Out.Ln;
   error := TRUE
END Mark;

PROCEDURE Get*(VAR sym: INTEGER);
   
   PROCEDURE Ident;
      VAR i, k: INTEGER;
   BEGIN
      i := 0;
      REPEAT
         IF i < IdLen THEN
            id[i] := ch;
            INC(i)
         END;
         Files.ReadChar(F, ch);
      UNTIL (ch < "0") OR (ch > "9") & (CAP(ch) < "A") OR (CAP(ch) > "Z");
      id[i] := 0X;
      k := 0;
      WHILE (k < nkw) & (id # keyTab[k].id) DO
         INC(k)
      END;
      IF k < nkw THEN
         sym := keyTab[k].sym
      ELSE
         sym := ident
      END
   END Ident;
   
   PROCEDURE Number;
   BEGIN
      val := 0;
      sym := number;
      REPEAT
         IF val <= 1048576 THEN
            val := 10 * val + (ORD(ch) - ORD("0"))
         ELSE
            Mark("Number too large");
            val := 0
         END;
         Files.ReadChar(F, ch);
      UNTIL (ch < "0") OR (ch > "9")
   END Number;
   
   PROCEDURE comment;
   BEGIN
      Files.ReadChar(F, ch);
      LOOP
         LOOP
            WHILE ch = "(" DO
               Files.ReadChar(F, ch);
               IF ch = "*" THEN
                  comment
               END
            END;
            IF ch = "*" THEN
               Files.ReadChar(F, ch);
               EXIT
            END;
            IF Files.Eof(F) THEN
               EXIT
            END;
            Files.ReadChar(F, ch);
         END;
         IF ch = ")" THEN
            Files.ReadChar(F, ch);
            EXIT
         END;
         IF Files.Eof(F) THEN
            Mark("Comment not terminated");
            EXIT
         END
      END
   END comment;
   
BEGIN
   WHILE ~Files.Eof(F) & (ch <= " ") DO
      Files.ReadChar(F, ch);
   END;
   IF Files.Eof(F) THEN
      sym := eof
   ELSE
      CASE ch OF
           '&': Files.ReadChar(F, ch); sym := and
         | '*': Files.ReadChar(F, ch); sym := times
         | '+': Files.ReadChar(F, ch); sym := plus
         | '-': Files.ReadChar(F, ch); sym := minus
         | '=': Files.ReadChar(F, ch); sym := eql
         | '#': Files.ReadChar(F, ch); sym := neq
         | '<': Files.ReadChar(F, ch);
            IF ch = '=' THEN
               Files.ReadChar(F, ch); sym := leq
            ELSE
               sym := lss
            END
         | '>': Files.ReadChar(F, ch);
            IF ch = '=' THEN
               Files.ReadChar(F, ch); sym := geq
            ELSE
               sym := lss
            END
         | ';': Files.ReadChar(F, ch); sym := semicolon
         | ',': Files.ReadChar(F, ch); sym := comma
         | ':': Files.ReadChar(F, ch);
            IF ch = "=" THEN
               Files.ReadChar(F, ch); sym := becomes
            ELSE
               sym := colon
            END
         | '.': Files.ReadChar(F, ch); sym := period
         | '(': Files.ReadChar(F, ch); 
            IF ch = '*' THEN
               comment;
               Get(sym)
            ELSE
               sym := lparen
            END
         | ')': Files.ReadChar(F, ch); sym := rparen
         | '[': Files.ReadChar(F, ch); sym := lbrak
         | ']': Files.ReadChar(F, ch); sym := rbrak
         | '0'..'9': Number
         | 'A'..'Z', 'a'..'z': Ident
         | '~': Files.ReadChar(F, ch); sym := not
      ELSE
         Files.ReadChar(F, ch);
         sym := null
      END
   END
END Get;
      
PROCEDURE Init*(CONST name: ARRAY OF CHAR);
BEGIN
   error := FALSE;
   F := Files.Open(name, "r");
   Files.ReadChar(F, ch);
END Init;

PROCEDURE EnterKW(sym: INTEGER; name: ARRAY OF CHAR);
BEGIN
   keyTab[nkw].sym := sym;
   COPY(name, keyTab[nkw].id);
   INC(nkw)
END EnterKW;

BEGIN
   error := TRUE;
   nkw := 0;
   EnterKW(null, "BY");
   EnterKW(do, "DO");
   EnterKW(if, "IF");
   EnterKW(null, "IN");
   EnterKW(null, "IS");
   EnterKW(of, "OF");
   EnterKW(or, "OR");
   EnterKW(null, "TO");
   EnterKW(end, "END");
   EnterKW(null, "FOR");
   EnterKW(mod, "MOD");
   EnterKW(null, "NIL");
   EnterKW(var, "VAR");
   EnterKW(null, "CASE");
   EnterKW(else, "ELSE");
   EnterKW(null, "EXIT");
   EnterKW(then, "THEN");
   EnterKW(type, "TYPE");
   EnterKW(null, "WITH");
   EnterKW(array, "ARRAY");
   EnterKW(begin, "BEGIN");
   EnterKW(const, "CONST");
   EnterKW(elsif, "ELSIF");
   EnterKW(null, "IMPORT");
   EnterKW(null, "UNTIL");
   EnterKW(while, "WHILE");
   EnterKW(record, "RECORD");
   EnterKW(null, "REPEAT");
   EnterKW(null, "RETURN");
   EnterKW(null, "POINTER");
   EnterKW(procedure, "PROCEDURE");
   EnterKW(div, "DIV");
   EnterKW(null, "LOOP");
   EnterKW(module, "MODULE");
END OSS.
