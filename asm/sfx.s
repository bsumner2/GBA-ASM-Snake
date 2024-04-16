    .section .rodata
    .align 2
    .global sound_rates
sound_rates:
    .word 8013, 7566, 7144, 6742, 6362, 6005, 5666, 5346
    .word 5048, 4766, 4499, 4246 
    .size sound_rates, .-sound_rates

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




    .text

    .thumb_func
    .align 2
    .global get_reg_base
    .type get_reg_base %function
get_reg_base:
    MOV r0, #128
    LSL r0, #19
    BX lr
    .size get_reg_base, .-get_reg_base

    .thumb_func
    .align 2
    .global sound_DSnDMG_control_init
    .type sound_DSnDMG_control_init %function
sound_DSnDMG_control_init:
    PUSH {lr}
    BL sound_master_enable
    MOV r0, #0x77  // 0x77 = 0b01110111 : lower 8 bits value for L/R full volume
    MOV r1, #0x99  // upper 8 bits value for L/R enable DMG noise & square1
    LSL r1, #8  // r1 = 0x9900  // Move upper bits up to MSByte
    ORR r1, r0  // r1 = 0x9900|0x0077 = 0x9977  // ORR MSB and LSB

    BL get_reg_base
    
    // get_reg_base only dirties up r0, and that's also just the return reg, so
    // we dont need to restore r1's value
    
    MOV r2, #128
    ORR r0, r2  // r0 = 0x04000000|0x80 = 0x04000080 = &REG_SNDDMGCNT
    STRH r1, [r0]  // *r0 : *((ushort*)0x04000080) = r1 : 0x9977
    MOV r1, #2
    ORR r0, r1  // r0 = 0x04000080|2 = 0x04000082 = &REG_SNDDSCNT
    // 2 also happens to be the bfield value for DMG vol ratio 100 in 
    // DSound ctl register, and with no shift required. How convenient!
    STRH r1, [r0]  // *r0 : *((ushort*)0x04000082) = r1 : 2
 
    POP {r1}
    BX r1
    .size sound_DSnDMG_control_init, .-sound_DSnDMG_control_init

//    .thumb_func
//    .align 2
//    .global <func>
//    .type <func> %function
//<func>:
//    .size <func>, .-<func>

    .thumb_func
    .align 2
    .global sound_master_enable
    .type sound_master_enable %function
sound_master_enable:
    PUSH {lr}
    MOV r1, #0x84
    BL get_reg_base
    ORR r0, r1  // r0 = 0x04000000|0x0084 = 0x04000084 = &REG_SND_STAT
    SUB r1, #4  // r1-=4 : r1 = 0x84-4 = 0x80 = Sound Status enable flag bit
    STRH r1, [r0]  // REG_SNDSTAT = Master enable flag bit high
    POP {r1}
    BX r1
    .size sound_master_enable, .-sound_master_enable

    .thumb_func
    .align 2
    .global sound_sq1_cnt_set
    .type sound_sq1_cnt_set %function
sound_sq1_cnt_set:
    // r0 = len, r1 = duty, r2 = env step time, r3 = env dir inc (HI=inc, LO=dec), stack top = init vol
//    PUSH {r4, lr}
    MOV r12, r3
    MOV r3, #0x3F
    AND r0, r3  // clamp length field to valid range
    MOV r3, #3
    AND r1, r3  // clamp duty to valid range
    ADD r3, #4  // r3 = 3+4 = 7
    AND r2, r3  // clamp env step time to valid range
    MOV r3, r12
    CMP r3, #0
    BEQ .Lssq1set_skip_edir
    MOV r3, #1
    LSL r3, #11
.Lssq1set_skip_edir:
    LSL r1, #6  // shift duty field to appropriate spot
    LSL r2, #8  // shift env step time to appropriate spot
    ORR r1, r0  // r1 = Duty|Len
    ORR r1, r2  // r1 = EST|Duty|Len
    ORR r1, r3  // r1 = Edir|EST|Duty|Len
    LDR r3, [sp]
    MOV r0, #15
    AND r3, r0  // r3 = clamp Env Init Val (EIV) to valid range
    LSL r3, #12  // shift EIV to appropriate spot
    ORR r1, r3  // r1 = EIV|Edir|EST|Duty|Len = Full SQ1 Controls Set
    PUSH {lr}
    BL get_reg_base
    MOV r2, #0x62
    ORR r0, r2  // r0 = 0x04000000|0x0062 = 0x04000062 = &REG_SND1CNT
    STRH r1, [r0]

    POP {r1}
    BX r1
    .size sound_sq1_cnt_set, .-sound_sq1_cnt_set

    .thumb_func
    .align 2
    .global sound_sq1_freq_set
    .type sound_sq1_freq_set %function
sound_sq1_freq_set:
    // r0 = rate, r1 = timed flag, r2 = reset flag
    PUSH {lr}
    MOV r3, #0x80
    LSL r3, #4  // r3 = 0x80<<4 = 0x800
    SUB r3, #1  // r3 = 0x800-1 = 0x7FF
    AND r0, r3  // clamp r0 to valid range 
    MOV r3, #1
    AND r1, r3  // clamp flag bit
    AND r2, r3  // clamp flag bit
    LSL r2, #15
    LSL r1, #14
    ORR r1, r0  // r1 = TimeFlag|Rate
    ORR r1, r2  // r1 = ResetFlag|TimeFlag|Rate
    
    BL get_reg_base
    MOV r2, #0x64
    ORR r0, r2  // r0 = 0x04000000|0x0064 = 0x04000064
    STRH r1, [r0]  // *(ushort*)0x04000064 = REG_SND1FREQ = Reset|Timed|Rate
    
    POP {r1}
    BX r1
    .size sound_sq1_freq_set, .-sound_sq1_freq_set

    .thumb_func
    .align 2
    .global sound_sq1_sweep_set
    .type sound_sq1_sweep_set %function
sound_sq1_sweep_set:
    // r0 = sweep shift num, r1  = sweep mode, r2 = sweep step time
    PUSH {lr}
    MOV r3, #7
    AND r0, r3  // r0&=7
    AND r2, r3  // r2&=7
    MOV r3, #1
    AND r1, r3  // r1&=1
    LSL r1, #3  // r1<<=3
    LSL r2, #4  // r2<<=4
    ORR r1, r0  // r1|=r0
    ORR r1, r2  // r1|=r2
    // r1 = r0|r1|r2 = ((sweep step time & 7)<<4)|((sweep mode &1)<<3)|(sweep shift num & 7)
    BL get_reg_base
    MOV r2, #0x60
    ORR r0, r2  // r0 |= 0x0060 : r0 = 0x04000060 = &REG_SND1SWEEP
    STRH r1, [r0]  // REG_SND1SWEEP = SweepStepTime|SweepMode|SweepShitNumber

    POP {r1}
    BX r1
    .size sound_sq1_sweep_set, .-sound_sq1_sweep_set
    
    .thumb_func
    .align 2
    .global sound_noise_cnt_set
    .type sound_noise_cnt_set %function
sound_noise_cnt_set:
    // r0=len, r1 = env step time, r2 = env increase flag, r3 = Initial step vol
    PUSH {r4, lr}
    MOV r4, #0x3F
    AND r0, r4  // r0 = Len&63
    MOV r4, #7
    AND r1, r4  // r1 = EST&7
    CMP r2, #0
    BEQ .Lsnscset_skip_edir
    MOV r2, #1
    LSL r2, #11  // r2 = EnvDir<<11
.Lsnscset_skip_edir:
    MOV r4, #15
    AND r3, r4  // r3 = InitVol&15
    LSL r3, #12  // r3 = InitVol<<12
    LSL r1, #8  // r1 = EST<<8
    ORR r1, r0  // r1 = EST|Len
    ORR r1, r2  // r1 = Edir|EST|Len
    ORR r1, r3  // r1 = InitVol|Edir|EST|Len
    
    BL get_reg_base
    MOV r2, #0x78
    ORR r0, r2  // r0 = 0x04000078 = &REG_SND4CNT
    STRH r1, [r0]
    
    POP {r4}
    POP {r1}
    BX r1
    
    .size sound_noise_cnt_set, .-sound_noise_cnt_set

    .thumb_func
    .align 2
    .global sound_noise_freq_set
    .type sound_noise_freq_set %function
sound_noise_freq_set:
    // r0 = Dividing ratio of freqs (whatever that means)
    // r1 = Counter step width ( 0: 15b, 1: 7b)
    // r2 = Shift clock freq
    // r3 = timed flag
    // stack top = reset
    PUSH {r4, r5, lr}
    LDR r4, [sp, #12]
    MOV r5, #1
    AND r4, r5  // r4 = Reset&1
    AND r3, r5  // r3 = Timed&1
    AND r1, r5  // r1 = StepWidth&1
    MOV r5, #15
    AND r2, r5  // r2 = ClockFreq&15
    MOV r5, #3
    AND r0, r5  // r0 = Div&3
    LSL r1, #3  // r1 = StepWidth<<3
    LSL r2, #4  // r2 = ClockFreq<<4
    LSL r3, #14  // r3 = Timed<<14
    LSL r4, #15  // r4 = Reset<<15
    ORR r1, r0  // r1 = StepWidth|Div
    ORR r1, r2  // r1 = ClockFreq|StepWidth|Div
    ORR r1, r3  // r1 = Timed|ClockFreq|StepWidth|Div
    ORR r1, r4  // r1 = Reset|Timed|ClockFreq|StepWidth|Div
    
    BL get_reg_base
    MOV r2, #0x7C
    ORR r0, r2  // r0 = 0x04000000|0x007C = 0x0400007C = &REG_SND4FREQ
    STRH r1, [r0]  // REG_SND4FREQ = r1
    POP {r4, r5}
    POP {r1}
    BX r1
    .size sound_noise_freq_set, .-sound_noise_freq_set

    .thumb_func
    .align 2
    .global sound_sq1_play
    .type sound_sq1_play %function
sound_sq1_play:
    // r0 = note, r1 = octave
    PUSH {lr}
    MOV r2, #0x80
    LSL r2, #4  // r2 = 0x80<<4 = 0x800 = 2048
    LDR r3, =sound_rates
    LSL r0, #2  // r0 = note*4
    LDR r0, [r3, r0]  // r0 = sound_rates[note]
    ADD r1, #4  // r1 = octave + 4
    LSR r0, r1  // r0 = sound_rates[note]>>(oct+4)
    SUB r0, r2, r0  // r0 = r2-r0 = 2048-(sound_rates[note]>>(octave+4))
    MOV r1, #0  // r1 = REG_SND1FREQ target timed flag value = 0
    MOV r2, #1  // r2 = REG_SND1FREQ target reset flag value = 1
    
    // CALL: sq1 frequency setter (rate, timed flag, reset flag)
    //  sound_sq1_freq_set((2048-(sound_rates[note]>>(octave+4))), 0, 1)
    BL sound_sq1_freq_set

    POP {r1}
    BX r1

    .size sound_sq1_play, .-sound_sq1_play

    .thumb_func
    .align 2
    .global sound_noise_play
    .type sound_noise_play %function
sound_noise_play:
    // r0 div ratio
    // r1 counter step width
    // r2 Shift clock freq
    // r3 len flag
    PUSH {lr}
    MOV r12, r0
    MOV r0, #1
    PUSH {r0}
    MOV r0, r12

    BL sound_noise_freq_set

    ADD sp, #4

    POP {r1}
    BX r1
    .size sound_noise_play, .-sound_noise_play

