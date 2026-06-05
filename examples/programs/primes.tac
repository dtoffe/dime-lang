tac program
procedures 3
proc 1 primes return=none params=0 locals=0 temps=0 blocks=1 labels=1 instructions=2
  frame params=0 locals=0 temps=0
  block 1 label=L1 first=1 count=2
   1 call_proc proc=printprime
   2 return
  labelmap L1 block=1 first=1
endproc
proc 2 isprime return=none params=0 locals=1 temps=17 blocks=6 labels=4 instructions=26
  local 1 i:integer
  frame params=0 locals=1 temps=17
  block 1 label=L2 first=1 count=4
   1 load_const result=t1:boolean left=#1:boolean
   2 store_var result=ret:boolean left=t1:boolean
   3 load_const result=t2:integer left=#2:integer
   4 store_var result=i:integer left=t2:integer
  block 2 label=L3 first=5 count=4
   5 load_var result=t3:integer left=i:integer
   6 load_var result=t4:integer left=arg:integer
   7 binary result=t5:boolean left=t3:integer right=t4:integer op=<
   8 goto_if_zero left=t5:boolean label=L4
  block 3 first=9 count=8
   9 load_var result=t6:integer left=arg:integer
  10 load_var result=t7:integer left=i:integer
  11 binary result=t8:integer left=t6:integer right=t7:integer op=/
  12 load_var result=t9:integer left=i:integer
  13 binary result=t10:integer left=t8:integer right=t9:integer op=*
  14 load_var result=t11:integer left=arg:integer
  15 binary result=t12:boolean left=t10:integer right=t11:integer op==
  16 goto_if_zero left=t12:boolean label=L5
  block 4 first=17 count=4
  17 load_const result=t13:boolean left=#0:boolean
  18 store_var result=ret:boolean left=t13:boolean
  19 load_var result=t14:integer left=arg:integer
  20 store_var result=i:integer left=t14:integer
  block 5 label=L5 first=21 count=5
  21 load_var result=t15:integer left=i:integer
  22 load_const result=t16:integer left=#1:integer
  23 binary result=t17:integer left=t15:integer right=t16:integer op=+
  24 store_var result=i:integer left=t17:integer
  25 goto label=L3
  block 6 label=L4 first=26 count=1
  26 return
  labelmap L2 block=1 first=1
  labelmap L3 block=2 first=5
  labelmap L4 block=6 first=26
endproc
proc 3 printprime return=none params=0 locals=0 temps=11 blocks=6 labels=5 instructions=19
  frame params=0 locals=0 temps=11
  block 1 label=L6 first=1 count=2
   1 load_const result=t18:integer left=#2:integer
   2 store_var result=arg:integer left=t18:integer
  block 2 label=L7 first=3 count=6
   3 load_const result=t19:integer left=#100:integer
   4 load_const result=t20:integer left=#1:integer
   5 binary result=t21:integer left=t19:integer right=t20:integer op=-
   6 load_var result=t23:integer left=arg:integer
   7 binary result=t22:boolean left=t23:integer right=t21:integer op=<=
   8 goto_if_zero left=t22:boolean label=L9
  block 3 first=9 count=3
   9 call_proc proc=isprime
  10 load_var result=t24:boolean left=ret:boolean
  11 goto_if_zero left=t24:boolean label=L10
  block 4 first=12 count=2
  12 load_var result=t25:integer left=arg:integer
  13 builtin_write left=t25:integer builtin=writeln
  block 5 label=L10 first=14 count=5
  14 load_const result=t26:integer left=#1:integer
  15 load_var result=t28:integer left=arg:integer
  16 binary result=t27:integer left=t28:integer right=t26:integer op=+
  17 store_var result=arg:integer left=t27:integer
  18 goto label=L7
  block 6 label=L9 first=19 count=1
  19 return
endproc
