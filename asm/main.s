#define GRID_WIDTH 60
#define GRID_HEIGHT 40
#define CELL_EMPTY 0
#define CELL_SNAKE 1
#define CELL_APPLE 2
#define GRID_CELL_SIZE 4

#define START_COORD_X 10
#define START_COORD_Y 20

#define START_GRID_IDX 1210

#define RATE_C    0x0
#define RATE_CIS  0x1
#define RATE_D    0x2
#define RATE_DIS  0x3
#define RATE_E    0x4
#define RATE_F    0x5
#define RATE_FIS  0x6
#define RATE_G    0x7
#define RATE_GIS  0x8
#define RATE_A    0x9
#define RATE_BES  0xA
#define RATE_B    0xB




.extern snake_init
.extern snake_grow
.extern snake_move
.extern free_snake_nodes

.extern coord_to_grid_idx

.extern sound_DSnDMG_control_init

.extern sound_sq1_cnt_set
.extern sound_sq1_freq_set
.extern sound_sq1_sweep_set

.extern sound_noise_cnt_set
.extern sound_noise_freq_set

.extern sound_sq1_play
.extern sound_noise_play

.extern Mode3_puts
.extern Mode3_putchar

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
    .align 2 
    .global INITED_LFSR
INITED_LFSR:
    .word 0
    .size INITED_LFSR, .-INITED_LFSR

    .section .rodata
    .align 2
    .global RNG_Seed
RNG_Seed:
    .hword 0xab38
    .size RNG_Seed, .-RNG_Seed
    .align 2
    .global START_PROMPT
START_PROMPT:
    .asciz "Press START to play!"
    .size START_PROMPT, .-START_PROMPT
    
    .align 2
    .global PAUSE_PROMPT
PAUSE_PROMPT:
    .asciz "Paused!\nPress A to cycle color scheme!\nPress:\nSEL to cycle color schemes\nUP/DOWN to change speed!\nCurrent game speed: "
    .size PAUSE_PROMPT, .-PAUSE_PROMPT



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
    // r3: color scheme
    CMP r2, #CELL_SNAKE
    BNE .Ldgc_NotSnake
    CMP r3, #0
    BNE .ldgc_snake_notpal0
    MOV r2, #0xFF
    MOV r3, #0x7F
    LSL r3, #8
    ORR r2, r3
    B .Ldgc_draw
.ldgc_snake_notpal0:
    // TODO: Colorscheme
    MOV r2, #1
    MOV r3, #5
    LSL r3, #8
    ORR r2, r3 
    B .Ldgc_draw
.Ldgc_NotSnake:
    BGE .Ldgc_Apple
    CMP r3, #0
    BNE .Ldgc_empty_notpal0
    MOV r2, #0
    B .Ldgc_draw
.Ldgc_empty_notpal0:
    MOV r2, #0x73
    MOV r3, #0x1E
    LSL r3, #8
    ORR r2, r3
    B .Ldgc_draw
.Ldgc_Apple:
    CMP r3, #0
    BNE .Ldgc_apple_notpal0
    MOV r2, #0x1F
    B .Ldgc_draw
.Ldgc_apple_notpal0:
    MOV r2, #0xA3
    MOV r3, #0x04
    LSL r3, #8
    ORR r2, r3
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
// So I just read that using the BIOS-provided vsync
// syscall saves a significant amount of battery life, since
// it actually HALTS the CPU instead of just busy-waiting
// with a while loop. So I'm gonna try that here:
vsync:
  SWI 0x05
  BX lr

/*
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
    */
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
    // r1 = back buffer
    // r2 = color scheme
    PUSH {r4-r7, lr}
    PUSH {r2}
    MOV r6, r0
    MOV r7, r1
    MOV r4, #0  // r4 = grid y coord.
.Ldg_y:
        MOV r5, #0  // r5 = grid x coord.
.Ldg_x:
            MOV r0, r5
            MOV r1, r4
            LDRB r2, [r6]
            LDRB r3, [r7]
            CMP r2, r3
            BEQ .Ldg_skip_overwrite  // if *backbuf == *frontbuf, skip pointless drawing
            STRB r2, [r7]  // *r7 = (r2=*r6) : overwrite back buf cell with front buf content
            LDR r3, [sp]
            BL draw_grid_cell
.Ldg_skip_overwrite:
            ADD r6, #1
            ADD r7, #1
            ADD r5, #1
            CMP r5, #GRID_WIDTH
            BLT .Ldg_x
        ADD r4, #1
        CMP r4, #GRID_HEIGHT
        BLT .Ldg_y
    ADD sp, #4
    POP {r4-r7}
    POP {r3}
    
    BX r3
    .size draw_grid, .-draw_grid


// FUNCTION: unpause_redraw_grid
    .thumb_func
    .align 2
    .global unpause_redraw_grid
    .type unpause_redraw_grid %function
unpause_redraw_grid:
    // r0 = current grid buffer to draw
    // r1 = color scheme
    PUSH {r4-r7, lr}
    MOV r6, r0
    MOV r7, r1
    MOV r4, #0  // r4 = grid y coord.
.Luprg_y:
        MOV r5, #0  // r5 = grid x coord.
.Luprg_x:
            MOV r0, r5
            MOV r1, r4
            MOV r3, r7
            LDRB r2, [r6]
            CMP r2, #0
            BEQ .Luprg_skip_empty_draw
            BL draw_grid_cell
.Luprg_skip_empty_draw:
            ADD r6, #1
            ADD r5, #1
            CMP r5, #GRID_WIDTH
            BLT .Luprg_x
        ADD r4, #1
        CMP r4, #GRID_HEIGHT
        BLT .Luprg_y
    
    POP {r4-r7}
    POP {r3}
    
    BX r3
    .size unpause_redraw_grid, .-unpause_redraw_grid








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

#define CURR_DIR_L 0
#define CURR_DIR_D 1
#define CURR_DIR_U 2
#define CURR_DIR_R 3

#define HNDL_MVMNT_COLLISION -1
#define HNDL_MVMNT_OK 0
#define HNDL_MVMNT_APPLE_COLLECTED 1

    .thumb_func
    .align 2
    .global handle_movement
    .type handle_movement %function
handle_movement:
    // r0: movement direction bfield val
    // r1: snake LL
    // r2: game grid
    // Todo: Left off here. Continue from here.
    PUSH {r4, r5, lr}
    MOV r4, r1  // put LL addr into r4
    MOV r5, r2  // keep game grid in r5

    MOV r2, r0  // Move the movement direction flag, out of r0, into r2
    
    LDR r3, [r4]  // r3 = LL->head
    LDRH r0, [r3]  // r0 = head.x
    LDRH r1, [r3, #2]  // r1 = head.y

    CMP r2, #CURR_DIR_U
    BGE .Lhndlmvmnt_uppercheck
    CMP r2, #CURR_DIR_D
    BEQ .Lhndlmvmnt_DOWN
    B .Lhndlmvmnt_LEFT



.Lhndlmvmnt_LEFT:
    CMP r0, #0
    BEQ .Lhndlmvmnt_hit_wall
    SUB r0, #1  // head.x -= 1 = newhead.x 
    B .Lhndlmvmnt_check_availability
.Lhndlmvmnt_DOWN:
    CMP r1, #39
    BEQ .Lhndlmvmnt_hit_wall
    ADD r1, #1
    B .Lhndlmvmnt_check_availability

.Lhndlmvmnt_uppercheck:
    BNE .Lhndlmvmnt_RIGHT

.Lhndlmvmnt_UP:
    CMP r1, #0
    BEQ .Lhndlmvmnt_hit_wall
    SUB r1, #1
    B .Lhndlmvmnt_check_availability
.Lhndlmvmnt_RIGHT:
    CMP r0, #59
    BEQ .Lhndlmvmnt_hit_wall
    ADD r0, #1
.Lhndlmvmnt_check_availability:
    PUSH {r6}
    SUB sp, #4  // alloc space for (x,y) on stack
    MOV r6, sp

    STRH r0, [r6]  // PUSH as HWORD r0 := new head x
    STRH r1, [r6, #2]  // PUSH as HWORD r1 := new head y
    // I.E: push newhead.(x,y) onto stack

    BL coord_to_grid_idx  // get newhead's grid coord
    LDRB r1, [r5, r0]  // r1 = r5[r0] = grid[newhead grid idx]
    CMP r1, #CELL_SNAKE
    BEQ .Lhndlmvmnt_hit_self  // if snake collided with self
    CMP r1, #CELL_APPLE
    BEQ .Lhndlmvmnt_eat_apple
.Lhndlmvmnt_ok:

    LDR r0, [r4, #4]  // r0 = LL->tail = tail
    LDRH r1, [r0, #2]  // r1 = tail->y
    LDRH r0, [r0]  // r0 = tail->x
    
    BL coord_to_grid_idx  // CALL: coord_to_grid_idx(tail->x, tail->y)
    MOV r1, #CELL_EMPTY
    STRB r1, [r5, r0]  // Overwrite previous tail cell with blank cell as snake advanced to new head location
     
    LDRH r0, [r6]  // r0 = newhead.x
    LDRH r1, [r6, #2] // r1 = newhead.y
    MOV r2, r4  // r2 = LL
    BL snake_move  // CALL: snake_move(newhead.x, newhead.y, LL) : update snake linked list
    // Now, LL updated. We advanced the tail on buffer. Now just need to do the same for the head
    LDRH r0, [r6]
    LDRH r1, [r6, #2]
    ADD sp, #4  // After this, we're done with newhead.(x,y), so dealloc it from stack
    POP {r6}  // and pop r6 off stack too
    
    BL coord_to_grid_idx  // CALL: coord_to_grid_idx(newhead.x, newhead.y) 
    // now, r0 = new head's grid index
    MOV r1, #CELL_SNAKE
    STRB r1, [r5, r0]  // r5[r0] = r1 : grid[new head index] = CELL_SNAKE (=1)
    
    // Aaand we're finally done with writing this god-foresaken function.
    // Can simply pop the shit we had to save off stack return

    POP {r4, r5}
    POP {r1}
    MOV r0, #HNDL_MVMNT_OK
    BX r1
.Lhndlmvmnt_eat_apple:
    MOV r1, #CELL_SNAKE
    STRB r1, [r5, r0]  // update grid cell w/ new head
    LDRH r0, [r6]  // get newhead.x back off stack into r0
    LDRH r1, [r6, #2]  // same w/ newhead.y
    ADD sp, #4  // dealloc newhead.(x,y) off stack
    POP {r6}
    
    MOV r2, r4  // put LL into r2

    BL snake_grow  // CALL: snake_grow(newhead.x, newhead.y, LL)
    
    POP {r4, r5}
    POP {r1}
    MOV r0, #HNDL_MVMNT_APPLE_COLLECTED
    BX r1
.Lhndlmvmnt_hit_self:
    ADD sp, #4  // dealloc new head coords off stack
    POP {r6}
.Lhndlmvmnt_hit_wall:
    POP {r4, r5}
    POP {r1}
    MOV r0, #0
    SUB r0, #1  // If game over collision, make r0 = RETURN VALUE = -1
    BX r1

    .size handle_movement, .-handle_movement


#define KEY_LEFT 32
#define KEY_DOWN 128
#define KEY_UP 64
#define KEY_RIGHT 16
#define KEY_START 8
#define KEY_SEL 4

    .thumb_func
    .align 2
    .global handle_input
    .type handle_input %function
handle_input:
    // r0 = key reg state, r1 = current direction
    MOV r2, #KEY_START
    AND r2, r0  // r3 = r0&r2 = REG_KEY&KEY_START
    
    CMP r2, #0
    BNE .Lhndlinput_no_pause

    MOV r0, #0
    SUB r0, #1 // return value = -1 means pause requested
    BX lr
.Lhndlinput_no_pause:
    CMP r1, #CURR_DIR_U
    BGE .Lhndlinput_upper_dircheck
    CMP r1, #CURR_DIR_L
    BEQ .Lhndlinput_DIR_R_or_L
    B .Lhndlinput_DIR_U_or_D
.Lhndlinput_upper_dircheck:
    BNE .Lhndlinput_DIR_R_or_L
.Lhndlinput_DIR_U_or_D:
    MOV r2, #KEY_LEFT
    MOV r3, #KEY_RIGHT
    ORR r2, r3  // r2 = KEY_LEFT|KEY_RIGHT
    MOV r3, r2  // r3 = KEY_LEFT|KEY_RIGHT, too
    AND r3, r0  // r3 = REG_KEY&(KEY_LEFT|KEY_RIGHT)
    CMP r3, r2
    // If REG_KEY&(KEY_LEFT|KEY_RIGHT) == (KEY_LEFT|KEY_RIGHT), then
    // neither left nor right are being pressed. No direction change,
    // return param 2: r1=current dir.
    BEQ .Lhndlinput_no_change
    MOV r2, #KEY_RIGHT
    AND r2, r0
    CMP r2, #0
    BEQ .Lhndlinput_change_R
    MOV r0, #CURR_DIR_L
    BX lr
.Lhndlinput_change_R:
    MOV r0, #CURR_DIR_R
    BX lr
    
.Lhndlinput_DIR_R_or_L:
    MOV r2, #KEY_DOWN
    MOV r3, #KEY_UP
    ORR r2, r3  // r2 = KEY_DOWN|KEY_UP
    MOV r3, r2  // r3 = r2 = K_DOWN|K_UP
    AND r3, r0  // r3 = REG_KEY&(KEY_DOWN|KEY_UP)
    CMP r3, r2
    // If REG_KEY&(KEY_DOWN|KEY_UP) == (KEY_DOWN|KEY_UP), then
    // neither down nor up are being pressed. No direction change,
    // return param 2: r1=current dir.
    BEQ .Lhndlinput_no_change
    MOV r2, #KEY_UP
    AND r2, r0
    CMP r2, #0
    BEQ .Lhndlinput_change_U
    MOV r0, #CURR_DIR_D
    BX lr
.Lhndlinput_change_U:
    MOV r0, #CURR_DIR_U
    BX lr

.Lhndlinput_no_change:
    MOV r0, r1  // return current direction
    BX lr
    
    .size handle_input, .-handle_input

#define GAME_SPEED_FIELD_MIN 1
#define GAME_SPEED_FIELD_MAX 4

    .thumb_func
    .align 2
    .global pause
    .type pause %function
    // r0 = speed
    // r1 = color scheme
pause:
    PUSH {r4-r7, lr}
    MOV r4, r0
    MOV r7, r1
.Lpause_debounceloop:
        BL poll_keys
        MOV r1, #KEY_START
        AND r1, r0
        CMP r1, #0
        BEQ .Lpause_debounceloop
.Lpause_waitloop_redraw:
    // For pause menu,
    // clear screen with fast_memset32(VRAM, 0, <<VRAM screen buffer word count>>)
    MOV r0, #0xC0
    LSL r0, #19  // r0 = VRAM start addr
    CMP r7, #0
    BNE .Lpause_clear_not0
    MOV r1, #0
    B .Lpause_clear
.Lpause_clear_not0:
    MOV r1, #0x73
    MOV r3, #0x1E
    LSL r3, #8
    ORR r1, r3
    LSL r3, r1, #16
    ORR r1, r3
.Lpause_clear:
    MOV r3, #80  // logic behind this part explained in block above free_snake_nodes call @ game over code
    LSL r2, r3, #4
    SUB r2, r3
    LSL r2, #4
    LDR r3, =fast_memset32
    BL .Llong_call_via_r3

    LDR r0, =PAUSE_PROMPT
    MOV r1, #8
    CMP r7, #0
    BNE .Lpause_draw_prompt_not0
    MOV r2, #0x7F
    MOV r3, #0xFF
    LSL r2, #8
    ORR r3, r2
    B .Lpause_draw_prompt
.Lpause_draw_prompt_not0:
    MOV r2, #0x04
    MOV r3, #0xA3
    LSL r2, #8
    ORR r3, r2
.Lpause_draw_prompt:
    MOV r2, #32
    BL Mode3_puts

    MOV r5, r0  // r5 = speed text x start pos
    MOV r6, r1  // r6 = speed text y start pos
    MOV r2, r1
    MOV r1, r0
    MOV r0, #5
    SUB r0, r4
    ADD r0, #'0'
    CMP r7, #0
    BNE .Lpause_draw_speed_not0
    MOV r3, #0x7F
    LSL r3, #8
    ADD r3, #0xFF
    B .Lpause_draw_speed
.Lpause_draw_speed_not0:
    MOV r3, #0x04
    LSL r3, #8
    ADD r3, #0xA3
.Lpause_draw_speed:
    BL Mode3_putchar

    
    
    
        
.Lpause_waitloop:
        BL poll_keys
        MOV r1, #KEY_START
        AND r1, r0
        CMP r1, #0
        BEQ .Lpause_debounceloop2

        MOV r1, #KEY_SEL
        AND r1, r0
        CMP r1, #0
        BNE .Lpause_no_colorscheme_cycle
.Lpause_wait_debounce_sel:
            BL poll_keys
            MOV r1, #KEY_SEL
            AND r1, r0
            CMP r1, #0
            BEQ .Lpause_wait_debounce_sel
        CMP r7, #0
        BEQ .Lpause_colorscheme0
        MOV r7, #0
        B .Lpause_waitloop_redraw
.Lpause_colorscheme0:
        MOV r7, #1
        B .Lpause_waitloop_redraw

.Lpause_no_colorscheme_cycle:
        MOV r1, #KEY_UP
        MOV r2, #KEY_DOWN
        ORR r2, r1  // r2 = UP|DOWN
        MOV r3, r2  // r3 = UP|DOWN
        AND r2, r0  // r2 = (UP|DOWN)&REG_KEY
        CMP r2, r3  // Mask&REG_KEY unchanged means no masked key pressed, otherwise it's zero.
        BEQ .Lpause_waitloop  // so if Mask&REG_KEY  == Mask, then neither UP or DOWN is pressed
        CMP r2, #KEY_UP  // If mask&reg == UP, then UP mask field unchanged, and DOWN was cleared,
                         // so DOWN must be pressed
        BEQ .Lpause_waitloop_DOWN
.Lpause_waitloop_UP:
            BL poll_keys  // Debounce key press
            MOV r1, #KEY_UP
            AND r1, r0
            CMP r1, #0
            BEQ .Lpause_waitloop_UP
        CMP r4, #GAME_SPEED_FIELD_MIN+1
        BGE .Lpause_waitloop_can_speedup
        B .Lpause_waitloop
.Lpause_waitloop_can_speedup:
        MOV r0, #5
        SUB r0, r4
        ADD r0, #'0'
        MOV r1, r5
        MOV r2, r6
        CMP r7, #0
        BNE .Lpause_waitloop_redrawspeed_erase_not0
        MOV r3, #0
        B .Lpause_waitloop_redrawspeed_erase
.Lpause_waitloop_redrawspeed_erase_not0:
        MOV r3, #0x1E
        LSL r3, #8
        ADD r3, #0x73
.Lpause_waitloop_redrawspeed_erase:
        BL Mode3_putchar  // erase last speed

        SUB r4, #1  // inc speed

        MOV r0, #5
        SUB r0, r4
        ADD r0, #'0'
        MOV r1, r5
        MOV r2, r6
        CMP r7, #0
        BNE .Lpause_wait_redrawspeed_not0
        MOV r3, #0x7F
        LSL r3, #8
        ADD r3, #0xFF
        B .Lpause_wait_redrawspeed
.Lpause_wait_redrawspeed_not0:
        MOV r3, #0x04
        LSL r3, #8
        ADD r3, #0xA3
.Lpause_wait_redrawspeed:
        BL Mode3_putchar  // write new speed
        B .Lpause_waitloop
        
.Lpause_waitloop_DOWN:
            BL poll_keys  // Debounce key press
            MOV r1, #KEY_DOWN
            AND r1, r0
            CMP r1, #0
            BEQ .Lpause_waitloop_DOWN
        CMP r4, #GAME_SPEED_FIELD_MAX
        BGE .Lpause_waitloop
        MOV r0, #5
        SUB r0, r4
        ADD r0, #'0'
        MOV r1, r5
        MOV r2, r6
        CMP r7, #0
        BNE .Lpause_wait_redrawspeed_erase2_not0
        MOV r3, #0
        B .Lpause_wait_redrawspeed_erase2
.Lpause_wait_redrawspeed_erase2_not0:
        MOV r3, #0x1E
        LSL r3, #8
        ADD r3, #0x73
.Lpause_wait_redrawspeed_erase2:
        BL Mode3_putchar  // erase last speed

        ADD r4, #1  // dec speed
        
        MOV r0, #5
        SUB r0, r4
        ADD r0, #'0'
        MOV r1, r5
        MOV r2, r6
        CMP r7, #0
        BNE .Lpause_wait_redrawspeed2_not0
        MOV r3, #0x7F
        LSL r3, #8
        ADD r3, #0xFF
        B .Lpause_wait_redrawspeed2
.Lpause_wait_redrawspeed2_not0:
        MOV r3, #4
        LSL r3, #8
        ADD r3, #0xA3
.Lpause_wait_redrawspeed2:
        BL Mode3_putchar  // write new speed
        B .Lpause_waitloop
        
.Lpause_debounceloop2:
        BL poll_keys
        MOV r1, #KEY_START
        AND r1, r0
        CMP r1, #0
        BEQ .Lpause_debounceloop2
    
    MOV r0, #5
    SUB r0, r4
    ADD r0, #'0'
    MOV r1, r5
    MOV r2, r6
    CMP r7, #0
    BNE .Lpause_erase_speed_not0
    MOV r3, #0
    B .Lpause_erase_speed
.Lpause_erase_speed_not0:
    MOV r3, #0x1E
    LSL r3, #8
    ADD r3, #0x73
.Lpause_erase_speed:
    BL Mode3_putchar  // erase last speed

    LDR r0, =PAUSE_PROMPT
    MOV r1, #8
    CMP r7, #0
    BNE .Lpause_eraseprompt_not0
    MOV r3, #0
    B .Lpause_eraseprompt
.Lpause_eraseprompt_not0:
    MOV r3, #0x73
    MOV r2, #0x1E
    LSL r2, #8
    ORR r3, r2
.Lpause_eraseprompt:
    MOV r2, #32
    BL Mode3_puts  // erase prompt


    MOV r0, r4
    MOV r1, r7
    POP {r4-r7}
    POP {r3}
    BX r3



    .size pause, .-pause
    
    

    .thumb_func
    .align 2
    .global spawn_new_apple
    .type spawn_new_apple %function
spawn_new_apple:
    // r0 = grid
    PUSH {r4, lr}
    MOV r4, r0
.Lsnewapple_find_empty_grid_idx:
        BL rand_grid_idx
        // Now r0 = lfsr_rand()%2400 = random grid spot for next apple.
        // but first gotta make sure that the spot is vacant
        LDRB r1, [r4, r0]  // r1 = r4[r0] = grid[rand()%2400]
        CMP r1, #CELL_EMPTY
        BNE .Lsnewapple_find_empty_grid_idx  // If they are same, get new random idx.
    // Now, r0 has new apple idx
    MOV r1, #CELL_APPLE
    STRB r1, [r4, r0]  // r4[r0] = r1 : grid[random empty idx] = apple

    POP {r4}
    POP {r1}

    BX r1

    .size spawn_new_apple, .-spawn_new_apple

    .thumb_func
    .align 2
    .global init_sound
    .type init_sound %function
init_sound:
    
    PUSH {lr}
    BL sound_DSnDMG_control_init
    
    MOV r0, #0
    MOV r1, #1
    MOV r2, #0
    
    BL sound_sq1_sweep_set
    MOV r0, #48
    MOV r1, #2  // Duty 1/2
    MOV r2, #7  // Envelope Shift Step Time
    MOV r3, #4  // Init vol. 12
    PUSH {r3}
    MOV r3, #0
    BL sound_sq1_cnt_set
    ADD sp, #4

    MOV r0, #0
    MOV r1, #7
    MOV r2, #1
    MOV r3, #8
    BL sound_noise_cnt_set

    POP {r3}
    
    BX r3

    .size init_sound, .-init_sound

    .section .iwram,"ax", %progbits
    .arm
    .align 2
    .global fast_memcpy32
    .type fast_memcpy32 %function
fast_memcpy32:
    // r0 dest, r1 src, r2 word ct
    AND r12, r2, #7  // r12 = word_ct % 8
    LSRS r2, #3
    BEQ .Lfmcpy_remainder
    PUSH {r4-r10}
.Lfmcpy_blocks:
        LDMIA r1!, {r3-r10}
        STMIA r0!, {r3-r10}
        SUBS r2, #1
        BNE .Lfmcpy_blocks
    POP {r4-r10}
.Lfmcpy_remainder:
        SUBS r12, #1
        LDRCS r3, [r1], #4
        STRCS r3, [r0], #4
        BCS .Lfmcpy_remainder
    BX lr
    .size fast_memcpy32, .-fast_memcpy32

    .arm
    .align 2
    .global fast_memset32
    .type fast_memset32 %function
fast_memset32:
    // r0 dest, r1 fill val, r2 word ct
    AND r12, r2, #7  // r12 = word_ct % 8
    LSRS r2, #3
    BEQ .Lfmcpy_remainder
    PUSH {r4-r9}
    MOV r3, r1
    MOV r4, r1 
    MOV r5, r1
    MOV r6, r1 
    MOV r7, r1
    MOV r8, r1 
    MOV r9, r1
.Lfmset_blocks:
        STMIA r0!, {r1, r3-r9}
        SUBS r2, #1
        BNE .Lfmset_blocks
    POP {r4-r9}
.Lfmset_remainder:
        SUBS r12, #1
        STRCS r1, [r0], #4
        BCS .Lfmset_remainder
    BX lr
    .size fast_memset32, .-fast_memset32
    
    .arm
    .align 2
    .global isr_callback
    .type isr_callback %function
isr_callback:
    MOV r0, #0x80
    MOV r0, r0, LSL #19  // r0 = 0x04000000
    LDR r1, [r0, #0x200]!  // Get REG_IE and REG_IF in one go since they're contiguous in mem
    AND r1, r1, LSR #16  // This ANDs REG_IE and REG_IF, since first 16b are REG_IE and the 2nd 16b are REG_IF
    STRH r1, [r0, #0x2]  // Write to REG_IF to ack IRQ
    LDR r2, [r0, #-0x208]  // get REG_IFBIOS
    ORR r2, r1  // OR REG_IE&REG_IF with REG_IFBIOS
    STR r2, [r0, #-0x208]  // Ack for REG_IFBIOS, too

    BX lr
    .size isr_callback, .-isr_callback
  
    

// FUNCTION: main
	.section	.text.startup,"ax",%progbits
    .thumb_func
    .align 2
    .global main
    .type main %function
main:
    
    MOV r0, #0x80
    MOV r1, r0
    LSL r0, #19  // #0x80<<19 = 0x04000000
    
    MOV r2, #3
    LSL r1, r2
    ORR r1, r2
    STR r1, [r0]  // Set video modes: Mode3 w/ BG2

    MOV r1, #8
    STRH r1, [r0, #4]  // Enable vblank IRQ trigger in display stat register
    
    LDR r1, =isr_callback
    SUB r0, #4
    STR r1, [r0]
    
    // So, now, r0 is 0x04000000 - 4
    // Still need to set REG_IE and REG_IME, which are 0x04000000 + (0x200 and 0x208) respectively
    MOV r2, #0x81  // r2 = 129
    LSL r2, #2  // r2 = 129*4 = (128+1)*4 = 512+4 = 0x200+0x004 = 0x204
    ADD r0, r2  // r0 = 0x04000000 - 0x004 + 0x204 = 0x04000000 + 0x200
    MOV r1, #1  // r1 = VBlank IRQ enable flag = 1<<0
    STRH r1, [r0]  // Enable receiving VBL IRQs in REG_IE

    STRH r1, [r0, #8]  // Flip IRQ Master enable switch

    LDR r0, =INITED_LFSR
    LDR r0, [r0]
    CMP r0, #0
    BEQ .Lmain_prompt_red


    LDR r0, =START_PROMPT
    MOV r1, #70
    MOV r2, #0x7F
    LSL r2, #8
    MOV r3, #0xFF
    ORR r3, r2
    MOV r2, #76 
    BL Mode3_puts
    B .Lmain_skip_redprompt

.Lmain_prompt_red:
    LDR r0, =START_PROMPT
    MOV r1, #70
    MOV r2, #76 
    MOV r3, #31
    BL Mode3_puts

.Lmain_skip_redprompt:
    LDR r0, =INITED_LFSR
    LDR r0, [r0]
    CMP r0, #0
    BNE .Lmain_skip_lfsr_init

    LDR r0, =RNG_Seed
    LDRH r0, [r0]
    MOV r1, #10
    MOV r2, #11
    BL lfsr_init
.Lmain_skip_lfsr_init:
    BL init_sound
    PUSH {r4-r7}
    
.Lmain_wait_for_start:
        BL poll_keys
        MOV r1, #8  // 8 = keypad bitfield value for start btn
        AND r0, r1
        CMP r0, #0
        BNE .Lmain_wait_for_start

    LDR r0, =START_PROMPT
    MOV r1, #70
    MOV r2, #76 
    MOV r3, #0
    BL Mode3_puts

    /*BL lfsr_rand
    MOV r1, #150
    LSL r1, #4
    BL __aeabi_uidivmod
    // Remember: With __aeabi_uidivmod, r0 holds quotient and r1 holds remainder upon return
    MOV r0, r1  // Therefore, move value from r1 into r0, since we want rand()%2400, not rand()/2400
    */

    LDR r0, =GRID_A
    BL snake_init
    MOV r5, r0  // r5 = snake LL

.Lmain_find_empty_for_apple:
        BL rand_grid_idx
        // Now r0 = lfsr_rand()%2400 = apple's random start spot.
        // but first gotta make sure that the spot is vacant

        // r1 = snake head's init start grid idx::
        MOV r1, #128
        LSL r1, #3  // r1 <<= 3 = (1<<7)<<3 = 1<<10 = 1024
        ADD r1, #186  // r1 = 1024 + (1210-1024=186)
        CMP r0, r1  // Check random apple spot isn't same as snake head's initial spot
        BEQ .Lmain_find_empty_for_apple  // If they are same, get new random idx.
        SUB r1, #1  // --r1 : the snake tail's init start grid idx
        CMP r0, r1  // Check rand idx isn't same as snake tails init spot
        BEQ .Lmain_find_empty_for_apple  // If they are the same, get new random idx

    LDR r1, =GRID_A
    MOV r2, #CELL_APPLE
    STRB r2, [r1, r0]
    MOV r0, r1
    LDR r1, =GRID_B
    MOV r2, #0
    BL draw_grid
    LDR r6, =GRID_B  // r6 = front buffer.
    LDR r7, =GRID_A  // r7 = back buffer.
    MOV r0, #0
    PUSH {r0}  // second-to-top = color scheme
    MOV r0, #4
    PUSH {r0}  // stack top = game speed
    MOV r4, #CURR_DIR_R  // r4 = current direction
    BL vsync
    B .Lmain_first_pass_loop  // skip input polling for first pass so that 
    //                           for each value assignment of r4=current direction,
    //                           handle_movement called **at least once**.
.Lmain_inf_loop:
        PUSH {r4,r5}
        LDR r4, [sp, #8]
        MOV r5, #0
.Lmain_vsyncs_loop:
            BL vsync
            ADD r5, #1
            CMP r5, r4
            BLT .Lmain_vsyncs_loop
        POP {r4,r5}
        BL poll_keys
        // r0 = ret from poll_keys = REG_KEY state
        MOV r1, r4  // r1 = mvmnt direction
        BL handle_input
        MOV r1, #0
        SUB r1, #1
        CMP r0, r1
        BNE .Lmain_no_pause

        LDR r0, [sp]
        LDR r1, [sp,#4]
        BL pause
        STR r0, [sp]
        STR r1, [sp, #4]
        MOV r0, r6
        LDR r1, [sp, #4]
        BL unpause_redraw_grid
        B .Lmain_first_pass_loop  // Skip the next part, since no direction 
        //                           flag values are -1, so running what's below
        //                           would cause a soft-locking error as r4 will
        //                           always be set to -1 in this scenario.
.Lmain_no_pause:
        CMP r0, r4
        BEQ .Lmain_first_pass_loop  // Name irrelevant, it just so happens that 
        //                             the first pass loop label is exactly where
        //                             I would want to jump to when r4 == r0.
        //                             If they !=, then update r4 w/ new direction
        
        MOV r4, r0  // If direction change, update r4 accordingly
.Lmain_first_pass_loop:
        MOV r0, r4  // r0 = mvmnt direction
        MOV r1, r5  // r1 = Snake body LL
        MOV r2, r6  // r2 = grid
        BL handle_movement
        CMP r0, #HNDL_MVMNT_OK
        BLT .Lmain_gameover
        BEQ .Lmain_drawgrid
        mov r0, #RATE_D
        mov r1, #4
        BL sound_sq1_play
        MOV r0, r6
        BL spawn_new_apple
        MOV r0, #RATE_FIS
        MOV r1, #3
        BL sound_sq1_play

.Lmain_drawgrid:
        MOV r0, r6  // r0 = front buf
        MOV r1, r7  // r1 = back buf
        LDR r2, [sp, #4]

        BL draw_grid
        MOV r0, r6  // temporarily put front buf's addr in r0
        MOV r6, r7  // then swap out back buf's addr into front buf ptr, r6
        MOV r7, r0  // Move back old fb, tmp'd in r0, into bb slot.

        B .Lmain_inf_loop
.Lmain_gameover:
    ADD sp, #4  // deallocate game speed var off stack top
    MOV r0, #2
    MOV r1, #1
    MOV r2, #5
    MOV r3, #1
    BL sound_noise_play
    
    LDR r0, =GRID_A
    MOV r1, #0
    MOV r2, #128
    LSL r2, #2
    ADD r2, #88
    LDR r3, =fast_memset32
    BL .Llong_call_via_r3

    LDR r0, =GRID_B
    MOV r1, #0
    MOV r2, #128
    LSL r2, #2
    ADD r2, #88
    LDR r3, =fast_memset32
    BL .Llong_call_via_r3
    
    MOV r0, #0xC0  // 192
    LSL r0, #0x13  // 19
    MOV r1, #0
    // Word ct:
    // 240x160 = VRAM pixel buffer dims when in Mode 3
    // and each pixel is an HWORD Mode 3, so that means
    // so (240x160)HWORDS * 0.5 WORDS/HWORD = (240X160)>>1 WORDS
    // 240x160>>1 = 240X80 = 80*15*16 = (80*(16-1)) * 16 = (80*16 - 80)*16 = ((80<<4)-80)<<4
    MOV r3, #80
    LSL r2, r3, #4  // r2 = r3<<4 = 80<<4
    SUB r2, r3  // r2 -= r3 : r2 = 80<<4 - 80
    LSL r2, #4
    LDR r3, =fast_memset32
    BL .Llong_call_via_r3

    BL free_snake_nodes
    LDR r0, =INITED_LFSR
    MOV r1, #1
    STR r1, [r0]
    POP {r4-r7}
    B main
.Llong_call_via_r3:
    BX r3
    .size main, .-main
