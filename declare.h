#ifndef DECLARA_H
#define DECLARA_H

struct node{
    int index;
    char *name;
    int entry_type;
    int data_type;
    int s_level;
    int parameter[10];
    struct node *next;
};

typedef struct Value Value;
struct Value {
    char* id_name;
    char* cur_type;
    int type_num;
    int i_val;
    float f_val;
    char* str_val;
};

#endif