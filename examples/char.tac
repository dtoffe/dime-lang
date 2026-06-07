tac program
procedures 1
proc 1 chardemo return=none params=0 locals=0 temps=12 blocks=1 labels=1 instructions=19
  frame params=0 locals=0 temps=12 temp_policy=stack_slots param_area=0 local_area=0 temp_area=12 frame_size=12
  frame_temp 1 temp[t1]:char/byte storage=stack_slot offset=-1 size=1
  frame_temp 2 temp[t2]:char/byte storage=stack_slot offset=-2 size=1
  frame_temp 3 temp[t3]:char/byte storage=stack_slot offset=-3 size=1
  frame_temp 4 temp[t4]:char/byte storage=stack_slot offset=-4 size=1
  frame_temp 5 temp[t5]:boolean/byte storage=stack_slot offset=-5 size=1
  frame_temp 6 temp[t6]:char/byte storage=stack_slot offset=-6 size=1
  frame_temp 7 temp[t7]:char/byte storage=stack_slot offset=-7 size=1
  frame_temp 8 temp[t8]:boolean/byte storage=stack_slot offset=-8 size=1
  frame_temp 9 temp[t9]:char/byte storage=stack_slot offset=-9 size=1
  frame_temp 10 temp[t10]:char/byte storage=stack_slot offset=-10 size=1
  frame_temp 11 temp[t11]:boolean/byte storage=stack_slot offset=-11 size=1
  frame_temp 12 temp[t12]:boolean/byte storage=stack_slot offset=-12 size=1
  block 1 label=L1 first=1 count=19
   1 enter left=imm(12):integer/dword
   2 copy result=temp[t1]:char/byte left=imm(97):char/byte
   3 store result=global[first]:char/byte left=temp[t1]:char/byte
   4 copy result=temp[t2]:char/byte left=imm(122):char/byte
   5 store result=global[last]:char/byte left=temp[t2]:char/byte
   6 load result=temp[t3]:char/byte left=global[first]:char/byte
   7 load result=temp[t4]:char/byte left=global[last]:char/byte
   8 cmp_lt result=temp[t5]:boolean/byte left=temp[t3]:char/byte right=temp[t4]:char/byte
   9 store result=global[ordered]:boolean/byte left=temp[t5]:boolean/byte
  10 load result=temp[t6]:char/byte left=global[first]:char/byte
  11 copy result=temp[t7]:char/byte left=imm(97):char/byte
  12 cmp_eq result=temp[t8]:boolean/byte left=temp[t6]:char/byte right=temp[t7]:char/byte
  13 load result=temp[t9]:char/byte left=global[last]:char/byte
  14 load result=temp[t10]:char/byte left=global[first]:char/byte
  15 cmp_gt result=temp[t11]:boolean/byte left=temp[t9]:char/byte right=temp[t10]:char/byte
  16 mul result=temp[t12]:boolean/byte left=temp[t8]:boolean/byte right=temp[t11]:boolean/byte
  17 store result=global[ordered]:boolean/byte left=temp[t12]:boolean/byte
  18 leave
  19 return
  labelmap L1 block=1 first=1
endproc
