tac program
procedures 1
  proc 1 forbasic blocks=3 instructions=17 temps=8 labels=3
blocks 3
  block 1 label=L1 first=1 count=3
  block 2 label=L2 first=4 count=12
  block 3 label=L3 first=16 count=2
instructions 17
   1 label label=L1
   2 load_const result=t1:integer left=#1:integer
   3 store_var result=i:integer left=t1:integer
   4 label label=L2
   5 load_const result=t2:integer left=#5:integer
   6 load_var result=t4:integer left=i:integer
   7 binary result=t3:boolean left=t4:integer right=t2:integer op=<=
   8 goto_if_zero left=t3:boolean label=L3
   9 load_var result=t5:integer left=i:integer
  10 builtin_write left=t5:integer builtin=write
  11 load_const result=t6:integer left=#2:integer
  12 load_var result=t8:integer left=i:integer
  13 binary result=t7:integer left=t8:integer right=t6:integer op=+
  14 store_var result=i:integer left=t7:integer
  15 goto label=L2
  16 label label=L3
  17 return
