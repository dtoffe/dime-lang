tac program
procedures 3
proc 1 primes return=none params=0 locals=0 temps=0 blocks=1 labels=1 instructions=2
  frame params=0 locals=0 temps=0 param_area=0 local_area=0 temp_area=0 frame_size=0
  block 1 label=L1 first=1 count=2
   1 call target=proc[printprime]:address
   2 return
  labelmap L1 block=1 first=1
endproc
proc 2 isprime return=none params=0 locals=1 temps=17 blocks=6 labels=4 instructions=26
  local 1 local[i]:integer/dword
  frame params=0 locals=1 temps=17 param_area=0 local_area=4 temp_area=56 frame_size=60
  frame_local 1 local[i]:integer/dword offset=-4 size=4
  frame_temp 1 temp[t1]:boolean/byte offset=-5 size=1
  frame_temp 2 temp[t2]:integer/dword offset=-9 size=4
  frame_temp 3 temp[t3]:integer/dword offset=-13 size=4
  frame_temp 4 temp[t4]:integer/dword offset=-17 size=4
  frame_temp 5 temp[t5]:boolean/byte offset=-18 size=1
  frame_temp 6 temp[t6]:integer/dword offset=-22 size=4
  frame_temp 7 temp[t7]:integer/dword offset=-26 size=4
  frame_temp 8 temp[t8]:integer/dword offset=-30 size=4
  frame_temp 9 temp[t9]:integer/dword offset=-34 size=4
  frame_temp 10 temp[t10]:integer/dword offset=-38 size=4
  frame_temp 11 temp[t11]:integer/dword offset=-42 size=4
  frame_temp 12 temp[t12]:boolean/byte offset=-43 size=1
  frame_temp 13 temp[t13]:boolean/byte offset=-44 size=1
  frame_temp 14 temp[t14]:integer/dword offset=-48 size=4
  frame_temp 15 temp[t15]:integer/dword offset=-52 size=4
  frame_temp 16 temp[t16]:integer/dword offset=-56 size=4
  frame_temp 17 temp[t17]:integer/dword offset=-60 size=4
  block 1 label=L2 first=1 count=4
   1 load_const result=temp[t1]:boolean/byte left=imm(1):boolean/byte
   2 store result=global[ret]:boolean/byte left=temp[t1]:boolean/byte
   3 load_const result=temp[t2]:integer/dword left=imm(2):integer/dword
   4 store result=local[i]:integer/dword left=temp[t2]:integer/dword
  block 2 label=L3 first=5 count=4
   5 load result=temp[t3]:integer/dword left=local[i]:integer/dword
   6 load result=temp[t4]:integer/dword left=global[arg]:integer/dword
   7 binary result=temp[t5]:boolean/byte left=temp[t3]:integer/dword right=temp[t4]:integer/dword op=<
   8 goto_if_zero left=temp[t5]:boolean/byte target=label[L4]:address
  block 3 first=9 count=8
   9 load result=temp[t6]:integer/dword left=global[arg]:integer/dword
  10 load result=temp[t7]:integer/dword left=local[i]:integer/dword
  11 binary result=temp[t8]:integer/dword left=temp[t6]:integer/dword right=temp[t7]:integer/dword op=/
  12 load result=temp[t9]:integer/dword left=local[i]:integer/dword
  13 binary result=temp[t10]:integer/dword left=temp[t8]:integer/dword right=temp[t9]:integer/dword op=*
  14 load result=temp[t11]:integer/dword left=global[arg]:integer/dword
  15 binary result=temp[t12]:boolean/byte left=temp[t10]:integer/dword right=temp[t11]:integer/dword op==
  16 goto_if_zero left=temp[t12]:boolean/byte target=label[L5]:address
  block 4 first=17 count=4
  17 load_const result=temp[t13]:boolean/byte left=imm(0):boolean/byte
  18 store result=global[ret]:boolean/byte left=temp[t13]:boolean/byte
  19 load result=temp[t14]:integer/dword left=global[arg]:integer/dword
  20 store result=local[i]:integer/dword left=temp[t14]:integer/dword
  block 5 label=L5 first=21 count=5
  21 load result=temp[t15]:integer/dword left=local[i]:integer/dword
  22 load_const result=temp[t16]:integer/dword left=imm(1):integer/dword
  23 binary result=temp[t17]:integer/dword left=temp[t15]:integer/dword right=temp[t16]:integer/dword op=+
  24 store result=local[i]:integer/dword left=temp[t17]:integer/dword
  25 goto target=label[L3]:address
  block 6 label=L4 first=26 count=1
  26 return
  labelmap L2 block=1 first=1
  labelmap L3 block=2 first=5
  labelmap L4 block=6 first=26
endproc
proc 3 printprime return=none params=0 locals=0 temps=11 blocks=6 labels=5 instructions=19
  frame params=0 locals=0 temps=11 param_area=0 local_area=0 temp_area=38 frame_size=38
  frame_temp 1 temp[t18]:integer/dword offset=-4 size=4
  frame_temp 2 temp[t19]:integer/dword offset=-8 size=4
  frame_temp 3 temp[t20]:integer/dword offset=-12 size=4
  frame_temp 4 temp[t21]:integer/dword offset=-16 size=4
  frame_temp 5 temp[t22]:boolean/byte offset=-17 size=1
  frame_temp 6 temp[t23]:integer/dword offset=-21 size=4
  frame_temp 7 temp[t24]:boolean/byte offset=-22 size=1
  frame_temp 8 temp[t25]:integer/dword offset=-26 size=4
  frame_temp 9 temp[t26]:integer/dword offset=-30 size=4
  frame_temp 10 temp[t27]:integer/dword offset=-34 size=4
  frame_temp 11 temp[t28]:integer/dword offset=-38 size=4
  block 1 label=L6 first=1 count=2
   1 load_const result=temp[t18]:integer/dword left=imm(2):integer/dword
   2 store result=global[arg]:integer/dword left=temp[t18]:integer/dword
  block 2 label=L7 first=3 count=6
   3 load_const result=temp[t19]:integer/dword left=imm(100):integer/dword
   4 load_const result=temp[t20]:integer/dword left=imm(1):integer/dword
   5 binary result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword op=-
   6 load result=temp[t23]:integer/dword left=global[arg]:integer/dword
   7 binary result=temp[t22]:boolean/byte left=temp[t23]:integer/dword right=temp[t21]:integer/dword op=<=
   8 goto_if_zero left=temp[t22]:boolean/byte target=label[L9]:address
  block 3 first=9 count=3
   9 call target=proc[isprime]:address
  10 load result=temp[t24]:boolean/byte left=global[ret]:boolean/byte
  11 goto_if_zero left=temp[t24]:boolean/byte target=label[L10]:address
  block 4 first=12 count=2
  12 load result=temp[t25]:integer/dword left=global[arg]:integer/dword
  13 builtin_write left=temp[t25]:integer/dword target=intrinsic[writeln]:address
  block 5 label=L10 first=14 count=5
  14 load_const result=temp[t26]:integer/dword left=imm(1):integer/dword
  15 load result=temp[t28]:integer/dword left=global[arg]:integer/dword
  16 binary result=temp[t27]:integer/dword left=temp[t28]:integer/dword right=temp[t26]:integer/dword op=+
  17 store result=global[arg]:integer/dword left=temp[t27]:integer/dword
  18 goto target=label[L7]:address
  block 6 label=L9 first=19 count=1
  19 return
endproc
