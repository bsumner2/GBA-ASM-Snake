#define GRID_WIDTH 60
#define GRID_HEIGHT 40
#define CELL_EMPTY 0
#define CELL_SNAKE 1
#define CELL_APPLE 2
#define GRID_CELL_SIZE 4

    .section .bss
    .align 2
    .global GRID_A
GRID_A:
    .space 2400
    .size GRID_A, .-GRID_A

    .align 2
    .global GRID_B
GRID_B:
    .space 2400
    .size GRID_B, .-GRID_B

    .align 2
    .global LFSR 
LFSR:
    .space 2  // For the LFSR RNG State: u16_t state
    .space 4  // For the Feedback Polynomial: u16_t feedback_polynomial[2]
    .size LFSR, .-LFSR
    
    .section .rodata
    .align 2
    .global RNG_Seed
RNG_Seed:
    .hword 0xab38
    .size RNG_Seed, .-RNG_Seed




    .text

// FUNCTION: draw_grid_cell
    .thumb_func
    .align 2
    .global draw_grid_cell
    .type draw_grid_cell %function
draw_grid_cell:
    // r0: x
    // r1: y
    // r2: cell_type
    CMP r2, #CELL_SNAKE
    BNE .Ldgc_NotSnake
    MOV r2, #0xFF
    MOV r3, #0x7F
    LSL r3, #8
    ORR r2, r3
    B .Ldgc_draw
.Ldgc_NotSnake:
    BGE .Ldgc_Apple
    MOV r2, #0
    B .Ldgc_draw
.Ldgc_Apple:
    MOV r2, #0x1F
.Ldgc_draw:
    // r1 = grid_y * 4 = screen y
    LSL r1, #2
    MOVS r3, r1
    // if r1 is zero then no need getting vertical VRAM offset.
    
    BEQ .Ldgc_y_is_zero
    
    // r1 = y*16
    LSL r1, #4
    // r1 = y*16 - y = y*(16-1) = y*15
    SUB r1, r3
    // r1 = y*15*64 = y*15*16 = y*240*4
    LSL r1, #4
    
.Ldgc_y_is_zero:
    // r0 = x*4
    LSL r0, #2
    ADD r0, r1
    // r0 = ((y*240+x)*4)*2
    LSL r0, #1
    
    // VRAM ADDRESS in r3
    MOV r3, #192
    LSL r3, #19
    // r3 = &VRAM + r0 = &VRAM + (y*240+x)*4*(2B/px) = VRAM[4*(y*240+x)]
    ADD r3, r0
     
    PUSH {r4}
    MOV r4, r3
    MOV r0, #4

.Ldgc_draw_row:
        MOV r1, #4
.Ldgc_draw_column:
            STRH r2, [r3]
            ADD r3, #2
            SUB r1, #1
            CMP r1, #0
            BNE .Ldgc_draw_column
        MOV r3, #240
        LSL r3, #1
        ADD r4, r3
        MOV r3, r4
        SUB r0, #1
        CMP r0, #0
        BNE .Ldgc_draw_row
    
    POP {r4}
    
    BX lr
    .size draw_grid_cell, .-draw_grid_cell


// FUNCTION: vsync
    .thumb_func
    .align 2
    .global vsync
    .type vsync %function
vsync:
    // r0 = 0x04000006 = REG_DISPLAY_VCOUNT
    MOV r0, #0x80
    LSL r0, #19
    ADD r0, #6
.Lvsync_get_outta_vbl:
        LDRH r1, [r0]
        CMP r1, #160
        BGE .Lvsync_get_outta_vbl
.Lvsync_get_outta_vdraw:
        LDRH r1, [r0]
        CMP r1, #160
        BLT .Lvsync_get_outta_vdraw
    BX lr
    .size vsync, .-vsync

// FUNCTION: lfsr_init
    .thumb_func
    .align 2
    .global lfsr_init
    .type lfsr_init %function
lfsr_init:
    // r0 = Seed
    // r1 = first feedback polynomial shamt
    // r2 = second feedback polynomial shamt
    LDR r3, =LFSR
    STRH r0, [r3]
    STRH r1, [r3, #2]
    STRH r2, [r3, #4]
    BX lr
    .size lfsr_init, .-lfsr_init

// FUNCTION: lfsr_shift
    .thumb_func
    .align 2
    .global lfsr_shift
    .type lfsr_shift %function
lfsr_shift:
    PUSH {r4}
    LDR r0, =LFSR
    MOV r1, #0  // r1 = feedback bit
    MOV r2, #2  // r2 = idx
    LDRH r3, [r0]  // r3 = LFSR->state
    MOV r12, r3  // r12 will hold LFSR->state's value
.Llfsr_shift_feedback_polys:
        LDRH r4, [r0, r2]  // r4 = LFSR->feedback_poly[(i=(r2-2)/2)] 
        LSL r3, r4  // r3 = LFSR->state >> LFSR->feedback_poly[i]
        MOV r4, #1
        AND r3, r4  // r3 &= 1
        EOR r1, r3  // r1 ^= r3

        MOV r3, r12  // Restore r3 to LFSR->state
        ADD r2, #2
        
        CMP r2, #6
        BLT .Llfsr_shift_feedback_polys
    
    POP {r4}

    LSL r3, #1
    LSR r1, #15
    ORR r3, r1
    STRH r3, [r0]

    BX lr
    .size lfsr_shift, .-lfsr_shift

// FUNCTION: lfsr_rand
    .thumb_func
    .align 2
    .global lfsr_rand
    .type lfsr_rand %function
lfsr_rand:
    PUSH {r4, lr}  // Save clean regs, lr and r4 by pushing onto stack in that order.
    LDR r0, =LFSR
    LDRH r4, [r0]  // r4 = *((u16*) (r0)) = *((u16*) (&LFSR)) = *(&LFSR.state) = LFSR.state

    BL lfsr_shift

    MOV r0, r4  // r0 = ret = r4 = (pre-shift LFSR.state)
    POP {r4}  // Pop r4's initial value off stack
    POP {r2}  // Pop lr into r2 and return via r2

    BX r2
    .size lfsr_rand, .-lfsr_rand


// FUNCTION: rng_state_manip
    .thumb_func
    .align 2
    .global rng_state_manip
    .type rng_state_manip %function
rng_state_manip:
    // r0 = state adjustment
    PUSH {r4}
    MOV r4, #255  // r4 = MASK
    LDR r1, =LFSR // r1 = &LFSR
    MOV r12, r1 // r12 = &LFSR
    
    LSR r2, r0, #8  // r2 = (adjVval)>>8
    AND r2, r4 // r2 &= 255 : r2 = (adj_val>>8)&0xFF
    AND r0, r4  // r0 &= 255
    LSL r0, #8  // r0 = (adj_val&0xFF)<<8

    // r0 |= r2 : r0 = ((adj_val&0xFF)<<8)|((adj_val>>8)&0xFF)
    ORR r0, r2

    LDRH r1, [r1]  // r1 = LFSR->state
    LSR r3, r1, #8  // r3 = (state>>8)
    AND r3, r4  // r3 = (state>>8)&255
    AND r1, r4  // r1 = state&255
    LSL r1, #8 // r1 = (state&255)<<8
    ORR r1, r3 // r1 = ((state&255)<<8) | ((state>>8)&255)
    POP {r4}

    EOR r0, r1  // r0 ^= r1 
    /* AKA: r0 = return value = NEW_LFSR_state
     *                  =
     * [((adj_value&255)<<8)|((adj_value>>8)&255)]
     *                  XOR
     * [((OLD_LFSR_state&255)<<8)|((OLD_LFSR_state>>8)&255)] */

    MOV r1, r12  // move &LFSR (which was tmp placed into r12) back to a LO register, i.e.: r1
    STRH r0, [r1]  // LFSR.state <-- return value (assign LFSR.state to be the returned value)

    BX lr
    .size rng_state_manip, .-rng_state_manip
    





// FUNCTION: poll_keys
    .thumb_func
    .align 2
    .global poll_keys
    .type poll_keys %function
poll_keys:
    PUSH {lr}  // save link register
    
    MOV r0, #128
    LSL r0, #15
    ADD r0, #19
    LSL r0, #4
    LDRH r0, [r0]  // r0 = (*((u16*) 0x04000130))
    PUSH {r0}  // save key poll onto stack
    // MVN r0, r0  // r0 = ~r0
    BL rng_state_manip
    POP {r0}  // pop og key poll value saved onto stack into return reg, r0
    
    // Since we can't use lr when popping in THUMB mode, we instead
    // pop og link addr into r3, and then either return via r3,

    POP {r3}
    BX r3

    // --or-- move it from r3 back into lr and return via lr as usual
    /*POP {r3}
    MOV lr, r3
    BX lr*/
    

    .size poll_keys, .-poll_keys


// FUNCTION: draw_grid     
    .thumb_func
    .align 2
    .global draw_grid
    .type draw_grid %function
draw_grid:
    // r0 = current grid buffer/front buffer grid
    PUSH {lr}
    PUSH {r4,r5, r6}
    MOV r6, r0
    MOV r4, #0  // r4 = grid y coord.
.Ldg_y:
        MOV r5, #0  // r5 = grid x coord.
.Ldg_x:
            MOV r0, r5
            MOV r1, r4
            LDRB r2, [r6]
            BL draw_grid_cell
            ADD r6, #1
            ADD r5, #1
            CMP r5, #GRID_WIDTH
            BLT .Ldg_x
        ADD r4, #1
        CMP r4, #GRID_HEIGHT
        BLT .Ldg_y
    
    POP {r4, r5, r6}
    POP {r3}
    
    BX r3
    .size draw_grid, .-draw_grid

// FUNCTION: rand_grid_idx
    .thumb_func
    .align 2
    .global rand_grid_idx
    .type rand_grid_idx %function
rand_grid_idx:
    PUSH {lr}
    BL lfsr_rand
    // Now, r0 = lfsr state
    MOV r1, #0x96  // r1 = 0x96 = 150
    LSL r1, #4  // r1 <<= 4 : r1 = 0x96<<4 = 150*16 = 0x960 = 2400

    // Remember: With __aeabi_uidivmod, r0 holds quotient and r1 holds remainder upon return
    BL __aeabi_uidivmod
    // Now, r0 = state/2400 and r1 = state%2400. Want to return val in r1, 
    
    // so move into r0 the value in r1:
    MOV r0, r1 

    POP {r1}  // Pop return addr into r1
    BX r1  // return via r1
    .size rand_grid_idx, .-rand_grid_idx

// FUNCTION: main
	.section	.text.startup,"ax",%progbits
    .thumb_func
    .align 2
    .global main
    .type main %function
main:

    MOV r0, #0x80
    MOV r1, r0
    LSL r0, #19
    
    MOV r2, #3
    LSL r1, r2
    ORR r1, r2
    STR r1, [r0]
    
    LDR r0, =RNG_Seed
    LDRH r0, [r0]
    MOV r1, #10
    MOV r2, #11
    BL lfsr_init
    
.Lmain_wait_for_start:
        BL poll_keys
        MOV r1, #8  // 8 = keypad bitfield value for start btn
        AND r0, r1
        CMP r0, #0
        BNE .Lmain_wait_for_start

    /*BL lfsr_rand
    MOV r1, #150
    LSL r1, #4
    BL __aeabi_uidivmod
    // Remember: With __aeabi_uidivmod, r0 holds quotient and r1 holds remainder upon return
    MOV r0, r1  // Therefore, move value from r1 into r0, since we want rand()%2400, not rand()/2400
    */
    BL rand_grid_idx
    // Now r0 = lfsr_rand()%2400
    LDR r1, =GRID_A
    MOV r2, #1
    STRB r2, [r1, r0]
    MOV r0, r1
    BL draw_grid
    
.Lmain_inf_loop:
    BL vsync
    
    B .Lmain_inf_loop

    .size main, .-main
