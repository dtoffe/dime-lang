tac program
procedures 6
proc 1 calc return=none params=0 locals=0 temps=18 blocks=10 labels=6 instructions=33
  frame params=0 locals=0 temps=18 temp_policy=stack_slots param_area=0 local_area=0 temp_area=60 frame_size=60
  frame_temp 1 temp[t1]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t2]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t3]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 4 temp[t4]:integer/dword storage=stack_slot offset=-16 size=4
  frame_temp 5 temp[t5]:boolean/byte storage=stack_slot offset=-17 size=1
  frame_temp 6 temp[t6]:integer/dword storage=stack_slot offset=-21 size=4
  frame_temp 7 temp[t7]:integer/dword storage=stack_slot offset=-25 size=4
  frame_temp 8 temp[t8]:integer/dword storage=stack_slot offset=-29 size=4
  frame_temp 9 temp[t9]:boolean/byte storage=stack_slot offset=-30 size=1
  frame_temp 10 temp[t10]:integer/dword storage=stack_slot offset=-34 size=4
  frame_temp 11 temp[t11]:integer/dword storage=stack_slot offset=-38 size=4
  frame_temp 12 temp[t12]:integer/dword storage=stack_slot offset=-42 size=4
  frame_temp 13 temp[t13]:boolean/byte storage=stack_slot offset=-43 size=1
  frame_temp 14 temp[t14]:integer/dword storage=stack_slot offset=-47 size=4
  frame_temp 15 temp[t15]:integer/dword storage=stack_slot offset=-51 size=4
  frame_temp 16 temp[t16]:integer/dword storage=stack_slot offset=-55 size=4
  frame_temp 17 temp[t17]:boolean/byte storage=stack_slot offset=-56 size=1
  frame_temp 18 temp[t18]:integer/dword storage=stack_slot offset=-60 size=4
  block 1 label=L1 first=1 count=5
   1 enter left=imm(60):integer/dword
   2 copy result=temp[t1]:integer/dword left=imm(0):integer/dword
   3 store result=global[done]:integer/dword left=temp[t1]:integer/dword
   4 copy result=temp[t2]:integer/dword left=imm(20):integer/dword
   5 store result=global[x]:integer/dword left=temp[t2]:integer/dword
  block 2 label=L2 first=6 count=4
   6 load result=temp[t3]:integer/dword left=global[done]:integer/dword
   7 copy result=temp[t4]:integer/dword left=imm(0):integer/dword
   8 cmp_eq result=temp[t5]:boolean/byte left=temp[t3]:integer/dword right=temp[t4]:integer/dword
   9 brfalse left=temp[t5]:boolean/byte target=label[L3]:address
  block 3 first=10 count=6
  10 copy result=temp[t6]:integer/dword left=imm(1):integer/dword
  11 store result=global[op]:integer/dword left=temp[t6]:integer/dword
  12 load result=temp[t7]:integer/dword left=global[op]:integer/dword
  13 copy result=temp[t8]:integer/dword left=imm(1):integer/dword
  14 cmp_lt result=temp[t9]:boolean/byte left=temp[t7]:integer/dword right=temp[t8]:integer/dword
  15 brfalse left=temp[t9]:boolean/byte target=label[L4]:address
  block 4 first=16 count=2
  16 copy result=temp[t10]:integer/dword left=imm(1):integer/dword
  17 store result=global[done]:integer/dword left=temp[t10]:integer/dword
  block 5 label=L4 first=18 count=4
  18 load result=temp[t11]:integer/dword left=global[op]:integer/dword
  19 copy result=temp[t12]:integer/dword left=imm(4):integer/dword
  20 cmp_gt result=temp[t13]:boolean/byte left=temp[t11]:integer/dword right=temp[t12]:integer/dword
  21 brfalse left=temp[t13]:boolean/byte target=label[L5]:address
  block 6 first=22 count=2
  22 copy result=temp[t14]:integer/dword left=imm(1):integer/dword
  23 store result=global[done]:integer/dword left=temp[t14]:integer/dword
  block 7 label=L5 first=24 count=4
  24 load result=temp[t15]:integer/dword left=global[done]:integer/dword
  25 copy result=temp[t16]:integer/dword left=imm(0):integer/dword
  26 cmp_eq result=temp[t17]:boolean/byte left=temp[t15]:integer/dword right=temp[t16]:integer/dword
  27 brfalse left=temp[t17]:boolean/byte target=label[L6]:address
  block 8 first=28 count=3
  28 copy result=temp[t18]:integer/dword left=imm(4):integer/dword
  29 store result=global[y]:integer/dword left=temp[t18]:integer/dword
  30 call target=proc[calculate]:address
  block 9 label=L6 first=31 count=1
  31 jump target=label[L2]:address
  block 10 label=L3 first=32 count=2
  32 leave
  33 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=6
  labelmap L3 block=10 first=32
  labelmap L4 block=5 first=18
  labelmap L5 block=7 first=24
  labelmap L6 block=9 first=31
endproc
proc 2 add return=none params=0 locals=0 temps=3 blocks=1 labels=1 instructions=7
  frame params=0 locals=0 temps=3 temp_policy=stack_slots param_area=0 local_area=0 temp_area=12 frame_size=12
  frame_temp 1 temp[t19]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t20]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t21]:integer/dword storage=stack_slot offset=-12 size=4
  block 1 label=L7 first=1 count=7
   1 enter left=imm(12):integer/dword
   2 load result=temp[t19]:integer/dword left=global[x]:integer/dword
   3 load result=temp[t20]:integer/dword left=global[y]:integer/dword
   4 add result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword
   5 store result=global[x]:integer/dword left=temp[t21]:integer/dword
   6 leave
   7 return
endproc
proc 3 sub return=none params=0 locals=0 temps=3 blocks=1 labels=1 instructions=7
  frame params=0 locals=0 temps=3 temp_policy=stack_slots param_area=0 local_area=0 temp_area=12 frame_size=12
  frame_temp 1 temp[t22]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t23]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t24]:integer/dword storage=stack_slot offset=-12 size=4
  block 1 label=L8 first=1 count=7
   1 enter left=imm(12):integer/dword
   2 load result=temp[t22]:integer/dword left=global[x]:integer/dword
   3 load result=temp[t23]:integer/dword left=global[y]:integer/dword
   4 sub result=temp[t24]:integer/dword left=temp[t22]:integer/dword right=temp[t23]:integer/dword
   5 store result=global[x]:integer/dword left=temp[t24]:integer/dword
   6 leave
   7 return
endproc
proc 4 mult return=none params=0 locals=1 temps=3 blocks=1 labels=1 instructions=7
  local 1 local[c]:integer/dword
  frame params=0 locals=1 temps=3 temp_policy=stack_slots param_area=0 local_area=4 temp_area=12 frame_size=16
  frame_local 1 local[c]:integer/dword offset=-4 size=4
  frame_temp 1 temp[t25]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 2 temp[t26]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 3 temp[t27]:integer/dword storage=stack_slot offset=-16 size=4
  block 1 label=L9 first=1 count=7
   1 enter left=imm(16):integer/dword
   2 load result=temp[t25]:integer/dword left=global[x]:integer/dword
   3 load result=temp[t26]:integer/dword left=global[y]:integer/dword
   4 mul result=temp[t27]:integer/dword left=temp[t25]:integer/dword right=temp[t26]:integer/dword
   5 store result=global[x]:integer/dword left=temp[t27]:integer/dword
   6 leave
   7 return
endproc
proc 5 div return=none params=0 locals=0 temps=10 blocks=5 labels=3 instructions=17
  frame params=0 locals=0 temps=10 temp_policy=stack_slots param_area=0 local_area=0 temp_area=34 frame_size=34
  frame_temp 1 temp[t28]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t29]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t30]:boolean/byte storage=stack_slot offset=-9 size=1
  frame_temp 4 temp[t31]:integer/dword storage=stack_slot offset=-13 size=4
  frame_temp 5 temp[t32]:integer/dword storage=stack_slot offset=-17 size=4
  frame_temp 6 temp[t33]:integer/dword storage=stack_slot offset=-21 size=4
  frame_temp 7 temp[t34]:integer/dword storage=stack_slot offset=-25 size=4
  frame_temp 8 temp[t35]:integer/dword storage=stack_slot offset=-29 size=4
  frame_temp 9 temp[t36]:boolean/byte storage=stack_slot offset=-30 size=1
  frame_temp 10 temp[t37]:integer/dword storage=stack_slot offset=-34 size=4
  block 1 label=L10 first=1 count=5
   1 enter left=imm(34):integer/dword
   2 load result=temp[t28]:integer/dword left=global[y]:integer/dword
   3 copy result=temp[t29]:integer/dword left=imm(0):integer/dword
   4 cmp_ne result=temp[t30]:boolean/byte left=temp[t28]:integer/dword right=temp[t29]:integer/dword
   5 brfalse left=temp[t30]:boolean/byte target=label[L11]:address
  block 2 first=6 count=4
   6 load result=temp[t31]:integer/dword left=global[x]:integer/dword
   7 load result=temp[t32]:integer/dword left=global[y]:integer/dword
   8 div result=temp[t33]:integer/dword left=temp[t31]:integer/dword right=temp[t32]:integer/dword
   9 store result=global[x]:integer/dword left=temp[t33]:integer/dword
  block 3 label=L11 first=10 count=4
  10 load result=temp[t34]:integer/dword left=global[y]:integer/dword
  11 copy result=temp[t35]:integer/dword left=imm(0):integer/dword
  12 cmp_eq result=temp[t36]:boolean/byte left=temp[t34]:integer/dword right=temp[t35]:integer/dword
  13 brfalse left=temp[t36]:boolean/byte target=label[L12]:address
  block 4 first=14 count=2
  14 copy result=temp[t37]:integer/dword left=imm(1):integer/dword
  15 store result=global[done]:integer/dword left=temp[t37]:integer/dword
  block 5 label=L12 first=16 count=2
  16 leave
  17 return
endproc
proc 6 calculate return=none params=0 locals=0 temps=12 blocks=9 labels=5 instructions=23
  frame params=0 locals=0 temps=12 temp_policy=stack_slots param_area=0 local_area=0 temp_area=36 frame_size=36
  frame_temp 1 temp[t38]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t39]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t40]:boolean/byte storage=stack_slot offset=-9 size=1
  frame_temp 4 temp[t41]:integer/dword storage=stack_slot offset=-13 size=4
  frame_temp 5 temp[t42]:integer/dword storage=stack_slot offset=-17 size=4
  frame_temp 6 temp[t43]:boolean/byte storage=stack_slot offset=-18 size=1
  frame_temp 7 temp[t44]:integer/dword storage=stack_slot offset=-22 size=4
  frame_temp 8 temp[t45]:integer/dword storage=stack_slot offset=-26 size=4
  frame_temp 9 temp[t46]:boolean/byte storage=stack_slot offset=-27 size=1
  frame_temp 10 temp[t47]:integer/dword storage=stack_slot offset=-31 size=4
  frame_temp 11 temp[t48]:integer/dword storage=stack_slot offset=-35 size=4
  frame_temp 12 temp[t49]:boolean/byte storage=stack_slot offset=-36 size=1
  block 1 label=L13 first=1 count=5
   1 enter left=imm(36):integer/dword
   2 load result=temp[t38]:integer/dword left=global[op]:integer/dword
   3 copy result=temp[t39]:integer/dword left=imm(1):integer/dword
   4 cmp_eq result=temp[t40]:boolean/byte left=temp[t38]:integer/dword right=temp[t39]:integer/dword
   5 brfalse left=temp[t40]:boolean/byte target=label[L14]:address
  block 2 first=6 count=1
   6 call target=proc[add]:address
  block 3 label=L14 first=7 count=4
   7 load result=temp[t41]:integer/dword left=global[op]:integer/dword
   8 copy result=temp[t42]:integer/dword left=imm(2):integer/dword
   9 cmp_eq result=temp[t43]:boolean/byte left=temp[t41]:integer/dword right=temp[t42]:integer/dword
  10 brfalse left=temp[t43]:boolean/byte target=label[L15]:address
  block 4 first=11 count=1
  11 call target=proc[sub]:address
  block 5 label=L15 first=12 count=4
  12 load result=temp[t44]:integer/dword left=global[op]:integer/dword
  13 copy result=temp[t45]:integer/dword left=imm(3):integer/dword
  14 cmp_eq result=temp[t46]:boolean/byte left=temp[t44]:integer/dword right=temp[t45]:integer/dword
  15 brfalse left=temp[t46]:boolean/byte target=label[L16]:address
  block 6 first=16 count=1
  16 call target=proc[mult]:address
  block 7 label=L16 first=17 count=4
  17 load result=temp[t47]:integer/dword left=global[op]:integer/dword
  18 copy result=temp[t48]:integer/dword left=imm(4):integer/dword
  19 cmp_eq result=temp[t49]:boolean/byte left=temp[t47]:integer/dword right=temp[t48]:integer/dword
  20 brfalse left=temp[t49]:boolean/byte target=label[L17]:address
  block 8 first=21 count=1
  21 call target=proc[div]:address
  block 9 label=L17 first=22 count=2
  22 leave
  23 return
endproc
