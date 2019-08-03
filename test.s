		OUTPUT	.PRG
		COMMENT	HEAD=%100111			; Super,MallocInTT-RAM,LoadInTT-RAM,Fastload
		;OPT	D-

SCREEN_WIDTH	EQU	256
SCREEN_HEIGHT	EQU	240
SCREEN_DEPTH	EQU	4
SCREENS		EQU	2

TBCR_VALUE	EQU	%1000				; event mode
TBDR_VALUE	EQU	1				; every TBDR_VALUE raster lines

SCREEN_OFFSETS	EQU	256
SIN_ENTRIES	EQU	256

; ------------------------------------------------------
		SECTION	TEXT
; ------------------------------------------------------

begin:		movea.l	4(sp),a5			; address to basepage
		move.l	$0c(a5),d0			; length of text segment
		add.l	$14(a5),d0			; length of data segment
		add.l	$1c(a5),d0			; length of bss segment
		add.l	#$100+$100,d0			; length of stackpointer+basepage
		move.l	a5,d1				; address to basepage
		add.l	d0,d1				; end of program
		and.b	#%11111100,d1			; make address long even
		movea.l	d1,sp				; new stackspace

		move.l	d0,-(sp)			; Mshrink()
		move.l	a5,-(sp)			;
		clr.w	-(sp)				;
		move.w	#$4a,-(sp)			;
		trap	#1				;
		lea	12(sp),sp			;

		move.w	#0,-(sp)			; mxalloc()
		move.l	#SCREENS*SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_DEPTH/8+65535,-(sp)
		move.w	#$44,-(sp)			;
		trap	#1				;
		addq.l	#8,sp				;

		add.l	#65535,d0
		and.l	#$ffff0000,d0
		move.l	d0,video_ram

		move.l	video_ram,a0
		move.w	#SCREENS*SCREEN_WIDTH*SCREEN_HEIGHT*SCREEN_DEPTH/8/4-1,d7
.clear_loop:	clr.l	(a0)+
		dbra	d7,.clear_loop

		move.l	video_ram,a1
		lea	tubes,a0
		move.w	#SCREENS*SCREEN_WIDTH*SCREEN_DEPTH/8/4-1,d7
.tube_loop:	move.l	(a0)+,(a1)+
		dbra	d7,.tube_loop

		lea	pal+16*3,a0
		lea	falcon_pal,a1
		move.w	#224,d7
		bsr	convert_pal
		lea	pal+16*3,a0
		lea	falcon_pal+224*1*4,a1
		move.w	#224,d7
		bsr	convert_pal
		lea	pal+16*3,a0
		lea	falcon_pal+224*2*4,a1
		move.w	#224,d7
		bsr	convert_pal

		lea	video_ml,a1
		lea	video_scroll,a2
		move.l	video_ram,d0			; d0.l: $00hhmmll
		move.w	#SCREEN_OFFSETS/16-1,d7

.offset_loop:	move.l	d0,d4				; d4.l: $00hhmmll
		lsl.l	#8,d4				; d4.l: $hhmmll00
		rol.w	#8,d4				; d4.l: $hhmm00ll

		clr.b	d5				; d5.b: scroll counter
		move.w	#16-1,d6

.scroll_loop:	move.l	d4,(a1)+
		move.b	d5,(a2)+
		addq.b	#1,d5
		dbra	d6,.scroll_loop

		addq.l	#4*2,d0				; add 16 pixels (4 words)
		dbra	d7,.offset_loop

		clr.l	-(sp)				; Super()
		move.w	#$20,-(sp)			;
		trap	#1				;
		addq.l	#6,sp				;
		move.l	d0,old_stack

		bsr	save_cache
		bsr	set_cache

		bsr	save_res
		bsr	set_res

		move.w	#$2700,sr			; ints off

		move.l	$70.w,old_vbl
		move.l	#my_vbl,$70.w

		move.l	$120.w,old_timerb
		move.l	#my_timerb,$120.w

		move.b	$fffffa1b.w,old_tbcr
		move.b	$fffffa21.w,old_tbdr

		move.b	$fffffa07.w,old_fa07
		move.b	$fffffa13.w,old_fa13

		move.b	$fffffa09.w,old_fa09
		move.b	$fffffa15.w,old_fa15

		; IE Register A:
		; bit 7: Monochrome Monitor Detect
		; bit 6: RS-232 Ring Indicator
		; bit 5: Timer A
		; bit 4: Receive Buffer Full
		; bit 3: Receive Buffer Empty
		; bit 2: Sender Buffer Empty
		; bit 1: Sender Error
		; bit 0: Timer B
		move.b	#%00000001,$fffffa07.w
		move.b	#%00000001,$fffffa13.w

		; IE Register B:
		; bit 7: FDC/HDC
		; bit 6: Keyboard/MIDI
		; bit 5: Timer C
		; bit 4: Timer D
		; bit 3: Blitter
		; bit 2: RS-232 Clear To Send
		; bit 1: RSR-232 Carrier Detect
		; bit 0: Centronics BUSY
		move.b	#%01000000,$fffffa09.w
		move.b	#%01000000,$fffffa15.w

		move.w	#$2300,sr			; ints back (since level 4)


.wait:		cmpi.b	#$39,$fffffc02.w		;
		bne.b	.wait				;


		move.w	#$2700,sr			; ints off

		move.l	old_vbl,$70.w

		move.l	old_timerb,$120.w

		move.b	old_fa07,$fffffa07.w
		move.b	old_fa13,$fffffa13.w

		move.b	old_fa09,$fffffa09.w
		move.b	old_fa15,$fffffa15.w

		move.b	old_tbcr,$fffffa1b.w
		move.b	old_tbdr,$fffffa21.w

		move.w	#$2300,sr			; ints back (since level 4)

		bsr	restore_res

		bsr	restore_cache

		move.l	old_stack,-(sp)			; Super()
		move.w	#$20,-(sp)			;
		trap	#1				;
		addq.l	#6,sp				;

		clr.w	-(sp)				; Pterm0()
		trap	#1

my_vbl:		movem.l	d0-a4,-(sp)

		clr.b	$fffffa1b.w
		move.b	#TBDR_VALUE,$fffffa21.w		; Timer B Data
		move.b	#TBCR_VALUE,$fffffa1b.w		; Timer B Control

		lea	sin_tab+SIN_ENTRIES*2/2,a0
		lea	falcon_pal,a1
		add.l	pal_offset,a1
		lea	video_ml+SCREEN_OFFSETS*4/2,a2
		lea	video_scroll+SCREEN_OFFSETS*1/2,a3
		lea	plasma_buffer,a4
		move.w	#SCREEN_HEIGHT-1,d7

		move.b	plasma_X2,d1
		move.b	plasma_X1adc,d3
		move.b	plasma_X2adc,d4

		add.b	d3,plasma_adc1
		move.b	plasma_adc1,d3
		add.b	d4,plasma_adc2
		move.b	plasma_adc2,d4

.offset_loop:	add.b	plasma_X1,d3
		ext.w	d3
		move.w	(a0,d3.w*2),d5

		add.b	d1,d4
		ext.w	d4
		move.w	(a0,d4.w*2),d2

		add.b	d2,d5
		ext.w	d5

		move.l	(a1)+,(a4)+
		move.l	(a2,d5.w*4),(a4)+
		move.b	(a3,d5.w*1),(a4)+

		dbra	d7,.offset_loop

.offsets_done:	lea	plasma_buffer,a5
		lea	$ffff9800.w,a6
		move.l	(a5)+,(a6)+			; $rrgg00bb
		; $00xx0000 + 256*240*4/2 = $00xx7800
		move.b	video_ram+1,$ffff8201.w
		move.l	(a5)+,d0			; d0.l: $00mm00ll
		swap	d0
		move.b	d0,$ffff8203.w
		swap	d0
		move.b	d0,$ffff820d.w
		move.b	(a5)+,$ffff8265.w		; $oo (0 ~ 15)
		move.w	#(SCREEN_WIDTH/16)*4,$ffff820e.w ; (hz res/16) * #bitplanes

		addq.w	#2,pal_counter
		cmp.w	#16,pal_counter
		ble.b	.done

		move.w	#1,pal_counter

		sub.l	#16*4,pal_offset
		bne.b	.done

		move.l	#224*4,pal_offset

.done:		movem.l	(sp)+,d0-a4
		rte

; a5: plasma_buffer
; a6: $ffff9800
my_timerb:	move.l	(a5)+,(a6)+

.wait:		btst	#0,$ffff82a1.w			; left half-line? (low byte of VFC)
		bne.b	.wait				; no, we are still on the right one

		move.l	(a5)+,$ffff8206.w
		move.b	(a5)+,$ffff8265.w

		bclr	#0,$fffffa0f.w			; clear in service bit
		rte

; a0: rrrrrrrr gggggggg bbbbbbbb
; a1: rrrrrr00 gggggg00 00000000 bbbbbb00
; d7: number of palette entries

convert_pal:	subq.w	#1,d7
.loop:		clr.l	d0
		move.b	(a0)+,d0
		lsl.l	#8,d0
		move.b	(a0)+,d0
		swap	d0
		move.b	(a0)+,d0
		move.l	d0,(a1)+
		dbra	d7,.loop
		rts

save_cache:	movec	cacr,d0
		move.l	d0,save_cacr
		rts

set_cache:	movec	cacr,d0
		bset	#0,d0				; i cache on
		;bclr	#0,d0
		bset	#4,d0				; i burst on
		;bclr	#4,d0
		bclr	#8,d0				; d cache off
		bclr	#12,d0				; d burst off
		movec	d0,cacr
		rts

restore_cache:	move.l	save_cacr,d0
		bset	#11,d0				; clear data cache
		bset	#3,d0				; clear inst cache
		movec	d0,cacr
		rts

set_res:	bsr	wait_vbl

		lea	res+122,a0
		move.l	(a0)+,$ffff8282.w
		move.l	(a0)+,$ffff8286.w
		move.l	(a0)+,$ffff828a.w
		move.l	(a0)+,$ffff82a2.w
		move.l	(a0)+,$ffff82a6.w
		move.l	(a0)+,$ffff82aa.w
		move.w	(a0)+,$ffff820a.w
		move.w	(a0)+,$ffff82c0.w
		clr.w	$ffff8266.w
		tst.w	(a0)+
		bne.b	.st

.falcon:	move.w	(a0)+,$ffff8266.w
		bra.b	.skip

.st:		addq.l	#1,a0
		move.b	(a0)+,$ffff8260.w

.skip:		move.w	(a0)+,$ffff82c2.w
		move.w	(a0)+,$ffff8210.w
		rts

save_res:	bsr	wait_vbl

		lea	$ffff9800.w,a0			; save falcon palette
		lea	save_pal,a1			;
		moveq	#128-1,d7			;
.loop:		move.l	(a0)+,(a1)+			;
		move.l	(a0)+,(a1)+			;
		dbra	d7,.loop			;

		movem.l	$ffff8240.w,d0-d7		; save st palette
		movem.l	d0-d7,(a1)			;

		lea	save_video,a0
		move.l	$ffff8200.w,(a0)+		; vidhm
		move.w	$ffff820c.w,(a0)+		; vidl

		move.l	$ffff8282.w,(a0)+		; h-regs
		move.l	$ffff8286.w,(a0)+		;
		move.l	$ffff828a.w,(a0)+		;

		move.l	$ffff82a2.w,(a0)+		; v-regs
		move.l	$ffff82a6.w,(a0)+		;
		move.l	$ffff82aa.w,(a0)+		;

		move.w	$ffff82c0.w,(a0)+		; vco
		move.w	$ffff82c2.w,(a0)+		; c_s

		move.l	$ffff820e.w,(a0)+		; offset
		move.w	$ffff820a.w,(a0)+		; sync

		move.b  $ffff8265.w,(a0)+		; p_o

		cmpi.w   #$b0,$ffff8282.w		; st(e) / falcon test
		sle	(a0)+				; it's a falcon resolution

		move.w	$ffff8266.w,(a0)+		; f_s
		move.w	$ffff8260.w,(a0)+		; st_s
		rts

restore_res:	bsr	wait_vbl

		lea	save_video,a0

		move.l	(a0)+,$ffff8200.w		; videobase_address:h&m
		move.w	(a0)+,$ffff820c.w		; l

		move.l	(a0)+,$ffff8282.w		; h-regs
		move.l	(a0)+,$ffff8286.w		;
		move.l	(a0)+,$ffff828a.w		;

		move.l	(a0)+,$ffff82a2.w		; v-regs
		move.l	(a0)+,$ffff82a6.w		;
		move.l	(a0)+,$ffff82aa.w		;

		move.w	(a0)+,$ffff82c0.w		; vco
		move.w	(a0)+,$ffff82c2.w		; c_s

		move.l	(a0)+,$ffff820e.w		; offset
		move.w	(a0)+,$ffff820a.w		; sync

	        move.b  (a0)+,$ffff8265.w		; p_o

	        tst.b   (a0)+   			; st(e) compatible mode?
        	bne.b   .ste				; yes

		move.w  (a0),$ffff8266.w		; falcon-shift

		move.w  $ffff8266.w,-(sp)		; Videl patch
		bsr	wait_vbl			; to avoid monochrome
		clr.w   $ffff8266.w			; sync errors
		bsr	wait_vbl			; (as seen in
		move.w	(sp)+,$ffff8266.w		; FreeMiNT kernel)

		bra.b	.video_restored

.ste:		;clr.w	$ffff8266.w
		move.w	(a0)+,$ffff8266.w		; falcon-shift
		move.w  (a0),$ffff8260.w		; st-shift
		lea	save_video,a0
		move.w	32(a0),$ffff82c2.w		; c_s
		move.l	34(a0),$ffff820e.w		; offset
.video_restored:

		lea	save_pal,a0			; restore falcon palette
		lea	$ffff9800.w,a1			;
		moveq	#128-1,d7			;
.loop:		move.l	(a0)+,(a1)+			;
		move.l	(a0)+,(a1)+			;
		dbra	d7,.loop			;

		movem.l	(a0),d0-d7			; restore st palette
		movem.l	d0-d7,$ffff8240.w		;
		rts

wait_vbl:	move.w	#$25,-(sp)			; Vsync()
		trap	#14				;
		addq.l	#2,sp				;
		rts

; ------------------------------------------------------
		SECTION	DATA
; ------------------------------------------------------

		EVEN
res:		incbin	"scp\16\256240v4.scp"
pal:		incbin	"atari800.pal"
tubes:		incbin	"tubes.bin"

pal_counter:	dc.w	1
pal_offset:	dc.l	224*4

		incbin	"sin_tab.bin"
sin_tab:	incbin	"sin_tab.bin"
		incbin	"sin_tab.bin"

plasma_X1	dc.b	5;	$7e	;8
plasma_X2	dc.b	-4;	1	;-9
plasma_X1adc	dc.b	1;	0	;1
plasma_X2adc	dc.b	1;	5	;1
plasma_adc1	dc.b	0
plasma_adc2	dc.b	0

; ------------------------------------------------------
		SECTION	BSS
; ------------------------------------------------------

		EVEN
old_stack:	ds.l	1
old_vbl:	ds.l	1
old_timerb:	ds.l	1

old_tbcr:	ds.b	1
old_tbdr:	ds.b	1

old_fa09:	ds.b	1
old_fa15:	ds.b	1
old_fa07:	ds.b	1
old_fa13:	ds.b	1

video_ram:	ds.l	1

save_pal:	ds.l	256+16/2			; old colours (falcon+st/e)
save_video:	ds.b	32+12+2				; videl save
save_cacr:	ds.l	1				; old cache settings

falcon_pal:	ds.l	224*3

video_ml:	ds.l	SCREEN_OFFSETS			; $00mm00ll
video_scroll:	ds.b	SCREEN_OFFSETS			; $oo

plasma_buffer:	ds.b	(4+4+1)*SCREEN_HEIGHT
