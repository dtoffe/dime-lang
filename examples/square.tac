tac program
procedures 2
proc 1 square return=none params=0 locals=2 temps=7 blocks=4 labels=3 instructions=15
  local 1 global[x]:integer/dword
  local 2 global[squ]:integer/dword
  frame params=0 locals=2 temps=7 temp_policy=stack_slots param_area=0 local_area=8 temp_area=25 frame_size=33
  frame_local 1 global[x]:integer/dword offset=-4 size=4
  frame_local 2 global[squ]:integer/dword offset=-8 size=4
  frame_temp 1 temp[t1]:integer/dword storage=stack_slot offset=-12 size=4
  frame_temp 2 temp[t2]:integer/dword storage=stack_slot offset=-16 size=4
  frame_temp 3 temp[t3]:integer/dword storage=stack_slot offset=-20 size=4
  frame_temp 4 temp[t4]:boolean/byte storage=stack_slot offset=-21 size=1
  frame_temp 5 temp[t5]:integer/dword storage=stack_slot offset=-25 size=4
  frame_temp 6 temp[t6]:integer/dword storage=stack_slot offset=-29 size=4
  frame_temp 7 temp[t7]:integer/dword storage=stack_slot offset=-33 size=4
  block 1 label=L1 first=1 count=3
   1 enter left=imm(33):integer/dword
   2 copy result=temp[t1]:integer/dword left=imm(1):integer/dword
   3 store result=global[x]:integer/dword left=temp[t1]:integer/dword
  block 2 label=L2 first=4 count=4
   4 load result=temp[t2]:integer/dword left=global[x]:integer/dword
   5 copy result=temp[t3]:integer/dword left=imm(10):integer/dword
   6 cmp_le result=temp[t4]:boolean/byte left=temp[t2]:integer/dword right=temp[t3]:integer/dword
   7 brfalse left=temp[t4]:boolean/byte target=label[L3]:address
  block 3 first=8 count=6
   8 call target=proc[square]:address
   9 load result=temp[t5]:integer/dword left=global[x]:integer/dword
  10 copy result=temp[t6]:integer/dword left=imm(1):integer/dword
  11 add result=temp[t7]:integer/dword left=temp[t5]:integer/dword right=temp[t6]:integer/dword
  12 store result=global[x]:integer/dword left=temp[t7]:integer/dword
  13 jump target=label[L2]:address
  block 4 label=L3 first=14 count=2
  14 leave
  15 return
  labelmap L1 block=1 first=1
  labelmap L2 block=2 first=4
  labelmap L3 block=4 first=14
endproc
proc 2 square return=none params=0 locals=0 temps=3 blocks=1 labels=1 instructions=7
  frame params=0 locals=0 temps=3 temp_policy=stack_slots param_area=0 local_area=0 temp_area=12 frame_size=12
  frame_temp 1 temp[t8]:integer/dword storage=stack_slot offset=-4 size=4
  frame_temp 2 temp[t9]:integer/dword storage=stack_slot offset=-8 size=4
  frame_temp 3 temp[t10]:integer/dword storage=stack_slot offset=-12 size=4
  block 1 label=L4 first=1 count=7
   1 enter left=imm(12):integer/dword
   2 load result=temp[t8]:integer/dword left=global[x]:integer/dword
   3 load result=temp[t9]:integer/dword left=global[x]:integer/dword
   4 mul result=temp[t10]:integer/dword left=temp[t8]:integer/dword right=temp[t9]:integer/dword
   5 store result=global[squ]:integer/dword left=temp[t10]:integer/dword
   6 leave
   7 return
endproc
