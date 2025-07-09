#define VERDANA_GLYPH_HEIGHT 12
#define VERDANA_GLYPH_COUNT 96

// Use for offsetting
#define VERDANA_FIRST_CHAR ' '

#define VERDANA_CELL_WIDTH 8
#define VERDANA_CELL_HEIGHT 16

// Cell size = size, in bytes, of a font glyph cell (for offsetting)
#define VERDANA_CELL_SIZE 16

#define SCREEN_WIDTH 240
#define SCREEN_HEIGHT 160

#define VERDANA_HEXGLYPH_WIDTH 6

.macro BIOS_DIV_THUMB dividend, divisor
    MOV r0, \dividend
    MOV r1, \divisor
    SVC #0x06
.endm

.macro BIOS_DIV_ARM dividend, divisor
    MOV r0, \dividend
    MOV r1, \divisor
    SVC #0x060000
.endm

.extern verdana_GlyphData
.extern verdana_GlyphWidths



    .text
    .thumb_func
    .align 2
    .global Mode3_Putchar
    .type Mode3_Putchar %function
Mode3_Putchar:
    // r0 char
    // r1 x
    // r2 y
    // r3 color
    MOV r12, r0
    MOV r0, #VERDANA_CELL_HEIGHT
    ADD r0, r0, r2  // r0:= VERDANA_CELL_HEIGHT + y
    CMP r0, #SCREEN_HEIGHT
    BGT .Lm3putchar_invalid_arg  // if 0 > r0, then return bc hit screen bottom

    MOV r0, r12
    CMP r0, #'\t'
    BEQ .Lm3putchar_whitespace
    SUB r0, #VERDANA_FIRST_CHAR
    CMP r0, #(VERDANA_GLYPH_COUNT - 1)  // count  - 1 bc might as well skip
                                        // ascii(DEL) since it's just a
                                        // whitespace char
    BGE .Lm3putchar_invalid_arg

    CMP r0, #0  // skip 0 idx because 0 is space idx
    BEQ .Lm3putchar_whitespace
    BLT .Lm3putchar_invalid_arg
    
    PUSH { r4-r7 }
    MOV r4, r0  // r4:=r0:=char - VERDANA_FIRST_CHAR:=' '
    LDR r0, =verdana_GlyphWidths  // r0:=glyph_Widths::uint8_t[]
    ADD r0, r0, r4  // r0:=(&glyph_Widths[char - VERDANA_FIRST_CHAR])::uint8_t*
    LDRB r0, [r0]  // r0:=*r0:=glyph_Widths[char - VERDANA_FIRST_CHAR]::uint8_t
    MOV r12, r0  // r12:=r0:=glyph_Widths[char-' ']=:GLYPH_WIDTH(char)::uint8_t
    ADD r0, r0, r1  // r0:= GLYPH_WIDTH(char) + x
    CMP r0, #SCREEN_WIDTH
    BGT .Lm3putchar_hit_scrn_edge_postpush

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
    
    // NOW: free regs) r0, r2, r5-r7
    //      used regs) r1 : draw start addr, r4 : glyph idx, r3 : color, 
    //                 r12 : temporarily holding GLYPH_WIDTH(char)
    LDR r0, =verdana_GlyphData
    LSL r2, r4, #4  // r2 = glyph_idx*16 = glyph index * glyph cell byte size
    ADD r0, r2  // r0 = font data addr + glyph data offset = glyph data addr
    MOV r2, r12  // r2:=GLYPH_WIDTH(char)
    // NOW: Free) r4, r5, r6, r7, r12
    //      Used) r0 : glyph data addr, r1 : draw start addr, r2 : glyph width,
    //            r3 : draw color

    LSL r2, #1  // r2 = 2*width
    MOV r12, r2  // r12 now has 2*width instead; freeing up r2
    MOV r2, #0
    B .Lm3putcharLoop_Y_FirstPass
.Lm3putcharLoop_Y:
        MOV r4, #SCREEN_WIDTH
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

.Lm3putchar_hit_scrn_edge_whitespace:
    MOV r0, #1
    LSL r0, r0, #31
    BX lr
.Lm3putchar_hit_scrn_edge_postpush:
    POP { r4-r7}
.Lm3putchar_hit_scrn_edge:
    MOV r0, #0
    BX lr
.Lm3putchar_whitespace:
    // already checked y is valid, so can just repurpose r2 for 
    // GLYPH_WIDTH[r0:=(' ' or '\t')::char]::uint8_t
    LDR r2, =verdana_GlyphWidths
    LDRB r2, [r2]
    CMP r0, #'\t'
    BNE .Lm3putchar_whitespace_got_width
    LSL r2, r2, #2  // r2:=GLYPH_WIDTH[' ']*4:=WIDTH('\t')
.Lm3putchar_whitespace_got_width:
    ADD r1, r1, r2  // r1:= x + WIDTH(r0:=charparam::char)
    CMP r1, #SCREEN_WIDTH
    BGT .Lm3putchar_hit_scrn_edge_whitespace
.Lm3putchar_return_whitespace:
    MOV r0, r2  // r0:=r2:=WIDTH(char)
    BX lr
.Lm3putchar_invalid_arg:
    MOV r0, #0
    MVN r0, r0
    BX lr
    .size Mode3_Putchar, .-Mode3_Putchar



    .thumb_func
    .align 2
    .global Mode3_Puts
    .type Mode3_Puts %function
Mode3_Puts:
    // r0: string addr r1: x r2: y r3: color
    PUSH {r4-r7, lr}
    MOV r4, r0  // str addr
    MOV r5, r1  // x
    MOV r6, r2  // y
    ADD r2, #VERDANA_GLYPH_HEIGHT
    CMP r2, #SCREEN_HEIGHT
    BGE .Lm3puts_cursor_ovf
    MOV r2, r6
    ADD r1, #VERDANA_CELL_WIDTH
    CMP r1, #SCREEN_WIDTH
    BGE .Lm3puts_cursor_ovf
    MOV r1, r5
    MOV r7, r5
    LDRB r0, [r4]
    CMP r0, #0
    BEQ .Lm3puts_nullterminator_reached
    B .Lm3puts_strloop
.Lm3puts_newline:
        MOV r5, r7
        ADD r6, #VERDANA_GLYPH_HEIGHT
        CMP r6, #SCREEN_HEIGHT
        BGE .Lm3puts_cursor_ovf
        MOV r1, r5
        MOV r2, r6
.Lm3puts_strloop:
        BL Mode3_Putchar
        ADD r4, #1  // advance string pointer
        // (Would normally put color back into r3 here, but r3 is intact from Putchar function
        ADD r5, r0  // add prev char width (ret'd by Putchar) to x coord.
        CMP r5, #SCREEN_WIDTH
        BGE .Lm3puts_newline
        MOV r1, r5
        MOV r2, r6
        LDRB r0, [r4]
        CMP r0, #10
        BEQ .Lm3puts_newline
        CMP r0, #0
        BNE .Lm3puts_strloop 
.Lm3puts_nullterminator_reached:
    MOV r0, r5
    MOV r1, r6
    POP {r4-r7}
    POP {r3}
    BX r3
.Lm3puts_cursor_ovf:
    MOV r0, #0
    SUB r0, #1
    MOV r1, r0
    POP {r4-r7}
    POP {r3}
    BX r3
    
    .size Mode3_Puts, .-Mode3_Puts


    .section .iwram,"ax", %progbits
    .arm 
    .align 2
.Lm3_printf_pstring:
    // r7: x
    // r6: y
    // r5: color
    // r4: fp[next_vararg]:= string
    // *((u32*)sp + 0): x origin
    // *((u32*)sp + 1): y origin
    MOV r12, fp
    MOV fp, sp  
    PUSH { r4, r12, lr }  // r12:= Mode3_Printf frame ptr
                          // fp:=  this subroutine's frame pointer,
                          //       aka parent routine sp
    LDR r4, [r9], #4  // r4:= va_next(r9::va_list)::string/char*
.Lm3pfpstr_loop:
        LDRB r0, [r4]
        CMP r0, #0
        POPEQ { r4, fp, pc }  // This is safe because only arm functions (namely Mdode3_Printf will branch into this subroutine
        MOV r1, r7
        MOV r2, r6
        MOV r3, r5
        LDR r12, =Mode3_Putchar
        BL .Lm3pf_call_by_r12  // Mode3_Putchar(cur_va_arg[i], x, y, color)
        CMP r0, #-1
        POPEQ { r4, fp, pc }  // if r0-(~0) == 0 then invalid char in str. return

        ANDS r1, r0, #0x7FFFFFFF
        ADDNE r7, r7, r0
        ADDEQ r6, r6, #VERDANA_CELL_HEIGHT
        LDREQ r7, [fp]
        TSTEQ r0, #0x80000000
        ADDNE r4, r4, #1
        B .Lm3pfpstr_loop

     
    

    .arm
    .global Mode3_Printf
    .type Mode3_Printf %function
Mode3_Printf:
    // r0: x
    // r1: y
    // r2: color
    // r3: fmt
    // STACK: args
//    PUSH { r4-r7, r11 }
    RSBS r12, r0, #(SCREEN_WIDTH-VERDANA_CELL_WIDTH) // r12: SCREEN_WIDTH - VERDANA_CELL_WIDTH - x
    RSBCSS r12, r1, #(SCREEN_HEIGHT - VERDANA_CELL_HEIGHT)  // r12: SCREEN_HEIGHT - VERDANA_CELL_HEIGHT - y
    MOVCC r0, #0
    BXCC lr  // r12 < 0 ? return : cont
    MOV r12, sp
    PUSH { r4-r10, fp, lr }
    MOV fp, r12
    MOV r4, r3  // r4: Print fmt string
    MOV r12, #0xFF
    ORR r12, r12, r12, LSL #7
    AND r5, r2, r12  // r5: Print color
    MOV r6, r1  // r6: Print cursor Y-Coord
    MOV r7, r0  // r7: Print cursor X-Coord
    MOV r8, #0  // r8: chars written
    MOV r9, fp  // r9: next vararg
    PUSH { r0-r1 }
    
.Lm3pf_loop:
        LDRB r0, [r4]
        CMP r0, #0
        BEQ .Lm3pf_return_good
        CMP r0, #'\n'
        LDREQ r7, [sp]
        ADDEQ r6, r6, #VERDANA_GLYPH_HEIGHT
        ADDEQ r4, r4, #1
        BEQ .Lm3pf_loop
        BLT .Lm3pf_return_error
        CMP r0, #'%'
        BNE .Lm3pf_putchar
        LDRB r0, [r4, #1]!
        CMP r0, #0
        BEQ .Lm3pf_return_error
        CMP r0, #'%'
        BEQ .Lm3pf_putchar
        CMP r0, #'c'
        LDREQ r0, [r9], #4
        ANDEQ r0, r0, #0xFF
        BEQ .Lm3pf_putchar
        CMP r0, #'x'
        MOVEQ r12, #0
        SUBNE r12, r0, #'x'
        CMPNE r12, #('X' - 'x')
        ADDEQ r4, r4, #1
        BEQ .Lm3pf_hex_flag
        CMP r0, #'d'
        MOVEQ r1, #1  // r1:= signed::bool :=1:= true if r0 =='d'
        MOVNE r1, #0  // r1:= signed::bool :=0:= false if r0 == 'u'
        CMPNE r0, #'u'
        // IF r0 == 'd' || r0 == 'u'
        ADDEQ r4, r4, #1  // Advance main FMT string ptr
        LDREQ r0, [r9], #4  // load fmt value arg into r0
        BEQ .Lm3pf_decimal_flag  // branch to decimal case
        // ENDIF
        CMP r0, #'s'
        BNE .Lm3pf_return_error
        ADD r4, r4, #1
        LDR lr, =.Lm3pf_loop
        B .Lm3_printf_pstring
.Lm3pf_decimal_flag:
        // r0:= decimal_val :: int32_t|uint32_t
        // r1:= signed :: bool
        MOV r3, r8
        PUSH { r3, r4, r9, r10, fp }
        ADD fp, sp, #20  // fp:= OG SP
        MOV r9, sp  // r9:= SP b4 chars pushed
        MOV r4, r0  // r4:= printval
        TST r1, #1  // if r1&1 : if signed==true
        // EQ: SIGNED NE: UNSIGNED
        MOVEQ r10, #0
        MOVEQ r8, #0
        BEQ .Lm3pf_decimal_flag_unsigned
        CMP r4, #0
        MOVLT r8, #1
        MOVGE r8, #0
        LDRLT r10, =verdana_GlyphWidths
        LDRLTB r10, [r10, #('-' - VERDANA_FIRST_CHAR)]
        MOVLT r1, #-10
        MOVGE r1, #10
        MOVGE r10, #0
        SVC #0x060000
        CMP r1, #0
        MVNLT r1, r1
        ADDLT r1, r1, #1
        ADD r1, r1, #'0'
        PUSH { r1 }
        B .Lm3pf_decimal_flag1
.Lm3pf_decimal_flag_unsigned:
        LSR r0, r0, #1  // Since BIOS div supervisor call assumes signed division,
                        // we need to do this roundabout way of doing unsigned 32b division
                        // logically shifting right to make sure MSB is 0'd out.
                        // Then divide by 5, r1 will then be MOD 5 so shift r1 right by 1
                        // to get (MOD 5)*2, and add OGdividend&1 to make it (MOD 10)
        MOV r1, #5
        SVC #0x060000
        LSL r1, r1, #1
        TST r4, #1
        ADDNE r1, r1, #(1 + '0')
        ADDEQ r1, r1, #'0'
        PUSH { r1 }
.Lm3pf_decimal_flag1:
        MOV r4, r3
        SUB r1, r1, #VERDANA_FIRST_CHAR
        LDR r2, =verdana_GlyphWidths
        LDRB r2, [r2, r1]
        ADD r10, r10, r2
        TEQ r4, #0
        BEQ .Lm3pf_decimal_check_clearance
.Lm3pf_decimal_check_clearance_loop:
            BIOS_DIV_ARM r4, #10
            MOV r4, r0
            ADD r1, r1, #'0'
            PUSH { r1 }
            SUB r1, r1, #VERDANA_FIRST_CHAR
            LDR r2, =verdana_GlyphWidths
            LDRB r2, [r2, r1]
            ADD r10, r10, r2
            TEQ r4, #0
            BNE .Lm3pf_decimal_check_clearance_loop
.Lm3pf_decimal_check_clearance:
        ADD r0, r10, r7  // r0:= width + x
        CMP r0, #SCREEN_WIDTH
        BLE .Lm3pf_decimal_print_prep
        LDR r1, [fp]  // r1:= OG x
        ADD r0, r10, r1
        CMP r0, #SCREEN_WIDTH
        SUBGT sp, fp, #4
        POPGT { fp }
        BGT .Lm3pf_return_error
        MOV r7, r1
        ADD r6, r6, #VERDANA_GLYPH_HEIGHT
        CMP r6, #(SCREEN_HEIGHT - VERDANA_GLYPH_HEIGHT)
        SUBGT sp, fp, #4
        POPGT { fp }
        BGT .Lm3pf_return_error
        CMP sp, r9
        SUBEQ sp, fp, #4
        POPEQ { fp }
        BEQ .Lm3pf_return_error
.Lm3pf_decimal_print_prep:
        MOV r12, r8
        LDR r8, [r9]
        TEQ r12, #0
        BEQ .Lm3pf_decimal_print_loop
        MOV r0, #'-'
        MOV r1, r7
        MOV r2, r6
        MOV r3, r5
        LDR r12, =Mode3_Putchar
        BL .Lm3pf_call_by_r12
        CMP r0, #0
        SUBLE sp, fp, #4
        POPLE { fp }
        BLE .Lm3pf_return_error
        ADD r7, r7, r0
        ADD r8, r8, #1
.Lm3pf_decimal_print_loop:
            POP { r0 }
            MOV r1, r7
            MOV r2, r6
            MOV r3, r5
            LDR r12, =Mode3_Putchar
            BL .Lm3pf_call_by_r12
            CMP r0, #0
            SUBLE sp, fp, #4
            POPLE { fp }
            BLE .Lm3pf_return_error
            ADD r7, r7, r0
            ADD r8, r8, #1
            CMP sp, r9
            BNE .Lm3pf_decimal_print_loop
        SUB sp, fp, #16
        POP { r4, r9, r10, fp }
        B .Lm3pf_loop
/*
        // r0:= value to print :: (signed or unsigned) 32b word
        // r1:= value signed :: bool
        PUSH { r4, r8-r10, fp }
        ADD fp, sp, #20
        PUSH { r0-r1 }
        CMP r0, #0
        MVNLT r0, r0
        ADDLT r4, r0, #1
        MOVGE r4, r0
        LDR r9, =verdana_GlyphWidths
        TEQ r1, #0
        LDRNEB r10, [r9, #('-' - VERDANA_FIRST_CHAR)]
        MOVEQ r10, #0
.Lm3pf_decimal_flag_find_plen:
            BIOS_DIV_ARM r4, #10
            MOV r4, r0
            ADD r1, r1, #('0' - VERDANA_FIRST_CHAR)
            LDRB r1, [r9, r1]
            ADD r10, r10, r1
            CMP r4, #0
            BNE .Lm3pf_decimal_flag_find_plen
        
        POP { r4, r8 }
        ADD r0, r7, r10
        RSBS r1, r0, #SCREEN_WIDTH 
        BCS .Lm3pf_decimal_flag_print
        LDR r0, [fp]
        ADD r1, r0, r10
        RSBS r1, r1, #SCREEN_WIDTH
        MOVCS r7, r0
        ADDCS r6, r6, #VERDANA_GLYPH_HEIGHT
        SUBCC sp, fp, #4
        POPCC { fp }
        BCC .Lm3pf_return_error
        TEQ r8, #0
        BEQ .Lm3pf_decimal_flag_print
        CMP r4, #0
        BGE .Lm3pf_decimal_flag_print
        MOV r0, #'-'
        MOV r1, r7
        MOV r2, r6
        MOV r3, r5
        LDR r12, =Mode3_Putchar
        BL .Lm3pf_call_by_r12
        CMP r0, #0
        SUBLE sp, fp, #4
        POPLE { fp }
        BLE .Lm3pf_return_error
        ADD r7, r7, r0
.Lm3pf_decimal_flag_print:
        CMP r4, #0
        MOVLT r8, #-10
        MOVGE r8, #10
.Lm3pf_decimal_flag_print_loop:
            BIOS_DIV_ARM r4, r8
            MOV r4, r3
            ADD r0, r1, #'0'
            MOV r1, r7
            MOV r2, r6
            MOV r3, r5
            LDR r12, =Mode3_Putchar
            BL .Lm3pf_call_by_r12
            CMP r0, #0
            SUBLE sp, fp, #4
            POPLE { fp }
            BLE .Lm3pf_return_error
            ADD r7, r7, r0
            TEQ r4, #0
            BNE .Lm3pf_decimal_flag_print_loop
     POP { r4, r8-r10, fp }
    B .Lm3pf_loop
*/
.Lm3pf_hex_flag:
        LDR r0, [r9], #4
        PUSH { r4, r9, fp  }  // save r4:=fmt r9:=varargp to stack fp
        ADD r9, r12, #('a'-10)  // r9:=hex digits a-f offset 
                                // ('a'-10 when lowercase)
                                // ('a'-10)+('X'-'x') when uppercase)
        MOV r4, #0
        PUSH { r4 }

        MOV r4, r0
        ADD fp, sp, #16
        MOV r10, #28  // r10:= shamt
.Lm3pf_hex_flag_check_print_clearance:
        MOV r1, #VERDANA_HEXGLYPH_WIDTH
        ADD r1, r7, r1, LSL #3  // r1:=
                                //  x + (VERDANA_HEXGLYPH_WIDTH
                                //      * (8 hexglyphs / 32b-word))
        LDR r3, =verdana_GlyphWidths
        LDRB r2, [r3, #('0'-VERDANA_FIRST_CHAR)]
        LDRB r3, [r3, #('x'-VERDANA_FIRST_CHAR)]
        ADD r2, r2, r3
        ADD r1, r1, r2  // print width of hex num += print width of "0x"

        RSBS r1, r1, #(SCREEN_WIDTH)  // if printing wont fit on scrn, either go
                                      // to newline or return depending on stack[top]
        ADDCS sp, sp, #4
        BCS .Lm3pf_hex_flag_loop
        POP { r12 }
        TEQ r12, #0
        ADDNE sp, sp, #8
        POPNE { fp }
        BNE .Lm3pf_return_error
        MOV r12, #1
        PUSH { r12 }
        LDR r7, [fp]
        ADD r6, r6, #VERDANA_CELL_HEIGHT
        B .Lm3pf_hex_flag_check_print_clearance
.Lm3pf_hex_flag_loop:
            LSR r0, r4, r10
            AND r0, r0, #15
            CMP r0, #10
            ADDLT r0, r0, #'0'
            ADDGE r0, r0, r9
            MOV r1, r7
            MOV r2, r6
            MOV r3, r5
            LDR r12, =Mode3_Putchar
            BL .Lm3pf_call_by_r12

            CMP r0, #-1
            ADDEQ sp, sp, #8
            POPEQ { fp }
            BEQ .Lm3pf_return_error

            TEQ r0, #0
            LDREQ r7, [fp]
            ADDEQ r6, r6, #VERDANA_CELL_HEIGHT
            BEQ .Lm3pf_hex_flag_loop

            ADD r7, r7, r0
            ADD r8, r8, #1
            SUBS r10, r10, #4
            BCS .Lm3pf_hex_flag_loop
    POP { r4, r9, fp }
    B .Lm3pf_loop
.Lm3pf_putchar:
        LDR r12, =Mode3_Putchar
        // r0 already has char
        MOV r1, r7  // r1: cur x
        MOV r2, r6  // r2: cur y
        MOV r3, r5  // r3: color
        BL .Lm3pf_call_by_r12

        CMP r0, #-1
        BEQ .Lm3pf_return_error
 
        ANDS r1, r0, #0x7FFFFFFF
        ADDNE r7, r7, r0
        ADDEQ r6, r6, #VERDANA_CELL_HEIGHT
        LDREQ r7, [sp]
        TSTEQ r0, #0x80000000
        ADDNE r4, r4, #1
        B .Lm3pf_loop



.Lm3pf_return_error:
    MVN r0, #0
    B .Lm3pf_return
.Lm3pf_return_good:
    MOV r0, r8
.Lm3pf_return:
    SUB sp, fp, #0x24
    POP { r4-r10, fp, lr }
    BX lr
.Lm3pf_call_by_r12:
    BX r12
    .size Mode3_Printf, .-.Lm3_printf_pstring
