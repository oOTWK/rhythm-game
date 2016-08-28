/*.include "nios_macros.s"*/

.text
.equ ADDR_SLIDESWITCHES, 0xFF200040
.equ ADDR_AUDIODACFIFO, 0xFF203040
.equ ADDR_REDLEDS, 0xFF200000 
.equ ADDR_TIMER0, 0xFF202000
.equ ADDR_PUSHBUTTONS, 0xFF200050
.equ ADDR_VGA, 0xFF203020
.equ ADDR_7SEG1, 0xFF200020
.equ ADDR_7SEG2, 0xFF200030
.equ ADDR_PS2, 0xFF200100

.equ PERIOD, 19000000 
.equ TOTALTIME, 270 # gaming time = TOTALTIME * PERIOD
.equ SOUND, 100000000

.global main
.section .exceptions, "ax"
IHANDLER:
	rdctl r2, ctl4          /* Check if an external interrupt has occurred */
	beq r2, r0, nothing_happened

# determine which interrupt occurred
	mov r3, r2
	andi r2, r2, 0b10	# interrupted by push button
	bne r0, r2, START_STOP
	
	andi r3, r3, 0b01
	bne r0, r3, TIMER_interrupt # interrupted by timer 
	
nothing_happened:
	subi ea,ea,4   # otherwise, exit exception handler
	eret


START_STOP:
	movia r2, ADDR_PUSHBUTTONS
	movia r3, 0x01	# Acknowledge
  	stwio r3, 12(r2)
	
	movia r4, start_stop_flag # determine the game was playing or not
	ldw r3, 0(r4)
	beq r0, r3, start_game
	
stop_game:	# flag was 1. the game was playing
	movia r4, start_stop_flag 
	stw r0, 0(r4)	# set start_stop_flag 0
   
	movia r7, ADDR_TIMER0
	movui r2, 0b1000
	stwio r2, 4(r7)
	stwio r0, 0(r7)
   
	movi r2,0b10
	wrctl ctl3,r2
	
	movia ea, WAIT_FOR_START
	br EXIT_EX
	
	
start_game: # flag was 0.
	movia r4, start_stop_flag 
	movi r3, 1		# start_stop_flag 1
	stw r3, 0(r4)

	movia r2, game_end_flag	# initialize game_end_flag
	movi r3, TOTALTIME
	stw r3, 0(r2)
	
	movia et, update_frame_flag	# initialize update_frame_flag
	movia r10, INITIAL_SPEED
	ldw r3, 0(r10)
	stw r3, 0(et)
	
# enable timer0 interrput
	movia r7, ADDR_TIMER0	# load period of timer 
	stwio r0, 0(r7)
	movui r2, %lo(PERIOD)
	stwio r2, 8(r7)                          
	movui r2, %hi(PERIOD)
	stwio r2, 12(r7)

	movui r2, 0b111
	stwio r2, 4(r7)		# Start the timer with continuing and interrupts 
   
	movi r2,0b11
	wrctl ctl3,r2 	# enable ienable

	movia ea, GAME_START
	br EXIT_EX

	
	
TIMER_interrupt:
# interrupted by timer 0. Update the entire game  
	movia r7, ADDR_TIMER0
	ldwio r3, 0(r7)
	beq r0, r3, EXIT_EX
	
# stop game if game_end_flag is 0
	movia r2, game_end_flag
	ldw r10, 0(r2)
	beq r0, r10, stop_game
	subi r10, r10, 1
	stw r10, 0(r2)
	
	stwio r0, 0(r7)	# Acknowledge
	
	movi r2,0b10	# disable timer interrupt
	wrctl ctl3,r2
	movi r2,0x1		# enable PIE
    wrctl ctl0, r2	

###	push button input instead of PS/2 keyboard - to test without PS/2 keyboard ###
#	movia r2, ADDR_PUSHBUTTONS
#	ldwio r4, 0(r2)
#	srli r4, r4, 1
#	andi r4, r4, 0x0007

	# read ps2
	call READ_PS2
	
	# turn on led
	movia r2,ADDR_REDLEDS
	stwio r4, 0(r2)
	call remove_dot
	stw r2, 0(sp)
	
	# update frame
	movia et, update_frame_flag
	ldw r3, 0(et)
	beq r0, r3, dropping_dot
	
	subi r3, r3, 1
	stw r3, 0(et)
	br exit_timer_interrupt
	
dropping_dot:
	
	movia r2, ADDR_TIMER0
	stwio r0, 16(r2)
	ldwio r4, 16(r2)
	xor r4, r4, r10
	andi r4, r4, 0x0007
	call update_frame
	stw r2, 0(et)
	
exit_timer_interrupt:
	call UPDATE_SCORE
	wrctl ctl0, r0
	movi r2,0b11
	wrctl ctl3,r2		# enable timer interrupt
	movia ea, PRODUCE_SOUND
	br EXIT_EX

EXIT_EX:
	wrctl ctl4, r0
   	eret
	
	


#----------------------Set up initial interrupts-------------------------------------------------

main:
	movia sp,  0x007FFFFC	/* setup the stack pointer */
	subi sp, sp, 4
	
	movia r2, update_frame_flag
	stwio r0, 0(r2)          # set flag 0
   
	movia r2, start_stop_flag
	stwio r0, 0(r2)          # set flag 0

# enable push button interrupt
	movia r7,ADDR_PUSHBUTTONS
	movia r2,0x01
	stwio r2,8(r7)  	/* Enable interrupt on push button 0 */
  	stwio r2, 12(r7)
	
	movi r2,0b10	
	wrctl ctl3,r2		# enable ienable
   
	movi r2, 0x1
	wrctl ctl0, r2		# enable PIE

WAIT_FOR_START:
	movia r2, ADDR_REDLEDS	# turn on leds
	movia r3, 0xFFFFFFFF
	stwio r3, 0(r2)
	call UPDATE_SCORE	
	
	call first_frame


WAIT:
	movia r2, start_stop_flag
	ldw r3, 0(r2)
	bne r3, r0, PRODUCE_SOUND
	
	movia r2, ADDR_PUSHBUTTONS
	ldwio r4, 0(r2)
	srli r4, r4, 1
	andi r4, r4, 0x0007

	stw r4, 0(sp)
	br PRODUCE_SOUND
 

PRODUCE_SOUND:	
	movia r20, SOUND
	mov r21, r20
	movia r23, 0xFFFFFFFF

	# 2's compliment
	xor r21, r21, r23	
	addi r21, r21, 1
	
	ldw r3, 0(sp)
	movia r8, array_sound
	slli r3, r3, 2 # multiply by 4
	add r8, r8, r3
	ldw r3, 0(r8)
	muli r3, r3, 100
	mov r4, r3
	
high_sound_loop:
	beq r0, r3, low_sound_loop
	# produce sound
	movia r2, ADDR_AUDIODACFIFO
	stwio r20, 8(r2)
	stwio r20, 12(r2)
	
	subi r3, r3, 1
	br high_sound_loop

low_sound_loop:
	beq r0, r4, WAIT
	stwio r21, 8(r2)
	stwio r21, 12(r2)

	subi r4, r4, 1
	br low_sound_loop

	
GAME_START:	
	movia r2, ADDR_REDLEDS	# turn off leds
	stwio r0, 0(r2)
	br GAME_START

UPDATE_SCORE:
	movia r11, score
	ldw r12, 0(r11)

	mov r18, r0		
	movi r14, 10
	mov r13, r0
	movi r20, 24
	
next_seven_seg:
	div r15, r12, r14
	mul r16, r15, r14
	sub r16, r12, r16
	movia r15, seven_seg
	slli r16, r16, 2
	add r15, r15, r16
	ldw r17, 0(r15)
	sll r17, r17, r13
	or r18, r18, r17
	div r12, r12, r14
	addi r13, r13, 8
	ble r13, r20, next_seven_seg

	movia r13, ADDR_7SEG1
	stwio r18, 0(r13)
	ret
	
READ_PS2:
	movia r2, ADDR_PS2
	mov r4, r0
	movui r7, 0x6B	# Left ARROW from keyboard
	movui r8, 0x72	# Down ARROW from keyboard
	movui r9, 0x74	# Right ARROW from keyboard
	
read_ps2_loop:
	ldwio r5, 0(r2)
	mov r6, r5
	srli r6, r6, 16
	beq r0, r6, no_input

	andi r5, r5, 0xFF
	beq r5, r7, L_ARROW
	beq r5, r8, D_ARROW
	beq r5, r9, R_ARROW
	br read_ps2_loop
L_ARROW:
	ori r4, r4, 0b100
	br read_ps2_loop
D_ARROW:
	ori r4, r4, 0b010
	br read_ps2_loop
R_ARROW:
	ori r4, r4, 0b001
	br read_ps2_loop
	
no_input:
	ret
	
	
.data
.align 2
speed: .space 4
update_frame_flag: .space 4	# 0 - need to update frame
start_stop_flag: .space 4	# 0 - game is not playing. 1 - game is playing.
game_end_flag: .space 4
seven_seg:
    .word 0b00111111 	# 0
    .word 0b00000110	# 1
    .word 0b01011011	# 2
    .word 0b01001111 	# 3
    .word 0b01100110	# 4
    .word 0b01101101 	# 5
    .word 0b01111101 	# 6
    .word 0b00000111 	# 7
    .word 0b01111111 	# 8
    .word 0b01101111 	# 9
	
array_sound: 
	.word 0
	.word 0b1111111111
	.word 0b0010011111
	.word 0b0000111111
	.word 0b0001011111
	.word 0b0000101111
	.word 0b0000100111
	.word 0b0000100011
