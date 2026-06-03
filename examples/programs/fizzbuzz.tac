tac program
procedures 2
  proc 1 fizzbuzz blocks=9 instructions=85 temps=48 labels=9
  proc 2 printsumma blocks=1 instructions=28 temps=13 labels=1
blocks 10
  block 1 label=L1 first=1 count=13
  block 2 label=L2 first=14 count=34
  block 3 label=L4 first=48 count=10
  block 4 label=L6 first=58 count=10
  block 5 label=L8 first=68 count=7
  block 6 label=L9 first=75 count=1
  block 7 label=L7 first=76 count=1
  block 8 label=L5 first=77 count=6
  block 9 label=L3 first=83 count=3
  block 10 label=L10 first=86 count=28
instructions 113
   1 label label=L1
   2 load_const result=t1:integer left=#0:integer
   3 store_var result=cnorm:integer left=t1:integer
   4 load_const result=t2:integer left=#0:integer
   5 store_var result=cfizz:integer left=t2:integer
   6 load_const result=t3:integer left=#0:integer
   7 store_var result=cbuzz:integer left=t3:integer
   8 load_const result=t4:integer left=#0:integer
   9 store_var result=cfb:integer left=t4:integer
  10 load_const result=t5:integer left=#0:integer
  11 store_var result=sumcnt:integer left=t5:integer
  12 load_const result=t6:integer left=#1:integer
  13 store_var result=n:integer left=t6:integer
  14 label label=L2
  15 load_const result=t7:integer left=#100:integer
  16 load_var result=t9:integer left=n:integer
  17 binary result=t8:boolean left=t9:integer right=t7:integer op=<=
  18 goto_if_zero left=t8:boolean label=L3
  19 load_var result=t10:integer left=n:integer
  20 load_const result=t11:integer left=#3:integer
  21 binary result=t12:integer left=t10:integer right=t11:integer op=/
  22 load_const result=t13:integer left=#3:integer
  23 binary result=t14:integer left=t12:integer right=t13:integer op=*
  24 load_var result=t15:integer left=n:integer
  25 binary result=t16:boolean left=t14:integer right=t15:integer op==
  26 store_var result=fizz:boolean left=t16:boolean
  27 load_var result=t17:integer left=n:integer
  28 load_const result=t18:integer left=#5:integer
  29 binary result=t19:integer left=t17:integer right=t18:integer op=/
  30 load_const result=t20:integer left=#5:integer
  31 binary result=t21:integer left=t19:integer right=t20:integer op=*
  32 load_var result=t22:integer left=n:integer
  33 binary result=t23:boolean left=t21:integer right=t22:integer op==
  34 store_var result=buzz:boolean left=t23:boolean
  35 load_var result=t24:boolean left=fizz:boolean
  36 load_var result=t25:boolean left=buzz:boolean
  37 binary result=t26:boolean left=t24:boolean right=t25:boolean op=and
  38 goto_if_zero left=t26:boolean label=L4
  39 load_const result=t27:char left=#70:char
  40 builtin_write left=t27:char builtin=write
  41 load_const result=t28:char left=#66:char
  42 builtin_write left=t28:char builtin=writeln
  43 load_var result=t29:integer left=cfb:integer
  44 load_const result=t30:integer left=#1:integer
  45 binary result=t31:integer left=t29:integer right=t30:integer op=+
  46 store_var result=cfb:integer left=t31:integer
  47 goto label=L5
  48 label label=L4
  49 load_var result=t32:boolean left=fizz:boolean
  50 goto_if_zero left=t32:boolean label=L6
  51 load_const result=t33:char left=#70:char
  52 builtin_write left=t33:char builtin=writeln
  53 load_var result=t34:integer left=cfizz:integer
  54 load_const result=t35:integer left=#1:integer
  55 binary result=t36:integer left=t34:integer right=t35:integer op=+
  56 store_var result=cfizz:integer left=t36:integer
  57 goto label=L7
  58 label label=L6
  59 load_var result=t37:boolean left=buzz:boolean
  60 goto_if_zero left=t37:boolean label=L8
  61 load_const result=t38:char left=#66:char
  62 builtin_write left=t38:char builtin=writeln
  63 load_var result=t39:integer left=cbuzz:integer
  64 load_const result=t40:integer left=#1:integer
  65 binary result=t41:integer left=t39:integer right=t40:integer op=+
  66 store_var result=cbuzz:integer left=t41:integer
  67 goto label=L9
  68 label label=L8
  69 load_var result=t42:integer left=n:integer
  70 builtin_write left=t42:integer builtin=writeln
  71 load_var result=t43:integer left=cnorm:integer
  72 load_const result=t44:integer left=#1:integer
  73 binary result=t45:integer left=t43:integer right=t44:integer op=+
  74 store_var result=cnorm:integer left=t45:integer
  75 label label=L9
  76 label label=L7
  77 label label=L5
  78 load_const result=t46:integer left=#1:integer
  79 load_var result=t48:integer left=n:integer
  80 binary result=t47:integer left=t48:integer right=t46:integer op=+
  81 store_var result=n:integer left=t47:integer
  82 goto label=L2
  83 label label=L3
  84 call_proc proc=printsumma
  85 return
  86 label label=L10
  87 load_const result=t49:char left=#78:char
  88 builtin_write left=t49:char builtin=write
  89 load_const result=t50:char left=#58:char
  90 builtin_write left=t50:char builtin=write
  91 load_var result=t51:integer left=cnorm:integer
  92 builtin_write left=t51:integer builtin=writeln
  93 load_const result=t52:char left=#70:char
  94 builtin_write left=t52:char builtin=write
  95 load_const result=t53:char left=#58:char
  96 builtin_write left=t53:char builtin=write
  97 load_var result=t54:integer left=cfizz:integer
  98 builtin_write left=t54:integer builtin=writeln
  99 load_const result=t55:char left=#66:char
 100 builtin_write left=t55:char builtin=write
 101 load_const result=t56:char left=#58:char
 102 builtin_write left=t56:char builtin=write
 103 load_var result=t57:integer left=cbuzz:integer
 104 builtin_write left=t57:integer builtin=writeln
 105 load_const result=t58:char left=#70:char
 106 builtin_write left=t58:char builtin=write
 107 load_const result=t59:char left=#66:char
 108 builtin_write left=t59:char builtin=write
 109 load_const result=t60:char left=#58:char
 110 builtin_write left=t60:char builtin=write
 111 load_var result=t61:integer left=cfb:integer
 112 builtin_write left=t61:integer builtin=writeln
 113 return
