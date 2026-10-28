#include <stdio.h>
#include <string.h>
char line[128];
int target[32];
int tar = 0;
int stack[32];
int st = 0;
int n;
char opt[128];
int opn=0;
int vis[32];
int flag = 0;
int tmp = 0;
int id = 0;
int result = 0;
char c;

void initialize(){
    memset(target,0,sizeof target);
    memset(vis,0,sizeof(vis));
    tar = 0;
    st = 0;
    opn = 0;
    flag = 0;
    result = 0;
    tmp = 0;
    id = 0;
}

int checkN(){
    if(n>30){
        printf("n > 30 !\n");
        return 1;
    }
    if(n<1){
        printf("n < 1 !\n");
        return 1;
    }
    return 0;
}

void val_out(){
    printf("Error: value out of range\n");
    result = 1;
    return;
}

void duplicate(){
    printf("Error: duplicate car %d\n",tmp);
    result = 1;
    return;
}

void illegal(){
    printf("illegal character '%c'\n",c);
    result = 1;
    return;
}

void checktmp(){
    if(tmp>n||tmp<1){
        val_out();
        return;
    }
    if(vis[tmp]==1){
        duplicate();
        return;
    }
}

void inputout(){
    printf("you've input out of %d numbers\n",n);
    result = 1;
    return;
}

void inputless(){
    printf("you've input less than 1 number\n");
    result = 1;
    return;
}

void checktar(){
    if(tar>n){
        inputout();
    }
    if(tar<n){
        inputless();
    }
}

void Impossible(){
    printf("IMPOSSIBLE\n");
    result = 1;
    return;
}

int dealChar(char c){
    if(c>='0'&&c<='9'){
        tmp*=10;
        tmp += c-'0';
        return 0;
    }
    else if(c==' '){
        checktmp();
        if(result==1){
            return 1;
        }
        target[tar] = tmp;
        vis[tmp] = 1;
        tmp = 0;
        tar++;
        return 0;
    }
    else{
        illegal();
        return 1;
    }
}

int inputNum(int n){
    fgets(line,sizeof line,stdin);
    int id = 0;
    while(line[id]!='\n'){
        c = line[id];
        flag = dealChar(c);
        if(flag==1){
            return 1;
        }
        id++;
    }
    checktmp(); //如果line[id] == '\n'
    if(result==1){
        return 1;
    }
    target[tar] = tmp;
    tmp = 0;
    tar++;
    checktar();
    if(result==1){
        return 1;
    }
    return 0;
}

void push(){
    st++;
    stack[st] = tmp;
    opn++;
    opt[opn] = 'p';
}

void pop(){
    st--;
    opn++;
    opt[opn] = 'o';
}

int peek(){
    if(st==0){
        return -1;
    }
    return stack[st];
}

void Possible(){
    printf("POSSIBLE ");
    return;
}

int run(){
    tmp = 1;
    tar = 0;
    while(tmp<=n){
        push();
        while(tar<n&&peek()==target[tar]){
            pop();
            tar++;
        }
        tmp++;
    }
    if(tar<n){
        Impossible();
        return 1;
    }
    // printf("POSSIBLE ");
    Possible();
    tmp = 1;
    while(tmp<=opn){
        printf("%c",opt[tmp]);
        tmp++;
    }
    printf("\n");
    return 0;
}

int main(void){
CASE1:
    scanf("%d",&n);
    getchar();
    while(n!=0){
        initialize();

        flag = checkN(n);
        if(flag!=0){
            goto CASE1;
        }

        flag = inputNum(n);
        if(flag!=0){
            goto CASE1;
        }

        flag = run();
        if(flag == 1){
            goto CASE1;
        }

        scanf("%d",&n);
        getchar();
    }
    return 0;
}