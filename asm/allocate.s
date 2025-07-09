.extern __eheap_start
.extern __eheap_end


    .section .data
    .align 4
    .type Snake_Page_Break %object
Snake_Page_Break:
    .word __eheap_end
    .size Snake_Page_Break, .-Snake_Page_Break

    .align 4
    .type Snake_HBlock_Base %object
Snake_HBlock_Base:
    .word Snake_HBlock_Base
    .word 0
    .size Snake_HBlock_Base, .-Snake_HBlock_Base

    .align 4
    .type Snake_HBlock_ListP %object
Snake_HBlock_ListP:
    .word Snake_HBlock_Base
    .size Snake_HBlock_ListP, .-Snake_HBlock_ListP
    
/** 
 * Heap header block fields:
 * HeaderBlockEntry *nextptr       : 4B(32b)
 * size_t            block_size    : 4B(32b)
 * 
 */

#define HDR_SIZE 8
#define HDR_SIZE_DIVMULSHAMT 3
#define MIN_ALLOC 256




    .section .iwram,"ax", %progbits
    .arm
    .type Snake_Free32 %function
Snake_Free32:
    SUB r0, r0, #HDR_SIZE  // r0:=block to free (from header) := free_block_base
    LDR r12, =Snake_HBlock_ListP  // r12:=&Snake_HBlock_ListP
    LDR r1, [r12]  // r1:= *((HeaderBlockEntry**)r12):=Snake_HBlock_ListP : head
                   //   := cur
.Lsnake_free32_blocklist_loop:
        LDR r2, [r1]  // r2:=((HeaderBlockEntry*)r1)->next := cur->next
        CMP r0, r1  // compare(free_block_base, cur)
        CMPGT r2, r0  // compare(cur->next, free_block_base) 
                      //        only if free_block_base > cur
        BGT .Lsnake_free32_found_block_insertion_pt  // break only if
                                                      // free_block_base > cur
                                                      // &&
                                                      // cur->next > free_block_base
.Lsnake_free32_inner_check:
        CMP r1, r2  // compare(cur, cur->next)
        MOVLT r1, r2  // cur = cur < cur->next ? cur->next : cur
        BLT .Lsnake_free32_blocklist_loop  // continue only if cur < cur->next
        CMP r0, r1  // compare(free_block_base, cur)
        CMPLE r2, r0  // compare(cur->next, free_block_base) only if free_block_base <= cur
        MOVLE r1, r2  // cur = (free_block_base <= cur && cur->next <= free_block_base)
                      //                    ? cur->next 
                      //                    : cur
        BLE .Lsnake_free32_blocklist_loop  // continue only if 
                                            //  free_block_base<=cur 
                                            //  && cur->next<=free_block_base
                                            // ELSE break
 .Lsnake_free32_found_block_insertion_pt:
    // r0:= free_block_base:= fbb (new name)
    // r1:= cur
    // r2:= cur->next
    PUSH { r4-r8 }
    


    
    LDR r3, [r0, #4]  // r3:=fbb->size
    LDR r4, [r1, #4]  // r4:=cur->size
    LDR r5, [r2, #4]  // r5:=cur->next->size
    ADD r6, r0, r3, LSL #HDR_SIZE_DIVMULSHAMT // r6:=fbb+fbb->size
    ADD r7, r1, r4, LSL #HDR_SIZE_DIVMULSHAMT  // r7:=cur+cur->size

    TEQ r6, r2  // test_equality(fbb+fbb->size, cur->next)
    STRNE r2, [r0]  // fbb->next = cur->next 
                    //      only if &fbb[fbb->size] != cur->next
    BNE .Lsnake_free32_curnxt_and_fbb_noncontiguous
    // -------------- do following block of instructions -----------------------
    // -------------- ONLY IF fbb+fbb->size == cur->next -----------------------
    // -------------- I.E: ONLY IF fbb & cur->next ARE contiguous --------------
    ADD r3, r3, r5  // r3:=fbb_new_size:= fbb->size + cur->next->size
    STR r3, [r0, #4]  // fbb->size:= r3:= fbb_new_size <=> fbb->size += cur->next->size
    // now r3:= fbb->size again
    LDR r8, [r2]  // r8:=(((HeaderBlockEntry*)r2):=cur->next)->next
                  //   :=cur->next->next
    STR r8, [r0]  // fbb->next:=cur->next->next
    // -------------------------------------------------------------------------
.Lsnake_free32_curnxt_and_fbb_noncontiguous:
    TEQ r7, r0  // test_equality(cur+cur->size, fbb)
    STRNE r0, [r1]  // cur->next = fbb only if cur+cur->size != fbb
    BNE .Lsnake_free32_cur_and_fbb_noncontiguous  // Insertion complete 
                                                   // only if fbb!=cur+cur->size
    // -------------- do the following block of instructions -------------------
    // -------------- ONLY IF cur + cur->size == fbb ---------------------------
    // -------------- I.E: ONLY IF fbb & cur ARE contiguous --------------------
    ADD r4, r4, r3  // r4:=new_cursize:= cur->size + fbb->size
    STR r4, [r1, #4] // cur->size:= r4:= new_cursize <=> cur->size += fbb->size
    LDR r8, [r0]  // r8:= fbb->next
    STR r8, [r1]  // cur->next = fbb->next
    // -------------------------------------------------------------------------
.Lsnake_free32_cur_and_fbb_noncontiguous:
    STR r1, [r12]  // Snake_HBlock_ListP = cur
    POP { r4-r8 }  // Restore r4-r8 register values back to caller's reg vals
    BX lr
    
    .size Snake_Free32, .-Snake_Free32

    .arm
    .type _snake_sbrk32 %function
_snake_sbrk32:
    // r0:arg0:=ksize of page break increase
    LDR r1, =Snake_Page_Break  // r1:=&Snake_Page_Break
    LDR r2, [r1]  // r2:= Snake_Page_Break
    SUB r2, r2, r0  // r2:= Snake_Page_Break - arg0:= Snake_Page_Break_New
    LDR r3, =__eheap_start  // r3:= heap lower bound
    CMP r2, r3  // compare(Snake_Page_Break_New, limit of heap)
    MOVLT r0, #-1
    BXLT lr
    MOV r0, r2 
    STR r2, [r1]  // *r1:=*(&Snake_Page_Break):=r2:=Snake_Page_Break_New (update page break to new val)
    BX lr

    .size _snake_sbrk32, .-_snake_sbrk32

    .arm
    .type _snake_morecore32 %function
_snake_morecore32:
    // r0: alloc_size
    PUSH { r4, lr }
    CMP r0, #MIN_ALLOC
    MOVLT r0, #MIN_ALLOC  // r0:= MIN_ALLOC>alloc_size ? MIN_ALLOC : alloc_size
    MOV r4, r0
    LSL r0, r0, #HDR_SIZE_DIVMULSHAMT  // r0:=alloc_sz*sizeof(HeaderBlockEntry)
    BL _snake_sbrk32
    CMP r0, #-1
    MOVEQ r0, #0
    POPEQ { r4, pc }
    STR r4, [r0, #4]
    ADD r0, r0, #HDR_SIZE
    BL Snake_Free32
    LDR r0, =Snake_HBlock_ListP
    LDR r0, [r0]
    POP { r4, pc }
    .size _snake_morecore32, .-_snake_morecore32

    .arm
    .align 2
    .global Snake_Malloc32
    .type Snake_Malloc32 %function
Snake_Malloc32:
    TEQ r0, #0
    BXEQ lr
    PUSH { r4-r8, lr }
    ADD r0, r0, #(HDR_SIZE - 1)
    LSR r0, r0, #HDR_SIZE_DIVMULSHAMT
    ADD r5, r0, #1  // r5:=malloc size in header units

    LDR r6, =Snake_HBlock_ListP  // r6:=&hdrblist :: HeaderBlockEntry**
    LDR r6, [r6]  // r6:=*(&hdrblist)=hdrblist :: HeaderBlockEntry*  (using as head node for loop break cnd)
    MOV r7, r6  // r7:=r6 :: HeaderBlockEntry* (using as prev ptr for loop)
    LDR r8, [r7]  // r7:=((HeaderBlockEntry*)r7)->next:=prev->next (using as cur ptr for loop)
.Lsnake_malloc32_findfreeblock:
        LDR r4, [r8, #4]  // r4:=cur->size
        CMP r4, r5  // compare(cur->size, alloc_size)
        // IF cur->size < alloc_size
        BLT .Lsnake_malloc32_block_2small  // branch to continue looping
        // ELSE IF cur->size == alloc_size
        LDREQ r0, [r8]  // r0:= cur->next
        STREQ r0, [r7]  // prev->next = cur->next
        // ELSE
        SUBGT r4, r4, r5  // r4:= cur->size - alloc_size
        STRGT r4, [r8, #4]  // r4:= new_cursize:= cur->size -= alloc_size
//        LSLGT r0, r4, #HDR_SIZE_DIVMULSHAMT
//        ADDGT r8, r8, r0
        ADDGT r8, r8, r4, LSL #HDR_SIZE_DIVMULSHAMT  // cur+=(new_cursize*HDR_SIZE) := ((HeaderBlockEntry*)cur) += new_cursize
        STRGT r5, [r8, #4]  // cur->size = alloc_size
        // ENDIF
        LDR r0, =Snake_HBlock_ListP  // r0:= &Snake_HBlock_ListP
        STR r7, [r0]  // Snake_HBlock_ListP = prev
        ADD r8, r8, #HDR_SIZE
        B .Lsnake_malloc32_found_block
.Lsnake_malloc32_block_2small:
        TEQ r8, r6
        MOVNE r7, r8  // r7:prev:= r8:cur::HeaderBlockEntry* only if head!=cur
        LDRNE r8, [r8]  // r8:cur:=((HeaderBlockEntry*)r8)->next:cur->next::HeaderBlockEntry* only if head!=cur
        BNE .Lsnake_malloc32_findfreeblock  // CONTINUE only if head!=cur
        MOV r0, r5  // r0:= alloc_size
        BL _snake_morecore32
        MOVS r8, r0  // cur = _snake_morecore32(alloc_size)
        // IF cur != NULL
        MOVNE r7, r8  // prev = cur
        LDRNE r8, [r8]  // cur = cur->next
        BNE .Lsnake_malloc32_findfreeblock  // CONTINUE
        // ENDIF
.Lsnake_malloc32_found_block:

    MOV r0, r8
    POP { r4-r8, lr }
    BX lr
    .size Snake_Malloc32, .-Snake_Malloc32

    .text
    .thumb_func
    .align 2
    .global Snake_Malloc16
    .type Snake_Malloc16 %function
Snake_Malloc16:
    PUSH { lr }
    LDR r1, =Snake_Malloc32
    BL .Lsm16_long_call
    POP { r1 }
.Lsm16_long_call:
    BX r1
    .size Snake_Malloc16, .-Snake_Malloc16
    
    .thumb_func
    .align 2
    .global Snake_Free16
    .type Snake_Free16 %function
Snake_Free16:
    PUSH { lr }
    LDR r1, =Snake_Free32
    BL .L_sf16_long_call
    POP { r1 }
.L_sf16_long_call:
    BX r1
    .size Snake_Free16, .-Snake_Free16
