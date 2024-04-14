    // I hate to include libc functions, but I'm not about to write my own memory
    // arena for a SNAKE GAME.
    .extern free
    .extern malloc

#define SIZEOF_NODE 8
/*
 * Node: ---------- base addr (addr+0)
 *  X Coord : ushort : HWORD   addr+0
 *  Y Coord : ushort : HWORD   addr+2
 *  Link    :  ptr   : WORD    addr+4
 *------------------ end addr (addr+8)
 * Therefore sizeof(LL Node) = 8
 */

#define START_COORD_X 10
#define START_COORD_Y 20

#define GRID_WIDTH 60
#define GRID_HEIGHT 40
#define CELL_EMPTY 0
#define CELL_SNAKE 1
#define CELL_APPLE 2
#define GRID_CELL_SIZE 4

#define SNAKE_INIT_LEN 2


    .section .bss
    .align 2
S_Snake_Body:
    .space 4  // Head : Node*
    .space 4  // Tail : Node*
    .space 2  // Length
    .size S_Snake_Body, .-S_Snake_Body




    .text
    .thumb_func
    .align 2
    .global node_alloc
    .type node_alloc, %function
node_alloc: 
    // r0 = grid x
    // r1 = grid y
    // r2 = next ptr
    PUSH {r4, r5, r6, lr}
    
    // Save param vals to GP regs b4 calling malloc
    MOV r4, r0  // r4 = r0 = x
    MOV r5, r1  // r5 = r1 = y
    MOV r6, r2  // r6 = r2 = link ptr
    
    // Move malloc param value into r0
    MOV r0, #SIZEOF_NODE
    BL malloc
    
    STRH r4, [r0]  // *((u16*) (&node + 0)) = node.x = r4 = x coord
    STRH r5, [r0, #2]  // *((u16*) (&node + 2)) = node.y = r5 = y coord
    STRH r6, [r0, #4]  // *((node**) (&node + 4)) = node.link = r6 = link ptr

    POP {r4-r6}
    POP {r1}
    BX r1
    .size node_alloc, .-node_alloc

    .thumb_func
    .align 2
    .global coord_to_grid_idx
    .type coord_to_grid_idx, %function
coord_to_grid_idx:
    // r0 = x
    // r1 = y
    MOVS r2, r1  // r2 = r1 = y
    BEQ .Lctidx_yzero
    LSL r1, #6  // r1 <<= 6 : r1 = y<<=6 = y*64
    LSL r2, #2  // r2 <<= 2 : r2 = y<<=2 = y*4
    SUB r1, r2  // r1 = r1-r2 = y*64 - y*4 = y*(64-4) = y*60 = y*GRID_WIDTH
    
    ADD r0, r1  // r0 = x + y*60 = x+y*GRID_WIDTH = (x:r0,y:r1)=>coord-2-grid_idx

.Lctidx_yzero:
    // If y is zero, there's literally nothing to do. r0 = x is already the grid idx when y = 0.
    BX lr
    .size coord_to_grid_idx, .-coord_to_grid_idx


    .thumb_func
    .align 2
    .global snake_init
    .type snake_init, %function
snake_init:
    // r0 = Grid Buffer
    PUSH {r4, r5, lr}
    MOV r5, r0  // temporarily keep grid buffer address in r5
    MOV r0, #START_COORD_X
    SUB r0, #1  // r0 = alloc_node param no. 1: x coord for initial snake's tail
    MOV r1, #START_COORD_Y  // r1 = alloc_node param no. 2: y coord for init snake's tail
    MOV r2, #0  // r2 = alloc_node param no. 3: NULL link for tail node

    LDR r4, =S_Snake_Body  // r4 = LL
    
    BL node_alloc  // alloc the node

    STR r0, [r4, #4]  // assign addr of alloc'd node to LL->tail
    
    MOV r2, r0  // r2 = alloc_node param no. 3: tail addr as link for head node we're about to alloc
    MOV r0, #START_COORD_X  // r0 = alloc_node param no. 1: x coord for head
    MOV r1, #START_COORD_Y  // r1 = alloc_node param no. 2: y coord for head
    BL node_alloc

    STR r0, [r4]  // LL->head = (head:new node)
    // MOV r4, r0  // Put LL->head (=head) into r4
    // LDRH r0, [r4] // r0 = head->x
    // LDRH r1, [r4, #2]  // r1 = head->y
    
    // BL coord_to_grid_idx  // r0 = coord_to_grid_idx(r0, r1) = coord_to_grid_idx(head.x, head.y) = head grid idx
    MOV r0, #128
    LSL r0, #3  // r0<<=3 : = 128<<3 = (1<<7)<<3 = 1<<10 = 1024
    ADD r0, #186  // r0+=186 : = 1024 + 186 = 1210 = 10 + 20*60
    //                         = head.x + head.y*GRID_WDITH = head grid idx

    MOV r1, #CELL_SNAKE
    STRB r1, [r5, r0]  // (r5[r0]=GRID_BUF[head_idx]) = (r1=CELL_SNAKE=1)
    
    SUB r0, #1  // r0 -= 1 : = head idx - 1 = 1209 = 9 + 20*60 = tail.x + tail.y*GRID_WIDTH = tail idx
    STRB r1, [r5, r0]  // GRID_BUF[tail_idx] = CELL_SNAKE

     
    MOV r0, r4  // (r0=RETURN VALUE REGISTER) = (r4=LL)
    MOV r1, #SNAKE_INIT_LEN  // Quickly just put snake length into LL data structure 
    //                          (done here because it was a last-minute idea, hamfisted into this function's impl'ation)
    STRH r1, [r0, #8]  // LL->len = SNAKE_INIT_LEN = 2


    POP {r4, r5}

    POP {r1}

    BX r1
    .size snake_init, .-snake_init

    


     
    

    
    

    
     
