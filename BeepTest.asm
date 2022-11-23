; BeepTest.asm
; Sends the value from the switches to the
; tone generator peripheral once per second.

ORG 0

	; Get the switch values
	IN     Switches
	; Send to the peripheral
	OUT    Note
	
	; Set mode
	LOADI  2	
	OUT    Mode
	
	; Set volume
	LOADI  1
	OUT	   Volume
	
	CALL   Delay
	CALL   Delay
	CALL   Delay
	CALL   Delay
	CALL   Delay
	
	; Get the switch values
	IN     Switches
	; Send to the peripheral
	OUT    Note
	
	; Set mode
	LOADI  2	
	OUT    Mode
	
	; Set volume
	LOADI  2
	OUT	   Volume
	
	CALL   Delay
	CALL   Delay
	CALL   Delay
	CALL   Delay
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
LEDs:      EQU 001
Timer:     EQU 002
Hex0:      EQU 004
Hex1:      EQU 005
Mode: 	   EQU &H40
TW:		   EQU &H41
Note:      EQU &H42
Volume:	   EQU &H43