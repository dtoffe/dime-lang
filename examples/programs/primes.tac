tac program
procedures 3
proc 1 primes return=none params=0 locals=0 temps=0 blocks=1 labels=1 instructions=3
  frame params=0 locals=0 temps=0
  block 1 label=L1 first=1 count=3
   1 label label=L1
   2 call_proc proc=primes
   3 return
endproc
proc 2 isprime return=none params=0 locals=1 temps=17 blocks=4 labels=4 instructions=30
  local 1 i:integer
  frame params=0 locals=1 temps=17
  block 1 label=L2 first=1 count=5
  block 2 label=L3 first=6 count=17
  block 3 label=L5 first=23 count=6
  block 4 label=L4 first=29 count=2
   1 label label=L2
   2 load_const result=t1:boolean left=#1:boolean
   3 store_var result=ret:boolean left=t1:boolean
   4 load_const result=t2:integer left=#2:integer
   5 store_var result=i:integer left=t2:integer
   6 label label=L3
   7 load_var result=t3:integer left=i:integer
   8 load_var result=t4:integer left=arg:integer
   9 binary result=t5:boolean left=t3:integer right=t4:integer op=<
  10 goto_if_zero left=t5:boolean label=L4
  11 load_var result=t6:integer left=arg:integer
  12 load_var result=t7:integer left=i:integer
  13 binary result=t8:integer left=t6:integer right=t7:integer op=/
  14 load_var result=t9:integer left=i:integer
  15 binary result=t10:integer left=t8:integer right=t9:integer op=*
  16 load_var result=t11:integer left=arg:integer
  17 binary result=t12:boolean left=t10:integer right=t11:integer op==
  18 goto_if_zero left=t12:boolean label=L5
  19 load_const result=t13:boolean left=#0:boolean
  20 store_var result=ret:boolean left=t13:boolean
  21 load_var result=t14:integer left=arg:integer
  22 store_var result=i:integer left=t14:integer
  23 label label=L5
  24 load_var result=t15:integer left=i:integer
  25 load_const result=t16:integer left=#1:integer
  26 binary result=t17:integer left=t15:integer right=t16:integer op=+
  27 store_var result=i:integer left=t17:integer
  28 goto label=L3
  29 label label=L4
  30 return
endproc
proc 3 primes return=none params=0 locals=0 temps=11 blocks=5 labels=5 instructions=24
  frame params=0 locals=0 temps=11
  block 1 label=L6 first=1 count=3
  block 2 label=L7 first=4 count=12
  block 3 label=L10 first=16 count=1
  block 4 label=L8 first=17 count=6
  block 5 label=L9 first=23 count=2
   1 label label=L6
   2 load_const result=t18:integer left=#2:integer
   3 store_var result=arg:integer left=t18:integer
   4 label label=L7
   5 load_const result=t19:integer left=#100:integer
   6 load_const result=t20:integer left=#1:integer
   7 binary result=t21:integer left=t19:integer right=t20:integer op=-
   8 load_var result=t23:integer left=arg:integer
   9 binary result=t22:boolean left=t23:integer right=t21:integer op=<=
  10 goto_if_zero left=t22:boolean label=L9
  11 call_proc proc=isprime
  12 load_var result=t24:boolean left=ret:boolean
  13 goto_if_zero left=t24:boolean label=L10
  14 load_var result=t25:integer left=arg:integer
  15 builtin_write left=t25:integer builtin=writeln
  16 label label=L10
  17 label label=L8
  18 load_const result=t26:integer left=#1:integer
  19 load_var result=t28:integer left=arg:integer
  20 binary result=t27:integer left=t28:integer right=t26:integer op=+
  21 store_var result=arg:integer left=t27:integer
  22 goto label=L7
  23 label label=L9
  24 return
endproc
