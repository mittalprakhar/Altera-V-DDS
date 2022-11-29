; TuningWord.asm
; Sends the value from the switches as
; the tuning word value to the tone
; generator peripheral once per second.

ORG 0
	; Get the switch values
	IN     Switches

	; Send to the peripheral
	OUT    TW
	
	; Set mode
	LOADI  1	
	OUT    Mode

	; Delay for 1 second
	CALL   Delay

	; Do it again
	JUMP   0
	
; Subroutine to delay for 0.2 seconds.
Delay:
	OUT    Timer
WaitingLoop:
	IN     Timer
	ADDI   -2
	JNEG   WaitingLoop
	RETURN

; IO address constants
Switches:  EQU 000
Timer:     EQU 002
Mode: 	   EQU &H40
TW:        EQU &H41