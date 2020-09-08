/*
 * Display.asm
 *
 *  Created: 2020-03-24 6:31:21 PM
 *   Author: Kelvin Leung V00927380 
	Date March 24th 2020
*code to simulate an LCD screen that is interrupted by a timer interrupt
; modified code of lilanne jackson shamelessly used by this csc student
 */ 
 .org 0x0000
	jmp setup

.org 0x0028
	jmp timer1_ISR

.org 0x0072
 #define count r23
 #define direct r22
 #define char r16
 .equ softwareoffset = 1000
 .equ softstack = RAMEND - softwareoffset -1
 .cseg
 .org 0x200

main_loop:
	rjmp main_loop

setup:
	//modified from class 16 example software stack divide
	;setup up the Software (sw) stack 
	ldi XH, high(softstack)
	ldi XL, low(softstack)
	//define software pop
	#define pushSW(Rr) st -X, Rr
	#define popSW(Rd) ld Rd, X+
	//initialize hardware stack
	ldi YL, low(RAMEND)
	out SPL, YL 
	ldi YH, high(RAMEND)
	out SPH, YH
	//initialize counter to 0
	ldi char, 1 
	sts counter, char
	
	//initialize direction to 0
	ldi char, 0 
	sts direction, char
	 
	//load addresses into registers for get_message
	ldi ZH, high(msg1_p<<1)
	ldi ZL, low(msg1_P<<1)
	ldi YH, high(line1)
	ldi YL, low(line1)
	call get_message

	ldi ZH, high(msg2_p<<1)
	ldi ZL, low(msg2_p<<1)
	ldi YH, high(line2)
	ldi YL, low(line2)
	call get_message

	ldi ZH, high(msg3_p<<1)
	ldi ZL, low(msg3_p<<1)
	ldi YH, high(msg3)
	ldi YL, low(msg3)
	call get_message 
	
	//preload line_stores to have **************
	ldi ZH, high(msg3_p<<1)
	ldi ZL, low(msg3_p<<1)
	ldi YH, high(line_store1)
	ldi YL, low(line_store1)
	call get_message

	ldi ZH, high(msg3_p<<1)
	ldi ZL, low(msg3_P<<1)
	ldi YH, high(line_store2)
	ldi YL, low(line_store2)
	call get_message

	//push addresses to stack to call for reverse string
	ldi ZH, high(msg1_p<<1)
	ldi ZL, low(msg1_p<<1)
	ldi YH, high(line3)
	ldi YL, low(line3)
	push ZH
	push ZL
	push YH
	push YL
	call reverse
	pop YL
	pop YL
	pop YL
	pop YL

	ldi ZH, high(msg2_p<<1)
	ldi ZL, low(msg2_p<<1)
	ldi YH, high(line4)
	ldi YL, low(line4)
	push ZH 
	push ZL 
	push YH 
	push YL
	call reverse
	pop YL 
	pop YL
	pop YL 
	pop YL
	
	
	//first astericks push
	ldi ZH, high(msg3)
	ldi ZL, low(msg3)
	ldi YH, high(msg3)
	ldi YL, low(msg3)
	pushSW(ZH)
	pushSW(ZL)
	pushSW(YH)
	pushSW(YL)
	call display

	call timer1_setup
 
	jmp main_loop 

 
 get_message: 
 //(program location, data location)
 //copies a string of characters from program program memory to data memory
 //since loading from space in memory needs to be known value
 //will pass in values from Z
//assumes Z has word to grab from 
//assumes r16 is free to use
 copy_loop: 
	lpm char, Z+
	st Y+, char
	tst char
	brne copy_loop 
	ret



//Y is set aside for data stack
//only Z can access the hardware stack
//strings in program memory

reverse: 
//reverse the string found at message and store at location
//(message, location)
	//initialize Z to stack pointer 
	//protect registers
	push ZH
	push ZL 
	push YH
	push YL
	push r15
	push r14
	//initialize stack pointers
	in ZH, SPH
	in ZL, SPL
	//load with offset
	ldd YH, Z + 13
	ldd YL, Z + 12
	//store values for Z to use
	mov r15, YH
	mov r14, YL
	
	ldd YH, Z + 11
	ldd YL, Z + 10
	//take the values
	mov ZH, r15
	mov ZL, r14
	 
	push r17
	//push to stack
	ldi char, 0
	push char
stack:
	lpm char, Z+  
	push char
	inc r17
	tst char
	brne stack
	//place onto stack
	pop char
pop_off: 
	pop char
	st Y+, char
	dec r17
	cpi r17, 0
	brne pop_off

	ldi char, 0
	st Y+, char
	pop r17
	pop r14
	pop r15
	pop YL
	pop YH
	pop ZL
	pop ZH
	ret 
	
display: 
//(lineA, Line B)
//copy string from lineA to Line1 of LCD screen cache memory
//copy string from LineB to line2 of LCD screen cache memory
//protect registers
    push ZH
	push ZL
	push YH
	push YL
	push r18
	push r17
	//pop from software stack
	popSW(ZL)
	popSW(ZH)
	//load in LCD address
	ldi YH, high(LCDCacheTopLine)
	ldi YL, low(LCDCacheTopLine)
	ldi r18, msg_length
top_line: 
	ld r17, Z+
	st Y+, r17
	dec r18
	cpi r18, 0
	brne top_line
	
	ldi r18, msg_length
	popSW(ZL)
	popSW(ZH)
	ldi YH, high(LCDCacheBottomLine)
	ldi YL, low(LCDCacheBottomLine)
bottom_line:
	ld r17, Z+ 
	st Y+, r17	
	dec r18
	cpi r18, 0
	brne bottom_line
	pop r17
	pop r18
	pop YL 
	pop YH
	pop ZL
	pop ZH
	ret

.equ TIMER1_DELAY = 15625
.equ TIMER1_MAX_COUNT = 0xFFFF
.equ TIMER1_COUNTER_INIT = TIMER1_MAX_COUNT-TIMER1_DELAY + 1
timer1_setup:
	//sets all bits in TCCR1A register to 0, disconnects Pin 0C1 from timer1/counter1
	ldi r16, 0x00 ;normal operation
	sts TCCR1A, r16
	//set clock to have no prescaling 
	ldi r16, (1<<CS12)|(1<<CS10) ;clock /1024
	sts TCCR1B, r16
	//allows timer to be interrupted by the CPU when it's counter overflows
	ldi r16, 1<<TOIE1
	sts TIMSK1, r16
	//set timer counter to TIMER1_COUNTER_INIT
	ldi r16, high(TIMER1_COUNTER_INIT) 
	sts TCNT1H, r16 ; write high byte first
	ldi r16, low(TIMER1_COUNTER_INIT)
	sts TCNT1L, r16 ; low byte

	;enable interrupts in the SREG
	sei 

	ret

timer1_ISR:
	push r16 
	push r17
	push r18
	lds r16, SREG
	push r16

	;RESET timer counter to TIMER_1_COUNTER_INIT
	ldi r16, high(TIMER1_COUNTER_INIT)
	sts TCNT1H, r16
	ldi r16, low(TIMER1_COUNTER_INIT)
	sts TCNT1L, r16; low byte
	
	//the real stuff happens here
	
	//get the value of direction from data memory 
	ldi ZH, high(direction)
	ldi ZL, low(direction)
	ld direct, Z
	//if direction is 0 do up. if direction is 1 do down. 
	cpi direct, 0
	brne down

up:
    //line_stored1 = line_stored2
	ldi YH, high(line_store1)
	ldi YL, low(line_store1)
	ldi ZH, high(line_store2)
	ldi ZL, low(line_store2)
	//copy over string from line_stored2 to line_stored1
	ldi r18, msg_length
copy_looper:
	ld r17, Z+
	st Y+, r17
	dec r18
	cpi r18, 0
	brne copy_looper
	//load the value of counter from memory
	ldi YH, high(counter)
	ldi YL, low(counter)
	ld count, Y

	//msg_count
	mov char, count
	//msg places address onto softwarestack 
	call msg 
	//get address from msg
	popSW(ZL)
	popSW(ZH)
	//load address to store to
	ldi YH, high(line_store2)
	ldi YL, low(line_store2)
	//store values from msg to line_store2
	ldi r18, msg_length
second_copy_looper:
	ld r17, Z+
	st Y+, r17
	dec r18
	cpi r18, 0
	brne second_copy_looper
	
	ldi YH, high(line_store1)
	ldi YL, low(line_store1)
	ldi ZH, high(line_store2)
	ldi ZL, low(line_store2)
	pushSW(ZH)
	pushSW(ZL)
	pushSW(YH)
	pushSW(YL)
	call display
	
	inc count
	//if count greater than 10 change direction 
	//and do not update counter value
	cpi count, 11
	brne skip_change_down
	ldi direct, 1 
	sts direction, direct
	dec count
skip_change_down:
	sts counter, count 
	jmp finish
	 
down:
    //line_stored2 = line_stored1
	ldi YH, high(line_store2)
	ldi YL, low(line_store2)
	ldi ZH, high(line_store1)
	ldi ZL, low(line_store1)
	//copy over string from line_stored1 to line_stored2
	ldi r18, msg_length
copy_looper2:
	ld r17, Z+
	st Y+, r17
	dec r18
	cpi r18, 0
	brne copy_looper2
	//load value of counter from memory
	ldi YH, high(counter)
	ldi YL, low(counter)
	ld count, Y
	//msg(count)
	mov char, count
	call msg
	//get address from msg
	popSW(ZL)
	popSW(ZH)
	//load address to store to
	ldi YH, high(line_store1)
	ldi YL, low(line_store1)
	//store values from msg to line_store2
	ldi r18, msg_length
second_copy_looper2:
	ld r17, Z+
	st Y+, r17
	dec r18
	cpi r18, 0
	brne second_copy_looper2
	
	ldi YH, high(line_store1)
	ldi YL, low(line_store1)
	ldi ZH, high(line_store2)
	ldi ZL, low(line_store2)
	pushSW(ZH)
	pushSW(ZL)
	pushSW(YH)
	pushSW(YL)
	call display
	
	dec count
	//if count 0 change direction
	//and do not update counter value 
	cpi count, 0
	brne skip_change_up
	ldi direct, 0 
	sts direction, direct
	inc count
skip_change_up:
	sts counter, count
	jmp finish
finish:	
	pop r16
	sts SREG, r16 
	pop r18
	pop r17
	pop r16
	reti 

msg: 
	//given a register countaining a number 
	//modulo it by 4 and return address to whichever line number
	//it corresponds to 
	push r17
	ldi r17, 3
	//mod 4
	and r16, r17

	//check if line1
	cpi r16, 1
    breq line_1

	//check if line2
	cpi r16, 2
	breq line_2
	//check if line3
	cpi r16, 3
	breq line_3
	//check if line4
	cpi r16,0
	breq line_4

line_1:
	ldi ZH, high(line1)
	ldi ZL, low(line1)
	pushSW(ZH)
	pushSW(ZL)
	jmp msg_end
line_2:
	ldi ZH, high(line2)
	ldi ZL, low(line2)
	pushSW(ZH)
	pushSW(ZL)
	jmp msg_end
line_3:
	ldi ZH, high(line3)
	ldi ZL, low(line3)
	pushSW(ZH)
	pushSW(ZL)
	jmp msg_end
line_4:
	ldi ZH, high(line4)
	ldi ZL, low(line4)
	pushSW(ZH)
	pushSW(ZL)
	jmp msg_end
msg_end:
	pop r17 
	ret
	

 msg1_p: .db "I love Assembly!!", 0
 msg2_p: .db "It's So Confusing", 0
 msg3_P: .db "*****************", 0
 .dseg
 //total message length = 18 characters 17 plus null
 .equ msg_length = 18 
 //these are not used
 msg1: .byte msg_length
 msg2: .byte msg_length 
 //this is used
 msg3: .byte msg_length
 //contain strings to be displated on the LCD
 //Each time through the characters are copied into these memory locations
 line1: .byte msg_length
 line2: .byte msg_length
 line3: .byte msg_length
 line4: .byte msg_length

 line_store1: .byte msg_length
 line_store2: .byte msg_length
 counter: .db 1
 direction: .db 1
 
 LCDCacheTopLine: .byte msg_length
 LCDCacheBottomLine:  .byte msg_length