tac program
procedures 2
proc 1 fizzbuzz return=none params=0 locals=8 temps=48 blocks=11 labels=10 instructions=82
  local 1 global[n]:integer/dword
  local 2 global[fizz]:boolean/byte
  local 3 global[buzz]:boolean/byte
  local 4 global[cnorm]:integer/dword
  local 5 global[cfizz]:integer/dword
  local 6 global[cbuzz]:integer/dword
  local 7 global[cfb]:integer/dword
  local 8 global[sumcnt]:integer/dword
  frame params=0 locals=8 temps=48 temp_policy=stack_slots param_area=0 local_area=26 temp_area=156 frame_size=182
  frame_local 1 global[n]:integer/dword offset=-4 size=4
  frame_local 2 global[fizz]:boolean/byte offset=-5 size=1
  frame_local 3 global[buzz]:boolean/byte offset=-6 size=1
  frame_local 4 global[cnorm]:integer/dword offset=-10 size=4
  frame_local 5 global[cfizz]:integer/dword offset=-14 size=4
  frame_local 6 global[cbuzz]:integer/dword offset=-18 size=4
  frame_local 7 global[cfb]:integer/dword offset=-22 size=4
  frame_local 8 global[sumcnt]:integer/dword offset=-26 size=4
  frame_temp 1 temp[t1]:integer/dword storage=stack_slot offset=-30 size=4
  frame_temp 2 temp[t2]:integer/dword storage=stack_slot offset=-34 size=4
  frame_temp 3 temp[t3]:integer/dword storage=stack_slot offset=-38 size=4
  frame_temp 4 temp[t4]:integer/dword storage=stack_slot offset=-42 size=4
  frame_temp 5 temp[t5]:integer/dword storage=stack_slot offset=-46 size=4
  frame_temp 6 temp[t6]:integer/dword storage=stack_slot offset=-50 size=4
  frame_temp 7 temp[t7]:integer/dword storage=stack_slot offset=-54 size=4
  frame_temp 8 temp[t8]:boolean/byte storage=stack_slot offset=-55 size=1
  frame_temp 9 temp[t9]:integer/dword storage=stack_slot offset=-59 size=4
  frame_temp 10 temp[t10]:integer/dword storage=stack_slot offset=-63 size=4
  frame_temp 11 temp[t11]:integer/dword storage=stack_slot offset=-67 size=4
  frame_temp 12 temp[t12]:integer/dword storage=stack_slot offset=-71 size=4
  frame_temp 13 temp[t13]:integer/dword storage=stack_slot offset=-75 size=4
  frame_temp 14 temp[t14]:integer/dword storage=stack_slot offset=-79 size=4
  frame_temp 15 temp[t15]:integer/dword storage=stack_slot offset=-83 size=4
  frame_temp 16 temp[t16]:boolean/byte storage=stack_slot offset=-84 size=1
  frame_temp 17 temp[t17]:integer/dword storage=stack_slot offset=-88 size=4
  frame_temp 18 temp[t18]:integer/dword storage=stack_slot offset=-92 size=4
  frame_temp 19 temp[t19]:integer/dword storage=stack_slot offset=-96 size=4
  frame_temp 20 temp[t20]:integer/dword storage=stack_slot offset=-100 size=4
  frame_temp 21 temp[t21]:integer/dword storage=stack_slot offset=-104 size=4
  frame_temp 22 temp[t22]:integer/dword storage=stack_slot offset=-108 size=4
  frame_temp 23 temp[t23]:boolean/byte storage=stack_slot offset=-109 size=1
  frame_temp 24 temp[t24]:boolean/byte storage=stack_slot offset=-110 size=1
  frame_temp 25 temp[t25]:boolean/byte storage=stack_slot offset=-111 size=1
  frame_temp 26 temp[t26]:boolean/byte storage=stack_slot offset=-112 size=1
  frame_temp 27 temp[t27]:char/byte storage=stack_slot offset=-113 size=1
  frame_temp 28 temp[t28]:char/byte storage=stack_slot offset=-114 size=1
  frame_temp 29 temp[t29]:integer/dword storage=stack_slot offset=-118 size=4
  frame_temp 30 temp[t30]:integer/dword storage=stack_slot offset=-122 size=4
  frame_temp 31 temp[t31]:integer/dword storage=stack_slot offset=-126 size=4
  frame_temp 32 temp[t32]:boolean/byte storage=stack_slot offset=-127 size=1
  frame_temp 33 temp[t33]:char/byte storage=stack_slot offset=-128 size=1
  frame_temp 34 temp[t34]:integer/dword storage=stack_slot offset=-132 size=4
  frame_temp 35 temp[t35]:integer/dword storage=stack_slot offset=-136 size=4
  frame_temp 36 temp[t36]:integer/dword storage=stack_slot offset=-140 size=4
  frame_temp 37 temp[t37]:boolean/byte storage=stack_slot offset=-141 size=1
  frame_temp 38 temp[t38]:char/byte storage=stack_slot offset=-142 size=1
  frame_temp 39 temp[t39]:integer/dword storage=stack_slot offset=-146 size=4
  frame_temp 40 temp[t40]:integer/dword storage=stack_slot offset=-150 size=4
  frame_temp 41 temp[t41]:integer/dword storage=stack_slot offset=-154 size=4
  frame_temp 42 temp[t42]:integer/dword storage=stack_slot offset=-158 size=4
  frame_temp 43 temp[t43]:integer/dword storage=stack_slot offset=-162 size=4
  frame_temp 44 temp[t44]:integer/dword storage=stack_slot offset=-166 size=4
  frame_temp 45 temp[t45]:integer/dword storage=stack_slot offset=-170 size=4
  frame_temp 46 temp[t46]:integer/dword storage=stack_slot offset=-174 size=4
  frame_temp 47 temp[t47]:integer/dword storage=stack_slot offset=-178 size=4
  frame_temp 48 temp[t48]:integer/dword storage=stack_slot offset=-182 size=4
  block 1 label=L1 first=1 count=13
   1 enter left=imm(182):integer/dword
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
  block 4 first=38 count=10
  38 copy result=temp[t27]:char/byte left=imm(70):char/byte
  39 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t27]:char/byte
  40 copy result=temp[t28]:char/byte left=imm(66):char/byte
  41 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t28]:char/byte
  42 intrinsic_call target=intrinsic[writeln]:address
  43 load result=temp[t29]:integer/dword left=global[cfb]:integer/dword
  44 copy result=temp[t30]:integer/dword left=imm(1):integer/dword
  45 add result=temp[t31]:integer/dword left=temp[t29]:integer/dword right=temp[t30]:integer/dword
  46 store result=global[cfb]:integer/dword left=temp[t31]:integer/dword
  47 jump target=label[L6]:address
  block 5 label=L5 first=48 count=2
  48 load result=temp[t32]:boolean/byte left=global[fizz]:boolean/byte
  49 brfalse left=temp[t32]:boolean/byte target=label[L7]:address
  block 6 first=50 count=8
  50 copy result=temp[t33]:char/byte left=imm(70):char/byte
  51 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t33]:char/byte
  52 intrinsic_call target=intrinsic[writeln]:address
  53 load result=temp[t34]:integer/dword left=global[cfizz]:integer/dword
  54 copy result=temp[t35]:integer/dword left=imm(1):integer/dword
  55 add result=temp[t36]:integer/dword left=temp[t34]:integer/dword right=temp[t35]:integer/dword
  56 store result=global[cfizz]:integer/dword left=temp[t36]:integer/dword
  57 jump target=label[L8]:address
  block 7 label=L7 first=58 count=2
  58 load result=temp[t37]:boolean/byte left=global[buzz]:boolean/byte
  59 brfalse left=temp[t37]:boolean/byte target=label[L9]:address
  block 8 first=60 count=8
  60 copy result=temp[t38]:char/byte left=imm(66):char/byte
  61 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t38]:char/byte
  62 intrinsic_call target=intrinsic[writeln]:address
  63 load result=temp[t39]:integer/dword left=global[cbuzz]:integer/dword
  64 copy result=temp[t40]:integer/dword left=imm(1):integer/dword
  65 add result=temp[t41]:integer/dword left=temp[t39]:integer/dword right=temp[t40]:integer/dword
  66 store result=global[cbuzz]:integer/dword left=temp[t41]:integer/dword
  67 jump target=label[L10]:address
  block 9 label=L9 first=68 count=7
  68 load result=temp[t42]:integer/dword left=global[n]:integer/dword
  69 intrinsic_call target=intrinsic[write_int]:address arg1=temp[t42]:integer/dword
  70 intrinsic_call target=intrinsic[writeln]:address
  71 load result=temp[t43]:integer/dword left=global[cnorm]:integer/dword
  72 copy result=temp[t44]:integer/dword left=imm(1):integer/dword
  73 add result=temp[t45]:integer/dword left=temp[t43]:integer/dword right=temp[t44]:integer/dword
  74 store result=global[cnorm]:integer/dword left=temp[t45]:integer/dword
  block 10 label=L10 alias=L3 alias=L6 alias=L8 first=75 count=5
  75 copy result=temp[t46]:integer/dword left=imm(1):integer/dword
  76 load result=temp[t48]:integer/dword left=global[n]:integer/dword
  77 add result=temp[t47]:integer/dword left=temp[t48]:integer/dword right=temp[t46]:integer/dword
  78 store result=global[n]:integer/dword left=temp[t47]:integer/dword
  79 jump target=label[L2]:address
  block 11 label=L4 first=80 count=3
  80 call target=proc[printsumma]:address
  81 leave
  82 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=14
  labelmap L3 block=10 first=75
  labelmap L4 block=11 first=80
  labelmap L5 block=5 first=48
  labelmap L6 block=10 first=75
  labelmap L7 block=7 first=58
  labelmap L8 block=10 first=75
  labelmap L9 block=9 first=68
  labelmap L10 block=10 first=75
endproc
proc 2 printsumma return=none params=0 locals=0 temps=13 blocks=1 labels=1 instructions=33
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
  block 1 label=L11 first=1 count=33
   1 enter left=imm(25):integer/dword
   2 copy result=temp[t49]:char/byte left=imm(78):char/byte
   3 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t49]:char/byte
   4 copy result=temp[t50]:char/byte left=imm(58):char/byte
   5 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t50]:char/byte
   6 load result=temp[t51]:integer/dword left=global[cnorm]:integer/dword
   7 intrinsic_call target=intrinsic[write_int]:address arg1=temp[t51]:integer/dword
   8 intrinsic_call target=intrinsic[writeln]:address
   9 copy result=temp[t52]:char/byte left=imm(70):char/byte
  10 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t52]:char/byte
  11 copy result=temp[t53]:char/byte left=imm(58):char/byte
  12 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t53]:char/byte
  13 load result=temp[t54]:integer/dword left=global[cfizz]:integer/dword
  14 intrinsic_call target=intrinsic[write_int]:address arg1=temp[t54]:integer/dword
  15 intrinsic_call target=intrinsic[writeln]:address
  16 copy result=temp[t55]:char/byte left=imm(66):char/byte
  17 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t55]:char/byte
  18 copy result=temp[t56]:char/byte left=imm(58):char/byte
  19 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t56]:char/byte
  20 load result=temp[t57]:integer/dword left=global[cbuzz]:integer/dword
  21 intrinsic_call target=intrinsic[write_int]:address arg1=temp[t57]:integer/dword
  22 intrinsic_call target=intrinsic[writeln]:address
  23 copy result=temp[t58]:char/byte left=imm(70):char/byte
  24 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t58]:char/byte
  25 copy result=temp[t59]:char/byte left=imm(66):char/byte
  26 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t59]:char/byte
  27 copy result=temp[t60]:char/byte left=imm(58):char/byte
  28 intrinsic_call target=intrinsic[write_char]:address arg1=temp[t60]:char/byte
  29 load result=temp[t61]:integer/dword left=global[cfb]:integer/dword
  30 intrinsic_call target=intrinsic[write_int]:address arg1=temp[t61]:integer/dword
  31 intrinsic_call target=intrinsic[writeln]:address
  32 leave
  33 return
  labelmap L11 block=1 first=1
endproc
