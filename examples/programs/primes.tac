tac program
procedures 3
  proc 1 primes blocks=1 instructions=3 temps=0 labels=1
  proc 2 isprime blocks=4 instructions=30 temps=17 labels=4
  proc 3 primes blocks=4 instructions=23 temps=11 labels=4
blocks 9
  block 1 label=L1 first=1 count=3
  block 2 label=L2 first=4 count=5
  block 3 label=L3 first=9 count=17
  block 4 label=L5 first=26 count=6
  block 5 label=L4 first=32 count=2
  block 6 label=L6 first=34 count=3
  block 7 label=L7 first=37 count=12
  block 8 label=L9 first=49 count=6
  block 9 label=L8 first=55 count=2
instructions 56
   1 label label=L1
   2 call_proc proc=primes
   3 return
   4 label label=L2
   5 load_const result=t1:boolean left=#1:boolean
   6 store_var result=ret:boolean left=t1:boolean
   7 load_const result=t2:integer left=#2:integer
   8 store_var result=i:integer left=t2:integer
   9 label label=L3
  10 load_var result=t3:integer left=i:integer
  11 load_var result=t4:integer left=arg:integer
  12 binary result=t5:boolean left=t3:integer right=t4:integer op=<
  13 goto_if_zero left=t5:boolean label=L4
  14 load_var result=t6:integer left=arg:integer
  15 load_var result=t7:integer left=i:integer
  16 binary result=t8:integer left=t6:integer right=t7:integer op=/
  17 load_var result=t9:integer left=i:integer
  18 binary result=t10:integer left=t8:integer right=t9:integer op=*
  19 load_var result=t11:integer left=arg:integer
  20 binary result=t12:boolean left=t10:integer right=t11:integer op==
  21 goto_if_zero left=t12:boolean label=L5
  22 load_const result=t13:boolean left=#0:boolean
  23 store_var result=ret:boolean left=t13:boolean
  24 load_var result=t14:integer left=arg:integer
  25 store_var result=i:integer left=t14:integer
  26 label label=L5
  27 load_var result=t15:integer left=i:integer
  28 load_const result=t16:integer left=#1:integer
  29 binary result=t17:integer left=t15:integer right=t16:integer op=+
  30 store_var result=i:integer left=t17:integer
  31 goto label=L3
  32 label label=L4
  33 return
  34 label label=L6
  35 load_const result=t18:integer left=#2:integer
  36 store_var result=arg:integer left=t18:integer
  37 label label=L7
  38 load_const result=t19:integer left=#100:integer
  39 load_const result=t20:integer left=#1:integer
  40 binary result=t21:integer left=t19:integer right=t20:integer op=-
  41 load_var result=t23:integer left=arg:integer
  42 binary result=t22:boolean left=t23:integer right=t21:integer op=<=
  43 goto_if_zero left=t22:boolean label=L8
  44 call_proc proc=isprime
  45 load_var result=t24:boolean left=ret:boolean
  46 goto_if_zero left=t24:boolean label=L9
  47 load_var result=t25:integer left=arg:integer
  48 builtin_write left=t25:integer builtin=writeln
  49 label label=L9
  50 load_const result=t26:integer left=#1:integer
  51 load_var result=t28:integer left=arg:integer
  52 binary result=t27:integer left=t28:integer right=t26:integer op=+
  53 store_var result=arg:integer left=t27:integer
  54 goto label=L7
  55 label label=L8
  56 return
