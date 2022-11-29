; ChromaticScale.asm
; Plays a chromatic scale using the
; tone generator peripheral with
; switches used to control volume.

ORG 0

	; Set to note mode
	LOADI  2	
	OUT    Mode
	
	; Set volume
	LOADI  1
	OUT	   Volume
	
	LOADI  &B001100000
	STORE  Value
	;OUT    NoteAddr
	
	; Octave = 3
	LOADI 3
	STORE Octave
OctLoop:
    ; Octave < 7
	LOAD Octave
	ADDI -6
	JPOS EndOctLoop
	
	; Note = 0
	LOADI 0 
	STORE Note
	
	; Value = 0
	LOAD Value
	AND AndBitMask
	STORE Value
	
NoteLoop:
	; Note < 12
	LOAD Note
	ADDI -11
	JPOS EndNoteLoop
	
	;Set Volume
	IN Switches
	AND VolBitMask
	OUT Volume
	
	
	; Play Note
	LOAD Value
	OUT Hex0
	OUT LEDs
	OUT NoteAddr
	
	CALL   Delay
	CALL   Delay

	
	; Note++
	LOAD Note
	ADDI 1
	STORE Note
	; Value++ 
	LOAD Value
	ADDI 1
	STORE Value
	
	JUMP   NoteLoop
EndNoteLoop:
	
	; Octave++
	LOAD Octave
	ADDI 1
	STORE Octave
	; Value++
	LOAD Value
	ADDI &B100000
	STORE Value
	
	JUMP OctLoop
EndOctLoop:

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
	
; LVs
Octave: 	   DW  000
Note:	   DW  000
Value:	   DW  000
AndBitMask:	DW &B111100000
VolBitMask: DW &B000000011

; IO address constants
Switches:  EQU 000
LEDs:      EQU 001
Timer:     EQU 002
Hex0:      EQU 004
Hex1:      EQU 005
Mode: 	   EQU &H40
TW:		   EQU &H41
NoteAddr:      EQU &H42
Volume:	   EQU &H43




