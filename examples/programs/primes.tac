tac program
procedures 3
proc 1 primes return=none params=0 locals=0 temps=0 blocks=1 labels=1 instructions=4
  frame params=0 locals=0 temps=0 temp_policy=stack_slots param_area=0 local_area=0 temp_area=0 frame_size=0
  block 1 label=L1 first=1 count=4
   1 enter left=imm(0):integer/dword
   2 call target=proc[printprime]:address
   3 leave
   4 return
  labelmap L1 block=1 first=1
endproc
proc 2 isprime return=none params=0 locals=1 temps=17 blocks=6 labels=4 instructions=28
  local 1 local[i]:integer/dword
  frame params=0 locals=1 temps=17 temp_policy=stack_slots param_area=0 local_area=4 temp_area=56 frame_size=60
  frame_local 1 local[i]:integer/dword offset=-4 size=4
  frame_temp 1 temp[t1]:boolean/byte storage=stack_slot offset=-5 size=1
  frame_temp 2 temp[t2]:integer/dword storage=stack_slot offset=-9 size=4
  frame_temp 3 temp[t3]:integer/dword storage=stack_slot offset=-13 size=4
  frame_temp 4 temp[t4]:integer/dword storage=stack_slot offset=-17 size=4
  frame_temp 5 temp[t5]:boolean/byte storage=stack_slot offset=-18 size=1
  frame_temp 6 temp[t6]:integer/dword storage=stack_slot offset=-22 size=4
  frame_temp 7 temp[t7]:integer/dword storage=stack_slot offset=-26 size=4
  frame_temp 8 temp[t8]:integer/dword storage=stack_slot offset=-30 size=4
  frame_temp 9 temp[t9]:integer/dword storage=stack_slot offset=-34 size=4
  frame_temp 10 temp[t10]:integer/dword storage=stack_slot offset=-38 size=4
  frame_temp 11 temp[t11]:integer/dword storage=stack_slot offset=-42 size=4
  frame_temp 12 temp[t12]:boolean/byte storage=stack_slot offset=-43 size=1
  frame_temp 13 temp[t13]:boolean/byte storage=stack_slot offset=-44 size=1
  frame_temp 14 temp[t14]:integer/dword storage=stack_slot offset=-48 size=4
  frame_temp 15 temp[t15]:integer/dword storage=stack_slot offset=-52 size=4
  frame_temp 16 temp[t16]:integer/dword storage=stack_slot offset=-56 size=4
  frame_temp 17 temp[t17]:integer/dword storage=stack_slot offset=-60 size=4
  block 1 label=L2 first=1 count=5
   1 enter left=imm(60):integer/dword
   2 copy result=temp[t1]:boolean/byte left=imm(1):boolean/byte
   3 store result=global[ret]:boolean/byte left=temp[t1]:boolean/byte
   4 copy result=temp[t2]:integer/dword left=imm(2):integer/dword
   5 store result=local[i]:integer/dword left=temp[t2]:integer/dword
  block 2 label=L3 first=6 count=4
   6 load result=temp[t3]:integer/dword left=local[i]:integer/dword
   7 load result=temp[t4]:integer/dword left=global[arg]:integer/dword
   8 cmp_lt result=temp[t5]:boolean/byte left=temp[t3]:integer/dword right=temp[t4]:integer/dword
   9 brfalse left=temp[t5]:boolean/byte target=label[L4]:address
  block 3 first=10 count=8
  10 load result=temp[t6]:integer/dword left=global[arg]:integer/dword
  11 load result=temp[t7]:integer/dword left=local[i]:integer/dword
  12 div result=temp[t8]:integer/dword left=temp[t6]:integer/dword right=temp[t7]:integer/dword
  13 load result=temp[t9]:integer/dword left=local[i]:integer/dword
  14 mul result=temp[t10]:integer/dword left=temp[t8]:integer/dword right=temp[t9]:integer/dword
  15 load result=temp[t11]:integer/dword left=global[arg]:integer/dword
  16 cmp_eq result=temp[t12]:boolean/byte left=temp[t10]:integer/dword right=temp[t11]:integer/dword
  17 brfalse left=temp[t12]:boolean/byte target=label[L5]:address
  block 4 first=18 count=4
  18 copy result=temp[t13]:boolean/byte left=imm(0):boolean/byte
  19 store result=global[ret]:boolean/byte left=temp[t13]:boolean/byte
  20 load result=temp[t14]:integer/dword left=global[arg]:integer/dword
  21 store result=local[i]:integer/dword left=temp[t14]:integer/dword
  block 5 label=L5 first=22 count=5
  22 load result=temp[t15]:integer/dword left=local[i]:integer/dword
  23 copy result=temp[t16]:integer/dword left=imm(1):integer/dword
  24 add result=temp[t17]:integer/dword left=temp[t15]:integer/dword right=temp[t16]:integer/dword
  25 store result=local[i]:integer/dword left=temp[t17]:integer/dword
  26 jump target=label[L3]:address
  block 6 label=L4 first=27 count=2
  27 leave
  28 return
  labelmap L2 block=1 first=1
  labelmap L3 block=2 first=6
  labelmap L4 block=6 first=27
endproc
proc 3 printprime return=none params=0 locals=0 temps=11 blocks=6 labels=5 instructions=23
  frame params=0 locals=0 temps=11 temp_policy=stack_slots param_area=0 local_area=0 temp_area=38 frame_size=38
  frame_temp 1 temp[t18]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t19]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t20]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 4 temp[t21]:integer/dword storage=stack_slot offset=-16 size=4
  frame_temp 5 temp[t22]:boolean/byte storage=stack_slot offset=-17 size=1
  frame_temp 6 temp[t23]:integer/dword storage=stack_slot offset=-21 size=4
  frame_temp 7 temp[t24]:boolean/byte storage=stack_slot offset=-22 size=1
  frame_temp 8 temp[t25]:integer/dword storage=stack_slot offset=-26 size=4
  frame_temp 9 temp[t26]:integer/dword storage=stack_slot offset=-30 size=4
  frame_temp 10 temp[t27]:integer/dword storage=stack_slot offset=-34 size=4
  frame_temp 11 temp[t28]:integer/dword storage=stack_slot offset=-38 size=4
  block 1 label=L6 first=1 count=3
   1 enter left=imm(38):integer/dword
   2 copy result=temp[t18]:integer/dword left=imm(2):integer/dword
   3 store result=global[arg]:integer/dword left=temp[t18]:integer/dword
  block 2 label=L7 first=4 count=6
   4 copy result=temp[t19]:integer/dword left=imm(100):integer/dword
   5 copy result=temp[t20]:integer/dword left=imm(1):integer/dword
   6 sub result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword
   7 load result=temp[t23]:integer/dword left=global[arg]:integer/dword
   8 cmp_le result=temp[t22]:boolean/byte left=temp[t23]:integer/dword right=temp[t21]:integer/dword
   9 brfalse left=temp[t22]:boolean/byte target=label[L9]:address
  block 3 first=10 count=3
  10 call target=proc[isprime]:address
  11 load result=temp[t24]:boolean/byte left=global[ret]:boolean/byte
  12 brfalse left=temp[t24]:boolean/byte target=label[L10]:address
  block 4 first=13 count=4
  13 load result=temp[t25]:integer/dword left=global[arg]:integer/dword
  14 arg left=temp[t25]:integer/dword index=0
  15 intrinsic_call target=intrinsic[write_int]:address
  16 intrinsic_call target=intrinsic[writeln]:address
  block 5 label=L10 first=17 count=5
  17 copy result=temp[t26]:integer/dword left=imm(1):integer/dword
  18 load result=temp[t28]:integer/dword left=global[arg]:integer/dword
  19 add result=temp[t27]:integer/dword left=temp[t28]:integer/dword right=temp[t26]:integer/dword
  20 store result=global[arg]:integer/dword left=temp[t27]:integer/dword
  21 jump target=label[L7]:address
  block 6 label=L9 first=22 count=2
  22 leave
  23 return
endproc
