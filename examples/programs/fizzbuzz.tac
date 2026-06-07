tac program
procedures 2
proc 1 fizzbuzz return=none params=0 locals=0 temps=48 blocks=11 labels=10 instructions=87
  frame params=0 locals=0 temps=48 temp_policy=stack_slots param_area=0 local_area=0 temp_area=156 frame_size=156
  frame_temp 1 temp[t1]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t2]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t3]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 4 temp[t4]:integer/dword storage=stack_slot offset=-16 size=4
  frame_temp 5 temp[t5]:integer/dword storage=stack_slot offset=-20 size=4
  frame_temp 6 temp[t6]:integer/dword storage=stack_slot offset=-24 size=4
  frame_temp 7 temp[t7]:integer/dword storage=stack_slot offset=-28 size=4
  frame_temp 8 temp[t8]:boolean/byte storage=stack_slot offset=-29 size=1
  frame_temp 9 temp[t9]:integer/dword storage=stack_slot offset=-33 size=4
  frame_temp 10 temp[t10]:integer/dword storage=stack_slot offset=-37 size=4
  frame_temp 11 temp[t11]:integer/dword storage=stack_slot offset=-41 size=4
  frame_temp 12 temp[t12]:integer/dword storage=stack_slot offset=-45 size=4
  frame_temp 13 temp[t13]:integer/dword storage=stack_slot offset=-49 size=4
  frame_temp 14 temp[t14]:integer/dword storage=stack_slot offset=-53 size=4
  frame_temp 15 temp[t15]:integer/dword storage=stack_slot offset=-57 size=4
  frame_temp 16 temp[t16]:boolean/byte storage=stack_slot offset=-58 size=1
  frame_temp 17 temp[t17]:integer/dword storage=stack_slot offset=-62 size=4
  frame_temp 18 temp[t18]:integer/dword storage=stack_slot offset=-66 size=4
  frame_temp 19 temp[t19]:integer/dword storage=stack_slot offset=-70 size=4
  frame_temp 20 temp[t20]:integer/dword storage=stack_slot offset=-74 size=4
  frame_temp 21 temp[t21]:integer/dword storage=stack_slot offset=-78 size=4
  frame_temp 22 temp[t22]:integer/dword storage=stack_slot offset=-82 size=4
  frame_temp 23 temp[t23]:boolean/byte storage=stack_slot offset=-83 size=1
  frame_temp 24 temp[t24]:boolean/byte storage=stack_slot offset=-84 size=1
  frame_temp 25 temp[t25]:boolean/byte storage=stack_slot offset=-85 size=1
  frame_temp 26 temp[t26]:boolean/byte storage=stack_slot offset=-86 size=1
  frame_temp 27 temp[t27]:char/byte storage=stack_slot offset=-87 size=1
  frame_temp 28 temp[t28]:char/byte storage=stack_slot offset=-88 size=1
  frame_temp 29 temp[t29]:integer/dword storage=stack_slot offset=-92 size=4
  frame_temp 30 temp[t30]:integer/dword storage=stack_slot offset=-96 size=4
  frame_temp 31 temp[t31]:integer/dword storage=stack_slot offset=-100 size=4
  frame_temp 32 temp[t32]:boolean/byte storage=stack_slot offset=-101 size=1
  frame_temp 33 temp[t33]:char/byte storage=stack_slot offset=-102 size=1
  frame_temp 34 temp[t34]:integer/dword storage=stack_slot offset=-106 size=4
  frame_temp 35 temp[t35]:integer/dword storage=stack_slot offset=-110 size=4
  frame_temp 36 temp[t36]:integer/dword storage=stack_slot offset=-114 size=4
  frame_temp 37 temp[t37]:boolean/byte storage=stack_slot offset=-115 size=1
  frame_temp 38 temp[t38]:char/byte storage=stack_slot offset=-116 size=1
  frame_temp 39 temp[t39]:integer/dword storage=stack_slot offset=-120 size=4
  frame_temp 40 temp[t40]:integer/dword storage=stack_slot offset=-124 size=4
  frame_temp 41 temp[t41]:integer/dword storage=stack_slot offset=-128 size=4
  frame_temp 42 temp[t42]:integer/dword storage=stack_slot offset=-132 size=4
  frame_temp 43 temp[t43]:integer/dword storage=stack_slot offset=-136 size=4
  frame_temp 44 temp[t44]:integer/dword storage=stack_slot offset=-140 size=4
  frame_temp 45 temp[t45]:integer/dword storage=stack_slot offset=-144 size=4
  frame_temp 46 temp[t46]:integer/dword storage=stack_slot offset=-148 size=4
  frame_temp 47 temp[t47]:integer/dword storage=stack_slot offset=-152 size=4
  frame_temp 48 temp[t48]:integer/dword storage=stack_slot offset=-156 size=4
  block 1 label=L1 first=1 count=13
   1 enter left=imm(156):integer/dword
   2 copy result=temp[t1]:integer/dword left=imm(0):integer/dword
   3 store result=global[cnorm]:integer/dword left=temp[t1]:integer/dword
   4 copy result=temp[t2]:integer/dword left=imm(0):integer/dword
   5 store result=global[cfizz]:integer/dword left=temp[t2]:integer/dword
   6 copy result=temp[t3]:integer/dword left=imm(0):integer/dword
   7 store result=global[cbuzz]:integer/dword left=temp[t3]:integer/dword
   8 copy result=temp[t4]:integer/dword left=imm(0):integer/dword
   9 store result=global[cfb]:integer/dword left=temp[t4]:integer/dword
  10 copy result=temp[t5]:integer/dword left=imm(0):integer/dword
  11 store result=global[sumcnt]:integer/dword left=temp[t5]:integer/dword
  12 copy result=temp[t6]:integer/dword left=imm(1):integer/dword
  13 store result=global[n]:integer/dword left=temp[t6]:integer/dword
  block 2 label=L2 first=14 count=4
  14 copy result=temp[t7]:integer/dword left=imm(100):integer/dword
  15 load result=temp[t9]:integer/dword left=global[n]:integer/dword
  16 cmp_le result=temp[t8]:boolean/byte left=temp[t9]:integer/dword right=temp[t7]:integer/dword
  17 brfalse left=temp[t8]:boolean/byte target=label[L4]:address
  block 3 first=18 count=20
  18 load result=temp[t10]:integer/dword left=global[n]:integer/dword
  19 copy result=temp[t11]:integer/dword left=imm(3):integer/dword
  20 div result=temp[t12]:integer/dword left=temp[t10]:integer/dword right=temp[t11]:integer/dword
  21 copy result=temp[t13]:integer/dword left=imm(3):integer/dword
  22 mul result=temp[t14]:integer/dword left=temp[t12]:integer/dword right=temp[t13]:integer/dword
  23 load result=temp[t15]:integer/dword left=global[n]:integer/dword
  24 cmp_eq result=temp[t16]:boolean/byte left=temp[t14]:integer/dword right=temp[t15]:integer/dword
  25 store result=global[fizz]:boolean/byte left=temp[t16]:boolean/byte
  26 load result=temp[t17]:integer/dword left=global[n]:integer/dword
  27 copy result=temp[t18]:integer/dword left=imm(5):integer/dword
  28 div result=temp[t19]:integer/dword left=temp[t17]:integer/dword right=temp[t18]:integer/dword
  29 copy result=temp[t20]:integer/dword left=imm(5):integer/dword
  30 mul result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword
  31 load result=temp[t22]:integer/dword left=global[n]:integer/dword
  32 cmp_eq result=temp[t23]:boolean/byte left=temp[t21]:integer/dword right=temp[t22]:integer/dword
  33 store result=global[buzz]:boolean/byte left=temp[t23]:boolean/byte
  34 load result=temp[t24]:boolean/byte left=global[fizz]:boolean/byte
  35 load result=temp[t25]:boolean/byte left=global[buzz]:boolean/byte
  36 mul result=temp[t26]:boolean/byte left=temp[t24]:boolean/byte right=temp[t25]:boolean/byte
  37 brfalse left=temp[t26]:boolean/byte target=label[L5]:address
  block 4 first=38 count=12
  38 copy result=temp[t27]:char/byte left=imm(70):char/byte
  39 arg left=temp[t27]:char/byte index=0
  40 intrinsic_call target=intrinsic[write_char]:address
  41 copy result=temp[t28]:char/byte left=imm(66):char/byte
  42 arg left=temp[t28]:char/byte index=0
  43 intrinsic_call target=intrinsic[write_char]:address
  44 intrinsic_call target=intrinsic[writeln]:address
  45 load result=temp[t29]:integer/dword left=global[cfb]:integer/dword
  46 copy result=temp[t30]:integer/dword left=imm(1):integer/dword
  47 add result=temp[t31]:integer/dword left=temp[t29]:integer/dword right=temp[t30]:integer/dword
  48 store result=global[cfb]:integer/dword left=temp[t31]:integer/dword
  49 jump target=label[L6]:address
  block 5 label=L5 first=50 count=2
  50 load result=temp[t32]:boolean/byte left=global[fizz]:boolean/byte
  51 brfalse left=temp[t32]:boolean/byte target=label[L7]:address
  block 6 first=52 count=9
  52 copy result=temp[t33]:char/byte left=imm(70):char/byte
  53 arg left=temp[t33]:char/byte index=0
  54 intrinsic_call target=intrinsic[write_char]:address
  55 intrinsic_call target=intrinsic[writeln]:address
  56 load result=temp[t34]:integer/dword left=global[cfizz]:integer/dword
  57 copy result=temp[t35]:integer/dword left=imm(1):integer/dword
  58 add result=temp[t36]:integer/dword left=temp[t34]:integer/dword right=temp[t35]:integer/dword
  59 store result=global[cfizz]:integer/dword left=temp[t36]:integer/dword
  60 jump target=label[L8]:address
  block 7 label=L7 first=61 count=2
  61 load result=temp[t37]:boolean/byte left=global[buzz]:boolean/byte
  62 brfalse left=temp[t37]:boolean/byte target=label[L9]:address
  block 8 first=63 count=9
  63 copy result=temp[t38]:char/byte left=imm(66):char/byte
  64 arg left=temp[t38]:char/byte index=0
  65 intrinsic_call target=intrinsic[write_char]:address
  66 intrinsic_call target=intrinsic[writeln]:address
  67 load result=temp[t39]:integer/dword left=global[cbuzz]:integer/dword
  68 copy result=temp[t40]:integer/dword left=imm(1):integer/dword
  69 add result=temp[t41]:integer/dword left=temp[t39]:integer/dword right=temp[t40]:integer/dword
  70 store result=global[cbuzz]:integer/dword left=temp[t41]:integer/dword
  71 jump target=label[L10]:address
  block 9 label=L9 first=72 count=8
  72 load result=temp[t42]:integer/dword left=global[n]:integer/dword
  73 arg left=temp[t42]:integer/dword index=0
  74 intrinsic_call target=intrinsic[write_int]:address
  75 intrinsic_call target=intrinsic[writeln]:address
  76 load result=temp[t43]:integer/dword left=global[cnorm]:integer/dword
  77 copy result=temp[t44]:integer/dword left=imm(1):integer/dword
  78 add result=temp[t45]:integer/dword left=temp[t43]:integer/dword right=temp[t44]:integer/dword
  79 store result=global[cnorm]:integer/dword left=temp[t45]:integer/dword
  block 10 label=L10 alias=L3 alias=L6 alias=L8 first=80 count=5
  80 copy result=temp[t46]:integer/dword left=imm(1):integer/dword
  81 load result=temp[t48]:integer/dword left=global[n]:integer/dword
  82 add result=temp[t47]:integer/dword left=temp[t48]:integer/dword right=temp[t46]:integer/dword
  83 store result=global[n]:integer/dword left=temp[t47]:integer/dword
  84 jump target=label[L2]:address
  block 11 label=L4 first=85 count=3
  85 call target=proc[printsumma]:address
  86 leave
  87 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=14
  labelmap L3 block=10 first=80
  labelmap L4 block=11 first=85
  labelmap L5 block=5 first=50
  labelmap L6 block=10 first=80
  labelmap L7 block=7 first=61
  labelmap L8 block=10 first=80
  labelmap L9 block=9 first=72
  labelmap L10 block=10 first=80
endproc
proc 2 printsumma return=none params=0 locals=0 temps=13 blocks=1 labels=1 instructions=46
  frame params=0 locals=0 temps=13 temp_policy=stack_slots param_area=0 local_area=0 temp_area=25 frame_size=25
  frame_temp 1 temp[t49]:char/byte storage=stack_slot offset=-1 size=1
  frame_temp 2 temp[t50]:char/byte storage=stack_slot offset=-2 size=1
  frame_temp 3 temp[t51]:integer/dword storage=stack_slot offset=-6 size=4
  frame_temp 4 temp[t52]:char/byte storage=stack_slot offset=-7 size=1
  frame_temp 5 temp[t53]:char/byte storage=stack_slot offset=-8 size=1
  frame_temp 6 temp[t54]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 7 temp[t55]:char/byte storage=stack_slot offset=-13 size=1
  frame_temp 8 temp[t56]:char/byte storage=stack_slot offset=-14 size=1
  frame_temp 9 temp[t57]:integer/dword storage=stack_slot offset=-18 size=4
  frame_temp 10 temp[t58]:char/byte storage=stack_slot offset=-19 size=1
  frame_temp 11 temp[t59]:char/byte storage=stack_slot offset=-20 size=1
  frame_temp 12 temp[t60]:char/byte storage=stack_slot offset=-21 size=1
  frame_temp 13 temp[t61]:integer/dword storage=stack_slot offset=-25 size=4
  block 1 label=L11 first=1 count=46
   1 enter left=imm(25):integer/dword
   2 copy result=temp[t49]:char/byte left=imm(78):char/byte
   3 arg left=temp[t49]:char/byte index=0
   4 intrinsic_call target=intrinsic[write_char]:address
   5 copy result=temp[t50]:char/byte left=imm(58):char/byte
   6 arg left=temp[t50]:char/byte index=0
   7 intrinsic_call target=intrinsic[write_char]:address
   8 load result=temp[t51]:integer/dword left=global[cnorm]:integer/dword
   9 arg left=temp[t51]:integer/dword index=0
  10 intrinsic_call target=intrinsic[write_int]:address
  11 intrinsic_call target=intrinsic[writeln]:address
  12 copy result=temp[t52]:char/byte left=imm(70):char/byte
  13 arg left=temp[t52]:char/byte index=0
  14 intrinsic_call target=intrinsic[write_char]:address
  15 copy result=temp[t53]:char/byte left=imm(58):char/byte
  16 arg left=temp[t53]:char/byte index=0
  17 intrinsic_call target=intrinsic[write_char]:address
  18 load result=temp[t54]:integer/dword left=global[cfizz]:integer/dword
  19 arg left=temp[t54]:integer/dword index=0
  20 intrinsic_call target=intrinsic[write_int]:address
  21 intrinsic_call target=intrinsic[writeln]:address
  22 copy result=temp[t55]:char/byte left=imm(66):char/byte
  23 arg left=temp[t55]:char/byte index=0
  24 intrinsic_call target=intrinsic[write_char]:address
  25 copy result=temp[t56]:char/byte left=imm(58):char/byte
  26 arg left=temp[t56]:char/byte index=0
  27 intrinsic_call target=intrinsic[write_char]:address
  28 load result=temp[t57]:integer/dword left=global[cbuzz]:integer/dword
  29 arg left=temp[t57]:integer/dword index=0
  30 intrinsic_call target=intrinsic[write_int]:address
  31 intrinsic_call target=intrinsic[writeln]:address
  32 copy result=temp[t58]:char/byte left=imm(70):char/byte
  33 arg left=temp[t58]:char/byte index=0
  34 intrinsic_call target=intrinsic[write_char]:address
  35 copy result=temp[t59]:char/byte left=imm(66):char/byte
  36 arg left=temp[t59]:char/byte index=0
  37 intrinsic_call target=intrinsic[write_char]:address
  38 copy result=temp[t60]:char/byte left=imm(58):char/byte
  39 arg left=temp[t60]:char/byte index=0
  40 intrinsic_call target=intrinsic[write_char]:address
  41 load result=temp[t61]:integer/dword left=global[cfb]:integer/dword
  42 arg left=temp[t61]:integer/dword index=0
  43 intrinsic_call target=intrinsic[write_int]:address
  44 intrinsic_call target=intrinsic[writeln]:address
  45 leave
  46 return
endproc
