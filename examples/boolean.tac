tac program
procedures 1
proc 1 booldemo return=none params=0 locals=0 temps=20 blocks=3 labels=2 instructions=27
  frame params=0 locals=0 temps=20 temp_policy=stack_slots param_area=0 local_area=0 temp_area=32 frame_size=32
  frame_temp 1 temp[t1]:boolean/byte storage=stack_slot offset=-1 size=1
  frame_temp 2 temp[t2]:boolean/byte storage=stack_slot offset=-2 size=1
  frame_temp 3 temp[t3]:boolean/byte storage=stack_slot offset=-3 size=1
  frame_temp 4 temp[t4]:boolean/byte storage=stack_slot offset=-4 size=1
  frame_temp 5 temp[t5]:boolean/byte storage=stack_slot offset=-5 size=1
  frame_temp 6 temp[t6]:boolean/byte storage=stack_slot offset=-6 size=1
  frame_temp 7 temp[t7]:boolean/byte storage=stack_slot offset=-7 size=1
  frame_temp 8 temp[t8]:integer/dword storage=stack_slot offset=-11 size=4
  frame_temp 9 temp[t9]:boolean/byte storage=stack_slot offset=-12 size=1
  frame_temp 10 temp[t10]:boolean/byte storage=stack_slot offset=-13 size=1
  frame_temp 11 temp[t11]:integer/dword storage=stack_slot offset=-17 size=4
  frame_temp 12 temp[t12]:boolean/byte storage=stack_slot offset=-18 size=1
  frame_temp 13 temp[t13]:integer/dword storage=stack_slot offset=-22 size=4
  frame_temp 14 temp[t14]:integer/dword storage=stack_slot offset=-26 size=4
  frame_temp 15 temp[t15]:boolean/byte storage=stack_slot offset=-27 size=1
  frame_temp 16 temp[t16]:boolean/byte storage=stack_slot offset=-28 size=1
  frame_temp 17 temp[t17]:boolean/byte storage=stack_slot offset=-29 size=1
  frame_temp 18 temp[t18]:boolean/byte storage=stack_slot offset=-30 size=1
  frame_temp 19 temp[t19]:boolean/byte storage=stack_slot offset=-31 size=1
  frame_temp 20 temp[t20]:boolean/byte storage=stack_slot offset=-32 size=1
  block 1 label=L1 first=1 count=16
   1 enter left=imm(32):integer/dword
   2 copy result=temp[t1]:boolean/byte left=imm(1):boolean/byte
   3 copy result=temp[t2]:boolean/byte left=imm(0):boolean/byte
   4 cmp_eq result=temp[t3]:boolean/byte left=temp[t2]:boolean/byte right=imm(0):boolean/byte
   5 mul result=temp[t4]:boolean/byte left=temp[t1]:boolean/byte right=temp[t3]:boolean/byte
   6 store result=global[flag]:boolean/byte left=temp[t4]:boolean/byte
   7 load result=temp[t5]:boolean/byte left=global[flag]:boolean/byte
   8 copy result=temp[t6]:boolean/byte left=imm(0):boolean/byte
   9 add result=temp[t8]:integer/dword left=temp[t5]:boolean/byte right=temp[t6]:boolean/byte
  10 cmp_eq result=temp[t7]:boolean/byte left=temp[t8]:integer/dword right=imm(1):integer/dword
  11 copy result=temp[t9]:boolean/byte left=imm(0):boolean/byte
  12 add result=temp[t11]:integer/dword left=temp[t7]:boolean/byte right=temp[t9]:boolean/byte
  13 cmp_ne result=temp[t10]:boolean/byte left=temp[t11]:integer/dword right=imm(0):integer/dword
  14 store result=global[flag]:boolean/byte left=temp[t10]:boolean/byte
  15 load result=temp[t12]:boolean/byte left=global[flag]:boolean/byte
  16 brfalse left=temp[t12]:boolean/byte target=label[L2]:address
  block 2 first=17 count=9
  17 copy result=temp[t13]:integer/dword left=imm(1):integer/dword
  18 copy result=temp[t14]:integer/dword left=imm(2):integer/dword
  19 cmp_lt result=temp[t15]:boolean/byte left=temp[t13]:integer/dword right=temp[t14]:integer/dword
  20 copy result=temp[t16]:boolean/byte left=imm(1):boolean/byte
  21 copy result=temp[t17]:boolean/byte left=imm(0):boolean/byte
  22 cmp_eq result=temp[t18]:boolean/byte left=temp[t16]:boolean/byte right=temp[t17]:boolean/byte
  23 cmp_eq result=temp[t19]:boolean/byte left=temp[t18]:boolean/byte right=imm(0):boolean/byte
  24 mul result=temp[t20]:boolean/byte left=temp[t15]:boolean/byte right=temp[t19]:boolean/byte
  25 store result=global[flag]:boolean/byte left=temp[t20]:boolean/byte
  block 3 label=L2 first=26 count=2
  26 leave
  27 return
  labelmap L1 block=1 first=1
  labelmap L2 block=3 first=26
endproc
