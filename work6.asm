.model small
MAXN    equ 60    ; equ是equate，定义符号常量，此句相当于#define MAXN 60的意思
STK_CAP equ MAXN+2  ;留哨兵余量 #define STK_CAP MAXN+2

.stack 200h   ;机器调用栈

.data   ;相当于data segment
    ;前面的单词相当于数组的名字，例如下面一行char cars_in[128] = {0}
    line    db 128  ;字符区容量，包含最后的回车
            db 0    ;实际输入长度，由dos填写，不包含回车
            db 128 dup(0)   ;原始输入行缓冲
    target  dw STK_CAP dup(0)  ;目标出栈序列t[0..n-1]
    tar dw 0
    car_stack dw STK_CAP dup(0)
    sta  dw 0
    n   dw 0
    opt db 128 dup(0)
    opn dw 0
    vis dw STK_CAP dup(0)
    flag dw 0
    tmp dw 0
    id dw 0
    result dw 0
    c db 0

    ;checkN data
    checkN_nlong db "n > 30 !",13,10,'$'
    checkN_nsmall db "n < 1 !",13,10,'$'
    val_out_str db "Error: value out of range",13,10,'$'
    duplicate_str1 db "Error: duplicate car $"
    duplicate_str2 db 13,10,'$'
    illegal_str1 db "illegal character $"
    illegal_str2 db 13,10,'$'
    inputout_str1 db "you've input out of $"
    inputout_str2 db " ",13,10,'$'
    inputless_str db "you've input less than 1 number",13,10,'$'
    impossible_str db "IMPOSSIBLE",13,10,'$'
    possible_str db "POSSIBLE $"
    newline_str db 13,10,'$'
    input_n_error_str db "illegal input n",13,10,'$'
    

    ;AH = 0Ah 选择“键盘缓冲输入”功能 int 21h 请求DOS读取一整行键盘输入
    ;介绍：dos会把输入放到地址ds:dx中 
    ;mov dx,offset cars_in
    ;int 21h
    ;注意cars_in[0]是最大容量128，cars_in[1]是字符串总长度，cars_in[2]才是字符串开头字符位置
    ;AH = 08h 读入一个字符，不回显 AH = 09h 输出以$结尾的字符串

.code

; 输入：AX = 无符号整数，范围 0～65535
; 保持：AX、BX、CX、DX
print_uint:
        push ax
        push bx
        push cx
        push dx

        mov bx, 10
        xor cx, cx

    print_uint_convert:
        xor dx, dx
        div bx                  ; DX:AX / 10，AX = 商，DX = 余数
        push dx
        inc cx

        cmp ax, 0
        jne print_uint_convert

    print_uint_output:
        pop dx
        add dl, '0'             ; 数字 0～9 转成字符 '0'～'9'
        mov ah, 02h
        int 21h
        loop print_uint_output

        pop dx
        pop cx
        pop bx
        pop ax
        ret

initialize:
        push ax
        push cx
        push bx

        mov cx,STK_CAP
        mov ax,0
        mov bx,0
    inis1:
        mov target[bx],ax
        mov vis[bx],ax
        add bx,2
        loop inis1
        mov tar,ax
        mov sta,ax
        mov opn,ax
        mov flag,ax
        mov result,0
        mov tmp,0
        mov id,0

        pop bx
        pop cx
        pop ax
        ret
    

checkN:
        push si
        push cx
        push dx

        mov ax,n
        cmp ax,30
        jg checkN_1

        cmp ax,1
        jl checkN_2

        jmp checkN_3

    checkN_1:   ;n>30
        mov dx,offset checkN_nlong
        jmp print_error
        
    checkN_2:   ;n<1
        mov dx,offset checkN_nsmall
        jmp print_error

    checkN_3:   ;else
        mov ax,0
        jmp checkN_ok

    print_error:
        mov ah,09h
        int 21h
        mov ax,1

    checkN_ok:  
        pop dx
        pop cx
        pop si
        ret     ;返回ax的值


val_out:
    push dx
    push ax

    mov dx,offset val_out_str
    mov ah,09h
    int 21h
    mov result,1

    pop ax
    pop dx
    ret

duplicate:
    push dx
    push ax

    mov dx,offset duplicate_str1
    mov ah,09h
    int 21h
    
    mov ax,tmp
    call print_uint

    mov dx,offset duplicate_str2
    mov ah,09h
    int 21h

    mov result,1

    pop ax
    pop dx
    ret

illegal:
    push dx
    push ax

    mov dx,offset illegal_str1
    mov ah,09h
    int 21h
    mov dl,c
    mov ah,02h
    int 21h
    mov dx,offset illegal_str2
    mov ah,09h
    int 21h

    mov result,1

    pop ax
    pop dx
    ret

checktmp:
        push ax
        push bx

        mov ax,tmp
        cmp ax,n
        jg checktmp_1
        cmp ax,1
        jl checktmp_1
        mov bx,ax
        shl bx,1
        mov ax,vis[bx]
        cmp ax,1
        je checktmp_2
        jmp checktmp_ok

    checktmp_1:
        call val_out
        jmp checktmp_ok

    checktmp_2:
        call duplicate
        

    checktmp_ok:
        pop bx
        pop ax
        ret


inputout:
    push dx
    push ax

    mov dx,offset inputout_str1
    mov ah,09h
    int 21h

    mov ax,n
    call print_uint

    mov dx,offset inputout_str2
    mov ah,09h
    int 21h

    mov result,1

    pop ax
    pop dx
    ret

inputless:
    push dx
    push ax

    mov dx,offset inputless_str
    mov ah,09h
    int 21h

    mov result,1

    pop ax
    pop dx
    ret


checktar:
    push ax
    mov ax,tar
    cmp ax,n
    jg checktar_1
    jl checktar_2
    jmp checktar_ok

    checktar_1:
        call inputout
        jmp checktar_ok

    checktar_2:
        call inputless
        jmp checktar_ok

    checktar_ok:
    pop ax
    ret

Impossible:
    push ax
    push dx

    mov dx,offset impossible_str
    mov ah,09h
    int 21h

    mov result,1

    pop dx
    pop ax
    ret

fgets:  ;读取一整行信息
    push dx
    push ax

    mov byte ptr line[1],0
    mov dx,offset line
    mov ah,0ah
    int 21h

    pop ax
    pop dx
    ret


dealChar:
    push bx

    ;al存储了c字符 c专门存储
    cmp c,'0'
    jb not_digit
    cmp c,'9'
    ja not_digit
    
    push ax
    push bx
    push cx
    push dx

    sub al,'0';
    mov ah,0
    mov bx,ax
    mov ax,tmp
    mov cx,10
    mul cx
    add ax,bx
    mov tmp,ax

    pop dx
    pop cx
    pop bx
    pop ax

    mov ax,0

    jmp dealChar_ok

    not_digit:
        cmp al,' '
        je dealChar_space
        
        mov c,al
        call illegal
        mov ax,1
        jmp dealChar_ok

    dealChar_space:
        call checktmp
        cmp result,1
        je dealChar_space_1
        mov bx,tar
        shl bx,1
        mov ax,tmp
        mov target[bx],ax
        mov ax,1
        mov bx,tmp
        shl bx,1
        mov vis[bx],ax
        mov tmp,0
        mov ax,tar
        inc ax
        mov tar,ax
        mov ax,0
        jmp dealChar_ok

        dealChar_space_1:
            mov ax,1
            jmp dealChar_ok


    dealChar_ok:
        pop bx
        ret
    

inputNum:
    push bx
    push cx
    push dx

    call fgets
    mov id,0
    scan_loop:
        mov bx,id
        mov al,line[bx+2]
        mov c,al
        cmp c,0dh
        je scan_done
        call dealChar
        mov flag,ax
        cmp flag,1
        je inputNum_1
        inc id
        jmp scan_loop

    scan_done:
        call checktmp
        cmp result,1
        je inputNum_1
        mov bx,tar
        shl bx,1
        mov ax,tmp
        mov target[bx],ax
        mov tmp,0
        inc tar
        call checktar
        cmp result,1
        je inputNum_1
        mov ax,0
        jmp inputNum_ok


    inputNum_1:
        mov ax,1

    inputNum_ok:
        pop dx
        pop cx
        pop bx
        ret

push_num:
    push ax
    push bx

    inc sta
    mov bx,sta
    shl bx,1
    mov ax,tmp
    mov car_stack[bx],ax
    inc opn
    mov bx,opn
    mov al,'p'
    mov opt[bx],al

    pop bx
    pop ax
    ret


pop_num:
    push ax
    push bx

    dec sta
    inc opn
    mov bx,opn
    mov al,'o'
    mov opt[bx],al

    pop bx
    pop ax
    ret


peek_num:
    cmp sta,0
    je peek_num_no
    jmp peek_num_ok

    peek_num_no:
        mov ax,-1
        ret

    peek_num_ok:
        push bx
        
        mov bx,sta
        shl bx,1
        mov ax,car_stack[bx]
    
        pop bx
        ret


Possible:
    push dx
    push ax

    mov dx,offset possible_str
    mov ah,09h
    int 21h

    pop ax
    pop dx
    ret



run:
    mov tmp,1
    mov tar,0
    run_loop1:  
        mov ax,tmp
        cmp ax,n
        jg run_loop1_done   ;如果tmp>n就退出loop1循环
        call push_num

        run_loop1_tarpeek:
        mov ax,tar
        cmp ax,n
        jl run_loop1_cmp2   ;如果tar<n就看第二个cmp结果
        jmp run_loop1_cmp1_done ;否则结束loop1中的while循环

        run_loop1_cmp2:
            call peek_num   ;ax = peek()
            call run_loop1_cmp_check    ;检查ax是否等于target[tar]
            cmp ax,1
            je run_loop1_equal ;如果相等执行while内指令 ;否则

        run_loop1_cmp1_done:
            inc tmp
            jmp run_loop1
        
    run_loop1_done:
        mov ax,tar
        cmp ax,n
        jl run_loop_tar
        jmp run_loop_tar_next

        run_loop_tar:
            call Impossible
            mov ax,1
            ret
        
    run_loop_tar_next:
        call Possible
        mov tmp,1
        run_loop2:
        mov ax,tmp
        cmp ax,opn
        jle run_loop2_print

        run_loop2_print_done:
        push dx
        push ax

        mov dx,offset newline_str
        mov ah,09h
        int 21h

        pop ax
        pop dx

        mov ax,0
        ret

    run_loop1_equal:
        call pop_num
        inc tar
        jmp run_loop1_tarpeek
        
    run_loop2_print:
        push dx
        push ax
        push bx

        mov bx,tmp
        mov dl,opt[bx]
        mov ah,02h
        int 21h
        inc tmp

        pop bx
        pop ax
        pop dx
        jmp run_loop2

    run_loop1_cmp_check:
        push bx
        push ax

        mov bx,tar
        shl bx,1
        mov ax,target[bx]
        mov bx,ax
        pop ax
        cmp ax,bx
        je run_loop1_cmp_check_case1
        mov ax,0
        run_loop1_cmp_check_ok:
        pop bx
        ret

    run_loop1_cmp_check_case1:
        mov ax,1
        jmp run_loop1_cmp_check_ok
        

read_n:
        push bx
        push cx
        push dx
        push si

        call fgets

        ; n = 0
        mov n, 0

        ; CX = 实际输入字符数
        xor cx, cx
        mov cl, line[1]

        ; SI = 字符下标，line[2] 是第一个输入字符
        xor si, si

        ; 空输入
        cmp cx, 0
        je read_n_error

    read_n_loop:
        ; AL = line[si + 2]
        mov al, line[si+2]

        ; 检查是否为数字字符
        cmp al, '0'
        jb read_n_error

        cmp al, '9'
        ja read_n_error

        ; AL = 当前数字的数值
        sub al, '0'
        xor ah, ah              ; AX = 0～9

        ; 暂存当前数字
        push ax

        ; n = n * 10
        mov ax, n
        mov bx, 10
        mul bx                  ; DX:AX = AX * 10

        ; 取出当前数字
        pop dx                  ; DX = 当前数字 0～9

        ; n = n * 10 + 当前数字
        add ax, dx
        mov n, ax

        inc si
        loop read_n_loop

        ; 成功
        mov ax, 0
        jmp read_n_done

    read_n_error:
        push dx
        mov dx,offset input_n_error_str
        mov ah,09h
        int 21h
        pop dx
        mov ax, 1

    read_n_done:
        pop si
        pop dx
        pop cx
        pop bx
        ret

start:
    mov ax,@data
    mov ds,ax   ;设置数据段

    main_loop:
    call read_n
    cmp ax,1
    je main_loop
    mov ax,n
    cmp ax,0
    je main_end
    call initialize
    call checkN
    cmp ax,0
    jne main_loop
    call inputNum
    cmp ax,0
    jne main_loop
    call run
    cmp ax,1
    je main_loop
    jmp main_loop


    main_end:
        mov ax,4c00h
        int 21h

end start

    
