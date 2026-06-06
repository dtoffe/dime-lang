tac program
procedures 2
proc 1 fizzbuzz return=none params=0 locals=0 temps=48 blocks=11 labels=10 instructions=76
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
  block 1 label=L1 first=1 count=12
   1 load_const result=temp[t1]:integer/dword left=imm(0):integer/dword
   2 store result=global[cnorm]:integer/dword left=temp[t1]:integer/dword
   3 load_const result=temp[t2]:integer/dword left=imm(0):integer/dword
   4 store result=global[cfizz]:integer/dword left=temp[t2]:integer/dword
   5 load_const result=temp[t3]:integer/dword left=imm(0):integer/dword
   6 store result=global[cbuzz]:integer/dword left=temp[t3]:integer/dword
   7 load_const result=temp[t4]:integer/dword left=imm(0):integer/dword
   8 store result=global[cfb]:integer/dword left=temp[t4]:integer/dword
   9 load_const result=temp[t5]:integer/dword left=imm(0):integer/dword
  10 store result=global[sumcnt]:integer/dword left=temp[t5]:integer/dword
  11 load_const result=temp[t6]:integer/dword left=imm(1):integer/dword
  12 store result=global[n]:integer/dword left=temp[t6]:integer/dword
  block 2 label=L2 first=13 count=4
  13 load_const result=temp[t7]:integer/dword left=imm(100):integer/dword
  14 load result=temp[t9]:integer/dword left=global[n]:integer/dword
  15 binary result=temp[t8]:boolean/byte left=temp[t9]:integer/dword right=temp[t7]:integer/dword op=<=
  16 goto_if_zero left=temp[t8]:boolean/byte target=label[L4]:address
  block 3 first=17 count=20
  17 load result=temp[t10]:integer/dword left=global[n]:integer/dword
  18 load_const result=temp[t11]:integer/dword left=imm(3):integer/dword
  19 binary result=temp[t12]:integer/dword left=temp[t10]:integer/dword right=temp[t11]:integer/dword op=/
  20 load_const result=temp[t13]:integer/dword left=imm(3):integer/dword
  21 binary result=temp[t14]:integer/dword left=temp[t12]:integer/dword right=temp[t13]:integer/dword op=*
  22 load result=temp[t15]:integer/dword left=global[n]:integer/dword
  23 binary result=temp[t16]:boolean/byte left=temp[t14]:integer/dword right=temp[t15]:integer/dword op==
  24 store result=global[fizz]:boolean/byte left=temp[t16]:boolean/byte
  25 load result=temp[t17]:integer/dword left=global[n]:integer/dword
  26 load_const result=temp[t18]:integer/dword left=imm(5):integer/dword
  27 binary result=temp[t19]:integer/dword left=temp[t17]:integer/dword right=temp[t18]:integer/dword op=/
  28 load_const result=temp[t20]:integer/dword left=imm(5):integer/dword
  29 binary result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword op=*
  30 load result=temp[t22]:integer/dword left=global[n]:integer/dword
  31 binary result=temp[t23]:boolean/byte left=temp[t21]:integer/dword right=temp[t22]:integer/dword op==
  32 store result=global[buzz]:boolean/byte left=temp[t23]:boolean/byte
  33 load result=temp[t24]:boolean/byte left=global[fizz]:boolean/byte
  34 load result=temp[t25]:boolean/byte left=global[buzz]:boolean/byte
  35 binary result=temp[t26]:boolean/byte left=temp[t24]:boolean/byte right=temp[t25]:boolean/byte op=and
  36 goto_if_zero left=temp[t26]:boolean/byte target=label[L5]:address
  block 4 first=37 count=9
  37 load_const result=temp[t27]:char/byte left=imm(70):char/byte
  38 builtin_write left=temp[t27]:char/byte target=intrinsic[write]:address
  39 load_const result=temp[t28]:char/byte left=imm(66):char/byte
  40 builtin_write left=temp[t28]:char/byte target=intrinsic[writeln]:address
  41 load result=temp[t29]:integer/dword left=global[cfb]:integer/dword
  42 load_const result=temp[t30]:integer/dword left=imm(1):integer/dword
  43 binary result=temp[t31]:integer/dword left=temp[t29]:integer/dword right=temp[t30]:integer/dword op=+
  44 store result=global[cfb]:integer/dword left=temp[t31]:integer/dword
  45 goto target=label[L6]:address
  block 5 label=L5 first=46 count=2
  46 load result=temp[t32]:boolean/byte left=global[fizz]:boolean/byte
  47 goto_if_zero left=temp[t32]:boolean/byte target=label[L7]:address
  block 6 first=48 count=7
  48 load_const result=temp[t33]:char/byte left=imm(70):char/byte
  49 builtin_write left=temp[t33]:char/byte target=intrinsic[writeln]:address
  50 load result=temp[t34]:integer/dword left=global[cfizz]:integer/dword
  51 load_const result=temp[t35]:integer/dword left=imm(1):integer/dword
  52 binary result=temp[t36]:integer/dword left=temp[t34]:integer/dword right=temp[t35]:integer/dword op=+
  53 store result=global[cfizz]:integer/dword left=temp[t36]:integer/dword
  54 goto target=label[L8]:address
  block 7 label=L7 first=55 count=2
  55 load result=temp[t37]:boolean/byte left=global[buzz]:boolean/byte
  56 goto_if_zero left=temp[t37]:boolean/byte target=label[L9]:address
  block 8 first=57 count=7
  57 load_const result=temp[t38]:char/byte left=imm(66):char/byte
  58 builtin_write left=temp[t38]:char/byte target=intrinsic[writeln]:address
  59 load result=temp[t39]:integer/dword left=global[cbuzz]:integer/dword
  60 load_const result=temp[t40]:integer/dword left=imm(1):integer/dword
  61 binary result=temp[t41]:integer/dword left=temp[t39]:integer/dword right=temp[t40]:integer/dword op=+
  62 store result=global[cbuzz]:integer/dword left=temp[t41]:integer/dword
  63 goto target=label[L10]:address
  block 9 label=L9 first=64 count=6
  64 load result=temp[t42]:integer/dword left=global[n]:integer/dword
  65 builtin_write left=temp[t42]:integer/dword target=intrinsic[writeln]:address
  66 load result=temp[t43]:integer/dword left=global[cnorm]:integer/dword
  67 load_const result=temp[t44]:integer/dword left=imm(1):integer/dword
  68 binary result=temp[t45]:integer/dword left=temp[t43]:integer/dword right=temp[t44]:integer/dword op=+
  69 store result=global[cnorm]:integer/dword left=temp[t45]:integer/dword
  block 10 label=L10 alias=L3 alias=L6 alias=L8 first=70 count=5
  70 load_const result=temp[t46]:integer/dword left=imm(1):integer/dword
  71 load result=temp[t48]:integer/dword left=global[n]:integer/dword
  72 binary result=temp[t47]:integer/dword left=temp[t48]:integer/dword right=temp[t46]:integer/dword op=+
  73 store result=global[n]:integer/dword left=temp[t47]:integer/dword
  74 goto target=label[L2]:address
  block 11 label=L4 first=75 count=2
  75 call target=proc[printsumma]:address
  76 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=13
  labelmap L3 block=10 first=70
  labelmap L4 block=11 first=75
  labelmap L5 block=5 first=46
  labelmap L6 block=10 first=70
  labelmap L7 block=7 first=55
  labelmap L8 block=10 first=70
  labelmap L9 block=9 first=64
  labelmap L10 block=10 first=70
endproc
proc 2 printsumma return=none params=0 locals=0 temps=13 blocks=1 labels=1 instructions=27
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
  block 1 label=L11 first=1 count=27
   1 load_const result=temp[t49]:char/byte left=imm(78):char/byte
   2 builtin_write left=temp[t49]:char/byte target=intrinsic[write]:address
   3 load_const result=temp[t50]:char/byte left=imm(58):char/byte
   4 builtin_write left=temp[t50]:char/byte target=intrinsic[write]:address
   5 load result=temp[t51]:integer/dword left=global[cnorm]:integer/dword
   6 builtin_write left=temp[t51]:integer/dword target=intrinsic[writeln]:address
   7 load_const result=temp[t52]:char/byte left=imm(70):char/byte
   8 builtin_write left=temp[t52]:char/byte target=intrinsic[write]:address
   9 load_const result=temp[t53]:char/byte left=imm(58):char/byte
  10 builtin_write left=temp[t53]:char/byte target=intrinsic[write]:address
  11 load result=temp[t54]:integer/dword left=global[cfizz]:integer/dword
  12 builtin_write left=temp[t54]:integer/dword target=intrinsic[writeln]:address
  13 load_const result=temp[t55]:char/byte left=imm(66):char/byte
  14 builtin_write left=temp[t55]:char/byte target=intrinsic[write]:address
  15 load_const result=temp[t56]:char/byte left=imm(58):char/byte
  16 builtin_write left=temp[t56]:char/byte target=intrinsic[write]:address
  17 load result=temp[t57]:integer/dword left=global[cbuzz]:integer/dword
  18 builtin_write left=temp[t57]:integer/dword target=intrinsic[writeln]:address
  19 load_const result=temp[t58]:char/byte left=imm(70):char/byte
  20 builtin_write left=temp[t58]:char/byte target=intrinsic[write]:address
  21 load_const result=temp[t59]:char/byte left=imm(66):char/byte
  22 builtin_write left=temp[t59]:char/byte target=intrinsic[write]:address
  23 load_const result=temp[t60]:char/byte left=imm(58):char/byte
  24 builtin_write left=temp[t60]:char/byte target=intrinsic[write]:address
  25 load result=temp[t61]:integer/dword left=global[cfb]:integer/dword
  26 builtin_write left=temp[t61]:integer/dword target=intrinsic[writeln]:address
  27 return
endproc
