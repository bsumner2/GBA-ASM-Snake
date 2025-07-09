    .extern Snake_Free16
    .extern Snake_Malloc16
    .extern Mode3_Puts
// #define Snake_Free16 free
// #define Snake_Malloc16 malloc
    .section .rodata
    .align 2
    .type ALLOC_ERR_MSG %object
ALLOC_ERR_MSG:
    .asciz "Snake_Malloc16 returned NULL"
    .size ALLOC_ERR_MSG, .-ALLOC_ERR_MSG


#define SIZEOF_NODE 12
/*
 * Node: ---------- base addr (addr+0)
 *  X Coord : ushort : HWORD   addr+0
 *  Y Coord : ushort : HWORD   addr+2
 *  Next    :  ptr   : WORD    addr+4
 *  Prev    :  ptr   : WORD    addr+8
 *------------------ end addr (addr+12)
 * Therefore sizeof(LL Node) = 12
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

/*
 * = Linked List Visual:
 *    - Head->next links to body segment behind head.
 *    - Head->prev links circularly back to tail
 *    = LL as C struct:
 *        struct LL {
 *          struct LL_Node *head;
 *          struct LL_Node *tail;
 *          unsigned short len;
 *        }
 *    = LL Node as C struct:
 *        struct LL_Node {
 *          ushort x;
 *          ushort y;
 *          struct LL_Node *next;
 *          struct LL_Node *prev;
 *        }
 */


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
    .type node_alloc %function
node_alloc: 
    // r0 = grid x
    // r1 = grid y
    // r2 = next ptr
    // r3 = prev ptr
    PUSH {r4, r5, r6, r7, lr}
    
    // Save param vals to GP regs b4 calling Snake_Malloc16
    MOV r4, r0  // r4 = r0 = x
    MOV r5, r1  // r5 = r1 = y
    MOV r6, r2  // r6 = r2 = next ptr
    MOV r7, r3  // r7 = r3 = prev
    
    // Move Snake_Malloc16 param value into r0
    MOV r0, #SIZEOF_NODE
    BL Snake_Malloc16
    CMP r0, #0
    BEQ .Lnode_alloc_NULL
    STRH r4, [r0]  // *((u16*) (&node + 0)) = node.x = r4 = x coord
    STRH r5, [r0, #2]  // *((u16*) (&node + 2)) = node.y = r5 = y coord
    STR r6, [r0, #4]  // *((node**) (&node + 4)) = node.next = r6 = front link ptr
    STR r7, [r0, #8]  // *((node**) (&node + 8)) = node.prev = r7 =  back link ptr

    POP {r4-r7}
    POP {r1}
    BX r1
.Lnode_alloc_NULL:
    LDR r0, =ALLOC_ERR_MSG
    MOV r1, #0
    MOV r2, #0
    MOV r3, #31
    BL Mode3_Puts
.Lnode_alloc_NULL_loop:
        SVC #0x05
        B .Lnode_alloc_NULL_loop
    .size node_alloc, .-node_alloc


    .thumb_func
    .align 2
    .global snake_grow
    .type snake_grow %function
snake_grow:
    // r0:newhead.x r1:newhead.y r2:LL
    PUSH {r4, lr}
    // When snake grows, new head appended at apple location
    MOV r4, r2  // Save LL addr in r4
    
    // First, update len
    LDRH r2, [r4, #8]
    ADD r2, #1
    STRH r2, [r4, #8]
    
    // already have first 2 node alloc params:
    // r0 = x
    // r1 = y
    // Just need node_alloc's 3rd and 4th args in r2, r3:
    // r2 = newhead.next = old head = LL->head
    LDR r2, [r4]
    
    // r3 = newhead.prev = head's circular link back to tail = LL->tail
    LDR r3, [r4, #4]

    // CALL: node_alloc(newhead.x : x_coord, newhead.y : y_coord, oldhead : next, tail : prev)
    BL node_alloc

    
    LDR r1, [r4]  // r1 = LL->head = old head
    STR r0, [r4]  // LL->head = new head
    STR r0, [r1, #8]  // (oldhead: new body1)->prev = new head

    LDR r1, [r4, #4]  // r1 = (LL->tail). Put tail into r1
    STR r0, [r1, #4]  // tail->next = new head



    POP {r4}

    POP {r1}
    BX r1
    .size snake_grow, .-snake_grow

    .thumb_func
    .align 2
    .global snake_move
    .type snake_move %function
snake_move:
    // r0 = new head x, r1 = new head y, r2 = LL
    // Recycle tail node for new head node. Simulates the movement quite nicely
    LDR r3, [r2, #4]  // r3 = LL->tail  : r3 has tail ptr which we recycle as new head ptr
    STR r3, [r2]  // LL->head = LL->tail : Overwrite LL->head w/ old tail, making tail new head


    // Additionally, due to double-linked and circular linkage design, we don't even need to
    // change any of the nodes' links. Just update LL->head = LL->tail, and LL->tail = LL->tail->prev,
    // along with changing old tail's coord values to reflect the new head's location, obviously.
    // So our checklist is:
    // Task 1. [x] Make LL->head point to recycled tail node, i.e.: overwrite LL->head w/ LL->tail
    // Task 2. [ ] Change tail coords to be new head coords
    // Task 3. [ ] Make LL->tail = LL->tail->prev, since LL->tail->prev is really just new_head->prev, 
    //             which, as head node, circulates back to tail
    
    
    STRH r0, [r3]  // new head->x = r0: param'd x coord
    STRH r1, [r3, #2]  // new head->y = r1: param'd y coord
    // Task 2. [x]
    
    // Done with params in r0, r1, so we can use em for other stuff,
    // and save on the overhead of relying on the clean GP LO regs, r4-r7
    LDR r0, [r3, #8]  // r0 = LL->tail->prev : r0 has new tail ptr
    STR r0, [r2, #4]  // LL->tail = LL->tail->prev
    // Task 3. [x]

    // AAAND we're done! Can exit without having to pop to restore any regs, or anything at all!
    // Such a refreshment after having to conjure up the mess that was main.s's handle_movement function.
    BX lr
    .size snake_move, .-snake_move

    .thumb_func
    .align 2
    .global coord_to_grid_idx
    .type coord_to_grid_idx %function
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
    .global grid_idx_to_coord
    .type grid_idx_to_coord %function
grid_idx_to_coord:
    // r0 = grid idx
    PUSH {lr}
    MOV r1, #GRID_WIDTH  // r0 = grid idx, r1 = grid width
    BL __aeabi_uidivmod
    // Now, r0 = quotient, r1 = remainder, so r0 = grid_idx/grid_width = y, r1 = grid_idx%grid_width = x
    MOV r2, r0  // Temporarily put y into r2
    MOV r0, r1  // Move x into r0
    MOV r1, r2  // Move y (which was tmp'd into r2) into r1

    POP {r2}
    BX r2
    .size grid_idx_to_coord, .-grid_idx_to_coord


    .thumb_func
    .align 2
    .global snake_init
    .type snake_init %function
snake_init:
    // r0 = Grid Buffer
    PUSH {r4, r5, lr}
    MOV r5, r0  // temporarily keep grid buffer address in r5
    MOV r0, #START_COORD_X
    SUB r0, #1  // r0 = alloc_node param no. 1: x coord for initial snake's tail
    MOV r1, #START_COORD_Y  // r1 = alloc_node param no. 2: y coord for init snake's tail
    MOV r2, #0  // r2 = alloc_node param no. 3: NULL link for tail node

    LDR r4, =S_Snake_Body  // r4 = LL
    
    BL node_alloc  // alloc the tail node

    STR r0, [r4, #4]  // assign addr of alloc'd node to LL->tail
    
    MOV r3, r0  // r3 = alloc_node param no. 4: tail addr as back link for head we're about to alloc
    MOV r2, r0  // r2 = alloc_node param no. 3: tail addr as front link, too
    MOV r1, #START_COORD_Y  // r1 = alloc_node param no. 2: y coord
    MOV r0, #START_COORD_X  // r0 = alloc_node param no. 1: x coord
    BL node_alloc

    STR r0, [r4]  // LL->head = (head:new node)
    // MOV r4, r0  // Put LL->head (=head) into r4
    // LDRH r0, [r4] // r0 = head->x
    // LDRH r1, [r4, #2]  // r1 = head->y
    LDR r1, [r4, #4]  // r1 = tail
    STR r0, [r1, #4]  // tail->next = head
    STR r0, [r1, #8]  // tail->prev = head
    

    
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

    .thumb_func
    .align 2
    .global free_snake_nodes
    .type free_snake_nodes %function
free_snake_nodes:
    PUSH {r4-r6, lr}
    LDR r4, =S_Snake_Body  // r4 = LL
    LDR r5, [r4]  // r5 = LL->head
    LDRH r6, [r4, #8]  // r6 = LL->len
    CMP r6, #0
    BEQ .Lfreenodes_already_empty

.Lfreenodes_loop:
        MOV r0, r5  // Move curr node, r5, into r0 for freeing
        LDR r5, [r0, #4]  // r5 = node->next

        BL Snake_Free16

        SUB r6, #1
.Lfreenodes_contcheck:
        CMP r6, #0
        BNE .Lfreenodes_loop

.Lfreenodes_already_empty:
    MOV r0, #0
    STR r0, [r4]  // LL->head = NULL
    STR r0, [r4, #4]  // LL->tail = NULL
    STRH r0, [r4, #8]  // LL->len = 0

    POP {r4-r6}
    POP {r3}
    BX r3
     
    
    .size free_snake_nodes, .-free_snake_nodes
     
