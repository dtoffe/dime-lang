tac program
procedures 3
proc 1 primes return=none params=0 locals=0 temps=0 blocks=1 labels=1 instructions=2
  frame params=0 locals=0 temps=0
  block 1 label=L1 first=1 count=2
   1 call_proc target=proc[printprime]:address
   2 return
  labelmap L1 block=1 first=1
endproc
proc 2 isprime return=none params=0 locals=1 temps=17 blocks=6 labels=4 instructions=26
  local 1 local[i]:integer/dword
  frame params=0 locals=1 temps=17
  block 1 label=L2 first=1 count=4
   1 load_const result=temp[t1]:boolean/byte left=imm(1):boolean/byte
   2 store_var result=global[ret]:boolean/byte left=temp[t1]:boolean/byte
   3 load_const result=temp[t2]:integer/dword left=imm(2):integer/dword
   4 store_var result=local[i]:integer/dword left=temp[t2]:integer/dword
  block 2 label=L3 first=5 count=4
   5 load_var result=temp[t3]:integer/dword left=local[i]:integer/dword
   6 load_var result=temp[t4]:integer/dword left=global[arg]:integer/dword
   7 binary result=temp[t5]:boolean/byte left=temp[t3]:integer/dword right=temp[t4]:integer/dword op=<
   8 goto_if_zero left=temp[t5]:boolean/byte target=label[L4]:address
  block 3 first=9 count=8
   9 load_var result=temp[t6]:integer/dword left=global[arg]:integer/dword
  10 load_var result=temp[t7]:integer/dword left=local[i]:integer/dword
  11 binary result=temp[t8]:integer/dword left=temp[t6]:integer/dword right=temp[t7]:integer/dword op=/
  12 load_var result=temp[t9]:integer/dword left=local[i]:integer/dword
  13 binary result=temp[t10]:integer/dword left=temp[t8]:integer/dword right=temp[t9]:integer/dword op=*
  14 load_var result=temp[t11]:integer/dword left=global[arg]:integer/dword
  15 binary result=temp[t12]:boolean/byte left=temp[t10]:integer/dword right=temp[t11]:integer/dword op==
  16 goto_if_zero left=temp[t12]:boolean/byte target=label[L5]:address
  block 4 first=17 count=4
  17 load_const result=temp[t13]:boolean/byte left=imm(0):boolean/byte
  18 store_var result=global[ret]:boolean/byte left=temp[t13]:boolean/byte
  19 load_var result=temp[t14]:integer/dword left=global[arg]:integer/dword
  20 store_var result=local[i]:integer/dword left=temp[t14]:integer/dword
  block 5 label=L5 first=21 count=5
  21 load_var result=temp[t15]:integer/dword left=local[i]:integer/dword
  22 load_const result=temp[t16]:integer/dword left=imm(1):integer/dword
  23 binary result=temp[t17]:integer/dword left=temp[t15]:integer/dword right=temp[t16]:integer/dword op=+
  24 store_var result=local[i]:integer/dword left=temp[t17]:integer/dword
  25 goto target=label[L3]:address
  block 6 label=L4 first=26 count=1
  26 return
  labelmap L2 block=1 first=1
  labelmap L3 block=2 first=5
  labelmap L4 block=6 first=26
endproc
proc 3 printprime return=none params=0 locals=0 temps=11 blocks=6 labels=5 instructions=19
  frame params=0 locals=0 temps=11
  block 1 label=L6 first=1 count=2
   1 load_const result=temp[t18]:integer/dword left=imm(2):integer/dword
   2 store_var result=global[arg]:integer/dword left=temp[t18]:integer/dword
  block 2 label=L7 first=3 count=6
   3 load_const result=temp[t19]:integer/dword left=imm(100):integer/dword
   4 load_const result=temp[t20]:integer/dword left=imm(1):integer/dword
   5 binary result=temp[t21]:integer/dword left=temp[t19]:integer/dword right=temp[t20]:integer/dword op=-
   6 load_var result=temp[t23]:integer/dword left=global[arg]:integer/dword
   7 binary result=temp[t22]:boolean/byte left=temp[t23]:integer/dword right=temp[t21]:integer/dword op=<=
   8 goto_if_zero left=temp[t22]:boolean/byte target=label[L9]:address
  block 3 first=9 count=3
   9 call_proc target=proc[isprime]:address
  10 load_var result=temp[t24]:boolean/byte left=global[ret]:boolean/byte
  11 goto_if_zero left=temp[t24]:boolean/byte target=label[L10]:address
  block 4 first=12 count=2
  12 load_var result=temp[t25]:integer/dword left=global[arg]:integer/dword
  13 builtin_write left=temp[t25]:integer/dword target=intrinsic[writeln]:address
  block 5 label=L10 first=14 count=5
  14 load_const result=temp[t26]:integer/dword left=imm(1):integer/dword
  15 load_var result=temp[t28]:integer/dword left=global[arg]:integer/dword
  16 binary result=temp[t27]:integer/dword left=temp[t28]:integer/dword right=temp[t26]:integer/dword op=+
  17 store_var result=global[arg]:integer/dword left=temp[t27]:integer/dword
  18 goto target=label[L7]:address
  block 6 label=L9 first=19 count=1
  19 return
endproc
