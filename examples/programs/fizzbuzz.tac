tac program
procedures 2
proc 1 fizzbuzz return=none params=0 locals=0 temps=48 blocks=11 labels=10 instructions=78
  frame params=0 locals=0 temps=48 param_area=0 local_area=0 temp_area=156 frame_size=156
  frame_temp 1 temp[t1]:integer/dword offset=-4 size=4
  frame_temp 2 temp[t2]:integer/dword offset=-8 size=4
  frame_temp 3 temp[t3]:integer/dword offset=-12 size=4
  frame_temp 4 temp[t4]:integer/dword offset=-16 size=4
  frame_temp 5 temp[t5]:integer/dword offset=-20 size=4
  frame_temp 6 temp[t6]:integer/dword offset=-24 size=4
  frame_temp 7 temp[t7]:integer/dword offset=-28 size=4
  frame_temp 8 temp[t8]:boolean/byte offset=-29 size=1
  frame_temp 9 temp[t9]:integer/dword offset=-33 size=4
  frame_temp 10 temp[t10]:integer/dword offset=-37 size=4
  frame_temp 11 temp[t11]:integer/dword offset=-41 size=4
  frame_temp 12 temp[t12]:integer/dword offset=-45 size=4
  frame_temp 13 temp[t13]:integer/dword offset=-49 size=4
  frame_temp 14 temp[t14]:integer/dword offset=-53 size=4
  frame_temp 15 temp[t15]:integer/dword offset=-57 size=4
  frame_temp 16 temp[t16]:boolean/byte offset=-58 size=1
  frame_temp 17 temp[t17]:integer/dword offset=-62 size=4
  frame_temp 18 temp[t18]:integer/dword offset=-66 size=4
  frame_temp 19 temp[t19]:integer/dword offset=-70 size=4
  frame_temp 20 temp[t20]:integer/dword offset=-74 size=4
  frame_temp 21 temp[t21]:integer/dword offset=-78 size=4
  frame_temp 22 temp[t22]:integer/dword offset=-82 size=4
  frame_temp 23 temp[t23]:boolean/byte offset=-83 size=1
  frame_temp 24 temp[t24]:boolean/byte offset=-84 size=1
  frame_temp 25 temp[t25]:boolean/byte offset=-85 size=1
  frame_temp 26 temp[t26]:boolean/byte offset=-86 size=1
  frame_temp 27 temp[t27]:char/byte offset=-87 size=1
  frame_temp 28 temp[t28]:char/byte offset=-88 size=1
  frame_temp 29 temp[t29]:integer/dword offset=-92 size=4
  frame_temp 30 temp[t30]:integer/dword offset=-96 size=4
  frame_temp 31 temp[t31]:integer/dword offset=-100 size=4
  frame_temp 32 temp[t32]:boolean/byte offset=-101 size=1
  frame_temp 33 temp[t33]:char/byte offset=-102 size=1
  frame_temp 34 temp[t34]:integer/dword offset=-106 size=4
  frame_temp 35 temp[t35]:integer/dword offset=-110 size=4
  frame_temp 36 temp[t36]:integer/dword offset=-114 size=4
  frame_temp 37 temp[t37]:boolean/byte offset=-115 size=1
  frame_temp 38 temp[t38]:char/byte offset=-116 size=1
  frame_temp 39 temp[t39]:integer/dword offset=-120 size=4
  frame_temp 40 temp[t40]:integer/dword offset=-124 size=4
  frame_temp 41 temp[t41]:integer/dword offset=-128 size=4
  frame_temp 42 temp[t42]:integer/dword offset=-132 size=4
  frame_temp 43 temp[t43]:integer/dword offset=-136 size=4
  frame_temp 44 temp[t44]:integer/dword offset=-140 size=4
  frame_temp 45 temp[t45]:integer/dword offset=-144 size=4
  frame_temp 46 temp[t46]:integer/dword offset=-148 size=4
  frame_temp 47 temp[t47]:integer/dword offset=-152 size=4
  frame_temp 48 temp[t48]:integer/dword offset=-156 size=4
  block 1 label=L1 first=1 count=13
   1 enter left=imm(156):integer/dword
   2 load_const result=temp[t1]:integer/dword left=imm(0):integer/dword
   3 store result=global[cnorm]:integer/dword left=temp[t1]:integer/dword
   4 load_const result=temp[t2]:integer/dword left=imm(0):integer/dword
   5 store result=global[cfizz]:integer/dword left=temp[t2]:integer/dword
   6 load_const result=temp[t3]:integer/dword left=imm(0):integer/dword
   7 store result=global[cbuzz]:integer/dword left=temp[t3]:integer/dword
   8 load_const result=temp[t4]:integer/dword left=imm(0):integer/dword
   9 store result=global[cfb]:integer/dword left=temp[t4]:integer/dword
  10 load_const result=temp[t5]:integer/dword left=imm(0):integer/dword
  11 store result=global[sumcnt]:integer/dword left=temp[t5]:integer/dword
  12 load_const result=temp[t6]:integer/dword left=imm(1):integer/dword
  13 store result=global[n]:integer/dword left=temp[t6]:integer/dword
  block 2 label=L2 first=14 count=4
  14 load_const result=temp[t7]:integer/dword left=imm(100):integer/dword
  15 load result=temp[t9]:integer/dword left=global[n]:integer/dword
  16 binary result=temp[t8]:boolean/byte left=temp[t9]:integer/dword right=temp[t7]:integer/dword op=<=
  17 goto_if_zero left=temp[t8]:boolean/byte target=label[L4]:address
  block 3 first=18 count=20
  18 load result=temp[t10]:integer/dword left=global[n]:integer/dword
  19 load_const result=temp[t11]:integer/dword left=imm(3):integer/dword
  20 binary result=temp[t12]:integer/dword left=temp[t10]:integer/dword right=temp[t11]:integer/dword op=/
  21 load_const result=temp[t13]:integer/dword left=imm(3):integer/dword
  22 binary result=temp[t14]:integer/dword left=temp[t12]:integer/dword right=temp[t13]:integer/dword op=*
  23 load result=temp[t15]:integer/dword left=global[n]:integer/dword
  24 binary result=temp[t16]:boolean/byte left=temp[t14]:integer/dword right=temp[t15]:integer/dword op==
  25 store result=global[fizz]:boolean/byte left=temp[t16]:boolean/byte
  26 load result=temp[t17]:integer/dword left=global[n]:integer/dword
  27 load_const result=temp[t18]:integer/dword left=imm(5):integer/dword
  28 binary result=temp[t19]:integer/dword left=temp[t17]:integer/dword right=temp[t18]:integer/dword op=/
  29 load_const result=temp[t20]:integer/dword left=imm(5):integer/dword
  30 binary result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword op=*
  31 load result=temp[t22]:integer/dword left=global[n]:integer/dword
  32 binary result=temp[t23]:boolean/byte left=temp[t21]:integer/dword right=temp[t22]:integer/dword op==
  33 store result=global[buzz]:boolean/byte left=temp[t23]:boolean/byte
  34 load result=temp[t24]:boolean/byte left=global[fizz]:boolean/byte
  35 load result=temp[t25]:boolean/byte left=global[buzz]:boolean/byte
  36 binary result=temp[t26]:boolean/byte left=temp[t24]:boolean/byte right=temp[t25]:boolean/byte op=and
  37 goto_if_zero left=temp[t26]:boolean/byte target=label[L5]:address
  block 4 first=38 count=9
  38 load_const result=temp[t27]:char/byte left=imm(70):char/byte
  39 builtin_write left=temp[t27]:char/byte target=intrinsic[write]:address
  40 load_const result=temp[t28]:char/byte left=imm(66):char/byte
  41 builtin_write left=temp[t28]:char/byte target=intrinsic[writeln]:address
  42 load result=temp[t29]:integer/dword left=global[cfb]:integer/dword
  43 load_const result=temp[t30]:integer/dword left=imm(1):integer/dword
  44 binary result=temp[t31]:integer/dword left=temp[t29]:integer/dword right=temp[t30]:integer/dword op=+
  45 store result=global[cfb]:integer/dword left=temp[t31]:integer/dword
  46 goto target=label[L6]:address
  block 5 label=L5 first=47 count=2
  47 load result=temp[t32]:boolean/byte left=global[fizz]:boolean/byte
  48 goto_if_zero left=temp[t32]:boolean/byte target=label[L7]:address
  block 6 first=49 count=7
  49 load_const result=temp[t33]:char/byte left=imm(70):char/byte
  50 builtin_write left=temp[t33]:char/byte target=intrinsic[writeln]:address
  51 load result=temp[t34]:integer/dword left=global[cfizz]:integer/dword
  52 load_const result=temp[t35]:integer/dword left=imm(1):integer/dword
  53 binary result=temp[t36]:integer/dword left=temp[t34]:integer/dword right=temp[t35]:integer/dword op=+
  54 store result=global[cfizz]:integer/dword left=temp[t36]:integer/dword
  55 goto target=label[L8]:address
  block 7 label=L7 first=56 count=2
  56 load result=temp[t37]:boolean/byte left=global[buzz]:boolean/byte
  57 goto_if_zero left=temp[t37]:boolean/byte target=label[L9]:address
  block 8 first=58 count=7
  58 load_const result=temp[t38]:char/byte left=imm(66):char/byte
  59 builtin_write left=temp[t38]:char/byte target=intrinsic[writeln]:address
  60 load result=temp[t39]:integer/dword left=global[cbuzz]:integer/dword
  61 load_const result=temp[t40]:integer/dword left=imm(1):integer/dword
  62 binary result=temp[t41]:integer/dword left=temp[t39]:integer/dword right=temp[t40]:integer/dword op=+
  63 store result=global[cbuzz]:integer/dword left=temp[t41]:integer/dword
  64 goto target=label[L10]:address
  block 9 label=L9 first=65 count=6
  65 load result=temp[t42]:integer/dword left=global[n]:integer/dword
  66 builtin_write left=temp[t42]:integer/dword target=intrinsic[writeln]:address
  67 load result=temp[t43]:integer/dword left=global[cnorm]:integer/dword
  68 load_const result=temp[t44]:integer/dword left=imm(1):integer/dword
  69 binary result=temp[t45]:integer/dword left=temp[t43]:integer/dword right=temp[t44]:integer/dword op=+
  70 store result=global[cnorm]:integer/dword left=temp[t45]:integer/dword
  block 10 label=L10 alias=L3 alias=L6 alias=L8 first=71 count=5
  71 load_const result=temp[t46]:integer/dword left=imm(1):integer/dword
  72 load result=temp[t48]:integer/dword left=global[n]:integer/dword
  73 binary result=temp[t47]:integer/dword left=temp[t48]:integer/dword right=temp[t46]:integer/dword op=+
  74 store result=global[n]:integer/dword left=temp[t47]:integer/dword
  75 goto target=label[L2]:address
  block 11 label=L4 first=76 count=3
  76 call target=proc[printsumma]:address
  77 leave
  78 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=14
  labelmap L3 block=10 first=71
  labelmap L4 block=11 first=76
  labelmap L5 block=5 first=47
  labelmap L6 block=10 first=71
  labelmap L7 block=7 first=56
  labelmap L8 block=10 first=71
  labelmap L9 block=9 first=65
  labelmap L10 block=10 first=71
endproc
proc 2 printsumma return=none params=0 locals=0 temps=13 blocks=1 labels=1 instructions=29
  frame params=0 locals=0 temps=13 param_area=0 local_area=0 temp_area=25 frame_size=25
  frame_temp 1 temp[t49]:char/byte offset=-1 size=1
  frame_temp 2 temp[t50]:char/byte offset=-2 size=1
  frame_temp 3 temp[t51]:integer/dword offset=-6 size=4
  frame_temp 4 temp[t52]:char/byte offset=-7 size=1
  frame_temp 5 temp[t53]:char/byte offset=-8 size=1
  frame_temp 6 temp[t54]:integer/dword offset=-12 size=4
  frame_temp 7 temp[t55]:char/byte offset=-13 size=1
  frame_temp 8 temp[t56]:char/byte offset=-14 size=1
  frame_temp 9 temp[t57]:integer/dword offset=-18 size=4
  frame_temp 10 temp[t58]:char/byte offset=-19 size=1
  frame_temp 11 temp[t59]:char/byte offset=-20 size=1
  frame_temp 12 temp[t60]:char/byte offset=-21 size=1
  frame_temp 13 temp[t61]:integer/dword offset=-25 size=4
  block 1 label=L11 first=1 count=29
   1 enter left=imm(25):integer/dword
   2 load_const result=temp[t49]:char/byte left=imm(78):char/byte
   3 builtin_write left=temp[t49]:char/byte target=intrinsic[write]:address
   4 load_const result=temp[t50]:char/byte left=imm(58):char/byte
   5 builtin_write left=temp[t50]:char/byte target=intrinsic[write]:address
   6 load result=temp[t51]:integer/dword left=global[cnorm]:integer/dword
   7 builtin_write left=temp[t51]:integer/dword target=intrinsic[writeln]:address
   8 load_const result=temp[t52]:char/byte left=imm(70):char/byte
   9 builtin_write left=temp[t52]:char/byte target=intrinsic[write]:address
  10 load_const result=temp[t53]:char/byte left=imm(58):char/byte
  11 builtin_write left=temp[t53]:char/byte target=intrinsic[write]:address
  12 load result=temp[t54]:integer/dword left=global[cfizz]:integer/dword
  13 builtin_write left=temp[t54]:integer/dword target=intrinsic[writeln]:address
  14 load_const result=temp[t55]:char/byte left=imm(66):char/byte
  15 builtin_write left=temp[t55]:char/byte target=intrinsic[write]:address
  16 load_const result=temp[t56]:char/byte left=imm(58):char/byte
  17 builtin_write left=temp[t56]:char/byte target=intrinsic[write]:address
  18 load result=temp[t57]:integer/dword left=global[cbuzz]:integer/dword
  19 builtin_write left=temp[t57]:integer/dword target=intrinsic[writeln]:address
  20 load_const result=temp[t58]:char/byte left=imm(70):char/byte
  21 builtin_write left=temp[t58]:char/byte target=intrinsic[write]:address
  22 load_const result=temp[t59]:char/byte left=imm(66):char/byte
  23 builtin_write left=temp[t59]:char/byte target=intrinsic[write]:address
  24 load_const result=temp[t60]:char/byte left=imm(58):char/byte
  25 builtin_write left=temp[t60]:char/byte target=intrinsic[write]:address
  26 load result=temp[t61]:integer/dword left=global[cfb]:integer/dword
  27 builtin_write left=temp[t61]:integer/dword target=intrinsic[writeln]:address
  28 leave
  29 return
endproc
