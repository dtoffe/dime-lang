tac program
procedures 2
proc 1 fizzbuzz return=none params=0 locals=0 temps=48 blocks=11 labels=10 instructions=76
  frame params=0 locals=0 temps=48
  block 1 label=L1 first=1 count=12
   1 load_const result=t1:integer left=#0:integer
   2 store_var result=cnorm:integer left=t1:integer
   3 load_const result=t2:integer left=#0:integer
   4 store_var result=cfizz:integer left=t2:integer
   5 load_const result=t3:integer left=#0:integer
   6 store_var result=cbuzz:integer left=t3:integer
   7 load_const result=t4:integer left=#0:integer
   8 store_var result=cfb:integer left=t4:integer
   9 load_const result=t5:integer left=#0:integer
  10 store_var result=sumcnt:integer left=t5:integer
  11 load_const result=t6:integer left=#1:integer
  12 store_var result=n:integer left=t6:integer
  block 2 label=L2 first=13 count=4
  13 load_const result=t7:integer left=#100:integer
  14 load_var result=t9:integer left=n:integer
  15 binary result=t8:boolean left=t9:integer right=t7:integer op=<=
  16 goto_if_zero left=t8:boolean label=L4
  block 3 first=17 count=20
  17 load_var result=t10:integer left=n:integer
  18 load_const result=t11:integer left=#3:integer
  19 binary result=t12:integer left=t10:integer right=t11:integer op=/
  20 load_const result=t13:integer left=#3:integer
  21 binary result=t14:integer left=t12:integer right=t13:integer op=*
  22 load_var result=t15:integer left=n:integer
  23 binary result=t16:boolean left=t14:integer right=t15:integer op==
  24 store_var result=fizz:boolean left=t16:boolean
  25 load_var result=t17:integer left=n:integer
  26 load_const result=t18:integer left=#5:integer
  27 binary result=t19:integer left=t17:integer right=t18:integer op=/
  28 load_const result=t20:integer left=#5:integer
  29 binary result=t21:integer left=t19:integer right=t20:integer op=*
  30 load_var result=t22:integer left=n:integer
  31 binary result=t23:boolean left=t21:integer right=t22:integer op==
  32 store_var result=buzz:boolean left=t23:boolean
  33 load_var result=t24:boolean left=fizz:boolean
  34 load_var result=t25:boolean left=buzz:boolean
  35 binary result=t26:boolean left=t24:boolean right=t25:boolean op=and
  36 goto_if_zero left=t26:boolean label=L5
  block 4 first=37 count=9
  37 load_const result=t27:char left=#70:char
  38 builtin_write left=t27:char builtin=write
  39 load_const result=t28:char left=#66:char
  40 builtin_write left=t28:char builtin=writeln
  41 load_var result=t29:integer left=cfb:integer
  42 load_const result=t30:integer left=#1:integer
  43 binary result=t31:integer left=t29:integer right=t30:integer op=+
  44 store_var result=cfb:integer left=t31:integer
  45 goto label=L6
  block 5 label=L5 first=46 count=2
  46 load_var result=t32:boolean left=fizz:boolean
  47 goto_if_zero left=t32:boolean label=L7
  block 6 first=48 count=7
  48 load_const result=t33:char left=#70:char
  49 builtin_write left=t33:char builtin=writeln
  50 load_var result=t34:integer left=cfizz:integer
  51 load_const result=t35:integer left=#1:integer
  52 binary result=t36:integer left=t34:integer right=t35:integer op=+
  53 store_var result=cfizz:integer left=t36:integer
  54 goto label=L8
  block 7 label=L7 first=55 count=2
  55 load_var result=t37:boolean left=buzz:boolean
  56 goto_if_zero left=t37:boolean label=L9
  block 8 first=57 count=7
  57 load_const result=t38:char left=#66:char
  58 builtin_write left=t38:char builtin=writeln
  59 load_var result=t39:integer left=cbuzz:integer
  60 load_const result=t40:integer left=#1:integer
  61 binary result=t41:integer left=t39:integer right=t40:integer op=+
  62 store_var result=cbuzz:integer left=t41:integer
  63 goto label=L10
  block 9 label=L9 first=64 count=6
  64 load_var result=t42:integer left=n:integer
  65 builtin_write left=t42:integer builtin=writeln
  66 load_var result=t43:integer left=cnorm:integer
  67 load_const result=t44:integer left=#1:integer
  68 binary result=t45:integer left=t43:integer right=t44:integer op=+
  69 store_var result=cnorm:integer left=t45:integer
  block 10 label=L10 alias=L3 alias=L6 alias=L8 first=70 count=5
  70 load_const result=t46:integer left=#1:integer
  71 load_var result=t48:integer left=n:integer
  72 binary result=t47:integer left=t48:integer right=t46:integer op=+
  73 store_var result=n:integer left=t47:integer
  74 goto label=L2
  block 11 label=L4 first=75 count=2
  75 call_proc proc=printsumma
  76 return
endproc
proc 2 printsumma return=none params=0 locals=0 temps=13 blocks=1 labels=1 instructions=27
  frame params=0 locals=0 temps=13
  block 1 label=L11 first=1 count=27
   1 load_const result=t49:char left=#78:char
   2 builtin_write left=t49:char builtin=write
   3 load_const result=t50:char left=#58:char
   4 builtin_write left=t50:char builtin=write
   5 load_var result=t51:integer left=cnorm:integer
   6 builtin_write left=t51:integer builtin=writeln
   7 load_const result=t52:char left=#70:char
   8 builtin_write left=t52:char builtin=write
   9 load_const result=t53:char left=#58:char
  10 builtin_write left=t53:char builtin=write
  11 load_var result=t54:integer left=cfizz:integer
  12 builtin_write left=t54:integer builtin=writeln
  13 load_const result=t55:char left=#66:char
  14 builtin_write left=t55:char builtin=write
  15 load_const result=t56:char left=#58:char
  16 builtin_write left=t56:char builtin=write
  17 load_var result=t57:integer left=cbuzz:integer
  18 builtin_write left=t57:integer builtin=writeln
  19 load_const result=t58:char left=#70:char
  20 builtin_write left=t58:char builtin=write
  21 load_const result=t59:char left=#66:char
  22 builtin_write left=t59:char builtin=write
  23 load_const result=t60:char left=#58:char
  24 builtin_write left=t60:char builtin=write
  25 load_var result=t61:integer left=cfb:integer
  26 builtin_write left=t61:integer builtin=writeln
  27 return
endproc
