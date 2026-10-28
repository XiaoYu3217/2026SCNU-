; 8086 + MASM/TASM + DOS reference for the user's C simulator
; UTF-8 comments. All executable identifiers and string literals are ASCII.
;
; 阅读顺序：initialize -> push_car/pop_car/peek -> run -> inputNum -> readN。
; 所有普通变量都在数据段；寄存器只是临时工作空间。
; 自定调用约定：AX 传入一个参数/返回结果；其余用到的寄存器由过程保存。
; 返回状态：AX=0 成功，AX=1 失败；peek 的 AX 则是栈顶值或 -1。
; DS 在 main 中初始化，此后各过程不改变 DS。
;
; 与 C 的对应：
;   int -> dw（本例用 16 位整数，合法车厢只有 1..30）
;   target/vis 从下标 0 开始；car_stack/opt 保留 C 的下标 1 开始习惯。
;   stack -> car_stack：STACK 是 MASM 的保留字，不适合作为变量名。
;   st -> stack_top：ST 在 MASM 中也是浮点寄存器保留名。
;   push/pop -> push_car/pop_car：避免与 CPU 的 PUSH/POP 指令重名。
;   DOS 0Ah 代替 fgets；DOS 09h 代替 printf，不调用 C 运行库。
;   输出沿用 C：小写 p/o、无 Case 编号；这是对照学习版。

.8086
.model small
.stack 200h                     ; 机器调用栈，只用于 CALL/RET/保存寄存器

MAXN    EQU 30
CAP     EQU 32
MAXOPS  EQU 2*MAXN

.data
    ; DOS 0Ah 的缓冲区必须连续排列：容量、实际长度、字符区域。
    ; 容量包含末尾回车。这里保守拒绝长度达到 127 的行，避免截断误判。
    line_buf   db 128
    line_len   db 0
    line       db 128 dup(0)

    target     dw CAP dup(0)
    tar        dw 0             ; 输入时：已读数字个数；模拟时：目标下标
    car_stack  dw CAP dup(0)    ; 业务栈，不是上面 .stack 的机器调用栈
    stack_top  dw 0             ; C 的 st；非空时栈顶在 car_stack[stack_top]
    n          dw 0
    opt        db 128 dup(0)
    opn        dw 0
    vis        dw CAP dup(0)
    flag       dw 0
    tmp        dw 0
    id         dw 0
    has_digit  dw 0             ; 新增：区分连续空格和一个真正的数字

    msg_large  db 'n > 30 !',13,10,'$'
    msg_small  db 'n < 1 !',13,10,'$'
    msg_badn   db 'Error: invalid n',13,10,'$'
    msg_long   db 'Error: input line too long',13,10,'$'
    msg_range  db 'Error: value out of range',13,10,'$'
    msg_dup    db 'Error: duplicate car $'
    msg_illegal db 'Error: illegal character',13,10,'$'
    msg_empty  db 'Error: empty sequence',13,10,'$'
    msg_less   db 'Error: incomplete sequence',13,10,'$'
    msg_more   db 'Error: too many numbers',13,10,'$'
    msg_full   db 'Error: stack full',13,10,'$'
    msg_under  db 'Error: stack empty',13,10,'$'
    msg_ops    db 'Error: operation buffer full',13,10,'$'
    msg_yes    db 'POSSIBLE $'
    msg_no     db 'IMPOSSIBLE',13,10,'$'
    newline    db 13,10,'$'
    num_buf    db 6 dup(0)      ; 最多 5 个十进制数字，加 '$'

.code

; ======================================================================
; 输出工具：DX=以 '$' 结束的字符串地址；保留 AX 和 DX。
; 使用示例：mov dx,OFFSET msg_yes / call printStr
; ======================================================================
printStr PROC NEAR
    push ax
    push dx
    mov ah,09h
    int 21h
    pop dx
    pop ax
    ret
printStr ENDP

; AX=无符号整数，输出十进制数字；保留所有用到的通用寄存器。
; printf("%d", tmp) 并不是一条机器指令，需要自己把数字转成字符。
printUnsigned PROC NEAR
    push ax
    push bx
    push dx
    push si
    mov bx,10
    mov si,OFFSET num_buf+5
    mov byte ptr [si],'$'
pu_digit:
    xor dx,dx
    div bx                      ; DX:AX / 10，商在 AX，余数在 DX
    add dl,'0'
    dec si
    mov [si],dl
    cmp ax,0
    jne pu_digit
    mov dx,si
    call printStr
    pop si
    pop dx
    pop bx
    pop ax
    ret
printUnsigned ENDP

; ======================================================================
; initialize()：对应 memset(target/vis,0,...) 和几个状态变量归零。
; 不清 n，因为 n 是这一组刚读到的车厢数量。
; ======================================================================
initialize PROC NEAR
    push ax
    push bx
    push cx
    xor ax,ax
    xor bx,bx
    mov cx,CAP
init_clear:
    mov target[bx],ax
    mov vis[bx],ax
    add bx,2                    ; dw 元素每项占 2 字节
    loop init_clear
    mov tar,ax
    mov stack_top,ax
    mov opn,ax
    mov flag,ax
    pop cx
    pop bx
    pop ax
    ret
initialize ENDP

; ======================================================================
; checkN(int n)：AX 输入 n；AX 返回 0 或 1。
; 输出之后再设置返回值；不要把保存的旧 AX 弹回来覆盖返回值。
; ======================================================================
checkN PROC NEAR
    push dx
    cmp ax,MAXN
    jg cn_large
    cmp ax,1
    jl cn_small
    xor ax,ax                   ; return 0
    jmp cn_done
cn_large:
    mov dx,OFFSET msg_large
    call printStr
    mov ax,1                    ; return 1
    jmp cn_done
cn_small:
    mov dx,OFFSET msg_small
    call printStr
    mov ax,1
cn_done:
    pop dx
    ret
checkN ENDP

; ======================================================================
; readLine：用 DOS 0Ah 读一行；line_len 不包括回车。
; 将 DOS 放在末尾的 0Dh 改成 0，后面按 C 字符串方式解析。
; 这是 DOS 控制台行输入，不是 Windows 原生控制台/重定向 EOF 接口。
; ======================================================================
readLine PROC NEAR
    push bx
    push dx
    mov line_len,0              ; 不沿用上一行的编辑长度
    mov dx,OFFSET line_buf
    mov ah,0Ah
    int 21h
    mov dx,OFFSET newline
    call printStr
    xor bx,bx
    mov bl,line_len
    mov byte ptr line[bx],0
    cmp bx,127
    jb rl_ok
    mov dx,OFFSET msg_long
    call printStr
    mov ax,1
    jmp rl_done
rl_ok:
    xor ax,ax
rl_done:
    pop dx
    pop bx
    ret
readLine ENDP

; ======================================================================
; readN：代替 scanf("%d",&n) + 清理行尾。
; 先读完整一行，再解析一个有符号 16 位整数；允许首尾空格/Tab。
; AX 返回状态，真正的数量写入内存变量 n；n=0 的退出由 main 决定。
; ======================================================================
readN PROC NEAR
    push bx
    push cx
    push dx
    push si
    push di
    call readLine
    cmp ax,0
    je rn_begin
    jmp rn_done
rn_begin:
    xor si,si
    xor di,di                   ; DI=1 表示负号，否则为 0
    mov tmp,0
rn_skip:
    mov al,line[si]
    cmp al,' '
    je rn_skip_one
    cmp al,9                    ; Tab
    jne rn_sign
rn_skip_one:
    inc si
    jmp rn_skip
rn_sign:
    cmp al,'-'
    jne rn_plus
    mov di,1
    inc si
    jmp rn_first
rn_plus:
    cmp al,'+'
    jne rn_first
    inc si
rn_first:
    ; 正负号后至少要有一个数字。
    mov al,line[si]
    cmp al,'0'
    jae rn_first_upper
    jmp rn_bad
rn_first_upper:
    cmp al,'9'
    jbe rn_digit
    jmp rn_bad
rn_digit:
    xor bx,bx
    mov bl,line[si]
    sub bl,'0'                  ; BX=当前数字，0..9
    mov ax,tmp
    ; 在乘十之前检查范围，避免 16 位溢出。
    cmp ax,3276
    jb rn_calculate
    je rn_last_digit
    jmp rn_bad
rn_last_digit:
    mov cx,7                    ; 正数最多 32767
    cmp di,0
    je rn_limit_ready
    mov cx,8                    ; 负数绝对值最多 32768
rn_limit_ready:
    cmp bx,cx
    jbe rn_calculate
    jmp rn_bad
rn_calculate:
    mov cx,10
    mul cx                      ; DX:AX = tmp * 10
    add ax,bx
    mov tmp,ax
    inc si
    mov al,line[si]
    cmp al,'0'
    jb rn_tail
    cmp al,'9'
    jbe rn_digit
rn_tail:
    mov al,line[si]
    cmp al,0
    je rn_store
    cmp al,' '
    je rn_tail_one
    cmp al,9
    je rn_tail_one
    jmp rn_bad
rn_tail_one:
    inc si
    jmp rn_tail
rn_store:
    mov ax,tmp
    cmp di,0
    je rn_positive
    neg ax
rn_positive:
    mov n,ax
    xor ax,ax
    jmp rn_done
rn_bad:
    mov dx,OFFSET msg_badn
    call printStr
    mov ax,1
rn_done:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
readN ENDP

; ======================================================================
; storeNumber：抽出 C 中“遇到空格/行尾时保存 tmp”的重复代码。
; has_digit=0 时忽略分隔符，所以连续空格/行尾空格不会产生假数字 0。
; AX=0 成功，AX=1 出错。先检查范围和个数，再访问数组。
; ======================================================================
storeNumber PROC NEAR
    push bx
    push dx
    cmp has_digit,0
    je sn_ok
    mov ax,tmp
    cmp ax,1
    jl sn_range
    cmp ax,n
    jg sn_range
    mov bx,tar
    cmp bx,n
    jae sn_more
    mov bx,tmp
    shl bx,1                    ; BX = tmp * 2，8086 没有 [tmp*2] 寻址
    cmp word ptr vis[bx],0
    jne sn_duplicate
    mov word ptr vis[bx],1
    mov bx,tar
    shl bx,1
    mov target[bx],ax            ; target[tar] = tmp
    inc tar
    mov tmp,0
    mov has_digit,0
sn_ok:
    xor ax,ax
    jmp sn_done
sn_range:
    mov dx,OFFSET msg_range
    jmp sn_message
sn_more:
    mov dx,OFFSET msg_more
    jmp sn_message
sn_duplicate:
    mov dx,OFFSET msg_dup
    call printStr
    mov ax,tmp
    call printUnsigned
    mov dx,OFFSET newline
sn_message:
    call printStr
    mov ax,1
sn_done:
    pop dx
    pop bx
    ret
storeNumber ENDP

; ======================================================================
; inputNum(int n)：n 从全局变量读，AX 返回 0/1。
; DOS 行输入没有 fgets 保存的 '\n'，这里以 readLine 补的 0 为结束标记。
; 每个数字读完立即检查 tmp<=n，所以很长的数字不会累加到整数溢出。
; ======================================================================
inputNum PROC NEAR
    push bx
    push cx
    push dx
    push si
    call readLine
    cmp ax,0
    je in_begin
    jmp in_done
in_begin:
    mov id,0
    mov tmp,0
    mov has_digit,0
in_loop:
    mov si,id
    mov al,line[si]
    cmp al,0
    jne in_not_end
    jmp in_end_line
in_not_end:
    cmp al,' '
    je in_separator
    cmp al,9
    je in_separator
    cmp al,'0'
    jb in_illegal
    cmp al,'9'
    ja in_illegal
    xor bx,bx
    mov bl,al
    sub bl,'0'
    mov ax,tmp
    mov cx,10
    mul cx
    add ax,bx                   ; AX = tmp*10 + 当前数字
    cmp ax,n
    jbe in_digit_ok
    mov dx,OFFSET msg_range
    jmp in_error
in_digit_ok:
    mov tmp,ax
    mov has_digit,1
    jmp in_next
in_separator:
    call storeNumber
    cmp ax,0
    jne in_done
in_next:
    inc id
    jmp in_loop
in_illegal:
    mov dx,OFFSET msg_illegal
    jmp in_error
in_end_line:
    call storeNumber            ; 行尾也必须保存最后一个数
    cmp ax,0
    jne in_done
    cmp tar,0
    je in_empty
    mov ax,tar
    cmp ax,n
    jb in_less
    xor ax,ax
    jmp in_done
in_empty:
    mov dx,OFFSET msg_empty
    jmp in_error
in_less:
    mov dx,OFFSET msg_less
in_error:
    call printStr
    mov ax,1
in_done:
    pop si
    pop dx
    pop cx
    pop bx
    ret
inputNum ENDP

; ======================================================================
; push(int num) -> push_car：AX 输入 num；AX 返回状态。
; 对应 C：st++; stack[st]=num; opn++; opt[opn]='p';
; st/opn 保留 C 的一基下标，操作前新增边界检查。
; ======================================================================
push_car PROC NEAR
    push bx
    push dx
    cmp stack_top,MAXN
    jae pc_full
    cmp opn,MAXOPS
    jae pc_ops_full
    inc stack_top
    mov bx,stack_top
    shl bx,1                    ; dw 数组：元素下标乘 2 才是字节偏移
    mov car_stack[bx],ax
    inc opn
    mov bx,opn
    mov byte ptr opt[bx],'p'     ; db 数组：直接用下标作为字节偏移
    xor ax,ax
    jmp pc_done
pc_full:
    mov dx,OFFSET msg_full
    jmp pc_error
pc_ops_full:
    mov dx,OFFSET msg_ops
pc_error:
    call printStr
    mov ax,1
pc_done:
    pop dx
    pop bx
    ret
push_car ENDP

; pop() -> pop_car：和 C 一样不返回车厢值；AX 只返回成功/失败状态。
pop_car PROC NEAR
    push bx
    push dx
    cmp stack_top,0
    je po_empty
    cmp opn,MAXOPS
    jae po_ops_full
    dec stack_top
    inc opn
    mov bx,opn
    mov byte ptr opt[bx],'o'
    xor ax,ax
    jmp po_done
po_empty:
    mov dx,OFFSET msg_under
    jmp po_error
po_ops_full:
    mov dx,OFFSET msg_ops
po_error:
    call printStr
    mov ax,1
po_done:
    pop dx
    pop bx
    ret
pop_car ENDP

; peek()：不改变 st，只通过 AX 返回栈顶车厢号。
peek PROC NEAR
    push bx
    cmp stack_top,0
    je peek_empty
    mov bx,stack_top
    shl bx,1
    mov ax,car_stack[bx]
    jmp peek_done
peek_empty:
    mov ax,-1
peek_done:
    pop bx
    ret
peek ENDP

; ======================================================================
; run()：基本逐段对应用户的 C。不是另换一种调度算法。
; 外层每次压入 tmp，内层尽量弹出匹配的目标；最后判断 tar==n。
; ======================================================================
run PROC NEAR
    push bx
    push dx
    mov tmp,1
    mov tar,0
run_outer:
    mov ax,tmp
    cmp ax,n
    jg run_check
    call push_car               ; AX 已经是参数 tmp
    cmp ax,0
    jne run_done
run_inner:
    mov ax,tar
    cmp ax,n
    jae run_next                ; 先检查 tar<n，再读取 target[tar]
    call peek                   ; AX = 栈顶，空栈时为 -1
    mov bx,tar
    shl bx,1
    cmp ax,target[bx]
    jne run_next
    call pop_car
    cmp ax,0
    jne run_done
    inc tar
    jmp run_inner
run_next:
    inc tmp
    jmp run_outer
run_check:
    mov ax,tar
    cmp ax,n
    jb run_impossible
    mov dx,OFFSET msg_yes
    call printStr
    ; opt[1..opn] 是操作串。给末尾补 '$'，一次输出，代替逐字符 printf。
    mov bx,opn
    inc bx
    mov byte ptr opt[bx],'$'
    mov dx,OFFSET opt+1
    call printStr
    mov dx,OFFSET newline
    call printStr
    xor ax,ax
    jmp run_done
run_impossible:
    mov dx,OFFSET msg_no
    call printStr
    mov ax,1
run_done:
    pop dx
    pop bx
    ret
run ENDP

; ======================================================================
; main：统一回到 main_read 读取下一组，不再重复两份 scanf/getchar。
; AX 返回值写入 flag，便于与 C 的 flag=函数调用 对照。
; ======================================================================
main PROC NEAR
    mov ax,@data
    mov ds,ax
main_read:
    call readN
    cmp ax,0
    jne main_read
    cmp n,0
    je main_exit

    call initialize
    mov ax,n
    call checkN
    mov flag,ax
    cmp ax,0
    jne main_read

    call inputNum
    mov flag,ax
    cmp ax,0
    jne main_read

    call run
    mov flag,ax
    jmp main_read
main_exit:
    mov ax,4C00h
    int 21h
main ENDP

END main
