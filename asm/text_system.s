#define VERDANA_GLYPH_HEIGHT 12
#define VERDANA_GLYPH_COUNT 96

// Use for offsetting
#define VERDANA_FIRST_CHAR ' '

#define VERDANA_CELL_WIDTH 8
#define VERDANA_CELL_HEIGHT 16

// Cell size = byte size of a font glyph cell (for offsetting)
#define VERDANA_CELL_SIZE 16

.extern verdana_GlyphData
.extern verdana_GlyphWidths

    .text
    .thumb_func
    .align 2
    .global Mode3_putchar
    .type Mode3_putchar %function
Mode3_putchar:
    // r0 char
    // r1 x
    // r2 y
    // r3 color
    SUB r0, #VERDANA_FIRST_CHAR
    CMP r0, #95  // verdana glyph count minus 1 bc might as well skip ascii(DEL) since it's just a whitespace char
    BGE .Lm3putchar_r0_oob_or_whitespace
    CMP r0, #0  // skip 0 idx because 0 is space idx
    BEQ .Lm3putchar_whitespace
    BLT .Lm3putchar_r0_oob
    PUSH {r4-r7}
    MOV r4, r0

    MOVS r0, r2  //  r0 = r2 = y
    BEQ .Lm3putchar_skip_y_ofs
    LSL r2, #4  // r2 = y*16
    SUB r2, r0  // r2 = y*16-y = y*15
    LSL r2, #4  // r2 = y*15*16 = y*240
    ADD r1, r2  // r1 = x + y*240
.Lm3putchar_skip_y_ofs:
    LSL r1, #1 // r1 = (x+y*240)*sizeof(mode 3 pixel):=2Byte
    MOV r0, #192  // r0 = 0xC0
    LSL r0, #19  // r0 = 0xC0<<19 = 0x06000000 = &VRAM
    
    ORR r1, r0  // r1 = &VRAM + (x,y start point as vram offset)
    
    // NOW: free regs: r0, r2, r4-r7, r12.
    //      used regs: r1 : draw start addr, r4 : glyph idx, r3 : color 
    LDR r0, =verdana_GlyphData
    LSL r2, r4, #4  // r2 = glyph_idx*16 = glyph index * data index offset multiplier
    ADD r0, r2  // r0 = font data addr + glyph data offset = glyph data addr
    LDR r2, =verdana_GlyphWidths
    ADD r2, r4  // r2 = &glyph_widths + glyph idx = &(current glyph width)
    LDRB r2, [r2]  // r2 = curr glyph width
    // NOW: Free: r4-r7, r12
    LSL r2, #1  // r2 = 2*width
    MOV r12, r2  // r12 now has 2*width instead; freeing up r2
    MOV r2, #0
    B .Lm3putcharLoop_Y_FirstPass
.Lm3putcharLoop_Y:
        MOV r4, #240
        LSL r4, #1
        ADD r1, r4
.Lm3putcharLoop_Y_FirstPass:
        MOV r4, #0
        MOV r5, #1
        LDR r6, [r0]
.Lm3putcharLoop_X:
            MOV r7, r6
            AND r7, r5
            CMP r7, #0
            BEQ .Lm3putchar_pixelSkip
            STRH r3, [r1, r4]
.Lm3putchar_pixelSkip:
            ADD r4, #2
            LSL r5, #1
            CMP r4, r12
            BNE .Lm3putcharLoop_X
        ADD r2, #1
        ADD r0, #1
        CMP r2, #VERDANA_GLYPH_HEIGHT
        BLT .Lm3putcharLoop_Y


    POP {r4-r7}
    MOV r0, r12
    LSR r0, #1
    BX lr

.Lm3putchar_whitespace:
    LDR r0, =verdana_GlyphWidths
    LDRB r0, [r0]
    BX lr
.Lm3putchar_r0_oob_or_whitespace:
    BEQ .Lm3putchar_whitespace
.Lm3putchar_r0_oob:
    MOV r0, #0
    SUB r0, #1
    BX lr
    .size Mode3_putchar, .-Mode3_putchar


    .thumb_func
    .align 2
    .global Mode3_puts
    .type Mode3_puts %function
Mode3_puts:
    // r0: string addr r1: x r2: y r3: color
    PUSH {r4-r6, lr}
    MOV r4, r0  // str addr
    MOV r5, r1  // x
    MOV r6, r2  // y
    ADD r2, #VERDANA_GLYPH_HEIGHT
    CMP r2, #160
    BGE .Lm3puts_cursor_ovf
    MOV r2, r6
    ADD r1, #VERDANA_CELL_WIDTH
    CMP r1, #240
    BGE .Lm3puts_cursor_ovf
    MOV r1, r5
    PUSH {r5}  // push r5=x:= START_X onto stack
    LDRB r0, [r4]
    CMP r0, #0
    BEQ .Lm3puts_nullterminator_reached
    B .Lm3puts_strloop
.Lm3puts_newline:
        LDR r5, [sp]
        ADD r6, #VERDANA_GLYPH_HEIGHT
        CMP r6, #160
        BGE .Lm3puts_cursor_ovf
        MOV r1, r5
        MOV r2, r6
.Lm3puts_strloop:
        BL Mode3_putchar
        ADD r4, #1  // advance string pointer
        // (Would normally put color back into r3 here, but r3 is intact from putchar function
        ADD r5, r0  // add prev char width (ret'd by putchar) to x coord.
        CMP r5, #240
        BGE .Lm3puts_newline
        MOV r1, r5
        MOV r2, r6
        LDRB r0, [r4]
        CMP r0, #0
        BNE .Lm3puts_strloop
        CMP r0, #'\n'
        BEQ .Lm3puts_newline
.Lm3puts_nullterminator_reached:
    ADD sp, #4  // dont bother wasting time from memory fetching by popping START_X off stack.
                // we just need to dealloc it; don't care about its contents.
    MOV r0, #0
    POP {r4-r6}
    POP {r3}
    BX r3
.Lm3puts_cursor_ovf:
    MOV r0, #0
    SUB r0, #1
    POP {r4-r6}
    POP {r3}
    BX r3
    
    .size Mode3_puts, .-Mode3_puts
