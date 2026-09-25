*-----------------------------------------------------------------------
* SCUMM for the Apple IIGS - an interpreter for the V2 games
* (Maniac Mansion, Zak McKracken)
*
* It reads the original .LFL files directly: the index, the rooms, the
* scripts. Nothing is pre-cooked, so the same program serves any V2 game
* and the disk stays small (567 KB instead of the 1.7 MB a set of
* already-converted rooms would need).
*
* The EGA palette lands exactly on the IIGS four-bits-per-channel grid:
* the game's colour indices are already the screen's indices, and with
* the same sixteen colours on every scanline no remapping table is
* needed, unlike BASS.
*
* Merlin32 / Brutal Deluxe
*
* Copyright (C) 2026 Michele Di Paola
*
* This program is free software; you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the
* Free Software Foundation; either version 2 of the License, or (at your
* option) any later version. It comes with ABSOLUTELY NO WARRANTY.
*
* The file formats and the opcode table were worked out from ScummVM and
* scummvm-tools, which are GPL-2.0-or-later.
*-----------------------------------------------------------------------
                 rel
                 dsk   SCUMM
                 typ   $B3
                 xc
                 xc
                 use   4/Locator.Macs
                 use   4/Mem.Macs
                 use   4/Misc.Macs
                 use   4/Event.Macs
                 use   4/Qd.Macs
                 use   4/Util.Macs

*----- screen ----------------------------------------------------------
SHRBASE          =     $E12000
SCBOFF           =     $7D00
PALOFF           =     $7E00
SCRW             =     160            ; bytes per screen row
SCRW2            =     320            ; and the pixels, which are double
SCRPIX           =     320
ROOMROWS         =     128            ; V2's play area

* The V2 screen, the way initScreens divides it: two lines of text at
* the top, then the room, then the panel. The scripts count rows on this
* layout, which is why they place the verbs at 152.
ROOMTOP          =     16             ; the room starts below the speech
ROOMOFF          =     2560           ; 16*160: its first byte
ROOMOFF2         =     2720           ; and the next row
MSGTOP           =     0              ; the speech: two rows at the top
MSGFONDO         =     16
PANTOP           =     144            ; the panel
PANOFF           =     23040          ; 144*160
PANEND           =     32000
SENTTOP          =     144            ; the sentence being built
INVTOP           =     176            ; the four inventory boxes
INVROW2          =     184
DBGTOP           =     192            ; the last row, for faults
CRED1TOP         =     176            ; the credit, where on the
CRED2TOP         =     184            ; credits there is nothing else
MSGMAX           =     240
NNOMI            =     10             ; renamed objects
INVSLOTS         =     16             ; objects that can be carried
INVLEN           =     256            ; the game's longest obcd fits
PREPLEN          =     6
NACT             =     25             ; the game's actors
NCOST            =     6              ; costumes held in memory at once
COSTLEN          =     4096
COSTSIZE         =     24576
NVERBS           =     16             ; the game uses fifteen
NSENT            =     6              ; sentences waiting
VERBTOP          =     152            ; where the game puts the panel
VERBEND          =     176
* The three verb-panel colours, as the DOS version sets them: picked by
* o2_verbOps, in the branch that is neither C64 nor NES.
COLVERB          =     2              ; at rest: EGA green
COLVERBHI        =     14             ; under the pointer: the yellow
COLVERBDIM       =     8              ; disabled by the game: dark grey
COLSENT          =     13             ; the purple of sentence and inventory
COLSENTHI        =     14

VAR_MOUSEX       =     30
VAR_MOUSEY       =     31
VAR_CLICKAREA    =     32
VAR_CLICKVERB    =     33
VAR_CLICKOBJ     =     35
VAR_ACTVERB      =     8
VAR_ACTOBJ1      =     9
VAR_ACTOBJ2      =     10
VAR_VERBOK       =     18
VAR_CURSOR       =     21             ; the game keeps the cursor state here
VAR_SENTPREP     =     29
VAR_TIMERNEXT    =     25
VAR_ACTMIN       =     19
VAR_ACTMAX       =     20
XMOVE0           =     $FFB8          ; -72: V2's fixed offset
YMOVE0           =     $FF9C          ; -100
VAR_HAVEMSG      =     3              ; "there is a message on screen"
VAR_CHARCNT      =     7              ; how many letters have come out
VAR_BACKVERB     =     38             ; the verb to fall back to after a sentence
VAR_KEY          =     39             ; the key pressed, as V2 counts it
VAR_SENTVERB     =     26
VAR_SENTOBJ1     =     27
VAR_SENTOBJ2     =     28
SCR_VERB         =     4              ; the script the game uses for clicks
SCR_SENT         =     2              ; and the one that runs sentences
SCR_ENTRA        =     5              ; the one that runs on entering a room

*----- memory ----------------------------------------------------------
RAWSIZE          =     27136          ; the biggest .LFL is 25510
PIXSIZE          =     65536          ; 960*128 at half a byte = 61440
SLOTS            =     12             ; scripts at once
SLOTLEN          =     $0C00          ; 3072 bytes per script (the
RESSIZE          =     36864          ; biggest real one takes 2674)
MASKSIZE         =     20480          ; 960/8 by 128: one bit per pixel

*----- the game --------------------------------------------------------
MAGICV2          =     $0100          ; signature of the DOS V2 index
NVARS            =     256
MAXOBJ           =     800
MAXSCR           =     256
MAXCOS           =     64
MAXSND           =     128

VAR_ROOM         =     4
VAR_LIGHTS       =     12
VAR_CAMMIN       =     23
VAR_CAMMAX       =     24
VAR_CAMPOS       =     2
VAR_EGO          =     0

* The system variables, already counted in bytes: Merlin evaluates
* expressions left to right, so Vars+VAR_X*2 would mean (Vars+VAR_X)*2.
* Keeping the doubled value here lets us simply write Vars+VO_X.
VO_ACTOBJ1        =     VAR_ACTOBJ1*2
VO_ACTOBJ2        =     VAR_ACTOBJ2*2
VO_ACTVERB        =     VAR_ACTVERB*2
VO_CAMMAX         =     VAR_CAMMAX*2
VO_CAMMIN         =     VAR_CAMMIN*2
VO_CAMPOS         =     VAR_CAMPOS*2
VO_EGO            =     VAR_EGO*2
VO_CLICKAREA      =     VAR_CLICKAREA*2
VO_CLICKVERB      =     VAR_CLICKVERB*2
VO_CLICKOBJ       =     VAR_CLICKOBJ*2
VO_LIGHTS         =     VAR_LIGHTS*2
VO_MOUSEX         =     VAR_MOUSEX*2
VO_MOUSEY         =     VAR_MOUSEY*2
VO_ROOM           =     VAR_ROOM*2
VO_SENTOBJ1       =     VAR_SENTOBJ1*2
VO_SENTOBJ2       =     VAR_SENTOBJ2*2
VO_SENTVERB       =     VAR_SENTVERB*2
VO_VERBOK         =     VAR_VERBOK*2
VO_CURSOR         =     VAR_CURSOR*2
VO_SENTPREP       =     VAR_SENTPREP*2
VO_TIMERNEXT      =     VAR_TIMERNEXT*2
VO_ACTMIN         =     VAR_ACTMIN*2
VO_ACTMAX         =     VAR_ACTMAX*2
VO_BACKVERB       =     VAR_BACKVERB*2
VO_HAVEMSG        =     VAR_HAVEMSG*2
VO_CHARCNT        =     VAR_CHARCNT*2
VO_KEY            =     VAR_KEY*2

MORTO            =     0
VIVO             =     1
DA_POOL          =     0
DA_STANZA        =     1
DA_MANO          =     2

*----- how a command ended ---------------------------------------------
VAI              =     0              ; carry on with the next
CEDI             =     1              ; the script yields
FINE             =     2              ; the script has ended

CreateGS         =     $2001
DestroyGS        =     $2002
OpenGS           =     $2010
ReadGS           =     $2012
WriteGS          =     $2013
CloseGS          =     $2014

* The save-game disk
NPOS             =     10             ; the slots on disk, Game A..J
FIRMALEN         =     8
CAPOLEN          =     FIRMALEN
SCR_VERBI        =     164            ; the script that rebuilds the panel
SetMarkGS        =     $2016
QuitGS           =     $2029

*----- our own direct page ---------------------------------------------
zpRaw            =     $00            ; the current room's file
zpRes            =     $04            ; the script store
zpCode           =     $08            ; the code being run
zpPix            =     $0C            ; the room pixels (a whole bank)
zpSrc            =     $10            ; where the compression is read
zpStr            =     $14
zpBg             =     $18            ; the room without objects, to put them back
zpCost           =     $1C            ; the costume store
zpMask           =     $20            ; the mask: who is in front of whom
zpNome           =     $24            ; the description whose name we want

*=======================================================================
Start            phk
                 plb
                 clc
                 xce
                 rep   #$30
                 mx    %00

                 _TLStartUp
                 pha
                 _MMStartUp
                 pla
                 sta   MyID
                 _MTStartUp

*----- six direct pages: three for QuickDraw, one for the Event --------
*      Manager, and the last one is ours.
                 PushLong #0
                 PushLong #$00000600
                 PushWord MyID
                 PushWord #$C005
                 PushLong #0
                 _NewHandle
                 PullLong DPHandle
                 bcc   :dpok
                 brl   NoMem
:dpok            lda   DPHandle
                 sta   $00
                 lda   DPHandle+2
                 sta   $02
                 lda   [$00]
                 sta   DPAddr

                 PushWord DPAddr
                 PushWord #$0000            ; 320 mode
                 PushWord #SCRPIX
                 PushWord MyID
                 _QDStartUp

                 lda   DPAddr
                 clc
                 adc   #$0300
                 pha
                 PushWord #20
                 PushWord #0
                 PushWord #SCRPIX
                 PushWord #0
                 PushWord #200
                 PushWord MyID
                 _EMStartUp

                 lda   DPAddr
                 clc
                 adc   #$0500
                 tcd

*----- the three memory blocks -----------------------------------------
* No alignment is needed: the 65816's [long pointer],Y addressing carries
* into the bank by itself, and the offsets in here never exceed the
* 61440 bytes of one room.
                 PushLong #RAWSIZE
                 PushWord #$C000            ; locked, fixed, one bank only
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpRaw
                 lda   BlockHi
                 sta   zpRaw+2

                 PushLong #RESSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpRes
                 lda   BlockHi
                 sta   zpRes+2

                 PushLong #PIXSIZE
                 PushWord #$C000            ; locked and fixed
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpPix
                 sta   PixBase
                 lda   BlockHi
                 sta   zpPix+2

                 PushLong #PIXSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpBg
                 lda   BlockHi
                 sta   zpBg+2

                 PushLong #MASKSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpMask
                 lda   BlockHi
                 sta   zpMask+2

                 PushLong #COSTSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcc   :memok
:nomem           brl   NoMem
:memok           lda   BlockLo
                 sta   zpCost
                 lda   BlockHi
                 sta   zpCost+2

*----- go --------------------------------------------------------------
                 jsr   ClearScreen
                 jsr   SetPalette
                 _InitCursor
                 PushPtr FrecciaCur         ; our own arrow, which shows
                 ldx   #$1104               ; in the dark too (SetCursor)
                 jsl   $E10000

                 jsr   LoadIndex
                 bcc   :indexok
                 brl   DiskError
:indexok         jsr   ResetVM

* At power-on the lights are on: variable 12 starts at zero, which means
* pitch dark, and without this the title screen came up black.
                 lda   #11
                 sta   Vars+VO_LIGHTS
                 sta   BuioStato

                 lda   #1                   ; the boot script
                 jsr   StartScript

*=======================================================================
MainLoop         jsr   Orologio
                 jsr   MsgTick
                 jsr   RunScripts
                 jsr   CheckSentence
* A game frame is not a loop iteration. Between one frame and the next,
* V2 waits the number of ticks the game keeps in variable 25
* (VAR_TIMER_NEXT): usually four, that is fifteen frames per second.
* Without that wait, on an idle machine the character took a step every
* sixtieth of a second and ran.
                 lda   Vars+VO_TIMERNEXT
                 bne   :hadetto
                 lda   #4                   ; the game has not said yet
:hadetto         cmp   #16
                 bcc   :nontroppo
                 lda   #15
:nontroppo       sta   PassoT
                 lda   TickAcc
                 clc
                 adc   Elapsed
                 sta   TickAcc
                 cmp   PassoT
                 bcc   :nocam
                 sec
                 sbc   PassoT               ; the remainder is kept for next,
                 cmp   PassoT               ; but long delays are not made up
                 bcc   :avanzook            ; long
                 lda   #0
:avanzook        sta   TickAcc
                 jsr   MoveCamera
                 jsr   AnimActors
                 jsr   MoveActors
                 jsr   RidisegnaAttori
:nocam           anop

* Safety net: if the scroll has changed since the last time the whole
* window was blitted, redraw everything anyway. A small rectangle would
* not do, and the screen would keep looking at the old position.
* If the lights changed, the room held in memory is no longer right:
* either it was black and is now visible, or the other way round.
                 lda   RoomH
                 beq   :luceok
                 lda   Vars+VO_LIGHTS
                 and   #6
                 cmp   BuioStato
                 beq   :luceok
                 lda   BuioStato            ; it was lit: darkening is only a
                 bne   :bastacomporre       ; matter of composing again
                 jsr   DecodeRoom           ; it was dark, and the black was
:bastacomporre   lda   #1                   ; laid on the room itself: the
                 sta   DaComporre           ; background has to come back
:luceok          lda   DaComporre
                 beq   :compostook
                 jsr   ComponiStanza
                 lda   #1
                 sta   Redraw
:compostook      anop

                 lda   ScrollX
                 cmp   ScrollDis
                 beq   :scrollok
                 lda   #1
                 sta   Redraw
:scrollok        lda   Redraw
                 beq   :nodraw
                 cmp   #2
                 beq   :pezzo
                 stz   Redraw
                 jsr   DrawRoom
                 bra   :nodraw
:pezzo           stz   Redraw
                 jsr   BlitRett
:nodraw          jsr   GuardaVerbo          ; the verb under the pointer
                 cmp   VerbLast             ; lights up, as in the DOS version
                 beq   :stesso
                 sta   VerbLast
                 lda   #1
                 sta   VerbsDirty
                 lda   #1
                 sta   PanDirty
:stesso          lda   VerbsDirty
                 beq   :noverb
                 stz   VerbsDirty
                 jsr   DrawVerbs

* the sentence being built: if one of its four parts changed it is
* rewritten, without touching the rest of the panel
:noverb          lda   Vars+VO_SENTVERB
                 clc
                 adc   Vars+VO_SENTOBJ1
                 clc
                 adc   Vars+VO_SENTOBJ2
                 clc
                 adc   Vars+VO_SENTPREP
                 cmp   SentLast
                 beq   :stessafrase
                 sta   SentLast
                 lda   #1
                 sta   PanDirty
:stessafrase     lda   PanDirty
                 beq   :nopan
                 stz   PanDirty
                 jsr   CiSonoVerbi
                 bcs   :nopan
                 jsr   DrawFrase
                 jsr   DrawInv
                 lda   DbgOn                ; the debug numbers change
                 ora   BadOp                ; constantly
                 beq   :nopan
                 jsr   DrawDbg
:nopan           lda   InvDirty
                 beq   :noinv
                 stz   InvDirty
                 jsr   CiSonoVerbi
                 bcs   :noinv
                 jsr   DrawInv
* In the dark, blitting in pieces does not work: the black is laid down
* by the full redraw, one row at a time.
:noinv           lda   Vars+VO_LIGHTS
                 and   #2
                 bne   :c_eluce
                 lda   Vars+VO_LIGHTS
                 and   #4
                 beq   :c_eluce
                 lda   #1                   ; the cone moves with whoever
                 sta   Redraw               ; carries it: redraw everything
:c_eluce         jsr   SayState

                 PushWord #0
                 PushWord #$FFFF
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 bne   :c_eevento
                 brl   :vivi
:c_eevento       lda   EvtWhat
                 cmp   #1                   ; button pressed
                 bne   :nonclic
                 jsr   DoClick
                 bra   :vivi
:nonclic         cmp   #3
                 beq   :tasto
                 cmp   #5
                 bne   :vivi
:tasto           lda   EvtMessage
                 and   #$00FF
                 cmp   #$1B
                 beq   :esci
                 cmp   #'q'
                 beq   :esci
                 cmp   #'Q'
                 beq   :esci
* service keys: to wander between rooms while the game cannot take us
* there by itself yet
                 cmp   #$2E                 ; full stop: next room
                 beq   :stanzaSu
                 cmp   #$2C                 ; comma: previous room
                 beq   :stanzaGiu
                 cmp   #$3B                 ; semicolon: ten rooms forward
                 beq   :stanzaDieci
                 cmp   #'d'                 ; D turns debug on and off
                 beq   :debug
                 cmp   #'D'
                 beq   :debug
                 jsr   TastoGioco
                 brl   :vivi
:debug           lda   DbgOn
                 eor   #1
                 sta   DbgOn
                 jsr   DrawDbg
                 brl   :vivi
:stanzaDieci     lda   CurRoom
                 clc
                 adc   #10
                 cmp   #54
                 bcc   :vai
                 lda   #1
                 bra   :vai
:stanzaSu        lda   CurRoom
                 inc   a
                 cmp   #54
                 bcc   :vai
                 lda   #1
                 bra   :vai
:stanzaGiu       lda   CurRoom
                 dec   a
                 bne   :vai
                 lda   #53
:vai             jsr   ChangeRoom
                 bra   :vivi

* Even when no script is alive any more we do not quit: whatever is on
* screen stays, so it can be looked at. Q or ESC closes.
:vivi            brl   MainLoop
:esci            brl   Shutdown

*=======================================================================
* TastoGioco - the keys the game expects. A = the character.
*=======================================================================
* The DOS version uses the function keys: F1, F2 and F3 to switch
* between kids, F5 for the disk. The IIGS has no such keys, so they come
* in through the Apple key: Apple-1, Apple-2, Apple-3, Apple-5.
* Return is 13, which in V2 means "run the sentence that is written
* there": it is the game's own way of confirming without clicking the
* object twice.
TastoGioco       sta   TastoQ
                 cmp   #$0D
                 bne   :conmela
                 lda   #13
                 bra   :manda
:conmela         lda   EvtModifiers
                 and   #$0100               ; the Apple key
                 beq   :niente
                 lda   TastoQ
                 cmp   #'1'
                 bcc   :niente
                 cmp   #'4'
                 bcc   :ragazzo             ; 1, 2, 3
                 cmp   #'5'
                 bne   :niente
                 lda   #5                   ; the disk
                 bra   :manda
:ragazzo         sec
                 sbc   #'0'
:manda           sta   Vars+VO_KEY
                 lda   #4                   ; pressed a key
                 sta   Vars+VO_CLICKAREA
                 lda   #SCR_VERB
                 jsr   StartScript
:niente          rts

*=======================================================================
* DoClick - the player pressed: set up what the game expects to find
*           and start its command script
*=======================================================================
DoClick          lda   EvtWhere             ; in IIGS points the vertical
                 sta   MouseY               ; the vertical comes first
                 lda   EvtWhere+2
                 sta   MouseX
                 lda   MouseY               ; if they were swapped we would
                 cmp   #200                 ; notice: the screen is
                 bcc   :ok                  ; 200 tall and 320 wide
                 lda   MouseX
                 cmp   #200
                 bcs   :ok
                 lda   MouseY
                 ldx   MouseX
                 stx   MouseY
                 sta   MouseX
:ok              lda   MouseX
                 cmp   #SCRPIX
                 bcs   :fine
                 lda   MouseY
                 cmp   #200
                 bcs   :fine

* The scripts count x in steps of eight and y in steps of two. Given
* pixels, walkActorTo got a target eight times too far away and the
* character shot off sideways.
                 lda   MouseX
                 clc
                 adc   ScrollX
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   Vars+VO_MOUSEX
                 lda   MouseY               ; the room starts below the
                 sec                        ; speech line
                 sbc   #ROOMTOP
                 bpl   :sottoiltesto
                 lda   #0
:sottoiltesto    lsr   a
                 sta   Vars+VO_MOUSEY

                 lda   MouseY
                 cmp   #ROOMTOP
                 bcc   :fine                ; the speech line does not answer
                 cmp   #PANTOP
                 bcs   :pannello
                 lda   #2                   ; clicked in the scene
                 sta   Vars+VO_CLICKAREA
                 bra   :avvia

* The panel has three parts: the sentence line, the verb buttons, and
* the inventory boxes.
:pannello        lda   MouseY
                 cmp   #VERBTOP
                 bcc   :frase
                 cmp   #INVTOP
                 bcs   :inventario

                 jsr   VerboSotto
                 bcs   :fine
                 lda   VerbId,x
                 sta   Vars+VO_CLICKVERB
                 lda   #1                   ; clicked a verb
                 sta   Vars+VO_CLICKAREA
                 bra   :avvia

:frase           lda   #5                   ; the sentence line
                 sta   Vars+VO_CLICKAREA
                 bra   :avvia

:inventario      lda   MouseY
                 cmp   #DBGTOP
                 bcs   :fine
                 jsr   OggettoSotto
                 bcs   :fine
                 sta   Vars+VO_CLICKOBJ
                 lda   #3                   ; clicked the inventory
                 sta   Vars+VO_CLICKAREA
:avvia           lda   #SCR_VERB
                 jsr   StartScript
:fine            rts

*=======================================================================
* OggettoSotto - which inventory object is under the pointer
*=======================================================================
* The four boxes sit in two rows and two columns, in the order
* DrawInvReal writes them. Carry set if there is nothing there.
OggettoSotto     lda   MouseY
                 cmp   #INVROW2
                 bcc   :primariga
                 lda   #2
                 bra   :rigaok
:primariga       lda   #0
:rigaok          sta   InvQuale
                 lda   MouseX
                 cmp   #144
                 bcc   :colonnaok           ; to the left
                 cmp   #176
                 bcc   :niente              ; the arrows are in between
                 inc   InvQuale
:colonnaok       stz   InvVisti
                 stz   InvIdx
:lp              ldx   InvIdx
                 lda   InvObj,x
                 beq   :prossimo
                 jsr   MioOggetto
                 bcs   :prossimo
                 lda   InvVisti
                 cmp   InvQuale
                 bne   :contato
                 ldx   InvIdx
                 lda   InvObj,x
                 clc
                 rts
:contato         inc   InvVisti
:prossimo        lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcc   :lp
:niente          sec
                 rts

*=======================================================================
* GetBlock - a memory block. On the stack: length (long), attributes
*            (word). Returns the address in BlockLo/BlockHi, carry if not.
*=======================================================================
GetBlock         pla                        ; return address
                 sta   RetAddr
                 pla
                 sta   Attr
                 pla
                 sta   Size
                 pla
                 sta   Size+2

                 PushLong #0
                 PushLong Size
                 PushWord MyID
                 PushWord Attr
                 PushLong #0
                 _NewHandle
                 PullLong TmpHandle
                 bcs   :male
                 lda   TmpHandle
                 ora   TmpHandle+2
                 beq   :male

                 lda   TmpHandle
                 sta   $F0
                 lda   TmpHandle+2
                 sta   $F2
                 lda   [$F0]
                 sta   BlockLo
                 ldy   #2
                 lda   [$F0],y
                 sta   BlockHi
                 clc
                 bra   :fine
:male            sec
:fine            lda   RetAddr
                 pha
                 rts

*=======================================================================
* LoadIndex - reads 00.LFL and builds the resource tables from it
*=======================================================================
LoadIndex        stz   FileNo
                 jsr   LoadWhole
                 bcc   :caricato
:kaputt          sec
                 rts

:caricato        ldy   #0
                 lda   [zpRaw],y
                 cmp   #MAGICV2
                 bne   :kaputt

* how many objects, and their initial state (owner low, state high)
                 ldy   #2
                 lda   [zpRaw],y
                 sta   NumObj
                 cmp   #MAXOBJ+1
                 bcs   :kaputt

                 ldy   #4
                 ldx   #0
                 sep   #$20
                 mx    %10
:obj             lda   [zpRaw],y
                 sta   ObjFlag,x
                 iny
                 inx
                 cpx   NumObj
                 bcc   :obj
                 rep   #$20
                 mx    %00
                 sty   IdxPos

* the four tables: rooms, costumes, scripts, sounds
                 lda   #0                   ; rooms are not kept: they are
                 jsr   SkipTable            ; separate files
                 lda   #MAXCOS
                 sta   TabMax
                 lda   #CosRoom
                 sta   TabRoom
                 lda   #CosOffs
                 sta   TabOffs
                 jsr   ReadTable
                 bcs   :male
                 sta   NumCos

                 lda   #MAXSCR
                 sta   TabMax
                 lda   #ScrRoom
                 sta   TabRoom
                 lda   #ScrOffs
                 sta   TabOffs
                 jsr   ReadTable
                 bcs   :male
                 sta   NumScr

                 lda   #MAXSND
                 sta   TabMax
                 lda   #SndRoom
                 sta   TabRoom
                 lda   #SndOffs
                 sta   TabOffs
                 jsr   ReadTable
                 bcs   :male
                 sta   NumSnd
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* SkipTable - skip a table (a count byte, then n bytes and n words)
*=======================================================================
SkipTable        ldy   IdxPos
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   TabN
                 iny
                 tya
                 clc
                 adc   TabN                 ; the room bytes
                 sta   IdxPos
                 lda   TabN
                 asl   a                    ; and the offset words
                 clc
                 adc   IdxPos
                 sta   IdxPos
                 rts

*=======================================================================
* ReadTable - a resource table into TabRoom/TabOffs. A = how many.
*=======================================================================
ReadTable        ldy   IdxPos
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   TabN
                 cmp   TabMax
                 bcc   :cape
                 sec
                 rts
:cape            iny
                 sty   IdxPos

                 lda   TabRoom
                 sta   zpStr
                 lda   #^ObjFlag
                 sta   zpStr+2
                 ldx   #0
                 sep   #$20
                 mx    %10
:stanze          lda   [zpRaw],y
                 sta   [zpStr]
                 inc   zpStr
                 bne   :nohi
                 inc   zpStr+1
:nohi            iny
                 inx
                 cpx   TabN
                 bcc   :stanze
                 rep   #$20
                 mx    %00

                 lda   TabOffs
                 sta   zpStr
                 ldx   #0
:offset          lda   [zpRaw],y
                 sta   [zpStr]
                 iny
                 iny
                 inc   zpStr
                 inc   zpStr
                 inx
                 cpx   TabN
                 bcc   :offset
                 sty   IdxPos
                 lda   TabN
                 clc
                 rts

*=======================================================================
* LoadWhole - load the whole of file FileNo into zpRaw and decipher it
*=======================================================================
LoadWhole        jsr   OpenLFL
                 bcs   :male
                 lda   zpRaw
                 sta   ReadBuf
                 lda   zpRaw+2
                 sta   ReadBuf+2
                 lda   #RAWSIZE
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 lda   ReadXfer
                 sta   RawLen
                 ora   ReadXfer+2
                 beq   :male
                 lda   zpRaw
                 sta   zpStr
                 lda   zpRaw+2
                 sta   zpStr+2
                 lda   RawLen
                 jsr   Decipher
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* Decipher - the whole game sits under an xor with $FF. A = how many bytes.
*=======================================================================
Decipher         inc   a                    ; round up to whole words
                 lsr   a
                 sta   DecN
                 ldy   #0
:lp              lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 dec   DecN
                 bne   :lp
                 rts

*=======================================================================
* OpenLFL - open file FileNo. Tries MM/NN.LFL and then 1/MM/NN.LFL
*=======================================================================
OpenLFL          lda   FileNo
                 ldy   #0
:dieci           cmp   #10
                 bcc   :unita
                 sec
                 sbc   #10
                 iny
                 bra   :dieci
:unita           sep   #$20
                 mx    %10
                 clc
                 adc   #'0'
                 sta   PathA+7
                 sta   PathB+9
                 tya
                 clc
                 adc   #'0'
                 sta   PathA+6
                 sta   PathB+8
                 rep   #$20
                 mx    %00

                 stz   PathUsata
                 lda   #PathA
                 sta   OpenPath
                 lda   #^PathA
                 sta   OpenPath+2
                 jsr   TryOpen
                 bcc   :fatto
                 lda   #1
                 sta   PathUsata
                 lda   #PathB
                 sta   OpenPath
                 lda   #^PathB
                 sta   OpenPath+2
                 jsr   TryOpen
                 bcs   :male
:fatto           lda   OpenRef
                 sta   ReadRef
                 sta   CloseRef
                 sta   MarkRef
                 clc
                 rts
:male            sec
                 rts

TryOpen          jsl   $E100A8
                 dw    OpenGS
                 adrl  OpenParm
                 rts

*=======================================================================
* ReadAndClose - read ReadCount bytes into ReadBuf and close
*=======================================================================
* GS/OS answers "end of file" when more bytes are asked for than there
* are: that is normal, only the count that actually arrived matters.
ReadAndClose     jsl   $E100A8
                 dw    ReadGS
                 adrl  ReadParm
                 jsl   $E100A8
                 dw    CloseGS
                 adrl  CloseParm
                 rts

*=======================================================================
* The actors
*=======================================================================
* A V2 character is an assembly: up to sixteen "limbs", each with its
* own frames, and a table saying, for every direction and movement,
* which frame each limb uses and how far to shift it. Drawing starts
* from a fixed offset of (-72, -100), which is how the game keeps the
* character standing on its feet.
*=======================================================================
* SlotCostume - A = costume number. Returns X = slot*2 in the store,
*               loading it if it is not there yet. Carry set if it cannot.
*=======================================================================
SlotCostume      sta   CostWant
                 ldx   #0
:cerca           lda   CostNum,x
                 cmp   CostWant
                 beq   :trovato
                 inx
                 inx
                 cpx   #NCOST*2
                 bcc   :cerca

* not there: load it over the oldest one
                 lda   CostWant
                 cmp   NumCos
                 bcs   :male
                 asl   a
                 tax
                 lda   CosOffs,x
                 sta   ScrOff
                 beq   :male
                 cmp   #$FFFF
                 beq   :male
                 ldx   CostWant
                 sep   #$20
                 mx    %10
                 lda   CosRoom,x
                 sta   FileNo
                 rep   #$20
                 mx    %00
                 lda   FileNo
                 and   #$00FF
                 sta   FileNo

                 lda   CostNext
                 sta   CostSlot
                 clc
                 adc   #2
                 cmp   #NCOST*2
                 bcc   :giro
                 lda   #0
:giro            sta   CostNext

                 lda   CostSlot             ; slot * 4096
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   CostOff
                 clc
                 adc   zpCost
                 sta   DestLo
                 lda   zpCost+2
                 adc   #0
                 sta   DestHi
                 lda   #COSTLEN
                 sta   DestMax
                 jsr   LoadResIn
                 bcs   :male
                 ldx   CostSlot
                 lda   CostWant
                 sta   CostNum,x
                 clc
                 rts
:trovato         clc
                 rts
:male            sec
                 rts

*=======================================================================
* BaseCostume - X = slot*2, points zpStr at the costume
*=======================================================================
BaseCostume      txa
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   zpCost
                 sta   zpStr
                 lda   zpCost+2
                 adc   #0
                 sta   zpStr+2
                 rts

*=======================================================================
* The state of the limbs
*=======================================================================
* A V2 animation does not describe the whole character: it names only
* the limbs that change. The head, for instance, is placed by frame 2
* (the starting one) and that is all; the walking and standing frames
* touch only legs, torso and arms. So the state has to be kept on the
* actor, one limb at a time, and updated piecemeal. Drawing the
* "standing" frame directly gives a character with no head.
*
* For every limb we keep where it sits in the command list (CostPos),
* the slice of the list that belongs to it (CostStart/CostEnd) and which
* animation it came from (CostFrm, needed when the actor turns round).
* CostPos is $FFFF when the limb is off.
*=======================================================================
* LimbOff - X = the slot of limb LimbNo of actor ActIdx
*=======================================================================
LimbOff          lda   ActIdx               ; actor*2 -> actor*32
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   LimbNo
                 adc   LimbNo
                 tax
                 rts

*=======================================================================
* ResetLimbs - every limb off
*=======================================================================
ResetLimbs       stz   LimbNo
:lp              jsr   LimbOff
                 lda   #$FFFF
                 sta   CostPos,x
                 sta   CostFrm,x
                 stz   CostStart,x
                 stz   CostEnd,x
                 inc   LimbNo
                 lda   LimbNo
                 cmp   #16
                 bcc   :lp
                 ldx   ActIdx
                 stz   CostStop,x
                 rts

*=======================================================================
* CostDecode - A = frame. Updates the limbs that animation names,
*              leaving the others alone.
*=======================================================================
CostDecode       sta   DecFrame
                 ldx   ActIdx
                 lda   ActCost,x
                 bne   :c_e
                 rts
:c_e             jsr   SlotCostume
                 bcc   :ok
                 rts
:ok              jsr   BaseCostume

                 ldy   #4
                 lda   [zpStr],y
                 and   #$00FF
                 sta   NAnim
                 ldy   #7
                 lda   [zpStr],y
                 sta   CmdOff

                 lda   DecFrame             ; facing plus four times the
                 asl   a                    ; frame
                 asl   a
                 ldx   ActIdx
                 clc
                 adc   ActFace,x
                 sta   AnimNo
                 cmp   NAnim                ; in the original the test is
                 beq   :dentro              ; only "greater"
                 bcc   :dentro
                 rts
:dentro          asl   a
                 clc
                 adc   #41
                 tay
                 lda   [zpStr],y
                 bne   :c_anim
                 rts
:c_anim          sta   AnimPtr

                 ldy   AnimPtr
                 lda   [zpStr],y
                 sta   LimbMask
                 inc   AnimPtr
                 inc   AnimPtr
                 stz   LimbNo

:arto            lda   LimbMask
                 and   #$8000
                 bne   :attivo
                 brl   :avanti
:attivo          ldy   AnimPtr
                 lda   [zpStr],y
                 and   #$00FF
                 inc   AnimPtr
                 cmp   #$00FF               ; off: here the extra byte does not
                 bne   :acceso              ; there
                 brl   :spegni
:acceso          anop
                 sta   LimbJ
                 ldy   AnimPtr
                 lda   [zpStr],y
                 and   #$00FF
                 inc   AnimPtr
                 sta   LimbExtra

                 lda   CmdOff               ; $79 and $7A do not draw:
                 clc                        ; stop and restart the limb
                 adc   LimbJ
                 tay
                 lda   [zpStr],y
                 and   #$00FF
                 cmp   #$007A
                 beq   :riparti
                 cmp   #$0079
                 beq   :ferma

                 jsr   LimbOff
                 lda   LimbJ
                 sta   CostStart,x
                 sta   CostPos,x
                 lda   LimbExtra
                 and   #$007F
                 clc
                 adc   LimbJ
                 sta   CostEnd,x
                 lda   LimbExtra
                 and   #$0080
                 beq   :nociclo
                 lda   CostPos,x
                 ora   #$8000               ; the high bit means "loop"
                 sta   CostPos,x
:nociclo         lda   AnimNo
                 sta   CostFrm,x
                 bra   :avanti

:spegni          jsr   LimbOff
                 lda   #$FFFF
                 sta   CostPos,x
                 stz   CostStart,x
                 lda   AnimNo
                 sta   CostFrm,x
                 bra   :avanti

:ferma           jsr   BitArto
                 ldx   ActIdx
                 ora   CostStop,x
                 sta   CostStop,x
                 bra   :avanti
:riparti         jsr   BitArto
                 eor   #$FFFF
                 ldx   ActIdx
                 and   CostStop,x
                 sta   CostStop,x

:avanti          lda   LimbMask
                 asl   a
                 sta   LimbMask
                 beq   :fine
                 inc   LimbNo
                 lda   LimbNo
                 cmp   #16
                 bcs   :fine
                 brl   :arto
:fine            rts

*=======================================================================
* BitArto - A = the bit of limb LimbNo
*=======================================================================
BitArto          lda   #1
                 ldy   LimbNo
                 beq   :fine
:lp              asl   a
                 dey
                 bne   :lp
:fine            rts

*=======================================================================
* StartAnim - A = frame: decode it and remember it
*=======================================================================
* Changing animation or facing changes the picture, so it has to be
* flagged: since ActDirty is raised only on real changes, without this
* the turn never reached the screen.
StartAnim        pha
                 jsr   CostDecode
                 pla
                 ldx   ActIdx
                 sta   ActFrame,x
                 lda   #1
                 sta   ActDirty
                 rts

*=======================================================================
* SetFacing - A = facing (0 left, 1 right, 2 front, 3 back)
*=======================================================================
* Turning means redoing every limb with the same animation as before but
* the new facing.
SetFacing        ldx   ActIdx
                 cmp   ActFace,x
                 bne   :cambia
                 rts
* The counter is its own: CostDecode uses LimbNo for its own loop, and
* if they shared it the loop would end after the first limb. That is why
* the head stayed facing the player while the body turned.
:cambia          sta   ActFace,x
                 stz   SetLimb
:lp              lda   SetLimb
                 sta   LimbNo
                 jsr   LimbOff
                 lda   CostFrm,x
                 cmp   #$FFFF
                 beq   :avanti
                 lsr   a                    ; the facing was in the two bits
                 lsr   a                    ; low: the frame is left
                 jsr   StartAnim
:avanti          inc   SetLimb
                 lda   SetLimb
                 cmp   #16
                 bcc   :lp
                 rts

*=======================================================================
* ShowActor - the character comes on stage
*=======================================================================
* Three passes, in the original's order: standing, then the head, then
* the mouth closed. Each adds its limbs to the ones already placed.
ShowActor        jsr   ResetLimbs
                 ldx   ActIdx
                 lda   ActFace,x            ; anyone who never turned
                 bne   :hagia               ; looks forward
                 lda   #2
                 sta   ActFace,x
:hagia           anop
                 lda   #1
                 jsr   StartAnim
                 lda   #2
                 jsr   StartAnim
                 lda   #4
                 jsr   StartAnim
                 ldx   ActIdx
                 lda   #1
                 sta   ActVis,x
                 lda   ActX,x
                 sta   ActOldX,x
                 lda   ActY,x
                 sta   ActOldY,x
                 rts

*=======================================================================
* MostraAttori - assemble whoever is in this room
*=======================================================================
* This has to happen as soon as the room is ready, BEFORE the scripts
* speak. Left until drawing time, ShowActor arrives after the animation
* the script has just asked for and wipes it: that is how the meteor
* stayed frozen on the crash picture.
MostraAttori     lda   ActIdx
                 pha
                 stz   ActIdx
:lp              ldx   ActIdx
                 lda   ActCost,x
                 beq   :prossimo
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :prossimo
                 lda   ActVis,x
                 bne   :prossimo
                 jsr   ShowActor
:prossimo        lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 pla
                 sta   ActIdx
                 rts

*=======================================================================
* MostraUno - assemble actor ActNo if it is here and not assembled yet
*=======================================================================
MostraUno        lda   RoomH
                 beq   :fine
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fine
                 lda   ActVis,x
                 bne   :fine
                 lda   ActIdx
                 pha
                 stx   ActIdx
                 jsr   ShowActor
                 pla
                 sta   ActIdx
:fine            rts

*=======================================================================
* DrawActors - the characters that are in this room
*=======================================================================
DrawActors       lda   RoomH
                 bne   :c_e
                 rts
:c_e             stz   ActIdx
:lp              ldx   ActIdx
                 lda   ActCost,x
                 beq   :prossimo
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :prossimo
                 lda   ActVis,x             ; anyone not assembled is not
                 beq   :prossimo            ; draw
                 jsr   DrawActor
:prossimo        lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 rts

*=======================================================================
* DrawActor - one character, limb by limb
*=======================================================================
* The walk box the actor stands on says whether any of the background
* passes in front of him: that is the box's mask byte, and it holds for
* the whole drawing.
DrawActor        stz   MascAtt
                 lda   NumBox
                 beq   :senza
                 ldx   ActIdx
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :hobox
                 ldx   ActIdx
                 lda   ActBox,x
:hobox           jsr   MascheraCasella
                 sta   MascAtt

:senza           ldx   ActIdx
                 lda   ActCost,x
                 jsr   SlotCostume
                 bcc   :ok
                 rts
:ok              jsr   BaseCostume          ; zpStr = start of the costume
                 ldy   #7
                 lda   [zpStr],y
                 sta   CmdOff               ; the animation commands

* In V2 the right-facing direction has no artwork of its own: it is the
* left one mirrored. The engine always draws mirrored, except when the
* character looks left and the costume does not say otherwise.
                 lda   #1
                 sta   MirrorOn
                 ldx   ActIdx
                 lda   ActFace,x
                 bne   :specchia
                 ldy   #5
                 lda   [zpStr],y
                 and   #$0080
                 bne   :specchia
                 stz   MirrorOn
:specchia        anop

                 lda   #$7FFF               ; the measurement starts empty
                 sta   SprX1
                 sta   SprY1
                 lda   #0
                 sta   SprX2
                 sta   SprY2

                 lda   #XMOVE0
                 sta   XMove
                 lda   #YMOVE0
                 sta   YMove
                 stz   LimbNo

:arto            jsr   LimbOff
                 lda   CostPos,x
                 cmp   #$FFFF               ; limb off
                 beq   :avanti
                 and   #$7FFF
                 sta   LimbJ
                 jsr   BitArto              ; limb stopped by a $79
                 ldx   ActIdx
                 and   CostStop,x
                 bne   :avanti

                 lda   CmdOff
                 clc
                 adc   LimbJ
                 tay
                 lda   [zpStr],y
                 and   #$007F
                 cmp   #$007B               ; nothing to draw
                 beq   :avanti
                 sta   LimbCmd
                 jsr   DrawLimb

:avanti          inc   LimbNo
                 lda   LimbNo
                 cmp   #16
                 bcc   :arto

* the measured box, clipped to the room
                 ldx   ActIdx
                 lda   SprX1
                 bpl   :x1ok
                 lda   #0
:x1ok            and   #$FFFC
                 sta   ActBX1,x
                 lda   SprY1
                 bpl   :y1ok
                 lda   #0
:y1ok            sta   ActBY1,x
                 lda   SprX2
                 bmi   :vuoto
                 clc
                 adc   #3
                 and   #$FFFC
                 cmp   RoomW
                 bcc   :x2ok
                 lda   RoomW
:x2ok            sta   ActBX2,x
                 lda   SprY2
                 cmp   RoomH
                 bcc   :y2ok
                 lda   RoomH
:y2ok            cmp   #ROOMROWS
                 bcc   :y2ok2
                 lda   #ROOMROWS
:y2ok2           sta   ActBY2,x
                 rts
:vuoto           stz   ActBX1,x             ; it has drawn nothing
                 stz   ActBY1,x
                 stz   ActBX2,x
                 stz   ActBY2,x
                 rts

*=======================================================================
* DrawLimb - the picture of one limb, with its offsets
*=======================================================================
DrawLimb         lda   LimbNo               ; where its frames are
                 asl   a
                 clc
                 adc   #9
                 tay
                 lda   [zpStr],y
                 sta   FramePtr
                 lda   LimbCmd
                 asl   a
                 clc
                 adc   FramePtr
                 tay
                 lda   [zpStr],y
                 sta   CelPtr

                 ldy   CelPtr               ; sizes and offsets
                 lda   [zpStr],y
                 sta   CelW
                 bne   :larga
                 rts
:larga           ldy   CelPtr
                 iny
                 iny
                 lda   [zpStr],y
                 sta   CelH
                 bne   :alta
                 rts
:alta            anop
                 ldy   CelPtr
                 iny
                 iny
                 iny
                 iny
                 lda   [zpStr],y
                 clc
                 adc   XMove
                 sta   CelX
                 ldy   CelPtr
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 lda   [zpStr],y
                 clc
                 adc   YMove
                 sta   CelY
                 ldy   CelPtr
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 lda   [zpStr],y
                 clc
                 adc   XMove
                 sta   XMove
                 ldy   CelPtr
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 iny
                 lda   [zpStr],y
                 sta   TmpW
                 lda   YMove
                 sec
                 sbc   TmpW
                 sta   YMove

* Where it lands on screen. The scripts count x in steps of eight and y
* in steps of two: that is the V2 scale. Without mirroring the piece
* sits to the left of the anchor instead of to the right.
                 ldx   ActIdx
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a
                 ldy   MirrorOn
                 beq   :arovescio
                 clc
                 adc   CelX
                 sta   CelX
                 bra   :messax
:arovescio       sec
                 sbc   CelX
                 sec
                 sbc   CelW
                 sta   CelX
:messax          anop
                 lda   ActY,x
                 asl   a
                 clc
                 adc   CelY
                 sta   CelY

* Grow the sprite's box by this piece. Clip to zero before comparing:
* that way every number is positive and the comparison need not care
* about signs (with cmp and bpl a piece left of the edge gave the
* opposite answer, and left rubbish on screen).
                 lda   CelX
                 bpl   :sx0
                 lda   #0
:sx0             cmp   SprX1
                 bcs   :nonpiusx
                 sta   SprX1
:nonpiusx        lda   CelY
                 bpl   :su0
                 lda   #0
:su0             cmp   SprY1
                 bcs   :nonpiusu
                 sta   SprY1
:nonpiusu        lda   CelX
                 clc
                 adc   CelW
                 bpl   :dx0
                 lda   #0
:dx0             cmp   SprX2
                 bcc   :nonpiudx
                 sta   SprX2
:nonpiudx        lda   CelY
                 clc
                 adc   CelH
                 bpl   :giu0
                 lda   #0
:giu0            cmp   SprY2
                 bcc   :nonpiugiu
                 sta   SprY2
:nonpiugiu       anop

                 lda   CelPtr
                 clc
                 adc   #12
                 sta   CelSrc
                 jsr   PaintCel
:fine            rts

*=======================================================================
* PaintCel - the compressed picture, column by column
*=======================================================================
* Same scheme as the backgrounds but with colour and run length in the
* same byte, and with colour zero meaning "transparent".
* The pending run must be cleared: it lasts to the end of the cel, no
* further.
PaintCel         stz   CelCol
                 stz   CelRun
:colonna         lda   MirrorOn
                 bne   :dritto
                 lda   CelW                 ; mirrored: the last column
                 sec                        ; of the drawing comes first
                 sbc   CelCol
                 dec   a
                 bra   :sommo
:dritto          lda   CelCol
:sommo           clc
                 adc   CelX
                 sta   CelPx                ; column on the screen
                 stz   CelRow

:pixel           lda   CelRun
                 bne   :dentro
                 ldy   CelSrc
                 lda   [zpStr],y
                 and   #$00FF
                 inc   CelSrc
                 sta   TmpW
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   CelColor
* With the lights off the game does not draw the characters in their own
* colours but all in grey: you can see where they are and when they move,
* and nothing else. Bit 3 of variable 12 is what says so.
                 lda   Vars+VO_LIGHTS
                 and   #8
                 bne   :coloreok
                 lda   CelColor
                 beq   :coloreok
                 lda   #8
                 sta   CelColor
:coloreok        lda   TmpW
                 and   #$000F
                 sta   CelRun
                 bne   :dentro
                 ldy   CelSrc               ; length in the next byte
                 lda   [zpStr],y
                 and   #$00FF
                 sta   CelRun
                 inc   CelSrc

:dentro          lda   CelColor
                 bne   :cisono              ; zero = transparent
:salta2          brl   :salta               ; trampoline: from here to :salta
:cisono          lda   CelPx                ; short branches no longer reach
                 bmi   :salta2              ; short
                 cmp   RoomW
                 bcs   :salta2
                 lda   CelRow
                 clc
                 adc   CelY
                 bmi   :salta2
                 cmp   RoomH
                 bcs   :salta2
                 cmp   #ROOMROWS
                 bcs   :salta2
                 sta   CelRy

* If the box the character stands on has a mask, the background at this
* point may pass in front of him: a set bit means the pixel stays the
* room's own.
                 lda   MascAtt
                 beq   :scoperto
                 lda   CelRy
                 asl   a
                 tax
                 lda   MaskRow,x
                 sta   TmpW
                 lda   CelPx
                 lsr   a
                 lsr   a
                 lsr   a
                 clc
                 adc   TmpW
                 tay
                 lda   [zpMask],y
                 and   #$00FF
                 sta   TmpW2
                 lda   CelPx
                 and   #$0007
                 asl   a
                 tax
                 lda   BitMasc,x
                 and   TmpW2
                 bne   :salta2

:scoperto        lda   CelRy
                 asl   a
                 tax
                 lda   RowOff,x
                 sta   TmpW
                 lda   CelPx
                 lsr   a
                 clc
                 adc   TmpW
                 tay
                 lda   CelPx
                 and   #1
                 bne   :basso
                 sep   #$20                 ; even pixel: high nibble
                 mx    %10
                 lda   CelColor
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW2
                 lda   [zpPix],y
                 and   #$0F
                 ora   TmpW2
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
                 bra   :salta
:basso           sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$F0
                 ora   CelColor
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00

:salta           dec   CelRun
                 inc   CelRow
                 lda   CelRow
                 cmp   CelH
                 bcs   :finecol
                 brl   :pixel

:finecol         inc   CelCol
                 lda   CelCol
                 cmp   CelW
                 bcs   :fine
                 brl   :colonna
:fine            rts

*=======================================================================
* ResetVM - variables to zero, no script alive
*=======================================================================
ResetVM          ldx   #0
                 lda   #0
:var             sta   Vars,x
                 inx
                 inx
                 cpx   #NVARS*2
                 bcc   :var
                 ldx   #0
:bit             sta   BitVars,x
                 inx
                 inx
                 cpx   #512
                 bcc   :bit
                 ldx   #0
:slot            sta   SlotStat,x
                 inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :slot
                 ldx   #0
                 lda   #0
:attore          sta   ActRoom,x
                 sta   ActCost,x
                 sta   ActX,x
                 sta   ActY,x
                 sta   ActFace,x
                 sta   ActFrame,x
                 inx
                 inx
                 cpx   #NACT*2
                 bcc   :attore
                 ldx   #0
                 lda   #$FFFF
:costume         sta   CostNum,x
                 inx
                 inx
                 cpx   #NCOST*2
                 bcc   :costume
                 stz   CostNext

                 stz   CurRoom
                 stz   Redraw
                 rts

*=======================================================================
* StartScript - A = number of the global script
*=======================================================================
StartScript      sta   ScrNo
                 cmp   NumScr
                 bcs   :no

* where it lives: room and position inside the file
                 asl   a
                 tax
                 lda   ScrOffs,x
                 sta   ScrOff
                 cmp   #$FFFF
                 beq   :no
                 ora   #0
                 beq   :no
                 ldx   ScrNo
                 sep   #$20
                 mx    %10
                 lda   ScrRoom,x
                 sta   ScrRm
                 rep   #$20
                 mx    %00
                 lda   ScrRm
                 and   #$00FF
                 sta   ScrRm

* Another run of the same script does not sit alongside the one already
* there: it replaces it, the way runScript does. Without this, the click
* script (number 4) stayed hanging in its "What is" loop - an endless
* loop with a breakHere inside, which ends only when somebody stops it -
* and every click hung another one. After a dozen clicks there were no
* free slots left: from then on no command started at all, neither the
* sentences nor "New Kid".
                 lda   ScrNo
                 jsr   FermaScript

* a free slot
                 jsr   FreeSlot
                 bcs   :no
                 sta   SlotIdx

* the code lands in the store, in the piece that belongs to this slot
                 lda   SlotIdx
                 jsr   SlotBase
                 sta   PoolOff
                 lda   ScrRm
                 sta   FileNo
                 jsr   LoadResource
                 bcs   :no

                 lda   SlotIdx              ; the tables step by two
                 asl   a
                 tax
                 lda   ScrNo
                 sta   SlotNum,x
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   #DA_POOL
                 sta   SlotWhere,x
                 lda   PoolOff
                 clc
                 adc   #4                   ; the resource header
                 sta   SlotBaseT,x
                 lda   #0
                 sta   SlotPC,x
                 sta   SlotDelLo,x
                 sta   SlotDelHi,x        ; (the high part of the delay)
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* SlotBase - A = slot, returns its place inside the store
*=======================================================================
SlotBase         asl   a                    ; ten doublings: slot*1024
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 asl   a                    ; slot*2048
                 clc
                 adc   TmpW                 ; slot*3072, that is SLOTLEN
                 rts

*=======================================================================
* FreeSlot - the first dead slot, carry if they are all taken
*=======================================================================
* Never the slot running right now, not even if the room change has just
* declared it dead: that code is still executing, and reassigning it
* would change where it reads its instructions from under its feet.
* From there on it would run the bytes of the new room as code.
FreeSlot         ldx   #0
:lp              cpx   CurSlot
                 beq   :prossimo
                 lda   SlotStat,x
                 beq   :trovato
:prossimo        inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 sec
                 rts
:trovato         txa
                 lsr   a
                 clc
                 rts

*=======================================================================
* LoadResource - bring the resource at FileNo/ScrOff into the store
*=======================================================================
LoadResource     lda   zpRes
                 clc
                 adc   PoolOff
                 sta   DestLo
                 lda   zpRes+2
                 adc   #0                   ; the carry goes into the bank
                 sta   DestHi
                 lda   #SLOTLEN
                 sta   DestMax
*                 (falls through into LoadResIn)

*=======================================================================
* LoadResIn - read a resource from file FileNo at position ScrOff and
*             put it where DestLo/DestHi say, at most DestMax bytes
*=======================================================================
LoadResIn        jsr   OpenLFL
                 bcs   :male
                 lda   ScrOff
                 sta   MarkPos
                 stz   MarkPos+2
                 jsl   $E100A8
                 dw    SetMarkGS
                 adrl  MarkParm
                 bcs   :chiudi

                 lda   DestLo
                 sta   ReadBuf
                 lda   DestHi
                 sta   ReadBuf+2
                 lda   DestMax
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 lda   ReadXfer
                 ora   ReadXfer+2
                 beq   :male

                 lda   ReadBuf
                 sta   zpStr
                 lda   ReadBuf+2
                 sta   zpStr+2
                 lda   ReadXfer
                 cmp   DestMax
                 bcc   :quanti
                 lda   DestMax
:quanti          jsr   Decipher
                 clc
                 rts
:chiudi          jsl   $E100A8
                 dw    CloseGS
                 adrl  CloseParm
:male            sec
                 rts

*=======================================================================
* Orologio - how many sixtieths of a second have gone by
*=======================================================================
* Script delays are counted in sixtieths, as in the original game: if we
* decremented them once per program loop a delay(60) would last a blink
* instead of a second.
Orologio         PushLong #0          ; room for the result
                 _GetTick
                 PullLong Tick
                 lda   Tick
                 sec
                 sbc   LastTick
                 sta   Elapsed
                 cmp   #30                  ; after half a second's pause
                 bcc   :ok                  ; (loads) are not made up for
                 lda   #1
                 sta   Elapsed
:ok              lda   Tick
                 sta   LastTick
                 rts

*=======================================================================
* MsgTick - the message on screen lasts a while, then goes away
*=======================================================================
MsgTick          lda   MsgTimer
                 beq   :fine
                 sec
                 sbc   Elapsed
                 bpl   :ancora
                 lda   #0
:ancora          sta   MsgTimer
                 bne   :fine

                 jsr   ProssimaPagina       ; is there another page?
                 bcs   :finepagine
                 jsr   TempoPagina
                 sta   MsgTimer
                 lda   #1
                 sta   Vars+VO_HAVEMSG
                 inc   MsgNew
                 rts

:finepagine      lda   MsgDopo              ; is another one queued?
                 beq   :basta
                 sta   zpStr
                 lda   #^MsgIIGS
                 sta   zpStr+2
                 stz   MsgDopo
                 jsr   CopiaMsg
                 lda   #235
                 sta   MsgTimer
                 lda   #1
                 sta   Vars+VO_HAVEMSG
                 inc   MsgNew
                 rts
:basta           jsr   SmettiParlare
                 stz   Vars+VO_HAVEMSG      ; now the game can go on
                 sep   #$20
                 mx    %10
                 lda   #0
                 sta   MsgText
                 sta   MsgPrev
                 rep   #$20
                 mx    %00
                 inc   MsgNew
:fine            rts

*=======================================================================
* SpegniMsg - throw away the sentence on screen
*=======================================================================
SpegniMsg        jsr   SmettiParlare
                 stz   MsgPag
                 stz   MsgTimer
                 stz   MsgDopo
                 stz   MsgLen
                 stz   Vars+VO_HAVEMSG
                 sep   #$20
                 mx    %10
                 lda   #0
                 sta   MsgText
                 sta   MsgPrev
                 rep   #$20
                 mx    %00
                 inc   MsgNew
                 rts

*=======================================================================
* RunScripts - one pass over every live slot
*=======================================================================
RunScripts       stz   Alive
                 ldx   #0
                 stx   SlotIdx2
:lp              ldx   SlotIdx2
                 lda   SlotStat,x
                 beq   :prossimo
                 inc   Alive

                 lda   SlotDelLo,x
                 ora   SlotDelHi,x
                 beq   :esegui
                 lda   SlotDelLo,x          ; down by however much passed
                 sec
                 sbc   Elapsed
                 sta   SlotDelLo,x
                 lda   SlotDelHi,x
                 sbc   #0
                 sta   SlotDelHi,x
                 bpl   :prossimo
                 lda   #0                   ; below zero: it has expired
                 sta   SlotDelLo,x
                 sta   SlotDelHi,x
                 bra   :prossimo

:esegui          txa
                 lsr   a
                 jsr   ExecSlot

:prossimo        lda   SlotIdx2
                 clc
                 adc   #2
                 sta   SlotIdx2
                 cmp   #SLOTS*2
                 bcc   :lp
                 rts

*=======================================================================
* ExecSlot - run slot A until it yields or ends
*=======================================================================
ExecSlot         asl   a
                 tax
                 stx   CurSlot

                 lda   SlotWhere,x
                 bne   :nondeposito
                 lda   zpRes
                 sta   zpCode
                 lda   zpRes+2
                 sta   zpCode+2
                 bra   :base
:nondeposito     cmp   #DA_MANO
                 bne   :dastanza
                 lda   #InvBuf              ; the script of an object that is
                 sta   zpCode               ; is carrying: its description
                 lda   #^InvBuf             ; was copied here when it was
                 sta   zpCode+2             ; was picked up
                 bra   :base
:dastanza        lda   zpRaw
                 sta   zpCode
                 lda   zpRaw+2
                 sta   zpCode+2
:base            lda   SlotBaseT,x
                 clc
                 adc   zpCode
                 sta   zpCode
                 lda   zpCode+2
                 adc   #0
                 sta   zpCode+2
                 lda   SlotPC,x
                 sta   PC

:passo           ldy   PC
                 lda   [zpCode],y
                 and   #$00FF
                 sta   Op
                 inc   PC
                 asl   a
                 tax
                 jsr   (OpTab,x)

* If meanwhile somebody turned off this very slot - another run of the
* same script, a stopScript - the code is no longer its own and we stop
* at once, like ScummVM clearing _currentScript. The status is already
* dead, there is nothing more to write.
                 lda   SlotFuori
                 bne   :spento
                 lda   Esito
                 beq   :passo

                 ldx   CurSlot
                 lda   Esito
                 cmp   #FINE
                 beq   :morto
                 lda   PC
                 sta   SlotPC,x
                 stz   Esito
                 rts
:morto           lda   #MORTO
                 sta   SlotStat,x
                 stz   Esito
                 rts
:spento          stz   SlotFuori
                 stz   Esito
                 rts

*=======================================================================
* The building blocks for reading arguments
*=======================================================================
* FetchB - the next byte of code
* The pointer must be advanced BEFORE reading: an inc at the end would
* redo the flags on the value of PC, and callers here look at the zero
* of the byte just read (that is how strings end).
FetchB           ldy   PC
                 inc   PC
                 lda   [zpCode],y
                 and   #$00FF
                 rts

* FetchW - the next word (signed, little endian)
FetchW           ldy   PC
                 inc   PC
                 inc   PC
                 lda   [zpCode],y
                 rts

* ReadVar - A = variable index, returns the value
* In V2 indices 14, 15 and 16 are indirect: they say where to look.
ReadVar          and   #$00FF
                 cmp   #14
                 bcc   :diretta
                 cmp   #17
                 bcs   :diretta
                 asl   a
                 tax
                 lda   Vars,x
                 and   #$00FF
:diretta         asl   a
                 tax
                 lda   Vars,x
                 rts

* DestVar2 - A = index of the destination variable, returns X = index*2.
* Careful: only READS go through the indirection of variables 14-16.
* When writing, the original engine uses the index as it stands.
ResolveVar       and   #$00FF
                 asl   a
                 tax
                 rts

* VarOrByte / VarOrWord, one for each of the three bits
VOB1             lda   Op
                 and   #$0080
                 bne   :var
                 jmp   FetchB
:var             jsr   FetchB
                 jmp   ReadVar

VOB2             lda   Op
                 and   #$0040
                 bne   :var
                 jmp   FetchB
:var             jsr   FetchB
                 jmp   ReadVar

VOB3             lda   Op
                 and   #$0020
                 bne   :var
                 jmp   FetchB
:var             jsr   FetchB
                 jmp   ReadVar

VOW1             lda   Op
                 and   #$0080
                 bne   :var
                 jmp   FetchW
:var             jsr   FetchB
                 jmp   ReadVar

VOW2             lda   Op
                 and   #$0040
                 bne   :var
                 jmp   FetchW
:var             jsr   FetchB
                 jmp   ReadVar

VOW3             lda   Op
                 and   #$0020
                 bne   :var
                 jmp   FetchW
:var             jsr   FetchB
                 jmp   ReadVar

* Salta - add the signed displacement that follows to the PC
Salta            jsr   FetchW
                 clc
                 adc   PC
                 sta   PC
                 rts

* SkipW - throw away a word (jump not taken)
SkipW            inc   PC
                 inc   PC
                 rts

* SkipStrPrint - the print string: bit 7 ends the word, below eight
* there is a code, and from four up the code carries a byte.
SkipStrPrint     jsr   FetchB
                 beq   :fine
                 and   #$007F
                 cmp   #8
                 bcs   SkipStrPrint
                 cmp   #4
                 bcc   SkipStrPrint
                 jsr   FetchB
                 bra   SkipStrPrint
:fine            rts

* SkipStrZero - string ended by zero, with the codes $FF and $FE
SkipStrZero      jsr   FetchB
                 beq   :fine
                 cmp   #$00FE
                 bcc   SkipStrZero
                 jsr   FetchB
                 cmp   #4
                 bcc   SkipStrZero
                 cmp   #8
                 bcs   SkipStrZero
                 jsr   FetchB
                 bra   SkipStrZero
:fine            rts

*=======================================================================
* The opcodes
*=======================================================================
hBad             lda   Op
                 sta   BadOp
                 lda   #FINE
                 sta   Esito
                 rts

hNop             stz   Esito
                 rts

*=======================================================================
* The camera
*=======================================================================
* A room can be up to 960 pixels wide, the screen shows 320 of them.
* The camera is the point at the centre of that window: from it we get
* ScrollX, the left edge. It moves in steps of eight pixels, because
* that is how the game thinks (columns are eight wide) and because that
* way the shift is always a whole number of bytes.
*
* Three modes: stopped where it is, travelling towards a point
* (panCameraTo), or attached to a character (actorFollowCamera).
*=======================================================================
* To work out who moves the camera when it misbehaves, we record the
* last three commands that touched it:
*   1 setCameraAt from a script   2 panCameraTo from a script
*   3 actorFollowCamera           4 setCameraAt of loadRoomWithEgo
*   5 follow of loadRoomWithEgo   6 room change
*   7 pan arrived
CAM_FERMA        =     0
CAM_SEGUI        =     1
CAM_VIAGGIO      =     2

* Move the camera one step and update ScrollX. Once per frame.
MoveCamera       lda   RoomW
                 cmp   #SCRW2+1             ; room no wider than the
                 bcs   :larga               ; screen: nothing to do
                 stz   ScrollX
                 stz   CamCur
                 rts

:larga           lda   CamCur               ; always on multiples of eight
                 and   #$FFF8
                 sta   CamCur

                 cmp   Vars+VO_CAMMIN
                 bcs   :nonsotto
                 clc
                 adc   #8
                 sta   CamCur
                 brl   CamMoved
:nonsotto        lda   Vars+VO_CAMMAX
                 cmp   CamCur
                 bcs   :nonsopra
                 lda   CamCur
                 sec
                 sbc   #8
                 sta   CamCur
                 brl   CamMoved

:nonsopra        lda   CamMode
                 cmp   #CAM_SEGUI
                 bne   :nonsegue
                 jsr   EgoX                 ; has the character gone
                 bcs   :nonsegue            ; out of the middle band?
                 sec
                 sbc   ScrollX
                 bmi   :attacca
                 cmp   #80                  ; fewer than ten columns from
                 bcc   :attacca             ; left
                 cmp   #240                 ; more than thirty from the left
                 bcs   :attacca
                 bra   :nonsegue
:attacca         lda   #1
                 sta   CamGo

:nonsegue        lda   CamGo
                 beq   :dest
                 jsr   EgoX
                 bcs   :dest
                 sta   CamDest

:dest            lda   CamDest              ; the target stays within limits
                 cmp   Vars+VO_CAMMIN
                 bcs   :d1
                 lda   Vars+VO_CAMMIN
                 sta   CamDest
:d1              lda   Vars+VO_CAMMAX
                 cmp   CamDest
                 bcs   :d2
                 sta   CamDest

:d2              lda   CamCur               ; one step towards the target
                 cmp   CamDest
                 beq   :arrivata
                 bcs   :indietro
                 clc
                 adc   #8
                 sta   CamCur
                 bra   :controlla
:indietro        sec
                 sbc   #8
                 sta   CamCur

:controlla       lda   CamGo                ; arrived on top of the
                 beq   CamMoved             ; character?
                 jsr   EgoX
                 bcs   CamMoved
                 and   #$FFF8
                 cmp   CamCur
                 bne   CamMoved
                 stz   CamGo
                 bra   CamMoved
:arrivata        lda   CamMode
                 cmp   #CAM_VIAGGIO
                 bne   CamMoved
                 lda   #7
                 jsr   NotaCam
                 lda   #CAM_FERMA
                 sta   CamMode

* From CamCur to ScrollX: the left edge is the centre minus half a
* screen, kept inside the room.
CamMoved         lda   CamCur
                 cmp   #SCRW2/2
                 bcs   :nonpoco
                 lda   #SCRW2/2
                 sta   CamCur
:nonpoco         lda   RoomW
                 sec
                 sbc   #SCRW2/2
                 cmp   CamCur
                 bcs   :ok
                 sta   CamCur
:ok              lda   CamCur
                 sec
                 sbc   #SCRW2/2
                 and   #$FFF8
                 cmp   ScrollX
                 beq   :uguale
                 sta   ScrollX
                 lda   #1                   ; changed: redraw everything
                 sta   Redraw
* VAR_CAMERA_POS_X is in pixels, not in the units the scripts use for x
* elsewhere: ScummVM assigns camera._cur.x to it untouched, and
* setCameraAt multiplies the script's argument by eight on the way in.
* Dividing it here made Edna's ambush wait for 47*8 pixels instead of 47:
* she only noticed you once you were on top of her, with no room left to
* run. Her script really does say "as soon as the camera is anywhere past
* the left edge", because the camera never goes below half a screen.
:uguale          lda   CamCur
                 sta   Vars+VO_CAMPOS
                 rts

*=======================================================================
* EgoX - where the player character is. Carry set if unknown.
*=======================================================================
EgoX             lda   CamFollow
                 jsr   ActIndex
                 bcs   :male
                 tax
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :male
                 lda   ActX,x               ; in pixels: the camera counts
                 asl   a                    ; this way, the scripts do not
                 asl   a
                 asl   a
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* SetCameraAt / PanCameraTo / FollowCamera
*=======================================================================
* The scroll must be updated at once: if it waits for the next tick, a
* redraw with the old value slips in between and the room is seen
* arriving in two stages.
NotaCam          pha
                 lda   CamChi2
                 sta   CamChi3
                 lda   CamChi
                 sta   CamChi2
                 pla
                 sta   CamChi
                 rts

SetCameraAt      sta   CamDest
                 sta   CamCur
                 stz   CamGo
                 jsr   ClampCam
                 jmp   CamMoved

PanCameraTo      sta   CamDest
                 lda   #CAM_VIAGGIO
                 sta   CamMode
                 stz   CamGo
                 rts

* Attaching the camera to a character also means following him where he
* is: if he is in another room, we change room. That is how the game
* enters the mansion after the title - no loadRoom does it.
FollowCamera     sta   CamFollow
                 stz   CamGo

                 lda   CamFollow
                 jsr   ActIndex
                 bcs   :fine
                 tax
                 lda   ActRoom,x
                 beq   :fine                ; he is nowhere
                 cmp   CurRoom
                 beq   :stessa
                 jsr   ChangeRoom

* The "follow" must be written afterwards, not before: ChangeRoom puts
* the camera back to stopped, and if it had already been set it would be
* cancelled. This is what left the character off screen with the room
* frozen - the camera followed nobody until somebody else came in,
* because that ran the whole thing again from the start.
:stessa          lda   #CAM_SEGUI
                 sta   CamMode
                 stz   CamGo
                 jsr   EgoX
                 bcs   :fine
                 sta   CamCur
                 sta   CamDest
                 jsr   ClampCam
                 jsr   CamMoved
:fine            rts

ClampCam         lda   CamCur
                 cmp   Vars+VO_CAMMIN
                 bcs   :c1
                 lda   Vars+VO_CAMMIN
                 sta   CamCur
:c1              lda   Vars+VO_CAMMAX
                 cmp   CamCur
                 bcs   :c2
                 sta   CamCur
:c2              rts

*=======================================================================
* The opcodes: $32 setCameraAt, $12 panCameraTo, $52 actorFollowCamera
*=======================================================================
hSetCamera       pha
                 lda   #1
                 jsr   NotaCam
                 pla
                 jsr   VOB1
                 asl   a                    ; the game counts in columns of
                 asl   a                    ; eight? no: in pixels, but on a
                 asl   a                    ; bytes. So x8.
                 jsr   SetCameraAt
                 stz   Esito
                 rts

hPanCamera       lda   #2
                 jsr   NotaCam
                 ldx   CurSlot              ; which script ordered it
                 lda   SlotNum,x
                 cmp   #1000
                 bcc   :segnato
                 lda   #999
:segnato         sta   CamQuale
                 jsr   VOB1
                 asl   a
                 asl   a
                 asl   a
                 jsr   PanCameraTo
                 stz   Esito
                 rts

hFollowCam       lda   #3
                 jsr   NotaCam
                 jsr   VOB1
                 jsr   FollowCamera
                 stz   Esito
                 rts

*=======================================================================
* hAnimate ($11) - animateActor
*=======================================================================
* The number carries two things at once: the facing in the low two bits,
* the command in the rest. And the command has to be reversed (63 minus
* what is there, plus two) to get back to the old numbering the engine
* uses.
hAnimate         jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   AnimArg
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 stx   ActIdx
                 lda   AnimArg
                 and   #$0003
                 sta   AnimDir
                 lda   AnimArg
                 lsr   a
                 lsr   a
                 sta   AnimChore
                 lda   #$3F
                 sec
                 sbc   AnimChore
                 clc
                 adc   #2
                 cmp   #2                   ; stop walking
                 beq   :ferma
                 cmp   #3                   ; turn at once
                 beq   :verso
                 cmp   #4                   ; turn slowly: same for now
                 beq   :verso
                 lda   AnimChore
                 jsr   StartAnim
                 bra   :fine
:ferma           lda   #1
                 jsr   StartAnim
                 bra   :fine
:verso           lda   AnimDir
                 jsr   SetFacing
:fine            stz   Esito
                 rts

*=======================================================================
* AnimActors - one animation step for everyone
*=======================================================================
* Every limb has its own slice of the command list (from CostStart to
* CostEnd) and walks through it one position at a time. With the high
* bit set the walk stops at the end, otherwise it starts over.
AnimActors       stz   ActIdx
:att             ldx   ActIdx
                 lda   ActCost,x
                 beq   :prossimo
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :prossimo
                 lda   ActVis,x
                 beq   :prossimo
                 jsr   AnimUno
:prossimo        lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :att
                 rts

AnimUno          lda   ActCost,x            ; this costume's commands
                 jsr   SlotCostume
                 bcs   :fine
                 jsr   BaseCostume
                 ldy   #7
                 lda   [zpStr],y
                 sta   CmdOff
                 stz   LimbNo
:arto            jsr   LimbOff
                 lda   CostPos,x
                 cmp   #$FFFF
                 beq   :avanti
                 and   #$7FFF
                 sta   LimbJ                ; where he is now
                 lda   CostPos,x
                 and   #$8000
                 sta   LimbExtra            ; the "do not loop" bit
                 bne   :unavolta

                 lda   LimbJ                ; wrapping round
                 cmp   CostEnd,x
                 bcc   :avantiuno
                 lda   CostStart,x
                 bra   :messo
:avantiuno       inc   a
                 bra   :messo

:unavolta        lda   LimbJ                ; to the end and stops there
                 cmp   CostEnd,x
                 beq   :messo
                 inc   a

:messo           ora   LimbExtra
                 sta   CostPos,x

* The picture changed only if the new command points at a different
* frame. A limb sitting on a one-position animation changes nothing, and
* flagging it made the screen redraw on every tick for ever.
                 and   #$7FFF
                 clc
                 adc   CmdOff
                 tay
                 lda   [zpStr],y
                 and   #$007F
                 sta   TmpW
                 lda   CmdOff
                 clc
                 adc   LimbJ
                 tay
                 lda   [zpStr],y
                 and   #$007F
                 cmp   TmpW
                 beq   :avanti
                 lda   #1
                 sta   ActDirty
:avanti          inc   LimbNo
                 lda   LimbNo
                 cmp   #16
                 bcc   :arto
:fine            rts

*=======================================================================
* MoveActors - one walking step for whoever is moving
*=======================================================================
* No walk boxes on the way for now: we go in a straight line, one step
* per tick along the longer axis and one now and then along the other,
* keeping the error. That is how you draw a line without dividing.
* Only actors in the room on screen walk: the real engine does the same
* (walkActors checks isInCurrentRoom). Without this check a character
* left halfway across another room kept moving in secret, and the script
* waiting for him woke up in the wrong place. That is how the meteor
* script, left waiting since the intro, started its pan to the mailbox
* while you were already in front of the mansion.
MoveActors       stz   ActIdx
:att             ldx   ActIdx
                 lda   ActMoving,x
                 beq   :prossimo
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :prossimo
                 jsr   MoveUno
:prossimo        lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :att
                 rts

MoveUno          ldx   ActIdx
                 lda   ActDstX,x            ; how much is left
                 sec
                 sbc   ActX,x
                 sta   WalkDX
                 lda   ActDstY,x
                 sec
                 sbc   ActY,x
                 sta   WalkDY
                 ora   WalkDX
                 bne   :cammina
                 brl   ArrivatoQui

:cammina         lda   WalkDX               ; the sign and the absolute value
                 bpl   :xpos
                 lda   #$FFFF
                 sta   WalkSX
                 lda   #0
                 sec
                 sbc   WalkDX
                 sta   WalkAX
                 bra   :fattox
:xpos            lda   #1
                 sta   WalkSX
                 lda   WalkDX
                 sta   WalkAX
:fattox          lda   WalkDY
                 bpl   :ypos
                 lda   #$FFFF
                 sta   WalkSY
                 lda   #0
                 sec
                 sbc   WalkDY
                 sta   WalkAY
                 bra   :fattoy
:ypos            lda   #1
                 sta   WalkSY
                 lda   WalkDY
                 sta   WalkAY

:fattoy          lda   WalkAX               ; which axis drives the step
                 cmp   WalkAY
                 bcc   :ycomanda

* the horizontal axis is the longer one
                 ldx   ActIdx
                 lda   ActX,x
                 clc
                 adc   WalkSX
                 sta   ActX,x
                 lda   ActErr,x
                 clc
                 adc   WalkAY
                 sta   ActErr,x
                 cmp   WalkAX
                 bcc   :versox
                 sec
                 sbc   WalkAX
                 sta   ActErr,x
                 lda   ActY,x
                 clc
                 adc   WalkSY
                 sta   ActY,x
:versox          bra   :fatto

* the vertical axis is the longer one
:ycomanda        ldx   ActIdx
                 lda   ActY,x
                 clc
                 adc   WalkSY
                 sta   ActY,x
                 lda   ActErr,x
                 clc
                 adc   WalkAX
                 sta   ActErr,x
                 cmp   WalkAY
                 bcc   :versoy
                 sec
                 sbc   WalkAY
                 sta   ActErr,x
                 lda   ActX,x
                 clc
                 adc   WalkSX
                 sta   ActX,x
:versoy          anop

:fatto           lda   #1
                 sta   ActDirty
                 rts

ArrivatoQui      ldx   ActIdx
                 lda   ActUltima,x          ; was it only a waypoint?
                 bne   :basta
                 jsr   ProssimaTappa
                 ldx   ActIdx
                 lda   ActMoving,x
                 beq   :basta
                 jsr   VersoCammino
                 lda   #1
                 sta   ActDirty
                 rts
:basta           ldx   ActIdx
                 stz   ActMoving,x
                 stz   ActErr,x
                 stz   ActUltima,x
                 lda   #1                   ; standing still
                 jsr   StartAnim
                 lda   #1
                 sta   ActDirty
                 rts

*=======================================================================
* The walk boxes
*=======================================================================
* Every room carries the list of the areas you can walk on. It sits at
* the offset written in byte $15 of the room: first how many there are,
* then eight bytes for each, then the matrix saying how to get from one
* to another.
*
* The eight bytes are, in this order: top y, bottom y, top-left x,
* top-right x, bottom-left x, bottom-right x, a mask and some flags.
* The left and right sides can slope, so a box is a trapezium, not a
* rectangle.
*
* The measures are in script units: x in steps of eight pixels, y in
* steps of two.
*=======================================================================
* LeggiCaselle - take from the room where the table sits
*=======================================================================
LeggiCaselle     stz   NumBox
                 lda   RoomH
                 beq   :fine
                 ldy   #$15
                 lda   [zpRaw],y
                 and   #$00FF
                 beq   :fine
                 sta   BoxOff
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   NumBox
:fine            rts

*=======================================================================
* CasellaN - A = box number. Puts its six numbers in place.
*=======================================================================
CasellaN         asl   a                    ; eight bytes per box, plus
                 asl   a                    ; the count byte
                 asl   a
                 clc
                 adc   BoxOff
                 inc   a
                 sta   BoxPtr
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxUy
                 ldy   BoxPtr
                 iny
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxLy
                 ldy   BoxPtr
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxUlx
                 ldy   BoxPtr
                 iny
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxUrx
                 ldy   BoxPtr
                 iny
                 iny
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxLlx
                 ldy   BoxPtr
                 iny
                 iny
                 iny
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxLrx
                 rts

*=======================================================================
* LatiACasella - the box's two x edges at height BoxQy
*=======================================================================
* Interpolate between the top edge and the bottom one. The division is
* done by DividiW, the only one in the program.
LatiACasella     lda   BoxLy                ; how tall it is
                 sec
                 sbc   BoxUy
                 sta   BoxDy
                 bne   :inclinata

                 lda   BoxUlx               ; zero high: the top edges
                 sta   BoxSx
                 lda   BoxUrx
                 sta   BoxDx
                 rts

:inclinata       lda   BoxQy                ; how far down we are
                 sec
                 sbc   BoxUy
                 sta   BoxDd

                 lda   BoxLlx               ; the left edge
                 sec
                 sbc   BoxUlx
                 jsr   ScorriLato
                 clc
                 adc   BoxUlx
                 sta   BoxSx

                 lda   BoxLrx               ; and the right one
                 sec
                 sbc   BoxUrx
                 jsr   ScorriLato
                 clc
                 adc   BoxUrx
                 sta   BoxDx
                 rts

*=======================================================================
* ScorriLato - A = how far the side slopes. Returns the part covered.
*=======================================================================
* That is, A times BoxDd divided by BoxDy, keeping the sign.
ScorriLato       sta   BoxTmp
                 bpl   :positivo
                 eor   #$FFFF               ; make it positive and
                 inc   a                    ; remember the sign
                 sta   BoxTmp2
                 jsr   :conto
                 eor   #$FFFF
                 inc   a
                 rts
:positivo        sta   BoxTmp2
:conto           lda   BoxTmp2
                 sta   MulA
                 lda   BoxDd
                 sta   MulB
                 jsr   MoltiplicaW
                 lda   BoxDy
                 sta   DivB
                 jmp   DividiW

*=======================================================================
* MoltiplicaW - MulA times MulB into ProdLo/ProdHi
*=======================================================================
MoltiplicaW      stz   ProdLo
                 stz   ProdHi
                 ldy   #16
:lp              lda   MulB
                 lsr   a
                 sta   MulB
                 bcc   :salta
                 lda   ProdLo
                 clc
                 adc   MulA
                 sta   ProdLo
                 lda   ProdHi
                 adc   #0
                 sta   ProdHi
:salta           asl   MulA
                 rol   ProdHi               ; the high part of the multiplicand
                 dey
                 bne   :lp
                 rts

*=======================================================================
* DividiW - ProdLo/ProdHi divided by DivB, result in A
*=======================================================================
* Long division, thirty-two bits by sixteen. More than enough: the
* numbers here are room heights, never above a hundred or so.
DividiW          stz   DivR
                 stz   DivQ
                 ldy   #16
:lp              asl   ProdLo               ; the top bit goes into the
                 rol   DivR                 ; remainder
                 lda   DivR
                 cmp   DivB
                 bcc   :piccolo
                 sec
                 sbc   DivB
                 sta   DivR
                 sec
                 bra   :metti
:piccolo         clc
:metti           rol   DivQ
                 dey
                 bne   :lp
                 lda   DivQ
                 rts

*=======================================================================
* DentroCasella - is the point (BoxQx,BoxQy) inside box A?
*=======================================================================
* Carry clear if it is.
DentroCasella    jsr   CasellaN
                 lda   BoxQy
                 cmp   BoxUy
                 bcc   :no
                 lda   BoxLy
                 cmp   BoxQy
                 bcc   :no
                 jsr   LatiACasella
                 lda   BoxQx
                 cmp   BoxSx
                 bcc   :no
                 lda   BoxDx
                 cmp   BoxQx
                 bcc   :no
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* PuntoNellaCasella - A = box. Its point nearest to BoxQx/BoxQy
*=======================================================================
* Comes out in BoxCx/BoxCy. It is enough to keep y between the two
* horizontal edges and then x between the two sides at that height.
PuntoNellaCasella
                 jsr   CasellaN
                 lda   BoxQy
                 cmp   BoxUy
                 bcs   :nonsopra
                 lda   BoxUy
:nonsopra        cmp   BoxLy
                 bcc   :yok
                 lda   BoxLy
:yok             sta   BoxCy

                 lda   BoxQy                ; the sides at that height
                 pha
                 lda   BoxCy
                 sta   BoxQy
                 jsr   LatiACasella
                 pla
                 sta   BoxQy

                 lda   BoxQx
                 cmp   BoxSx
                 bcs   :nonsx
                 lda   BoxSx
:nonsx           cmp   BoxDx
                 bcc   :xok
                 lda   BoxDx
:xok             sta   BoxCx
                 rts

*=======================================================================
* DistanzaPunto - how far (BoxQx,BoxQy) is from (BoxCx,BoxCy)
*=======================================================================
* City-block: the sum of the two differences. No square root is needed
* to decide which box is the nearest.
DistanzaPunto    lda   BoxQx
                 sec
                 sbc   BoxCx
                 bpl   :dx
                 eor   #$FFFF
                 inc   a
:dx              sta   BoxDist
                 lda   BoxQy
                 sec
                 sbc   BoxCy
                 bpl   :dy
                 eor   #$FFFF
                 inc   a
:dy              clc
                 adc   BoxDist
                 rts

*=======================================================================
* AvvicinaPunto - bring (BoxQx,BoxQy) inside the nearest box
*=======================================================================
* Leaves the chosen box number in BoxScelta, or $FFFF if the room has
* none.
AvvicinaPunto    lda   #$FFFF
                 sta   BoxScelta
                 lda   NumBox
                 bne   :cisono
                 rts

:cisono          stz   BoxI
:dentro          lda   BoxI                 ; is it already walkable?
                 jsr   DentroCasella
                 bcs   :ancora
                 lda   BoxI
                 sta   BoxScelta
                 rts
:ancora          inc   BoxI
                 lda   BoxI
                 cmp   NumBox
                 bcc   :dentro

                 lda   #$7FFF
                 sta   BoxBest
                 stz   BoxI
:cerca           lda   BoxI
                 jsr   PuntoNellaCasella
                 jsr   DistanzaPunto
                 cmp   BoxBest
                 bcs   :prossima
                 sta   BoxBest
                 lda   BoxCx
                 sta   BoxNx
                 lda   BoxCy
                 sta   BoxNy
                 lda   BoxI
                 sta   BoxScelta

:prossima        inc   BoxI
                 lda   BoxI
                 cmp   NumBox
                 bcs   :scelta
                 brl   :cerca

:scelta          lda   BoxScelta
                 cmp   #$FFFF
                 beq   :fine
                 lda   BoxNx
                 sta   BoxQx
                 lda   BoxNy
                 sta   BoxQy
:fine            rts

*=======================================================================
* CasellaDelPunto - which box is (BoxQx,BoxQy) in? $FFFF if none.
*=======================================================================
CasellaDelPunto  stz   BoxI
:lp              lda   BoxI
                 jsr   DentroCasella
                 bcc   :trovata
                 inc   BoxI
                 lda   BoxI
                 cmp   NumBox
                 bcc   :lp
                 lda   #$FFFF
                 rts
:trovata         lda   BoxI
                 rts

*=======================================================================
* ProssimaCasella - from BoxDa to BoxA, which box to cross next
*=======================================================================
* The matrix sits right after the list of boxes: first one index per row,
* then the rows. The value is the box to cross, or $FF if there is no
* way through.
ProssimaCasella  lda   BoxDa
                 cmp   BoxA
                 bne   :cerca
                 rts                        ; already there
:cerca           lda   BoxOff               ; where the matrix starts
                 inc   a
                 sta   BoxMat
                 lda   NumBox
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   BoxMat
                 sta   BoxMat

                 lda   BoxMat               ; the row index
                 clc
                 adc   BoxDa
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 clc
                 adc   BoxMat
                 adc   NumBox
                 clc
                 adc   BoxA
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 cmp   #$00FF
                 beq   :niente
                 rts
:niente          lda   #$FFFF
                 rts

*=======================================================================
* VersoCammino - which way a walking character looks
*=======================================================================
* Decided once, when the walk starts, and kept for the whole trip.
* Deciding it at every step turns the character to face front whenever a
* step touches the vertical, and it shows badly.
VersoCammino     ldx   ActIdx
                 lda   ActDstX,x
                 sec
                 sbc   ActX,x
                 sta   WalkDX
                 lda   ActDstY,x
                 sec
                 sbc   ActY,x
                 sta   WalkDY
                 lda   WalkDX
                 bpl   :dx1
                 eor   #$FFFF
                 inc   a
:dx1             sta   WalkAX
                 lda   WalkDY
                 bpl   :dy1
                 eor   #$FFFF
                 inc   a
:dy1             sta   WalkAY
                 lda   WalkAX
                 cmp   WalkAY
                 bcc   :vert
                 lda   WalkDX               ; the horizontal drives
                 bmi   :sx
                 lda   #1
                 bra   :messo
:sx              lda   #0
                 bra   :messo
:vert            lda   WalkDY
                 bmi   :su
                 lda   #2
                 bra   :messo
:su              lda   #3
:messo           jmp   SetFacing

*=======================================================================
* hWalkTo ($1E) - walkActorTo
*=======================================================================
hWalkTo          jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg
                 jsr   VOB3
                 sta   ActArg2
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :niente
                 stx   ActIdx
                 jsr   AvviaCamminoQui
:niente          stz   Esito
                 rts

*=======================================================================
* AvviaCammino - ActNo towards (ActArg,ActArg2)
*=======================================================================
AvviaCammino     lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 stx   ActIdx
                 jmp   AvviaCamminoQui
:fine            rts

*=======================================================================
* AvviaCamminoQui - as above, but ActIdx is already set
*=======================================================================
* The destination has to be brought inside the walkable area, and we note
* which box it landed in: the trip is made box by box.
AvviaCamminoQui  anop
                 lda   ActArg
                 sta   BoxQx
                 lda   ActArg2
                 sta   BoxQy
                 jsr   AvvicinaPunto
                 ldx   ActIdx
                 lda   BoxQx
                 sta   ActFinX,x
                 lda   BoxQy
                 sta   ActFinY,x
                 lda   BoxScelta
                 sta   ActBoxFin,x

                 lda   ActX,x               ; and where we start from
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :hocasella
                 jsr   AvvicinaPunto        ; outside them all: the nearest
                 lda   BoxScelta
:hocasella       ldx   ActIdx
                 sta   ActBox,x
                 stz   ActUltima,x
                 stz   ActErr,x
                 lda   #1
                 sta   ActMoving,x
                 jsr   ProssimaTappa
                 ldx   ActIdx
                 lda   ActMoving,x
                 beq   :fine
                 jsr   VersoCammino
                 lda   #0                   ; the walking frame
                 jsr   StartAnim
:fine            rts

*=======================================================================
* ProssimaTappa - where to go now, within the trip
*=======================================================================
* If we are already in the destination box, head straight for the goal.
* Otherwise ask the matrix which box to cross, find that box's point
* nearest to where we are, and then bring it back onto the edge of the
* box we are in: that edge point is the one to reach.
ProssimaTappa    ldx   ActIdx
                 lda   ActUltima,x
                 beq   :avanti
                 brl   :finita
:avanti          lda   ActBoxFin,x
                 cmp   #$FFFF
                 beq   :dritto
                 cmp   ActBox,x
                 beq   :dritto

                 sta   BoxA
                 lda   ActBox,x
                 sta   BoxDa
                 jsr   ProssimaCasella
                 cmp   #$FFFF
                 beq   :dritto
                 sta   BoxProx

                 ldx   ActIdx               ; the point of the next
                 lda   ActX,x               ; box nearest to us
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 lda   BoxProx
                 jsr   PuntoNellaCasella
                 lda   BoxCx                ; and from there back to the edge
                 sta   BoxQx                ; of the current box
                 lda   BoxCy
                 sta   BoxQy
                 ldx   ActIdx
                 lda   ActBox,x
                 jsr   PuntoNellaCasella
                 ldx   ActIdx
                 lda   BoxCx
                 sta   ActDstX,x
                 lda   BoxCy
                 sta   ActDstY,x
                 lda   BoxProx              ; once there, we will be across
                 sta   ActBox,x
                 stz   ActErr,x
                 bra   :controlla

:dritto          ldx   ActIdx
                 lda   ActFinX,x
                 sta   ActDstX,x
                 lda   ActFinY,x
                 sta   ActDstY,x
                 lda   #1
                 sta   ActUltima,x
                 stz   ActErr,x

:controlla       ldx   ActIdx               ; if already there, no step
                 lda   ActDstX,x
                 cmp   ActX,x
                 bne   :muovi
                 lda   ActDstY,x
                 cmp   ActY,x
                 bne   :muovi
                 lda   ActUltima,x
                 bne   :finita
                 jmp   ProssimaTappa        ; waypoint already reached: on
:finita          ldx   ActIdx
                 stz   ActMoving,x
                 rts
:muovi           lda   #1
                 sta   ActMoving,x
                 rts

*=======================================================================
* hWaitActor ($3B) - wait until he has finished walking
*=======================================================================
hWaitActor       jsr   VOB1
                 jsr   ActIndex
                 bcs   :libero
                 lda   ActMoving,x
                 beq   :libero
                 dec   PC                   ; put the opcode back and
                 dec   PC                   ; yield again
                 lda   #CEDI
                 sta   Esito
                 rts
:libero          stz   Esito
                 rts

*=======================================================================
* hGetActX ($43) / hGetActY ($23)
*=======================================================================
hGetActX         jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :zero
                 lda   ActX,x
                 bra   :metti
:zero            lda   #0
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hGetActY         jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :zero
                 lda   ActY,x
                 bra   :metti
:zero            lda   #0
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* RiscriviCred - the sound credit line, rewritten for the IIGS
*=======================================================================
* In the credits the game says "IBM sounds by": on this machine that
* makes no sense. If that line is recognised, ours goes in its place,
* keeping the names of whoever wrote it.
RiscriviCred     ldx   #0
:cerca           lda   MsgText,x            ; look for the three letters
                 and   #$00FF
                 cmp   #'I'
                 bne   :avanti
                 lda   MsgText+1,x
                 and   #$00FF
                 cmp   #'B'
                 bne   :avanti
                 lda   MsgText+2,x
                 and   #$00FF
                 cmp   #'M'
                 beq   :trovato
:avanti          inx
                 cpx   #MSGMAX-3
                 bcc   :cerca
                 rts

:trovato         lda   #MsgIIGS             ; my own line first, on its own
                 sta   zpStr
                 lda   #^MsgIIGS
                 sta   zpStr+2
                 jsr   CopiaMsg
                 lda   #MsgMusica           ; then the music one
                 sta   MsgDopo
                 rts

*=======================================================================
* CopiaMsg - bring the string zpStr points at into MsgText
*=======================================================================
CopiaMsg         ldy   #0
:lp              lda   [zpStr],y
                 and   #$00FF
                 sep   #$20
                 mx    %10
                 sta   MsgText,y
                 rep   #$20
                 mx    %00
                 beq   :fatta
                 iny
                 cpy   #MSGMAX-1
                 bcc   :lp
:fatta           sty   MsgLen
                 rts

*=======================================================================
* RidisegnaAttori - put whoever moves back in place
*=======================================================================
* The room buffer holds background, objects and characters already
* assembled. When a character moves he has to be erased from where he
* was (that is, the background and any lit objects there put back) and
* redrawn where he is now. We take a rectangle wide enough to hold him:
* forty-eight by seventy around the feet.
ATTW             =     80
ATTH             =     96

RidisegnaAttori  lda   RoomH
                 bne   :c_e
                 rts
:c_e             lda   ActDirty
                 bne   :lavoro
                 rts

* Two passes. In the first, every character is erased from where he was,
* using the box measured the last time he was drawn: underneath go the
* background and the lit objects. Then they are all redrawn, which
* updates the boxes. In the second pass the new boxes are marked too,
* otherwise the freshly drawn part would never reach the screen.
:lavoro          stz   ActDirty
                 stz   ActIdx
:pulisci         jsr   AttoreInScena
                 bcs   :pross1
                 jsr   ScatolaVecchia
                 bcs   :pross1
                 jsr   PuliscoRett
                 lda   DstX
                 sta   AggX
                 lda   DstY
                 sta   AggY
                 lda   DstX
                 clc
                 adc   BlkW
                 sta   AggR
                 lda   DstY
                 clc
                 adc   BlkH
                 sta   AggB
                 jsr   RidisegnaRett

* RidisegnaRett has just put back the objects that touched the piece,
* and for each one it left its own box in DstX/BlkW: marking that would
* send the object to the screen instead of the place the character left,
* and the old silhouette would stay there (the trail).
                 lda   AggX
                 sta   DstX
                 lda   AggY
                 sta   DstY
                 lda   AggR
                 sec
                 sbc   AggX
                 sta   BlkW
                 lda   AggB
                 sec
                 sbc   AggY
                 sta   BlkH
                 jsr   SegnaRett
:pross1          lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :pulisci

                 jsr   DrawActors

                 stz   ActIdx
:segna           jsr   AttoreInScena
                 bcs   :pross2
                 jsr   ScatolaVecchia
                 bcs   :pross2
                 jsr   SegnaRett
:pross2          lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :segna
                 rts

*=======================================================================
* AttoreInScena - carry clear if actor ActIdx should be drawn
*=======================================================================
AttoreInScena    ldx   ActIdx
                 lda   ActCost,x
                 beq   :no
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :no
                 lda   ActVis,x
                 beq   :no
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* ScatolaVecchia - puts the actor's box into DstX/DstY/BlkW/BlkH
*=======================================================================
* Carry set if it is empty (he has not drawn anything yet).
* The box to clean is the one measured the last time the actor was
* drawn: exact by construction. If it is empty nothing was drawn, so
* there is nothing to erase.
SPRW             =     176
SPRH             =     120

ScatolaVecchia   ldx   ActIdx
                 lda   ActBX2,x
                 sec
                 sbc   ActBX1,x
                 beq   :grande
                 bmi   :grande
                 sta   BlkW
                 lda   ActBY2,x
                 sec
                 sbc   ActBY1,x
                 beq   :grande
                 bmi   :grande
                 sta   BlkH
                 lda   ActBX1,x
                 sta   DstX
                 lda   ActBY1,x
                 sta   DstY
                 clc
                 rts

:grande          ldx   ActIdx
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a
                 sec
                 sbc   #72
                 bpl   :sx
                 lda   #0
:sx              and   #$FFFC
                 sta   DstX
                 clc
                 adc   #SPRW
                 cmp   RoomW
                 bcc   :dx
                 lda   RoomW
:dx              sec
                 sbc   DstX
                 sta   BlkW
                 beq   :vuota
                 bmi   :vuota

                 ldx   ActIdx
                 lda   ActY,x
                 asl   a
                 sec
                 sbc   #100
                 bpl   :su
                 lda   #0
:su              sta   DstY
                 clc
                 adc   #SPRH
                 cmp   RoomH
                 bcc   :giu
                 lda   RoomH
:giu             cmp   #ROOMROWS
                 bcc   :giu2
                 lda   #ROOMROWS
:giu2            sec
                 sbc   DstY
                 sta   BlkH
                 beq   :vuota
                 bmi   :vuota
                 clc
                 rts
:vuota           sec
                 rts

*=======================================================================
* hCutscene ($40) / hEndCut ($C0)
*=======================================================================
* A scene to watch: the cursor state is put aside, the pending sentence
* is cleared and everything is frozen. At the end it is all put back and
* the camera attaches to the player character again.
* A scene takes over the screen: how the game was - the room, the camera,
* the cursor - is put aside so that endCutscene can restore it. Without
* the room, the disk screen never came back: it sat there with room 50
* still on it.
hCutscene        lda   Vars+VO_CURSOR
                 sta   CutCursor
                 lda   CurRoom
                 sta   CutRoom
                 lda   CamMode
                 sta   CutCam
                 stz   Vars+VO_CURSOR
                 stz   SentN                ; the waiting sentence is void
                 lda   #SCR_SENT
                 jsr   FermaScript
                 jsr   ResetSentence
                 stz   Esito
                 rts

hEndCut          lda   CutCam
                 sta   CamMode
                 cmp   #CAM_SEGUI
                 bne   :stanza
                 lda   Vars+VO_EGO          ; following the player character means
                 jsr   FollowCamera         ; mean going where he is
                 bra   :cursore
:stanza          lda   CutRoom
                 cmp   CurRoom
                 beq   :cursore
                 jsr   ChangeRoom
:cursore         lda   CutCursor
                 cmp   #3
                 bcc   :ok
                 lda   #3
:ok              sta   Vars+VO_CURSOR
                 lda   #1
                 sta   Redraw
                 sta   PanDirty
                 sta   VerbsDirty
* On entering the disk screen the game deletes the verb panel to make
* room for the list of saved games, and on the way out it does not
* rebuild it: in the original interpreter the "user state" handling took
* care of that, and I have none. So script 164 is started again, which is
* exactly the one the game uses to rebuild its fifteen commands.
                 lda   DiscoAperto
                 beq   :niente
                 stz   DiscoAperto
                 lda   #SCR_VERBI
                 jsr   StartScript
:niente          stz   Esito
                 rts

*=======================================================================
* hOverride ($58) - the way out of a scene.
*=======================================================================
* It is there for whoever presses ESC: it records where to jump back to.
* But the important part is that the jump that follows must NOT be
* executed: it is the shortcut for skipping the scene, not the normal
* flow. So it is stepped over (one opcode byte plus the displacement
* word). Without this the whole live part of the script is skipped - the
* choice of the kids, for instance.
hOverride        lda   PC
                 sta   OvrPC
                 lda   SlotIdx
                 sta   OvrSlot
                 jsr   FetchB
                 jsr   FetchW
                 stz   Esito
                 rts

*=======================================================================
* hWaitMsg - wait until the message on screen has finished
*=======================================================================
* We step back one byte and yield: next time round the script reads this
* same opcode again. That is what the original engine does.
hWaitMsg         lda   Vars+VO_HAVEMSG
                 beq   :libero
                 dec   PC
                 lda   #CEDI
                 sta   Esito
                 rts
:libero          stz   Esito
                 rts

hStop            lda   #FINE
                 sta   Esito
                 rts

hBreak           lda   #CEDI
                 sta   Esito
                 rts

hGoto            jsr   Salta
                 stz   Esito
                 rts

hMove            jsr   FetchB
                 sta   DestVar
                 jsr   VOW1
                 ldx   DestVar
                 stx   TmpW
                 pha
                 lda   TmpW
                 jsr   ResolveVar
                 pla
                 sta   Vars,x
                 stz   Esito
                 rts

hMoveInd         jsr   FetchB               ; Var[Var[i]]
                 asl   a
                 tax
                 lda   Vars,x
                 and   #$00FF
                 asl   a
                 sta   DestVar
                 jsr   VOW1
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hAdd             jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 ldx   DestVar
                 clc
                 adc   Vars,x
                 sta   Vars,x
                 stz   Esito
                 rts

hAddInd          jsr   FetchB
                 asl   a
                 tax
                 lda   Vars,x
                 and   #$00FF
                 asl   a
                 sta   DestVar
                 jsr   VOW1
                 ldx   DestVar
                 clc
                 adc   Vars,x
                 sta   Vars,x
                 stz   Esito
                 rts

hSub             jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 sta   TmpW
                 ldx   DestVar
                 lda   Vars,x
                 sec
                 sbc   TmpW
                 sta   Vars,x
                 stz   Esito
                 rts

hSubInd          jsr   FetchB
                 asl   a
                 tax
                 lda   Vars,x
                 and   #$00FF
                 asl   a
                 sta   DestVar
                 jsr   VOW1
                 sta   TmpW
                 ldx   DestVar
                 lda   Vars,x
                 sec
                 sbc   TmpW
                 sta   Vars,x
                 stz   Esito
                 rts

hAssignB         jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   FetchB
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hInc             jsr   FetchB
                 jsr   ResolveVar
                 lda   Op
                 and   #$0080
                 bne   :giu
                 lda   Vars,x
                 inc   a
                 bra   :scrivi
:giu             lda   Vars,x
                 dec   a
:scrivi          sta   Vars,x
                 stz   Esito
                 rts

hVarRange        jsr   FetchB
                 asl   a
                 sta   DestVar
                 jsr   FetchB
                 sta   RangeN
:lp              lda   Op
                 and   #$0080
                 beq   :byte
                 jsr   FetchW
                 bra   :metti
:byte            jsr   FetchB
:metti           ldx   DestVar
                 sta   Vars,x
                 inx
                 inx
                 stx   DestVar
                 dec   RangeN
                 bne   :lp
                 stz   Esito
                 rts

*----- comparisons -----------------------------------------------------
* They all end with a displacement: jump if the condition is false.
* The order matters: in the original engine the first operand read is the
* variable (call it A) and the second the value (B), but the condition is
* written as "B compare A". The jump happens when it is FALSE.
hUnless          lda   Op
                 cmp   #$0028
                 beq   :zero
                 cmp   #$00A8
                 beq   :zero

                 jsr   FetchB
                 jsr   ReadVar
                 sta   CmpA
                 jsr   VOW1
                 sta   CmpB

                 lda   CmpB
                 cmp   CmpA
                 beq   :uguali
* less or greater, signed: if the subtraction overflows, the sign bit
* has to be flipped before looking at it
                 lda   CmpB
                 sec
                 sbc   CmpA
                 bvc   :nov
                 eor   #$8000
:nov             bmi   :minore
* here B > A
                 lda   Op
                 and   #$007F
                 cmp   #$0008               ; !=
                 beq   :vero
                 cmp   #$0078               ; B > A
                 beq   :vero
                 cmp   #$0004               ; B >= A
                 beq   :vero
                 bra   :falso
:minore          lda   Op
                 and   #$007F
                 cmp   #$0008               ; !=
                 beq   :vero
                 cmp   #$0044               ; B < A
                 beq   :vero
                 cmp   #$0038               ; B <= A
                 beq   :vero
                 bra   :falso
:uguali          lda   Op
                 and   #$007F
                 cmp   #$0048               ; ==
                 beq   :vero
                 cmp   #$0004               ; B >= A
                 beq   :vero
                 cmp   #$0038               ; B <= A
                 beq   :vero
                 bra   :falso

:zero            jsr   FetchB
                 jsr   ReadVar
                 tay
                 lda   Op
                 cmp   #$0028
                 bne   :nonzero
                 tya
                 beq   :vero
                 bra   :falso
:nonzero         tya
                 bne   :vero
:falso           jsr   Salta
                 stz   Esito
                 rts
:vero            jsr   SkipW
                 stz   Esito
                 rts

* unlessState - the four state bits of an object
hUnlessState     lda   Op
                 and   #$007F
                 sta   TmpW
                 jsr   VOW1
                 sta   ObjNo
                 jsr   GetObjState

                 ldx   TmpW
                 cpx   #$003F
                 beq   :b1n
                 cpx   #$005F
                 beq   :b2n
                 cpx   #$002F
                 beq   :b4n
                 cpx   #$000F
                 beq   :b8n
                 cpx   #$007F
                 beq   :b1
                 cpx   #$001F
                 beq   :b2
                 cpx   #$006F
                 beq   :b4
* $4F is left: state bit 8 set
:b8              and   #8
                 bra   :acceso
:b4              and   #4
                 bra   :acceso
:b2              and   #2
                 bra   :acceso
:b1              and   #1
                 bra   :acceso
:b8n             and   #8
                 bra   :spento
:b4n             and   #4
                 bra   :spento
:b2n             and   #2
                 bra   :spento
:b1n             and   #1
:spento          bne   :falso
                 bra   :vero
:acceso          bne   :vero
:falso           jsr   Salta
                 stz   Esito
                 rts
:vero            jsr   SkipW
                 stz   Esito
                 rts

*=======================================================================
* hClassOf ($1D) - jump if the object is NOT of those classes
*=======================================================================
* The object description carries a class byte at obcd+6: the game passes
* a mask and goes on only if all of them are there. An object that does
* not exist in this room counts as "does not have them".
hClassOf         jsr   VOW1
                 sta   ObjFound
                 jsr   VOB2
                 sta   TmpW                 ; the classes asked for
                 jsr   TrovaOggetto
                 bcs   :falso
                 lda   ObjCd
                 clc
                 adc   #6
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 and   TmpW
                 cmp   TmpW
                 bne   :falso
                 jsr   SkipW
                 stz   Esito
                 rts
:falso           jsr   Salta
                 stz   Esito
                 rts

*----- scripts ---------------------------------------------------------
hStartScript     jsr   VOB1
                 jsr   StartScript
                 stz   Esito
                 rts

hStopScript      jsr   VOB1
                 ora   #0
                 bne   :altro
                 lda   #FINE                ; zero means "freeze me"
                 sta   Esito
                 rts
:altro           sta   TmpW
                 ldx   #0
:lp              lda   SlotNum,x
                 cmp   TmpW
                 bne   :avanti
                 lda   SlotWhere,x
                 bne   :avanti
                 lda   #MORTO
                 sta   SlotStat,x
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 stz   Esito
                 rts

hChainScript     jsr   VOB1
                 jsr   StartScript
                 lda   #FINE
                 sta   Esito
                 rts

hIsRunning       jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 sta   TmpW
                 ldy   #0
                 ldx   #0
:lp              lda   SlotStat,x
                 beq   :avanti
                 lda   SlotNum,x
                 cmp   TmpW
                 bne   :avanti
                 ldy   #1
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 tya
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hDelay           jsr   FetchB
                 sta   DelLo
                 jsr   FetchB
                 xba
                 and   #$FF00
                 ora   DelLo
                 sta   DelLo
                 jsr   FetchB
                 sta   DelHi
* the number is written the other way round: the real delay is $FFFFFF
* minus the one given
                 lda   #$FFFF
                 sec
                 sbc   DelLo
                 sta   DelLo
                 lda   #$00FF
                 sbc   DelHi
                 sta   DelHi
* If a credits line has just been split into two prints, the pause that
* follows is lengthened: otherwise my two would share the time of one
* and stay on screen for half as long as the others.
                 lda   MsgDopo
                 beq   :normale
                 lda   DelLo
                 clc
                 adc   #240
                 sta   DelLo
                 lda   DelHi
                 adc   #0
                 sta   DelHi
:normale         ldx   CurSlot
                 lda   DelLo
                 sta   SlotDelLo,x
                 lda   DelHi
                 sta   SlotDelHi,x
                 lda   #CEDI
                 sta   Esito
                 rts

*----- room ------------------------------------------------------------
* It does not yield: in the original the script goes straight on, and the
* next two instructions are nearly always the ones that set the camera.
* If we yield, a redraw with the old framing slips in between.
* The exception is the script living inside the room file just replaced:
* that one is simply dead.
hLoadRoom        jsr   VOB1
                 jsr   ChangeRoom
                 jmp   DopoStanza

hRoomEgoFine     anop
DopoStanza       lda   SlotUcciso           ; the room change took away
                 beq   :guarda              ; the file I was reading from
                 stz   SlotUcciso
                 lda   #FINE
                 sta   Esito
                 rts
:guarda          ldx   CurSlot
                 lda   SlotWhere,x
                 beq   :vivo
                 lda   #FINE
                 sta   Esito
                 rts
:vivo            stz   Esito
                 rts

*=======================================================================
* hRoomEgo ($24) - loadRoomWithEgo
*=======================================================================
* Changing room is not enough: the player character also has to be put on
* the door he comes in through, turned, have the camera pointed at him
* and the entry script started. Without the camera you come in looking at
hRoomEgo         jsr   VOW1
                 sta   EgoObj
                 jsr   VOB2
                 sta   EgoStanza
                 jsr   FetchB               ; where to walk next, signed
                 sta   EgoAndX
                 jsr   FetchB
                 sta   EgoAndY
* The player character has to be assigned to the new room BEFORE it is
* loaded: the camera follows him, and if it still finds him in the old
* one it does the room change backwards and everything stays black.
                 lda   Vars+VO_EGO
                 jsr   ActIndex
                 bcs   :senzaego
                 lda   EgoStanza
                 sta   ActRoom,x
                 stz   ActVis,x
                 stz   ActMoving,x
:senzaego        lda   EgoStanza
                 jsr   ChangeRoom

                 lda   EgoObj               ; the door, in this room
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :senzaporta

                 lda   ObjCd                ; where you go and stand
                 clc
                 adc   #11
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   BoxQx
                 lda   ObjCd
                 clc
                 adc   #12
                 tay
                 lda   [zpRaw],y
                 and   #$001F
                 asl   a                    ; the byte counts in eights
                 asl   a                    ; pixels, actor y in twos
                 sta   BoxQy
                 jsr   AvvicinaPunto

                 lda   Vars+VO_EGO
                 jsr   ActIndex
                 bcs   :senzaporta
                 stx   ActIdx
                 lda   BoxQx
                 sta   ActX,x
                 lda   BoxQy
                 sta   ActY,x
                 stz   ActMoving,x
                 stz   ActVis,x
                 jsr   MostraAttori

:senzaporta      lda   Vars+VO_EGO          ; the camera onto him
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a
                 pha
                 lda   #4
                 jsr   NotaCam
                 pla
                 jsr   SetCameraAt
                 lda   #5
                 jsr   NotaCam
                 lda   Vars+VO_EGO
                 jsr   FollowCamera

                 lda   EgoAndX              ; and, if the opcode asks,
                 and   #$0080               ; two steps inside
                 bne   :fine
                 lda   EgoAndY
                 and   #$0080
                 bne   :fine
                 lda   Vars+VO_EGO
                 sta   ActNo
                 lda   EgoAndX
                 and   #$00FF
                 sta   ActArg
                 lda   EgoAndY
                 and   #$00FF
                 sta   ActArg2
                 jsr   AvviaCammino

:fine            lda   #SCR_ENTRA           ; the entry script
                 jsr   StartScript
                 jmp   DopoStanza

hRoomOps         jsr   VOB1
                 sta   RoomA
                 jsr   VOB2
                 sta   RoomB
                 jsr   FetchB
                 and   #$001F
                 cmp   #1
                 bne   :fine
                 lda   RoomA                ; the pan limits,
                 asl   a                    ; written in cells of eight
                 asl   a
                 asl   a
                 jsr   LimiteCamera
                 sta   Vars+VO_CAMMIN
                 lda   RoomB
                 asl   a
                 asl   a
                 asl   a
                 jsr   LimiteCamera
                 sta   Vars+VO_CAMMAX
:fine            stz   Esito
                 rts

*=======================================================================
* LimiteCamera - clamp a limit to what the room allows
*=======================================================================
* The real engine does this too (o2_roomOps, SO_ROOM_SCROLL): without it,
* a script asking for a band narrower than the room drives the camera
* into one end and leaves it there.
LimiteCamera     cmp   #SCRW2/2
                 bcs   :nontroppopoco
                 lda   #SCRW2/2
:nontroppopoco   sta   TmpW
                 lda   RoomW
                 sec
                 sbc   #SCRW2/2
                 bpl   :largaabbastanza
                 lda   #SCRW2/2
:largaabbastanza cmp   TmpW
                 bcs   :vabene
                 rts
:vabene          lda   TmpW
                 rts

*----- actors (for now we only take note) ------------------------------
hActorOps        jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg
                 jsr   FetchB
                 sta   ActSub
                 cmp   #2
                 bne   :noncolore
                 jsr   FetchB               ; Color carries one extra byte
                 brl   :fine
:noncolore       cmp   #3
                 bne   :costume
                 lda   ActNo                ; Name: needed by the sentence
                 jsr   ActIndex             ; sentence ("Give key to Bernard")
                 bcs   :saltanome
                 txa
                 asl   a
                 asl   a
                 asl   a                    ; index times sixteen
                 sta   NameBase2
                 stz   NameLen
:nlp             jsr   FetchB
                 beq   :nfatto
                 cmp   #$00FE
                 bcc   :nnormale
                 jsr   FetchB
                 bra   :nlp
:nnormale        cmp   #'@'
                 beq   :nlp
                 ldx   NameLen
                 cpx   #15
                 bcs   :nlp
                 sta   CopiaByte
                 txa
                 clc
                 adc   NameBase2
                 tax
                 sep   #$20
                 mx    %10
                 lda   CopiaByte
                 sta   ActName,x
                 rep   #$20
                 mx    %00
                 inc   NameLen
                 bra   :nlp
:nfatto          lda   NameLen
                 clc
                 adc   NameBase2
                 tax
                 sep   #$20
                 mx    %10
                 lda   #0
                 sta   ActName,x
                 rep   #$20
                 mx    %00
                 bra   :fine
:saltanome       jsr   SkipStrZero
                 bra   :fine
:costume         cmp   #4
                 bne   :voce
                 lda   ActNo                ; it is the costume: note it
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActArg
                 sta   ActCost,x
                 stz   ActVis,x             ; has to be reassembled
                 jsr   MostraUno
                 bra   :fine
* The colour he speaks in. With actor zero it is the fallback one, which
* the game sets at startup for everybody without one of their own.
:voce            cmp   #5
                 bne   :fine
                 lda   ActNo
                 bne   :suo
                 lda   ActArg
                 sta   DefTalk
                 bra   :fine
:suo             jsr   ActIndex
                 bcs   :fine
                 lda   ActArg
                 sta   ActTalk,x
:fine            stz   Esito
                 rts

*=======================================================================
* ActIndex - A = actor number, returns X = index*2
*=======================================================================
* The dark - rooms with the lights off
*=======================================================================
* Variable 12 says how the room is lit: bit 1 is the room light, bit 2
* the flashlight. Without the first the room must be blacked out; with
* the second a rectangle around the player character stays visible, as
* big as lights() said, with rounded corners.
* The black is not laid over the room once it is drawn - that would
* flicker - but inside the blit: every row is either copied or blacked,
* in a single pass.
PreparaBuio      stz   BuioOn
                 stz   TorOn
                 lda   Vars+VO_LIGHTS
                 and   #2
                 bne   :fine                ; lights on: nothing to do
                 lda   Vars+VO_LIGHTS
                 and   #4
                 beq   :fine                ; pitch dark: the room in
                 lda   #1                   ; memory is already black
                 sta   BuioOn
                 lda   TorciaW
                 beq   :fine
                 lda   Vars+VO_EGO
                 jsr   ActIndex
                 bcs   :fine
                 phx
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a                    ; in pixels inside the room
                 sec
                 sbc   ScrollX              ; and on the screen
                 sec
                 sbc   TorMezzaW
                 and   #$FFFE               ; on a whole byte
                 sta   TorX1
                 clc
                 adc   TorciaW
                 sta   TorX2
                 plx
                 lda   ActY,x
                 asl   a
                 clc
                 adc   #ROOMTOP
                 sec
                 sbc   TorMezzaH
                 sta   TorY1
                 clc
                 adc   TorciaH
                 sta   TorY2
                 lda   #1
                 sta   TorOn
:fine            rts

*=======================================================================
* RigaBuia - for screen row A, from which pixel to which it is lit
*=======================================================================
RigaBuia         sta   BuioY
                 stz   BuioL
                 stz   BuioR
                 lda   TorOn
                 beq   :fine
                 lda   BuioY
                 cmp   TorY1
                 bcc   :fine
                 cmp   TorY2
                 bcs   :fine
                 jsr   Smusso               ; the corners come in
                 sta   BuioSm
                 lda   TorX1
                 clc
                 adc   BuioSm
                 jsr   DentroSchermo
                 sta   BuioL
                 lda   TorX2
                 sec
                 sbc   BuioSm
                 jsr   DentroSchermo
                 cmp   BuioL
                 bcs   :ok
                 lda   BuioL
:ok              sta   BuioR
:fine            rts

* DentroSchermo - A clamped to zero..SCRPIX, in steps of two
DentroSchermo    bpl   :nonsotto
                 lda   #0
:nonsotto        cmp   #SCRPIX
                 bcc   :ok
                 lda   #SCRPIX
:ok              and   #$FFFE
                 rts

* Smusso - how far the cut comes in at this height. The eight values are
* the original's.
Smusso           lda   BuioY
                 sec
                 sbc   TorY1
                 cmp   #8
                 bcc   :alto
                 lda   TorY2
                 sec
                 sbc   BuioY
                 dec   a
                 cmp   #8
                 bcc   :alto
                 lda   #0
                 rts
:alto            asl   a
                 tax
                 lda   Angoli,x
                 rts

Angoli           dw    8,6,4,3,2,2,1,1

*=======================================================================
* PadreOk - is ObjCd inside another object? Carry if it is not drawn
*=======================================================================
* In V2 an object can have a "parent" and require it to be in a given
* state: that is how the things in the refrigerator stay hidden while the
* door is shut. The parent is the index within the room, counted from
* one, and the required state is in the high bit of the y.
* Without this check, objects already picked up came back into view as
* soon as somebody re-entered the room and the screen was fully redrawn.
PadreOk          lda   ObjCd
                 sta   PadreCd
:giro            lda   PadreCd
                 clc
                 adc   #8
                 tay
                 lda   [zpRaw],y
                 and   #$0080
                 beq   :zero
                 lda   #8
:zero            sta   PadreMask
                 lda   PadreCd
                 clc
                 adc   #10
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 beq   :si                  ; no parent: it is drawn
                 dec   a                    ; the table counts from one
                 asl   a
                 clc
                 adc   #28
                 adc   PadreLen
                 tay
                 lda   [zpRaw],y
                 beq   :si
                 sta   PadreCd
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   PadreNo
                 jsr   StatoDiPadre
                 and   PadreMask
                 cmp   PadreMask
                 bne   :no
                 bra   :giro
:si              clc
                 rts
:no              sec
                 rts

StatoDiPadre     lda   PadreNo
                 cmp   #MAXOBJ
                 bcs   :fuori
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 rts
:fuori           lda   #0
                 rts

*=======================================================================
ActIndex         cmp   #NACT
                 bcs   :fuori
                 asl   a
                 tax
                 clc
                 rts
:fuori           sec
                 rts

hPutActor        jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg               ; x
                 jsr   VOB3
                 sta   ActArg2              ; y
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActArg
                 sta   ActX,x
                 lda   ActArg2
                 sta   ActY,x
                 jsr   MostraUno
                 lda   ActNo                ; if it is here, redraw it
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fine
                 lda   #1
                 sta   Redraw
:fine            stz   Esito
                 rts

hPutInRoom       jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActArg
                 sta   ActRoom,x
                 stz   ActVis,x
                 jsr   MostraUno
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fine
* One, not an increment: if a "redraw everything" was already pending
* (value 1), incrementing it turned it into "redraw only the rectangle"
* (value 2), and the screen stayed behind at the old scroll position.
                 lda   #1
                 sta   Redraw
:fine            stz   Esito
                 rts

*=======================================================================
* hActorRoom ($03) - getActorRoom: which room a character is in
*=======================================================================
* This used to answer zero for everybody, and that one lie was enough to
* send you to the dungeon the moment Edna saw you: her script 36 asks
* where she is, compares it with the room you are in, and if the two
* differ it takes that to mean she has chased you out of sight and
* catches you there and then, without a word. Out of range the original
* answers zero as well, so an actor who does not exist is nowhere.
hActorRoom       jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :nessuno
                 lda   ActRoom,x
                 bra   :dillo
:nessuno         lda   #0
:dillo           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*----- objects ---------------------------------------------------------
hSetState        lda   Op
                 and   #$007F
                 jsr   BitDiStato
                 sta   StBit
                 jsr   VOW1
                 sta   ObjNo
                 jsr   GetObjState
                 ora   StBit
                 jsr   PutObjState
                 lda   StBit
                 cmp   #8
                 bne   :basta
                 jsr   AggiornaOggetto
:basta           stz   Esito
                 rts

hClearState      lda   Op
                 and   #$007F
                 jsr   BitDiStato
                 eor   #$FFFF
                 sta   StBit
                 jsr   VOW1
                 sta   ObjNo
                 jsr   GetObjState
                 and   StBit
                 jsr   PutObjState
                 lda   StBit
                 cmp   #$FFF7               ; it was bit 8, inverted
                 bne   :basta
                 jsr   AggiornaOggetto
:basta           stz   Esito
                 rts

* BitDiStato - from an opcode to the bit it touches
BitDiStato       cmp   #$0007
                 beq   :otto
                 cmp   #$0047
                 beq   :otto
                 cmp   #$0027
                 beq   :quattro
                 cmp   #$0067
                 beq   :quattro
                 cmp   #$0057
                 beq   :due
                 cmp   #$0017
                 beq   :due
                 lda   #1
                 rts
:due             lda   #2
                 rts
:quattro         lda   #4
                 rts
:otto            lda   #8
                 rts

* GetObjState - ObjNo -> A = the four high bits (the state)
GetObjState      lda   ObjNo
                 cmp   #MAXOBJ
                 bcs   :fuori
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 rts
:fuori           lda   #0
                 rts

* PutObjState - A = new state (four bits) for ObjNo
PutObjState      and   #$000F
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 lda   ObjNo
                 cmp   #MAXOBJ
                 bcs   :fuori
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 and   #$0F                 ; the owner stays as it is
                 ora   TmpW
                 sta   ObjFlag,x
                 rep   #$20
                 mx    %00
:fuori           rts

*----- bit variables ---------------------------------------------------
hSetBit          jsr   FetchW
                 sta   BitBase
                 jsr   VOB1
                 clc
                 adc   BitBase
                 sta   BitNo
                 jsr   VOB2
                 sta   BitVal
                 jsr   BitAddr
                 lda   BitVal
                 beq   :spegni
                 sep   #$20
                 mx    %10
                 lda   BitVars,x
                 ora   BitMask
                 sta   BitVars,x
                 rep   #$20
                 mx    %00
                 stz   Esito
                 rts
:spegni          sep   #$20
                 mx    %10
                 lda   BitMask
                 eor   #$FF
                 and   BitVars,x
                 sta   BitVars,x
                 rep   #$20
                 mx    %00
                 stz   Esito
                 rts

hGetBit          jsr   FetchB
                 sta   TmpW
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   FetchW
                 sta   BitBase
                 jsr   VOB1
                 clc
                 adc   BitBase
                 sta   BitNo
                 jsr   BitAddr
                 sep   #$20
                 mx    %10
                 lda   BitVars,x
                 and   BitMask
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 beq   :zero
                 lda   #1
:zero            ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

* BitAddr - from BitNo to X = byte, BitMask = mask
*=======================================================================
* The game's bits are four thousand and ninety-six, not two thousand:
* the sentence script reads 2952 plus the player character's number.
* With the small table that bit landed on top of 904, which somebody
* else had meanwhile set, and every "walk to" on an object was skipped
* in silence.
BitAddr          lda   BitNo
                 and   #$0FFF
                 sta   TmpW
                 lsr   a
                 lsr   a
                 lsr   a
                 tax
                 lda   TmpW
                 and   #$0007
                 tay
                 lda   #1
:lp              cpy   #0
                 beq   :fatto
                 asl   a
                 dey
                 bra   :lp
:fatto           sta   BitMask
                 rts

*----- opcodes that for now only consume their arguments ---------------
* The low byte goes into variable 21: that is the cursor state, and the
* game looks at it to know which mode it is in (3 = opening screen).
* The high byte turns parts of the interface on and off: left alone for now.
hCursor          jsr   VOW1
                 and   #$00FF
                 beq   :fine
                 sta   Vars+VO_CURSOR
:fine            stz   Esito
                 rts

*=======================================================================
* hPrint ($14) / hPrintEgo ($D8) - somebody says something
*=======================================================================
* Whoever was talking stops first. actorTalk does the same (stopTalk
* before runActorTalkScript) and it is not a detail: a line that arrives
* while the one before is still on screen replaces it without the timer
* ever running out, so nobody would close the first speaker's mouth.
* Bernard is where it showed: he says "Ok, I'm outta here!", Razor cuts
* in over him, and from then on Bernard chewed his way through the rest
* of the scene. The standing animation does not touch the mouth - in the
* costume it is a limb of its own, and only the two talk animations
* touch it - so once it is left looping nothing takes it back.
hPrint           jsr   SmettiParlare
                 jsr   VOB1
                 jsr   ColoreVoce
                 jsr   CatchStr
                 jsr   AttaccaParlare
                 stz   Esito
                 rts

hPrintEgo        jsr   SmettiParlare
                 lda   Vars+VO_EGO
                 jsr   ColoreVoce
                 jsr   CatchStr
                 jsr   AttaccaParlare
                 stz   Esito
                 rts

*=======================================================================
* AttaccaParlare / SmettiParlare - the mouth opening and closing
*=======================================================================
* In V2 there is nothing special about it: talking means starting a
* costume animation (frame 5) and stopping means starting another one
* (frame 4). The limbs then walk on by themselves every frame, and that
* is how the mouth moves.
ATTACCAPARLA     =     5
SMETTIPARLA      =     4

AttaccaParlare   lda   ChiParla
                 cmp   #255
                 beq   :niente
                 jsr   ActIndex
                 bcs   :niente
                 lda   ActRoom,x            ; not here means not visible
                 cmp   CurRoom
                 bne   :niente
                 lda   ActVis,x
                 beq   :niente
                 stx   ActIdx
                 lda   ChiParla
                 sta   ParlaOra
                 lda   #ATTACCAPARLA
                 jmp   StartAnim
:niente          stz   ParlaOra
                 rts

SmettiParlare    lda   ParlaOra
                 beq   :niente
                 cmp   #255
                 beq   :niente
                 jsr   ActIndex
                 bcs   :niente
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :niente
                 lda   ActVis,x
                 beq   :niente
                 stx   ActIdx
                 lda   #SMETTIPARLA
                 jsr   StartAnim
:niente          stz   ParlaOra
                 rts

*=======================================================================
* ColoreVoce - A = who is talking. Sets the message colour.
*=======================================================================
* Actor 255 is nobody: it is the room's voice, and goes in white.
ColoreVoce       sta   ChiParla
                 cmp   #255
                 beq   :bianco
                 jsr   ActIndex
                 bcs   :bianco
                 lda   ActTalk,x
                 bne   :suo
                 lda   DefTalk
                 bne   :suo
:bianco          lda   #15
:suo             sta   MsgColor
                 rts

*=======================================================================
* CatchStr - take the game's string and keep it for the panel,
*            instead of throwing it away
*=======================================================================
* Bit 7 of a byte ends a word (a space follows), values below eight are
* control codes, and from four up the code carries another byte with it.
* Code 1 is the line break.
CatchStr         stz   MsgLen
:lp              jsr   FetchB
                 beq   :fine
                 sta   ChTmp
                 and   #$007F
                 cmp   #8
                 bcs   :stampabile

                 cmp   #1
                 bne   :noncapo
                 lda   #$000A               ; 1: line break
                 jsr   PushMsg
                 bra   :noacapo
:noncapo         cmp   #3
                 bne   :noacapo
                 lda   #$0001               ; 3: the sentence pauses here and
                 jsr   PushMsg              ; wait; the rest is another
:noacapo         lda   ChTmp                ; screen
                 and   #$007F
                 cmp   #4
                 bcc   :spazio
                 jsr   FetchB
                 bra   :spazio

:stampabile      jsr   PushMsg
:spazio          lda   ChTmp
                 and   #$0080
                 beq   :lp
                 lda   #' '
                 jsr   PushMsg
                 bra   :lp

:fine            lda   #0
                 jsr   PushMsg
                 jsr   RiscriviCred

* If the game reprints the same line (and in the waiting loop it does so
* constantly) the screen is left alone: it would only flicker.
                 ldx   #0
:uguale          lda   MsgText,x
                 cmp   MsgPrev,x
                 bne   :nuovo
                 inx
                 inx
                 cpx   #MSGMAX
                 bcc   :uguale
                 rts
:nuovo           ldx   #0
:copia           lda   MsgText,x
                 sta   MsgPrev,x
                 inx
                 inx
                 cpx   #MSGMAX
                 bcc   :copia
                 inc   MsgNew

* How long it stays on screen, as in the game: it depends on the length.
* Without this delay the next message wipes it instantly, which is why a
* kid's description could only be read by holding the button down.
                 stz   MsgPag               ; start from the first page
                 lda   MsgDopo              ; if another follows, this one
                 beq   :normale             ; has to make room for them
                 lda   #235
                 bra   :messo
:normale         jsr   TempoPagina
:messo           sta   MsgTimer
                 lda   #1
                 sta   Vars+VO_HAVEMSG

* The counter of letters printed. It is never cleared: scripts use it to
* wait until a sentence has reached a given point. Without it, the
* opening dialogue script waits for ever - which is why choosing Bernard
* left the verb panel empty.
                 lda   Vars+VO_CHARCNT
                 clc
                 adc   MsgLen
                 sta   Vars+VO_CHARCNT
                 rts

*=======================================================================
* LunghPagina - how many characters the page starting at MsgPag has
*=======================================================================
* A page ends at code 1 (which in the game's text was code 3, "wait") or
* at the end of the sentence.
LunghPagina      ldx   MsgPag
                 lda   #0
                 sta   PagLen
:lp              cpx   #MSGMAX
                 bcs   :fine
                 sep   #$20
                 mx    %10
                 lda   MsgText,x
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 beq   :fine
                 cmp   #1
                 beq   :fine
                 inc   PagLen
                 inx
                 bra   :lp
:fine            lda   PagLen
                 rts

*=======================================================================
* TempoPagina - how long the current page stays on screen
*=======================================================================
TempoPagina      jsr   LunghPagina
                 asl   a
                 asl   a
                 clc
                 adc   #60
                 rts

*=======================================================================
* ProssimaPagina - move to the next page. Carry set if it was the last.
*=======================================================================
ProssimaPagina   ldx   MsgPag
:lp              cpx   #MSGMAX
                 bcs   :basta
                 sep   #$20
                 mx    %10
                 lda   MsgText,x
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 beq   :basta
                 inx
                 cmp   #1
                 bne   :lp
                 stx   MsgPag               ; the character after the sign
                 clc
                 rts
:basta           sec
                 rts

PushMsg          ldx   MsgLen
                 cpx   #MSGMAX
                 bcs   :pieno
                 sep   #$20
                 mx    %10
                 sta   MsgText,x
                 rep   #$20
                 mx    %00
                 inc   MsgLen
:pieno           rts

hSentence        jsr   VOB1
                 sta   TmpW
                 cmp   #$00FC               ; stop the sentences
                 bne   :nonferma
                 stz   SentN
                 lda   #SCR_SENT
                 jsr   FermaScript
                 stz   Esito
                 rts
:nonferma        cmp   #$00FB               ; clear the sentence
                 bne   :piena
                 jsr   ResetSentence
                 stz   Esito
                 rts

:piena           jsr   VOW2
                 sta   TmpW2
                 jsr   VOW3
                 sta   SentBT
                 jsr   FetchB
                 sta   SentSub

                 lda   SentSub
                 cmp   #1
                 beq   :subito
                 cmp   #2
                 beq   :scrivi
* zero: queued, the sentence script will deal with it
                 lda   SentN
                 cmp   #NSENT
                 bcs   :fine
                 asl   a
                 tax
                 lda   TmpW
                 sta   SentVerb,x
                 lda   TmpW2
                 sta   SentObjA,x
                 lda   SentBT
                 sta   SentObjB,x
                 inc   SentN
:fine            stz   Esito
                 rts

* Run it now. Verbs 253 and 250 are special: they exist to run an
* object's script without touching the sentence variables, and that is
* how the disk screen lights up its buttons. Writing them anyway made the
* game believe the player had just clicked "Continue playing", so it
* closed by itself.
:subito          lda   TmpW
                 cmp   #$00FE               ; 254: stop the object's script
                 bne   :nonferma2
                 lda   TmpW2
                 jsr   FermaOggetto
                 stz   Esito
                 rts
:nonferma2       cmp   #$00FD
                 beq   :speciale
                 cmp   #$00FA
                 beq   :speciale
                 sta   Vars+VO_ACTVERB
                 lda   TmpW2
                 sta   Vars+VO_ACTOBJ1
                 lda   SentBT
                 sta   Vars+VO_ACTOBJ2
                 bra   :esegui
:speciale        lda   #$00FD
                 sta   TmpW
                 lda   #1
                 sta   SpecialeOra
:esegui          lda   TmpW2
                 sta   ObjFound
                 lda   TmpW
                 sta   VerbWanted
                 jsr   RunObjScript
                 bcs   :finito
                 lda   SpecialeOra
                 beq   :finito
                 jsr   GiraSubito
:finito          stz   SpecialeOra
                 stz   Esito
                 rts

:scrivi          lda   TmpW                 ; the sentence is only displayed
                 sta   Vars+VO_SENTVERB
                 lda   TmpW2
                 sta   Vars+VO_SENTOBJ1
                 lda   SentBT
                 sta   Vars+VO_SENTOBJ2
                 stz   Esito
                 rts

*=======================================================================
* ResetSentence - the sentence starts over
*=======================================================================
* The verb does not go to zero but to the "backup verb", which in this
* game is 13, that is "walk to". That is why clicking an object without
* having picked a verb counts as "go there".
ResetSentence    lda   Vars+VO_BACKVERB
                 sta   Vars+VO_SENTVERB
                 lda   #0
                 sta   Vars+VO_SENTOBJ1
                 sta   Vars+VO_SENTOBJ2
                 sta   Vars+VO_SENTPREP
                 rts

*=======================================================================
* FermaScript - A = number, kills the slots running it
*=======================================================================
FermaScript      sta   TmpW
                 ldx   #0
:lp              lda   SlotStat,x
                 beq   :avanti
                 lda   SlotNum,x
                 cmp   TmpW
                 bne   :avanti
                 lda   SlotWhere,x
                 bne   :avanti
                 lda   #MORTO
                 sta   SlotStat,x
                 cpx   CurSlot              ; did I just kill myself?
                 bne   :avanti
                 lda   #1
                 sta   SlotFuori
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 rts

*=======================================================================
* FermaOggetto - A = object number, kills its scripts
*=======================================================================
* The twin of FermaScript for scripts living inside an object
* (stopObjectScript): same sums, but the other way round on "where".
FermaOggetto     sta   TmpW
                 ldx   #0
:lp              lda   SlotStat,x
                 beq   :avanti
                 lda   SlotWhere,x
                 beq   :avanti
                 lda   SlotNum,x
                 cmp   TmpW
                 bne   :avanti
                 lda   #MORTO
                 sta   SlotStat,x
                 cpx   CurSlot
                 bne   :avanti
                 lda   #1
                 sta   SlotFuori
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 rts

*=======================================================================
* GiraScript - A = number, returns 1 in A if it is running
*=======================================================================
* Only real scripts: isScriptRunning does not look at object ones, and an
* object can perfectly well have the same number as a script.
GiraScript       sta   TmpW
                 ldx   #0
:lp              lda   SlotStat,x
                 beq   :avanti
                 lda   SlotWhere,x
                 bne   :avanti
                 lda   SlotNum,x
                 cmp   TmpW
                 beq   :si
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 lda   #0
                 rts
:si              lda   #1
                 rts

*=======================================================================
* CheckSentence - once per frame: if a sentence is waiting, hand it to
*                 the script the game uses to carry them out
*=======================================================================
CheckSentence    lda   #SCR_SENT
                 jsr   GiraScript
                 bne   :fine
                 lda   SentN
                 beq   :fine
                 dec   SentN
                 lda   SentN
                 asl   a
                 tax
                 lda   SentVerb,x
                 sta   Vars+VO_ACTVERB
                 sta   VerbWanted
                 lda   SentObjA,x
                 sta   Vars+VO_ACTOBJ1
                 sta   ObjFound
                 lda   SentObjB,x
                 sta   Vars+VO_ACTOBJ2

                 lda   ObjFound             ; is the verb allowed?
                 sta   NomeChi
                 jsr   CercaObcd
                 bcs   :nopuoi
                 jsr   EntrataVerbo
                 bcs   :nopuoi
                 lda   #1
                 bra   :segna
:nopuoi          lda   #0
:segna           sta   Vars+VO_VERBOK
                 lda   #SCR_SENT
                 jsr   StartScript
:fine            rts

*=======================================================================
* TrovaOggetto - ObjFound -> ObjCd, carry if it is not in this room
*=======================================================================
TrovaOggetto     lda   RoomH
                 beq   :no
                 ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   NumRoomObj
                 beq   :no
                 asl   a
                 sta   ObjTabLen
                 stz   ObjIdx
:lp              lda   #28
                 clc
                 adc   ObjTabLen
                 adc   ObjIdx
                 tay
                 lda   [zpRaw],y
                 sta   ObjCd
                 beq   :prossimo
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 cmp   ObjFound
                 beq   :trovato
                 bra   :prossimo
:prossimo        lda   ObjIdx
                 clc
                 adc   #2
                 sta   ObjIdx
                 cmp   ObjTabLen
                 bcc   :lp
:no              sec
                 rts
:trovato         clc
                 rts

*=======================================================================
* EntrataVerbo - look for VerbWanted in ObjCd. VerbOff = where its
*                script starts, carry if that verb is not there
*=======================================================================
* The table sits at obcd+15: pairs (verb, offset), ended by a zero.
* Verb $FF covers everything not listed.
EntrataVerbo     lda   #15
                 sta   TmpW
:lp              ldy   TmpW
                 lda   [zpNome],y
                 and   #$00FF
                 beq   :no
                 cmp   VerbWanted
                 beq   :preso
                 cmp   #$00FF
                 beq   :preso
                 lda   TmpW
                 clc
                 adc   #2
                 sta   TmpW
                 bra   :lp
:preso           ldy   TmpW
                 iny
                 lda   [zpNome],y
                 and   #$00FF
                 beq   :no
                 sta   VerbOff              ; offset inside the obcd
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* RunObjScript - start the script for verb VerbWanted on object
*                ObjFound, if it has one
*=======================================================================
RunObjScript     lda   ObjFound
                 sta   NomeChi
                 jsr   CercaObcd
                 bcs   :no
                 jsr   EntrataVerbo
                 bcs   :no
                 lda   SpecialeOra          ; special verbs may run
                 bne   :senzafermare        ; in several copies: that is how the
                 lda   ObjFound             ; disk screen calls the same script
                 jsr   FermaOggetto         ; ten times in a row
:senzafermare    jsr   FreeSlot
                 bcs   :no
                 sta   NestSlot
                 asl   a
                 tax
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   ObjDove              ; in the room or already in hand
                 beq   :dallastanza
                 lda   #DA_MANO
                 bra   :doveok
:dallastanza     lda   #DA_STANZA
:doveok          sta   SlotWhere,x
                 lda   ObjFound
                 sta   SlotNum,x
                 lda   ObjBaseT
                 sta   SlotBaseT,x
                 lda   #0
                 sta   SlotDelLo,x
                 sta   SlotDelHi,x
                 lda   VerbOff
                 sta   SlotPC,x
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* GiraSubito - run slot NestSlot here and now
*=======================================================================
* An object script started by doSentence "run now" does not begin on the
* next frame: it runs straight away, inside whoever asked for it, the way
* runScriptNested does. It really is needed: the disk screen builds the
* list of saved games by calling the same script ten times in a row,
* changing one variable each time. If they all started afterwards they
* would all read the last value and a single name would be left.
GiraSubito       lda   CurSlot              ; put aside the one running
                 pha
                 lda   PC
                 pha
                 lda   zpCode
                 pha
                 lda   zpCode+2
                 pha
                 lda   Op
                 pha
                 lda   Esito
                 pha
                 lda   SlotFuori
                 pha

                 stz   SlotFuori
                 lda   NestSlot
                 jsr   ExecSlot

                 pla
                 sta   SlotFuori
                 pla
                 sta   Esito
                 pla
                 sta   Op
                 pla
                 sta   zpCode+2
                 pla
                 sta   zpCode
                 pla
                 sta   PC
                 pla
                 sta   CurSlot
                 rts

*=======================================================================
* LeggiObj - from ObjCd/ObjIdx get position, size and picture
*=======================================================================
LeggiObj         lda   #28                  ; the first table holds the
                 clc                        ; pictures
                 adc   ObjIdx
                 tay
                 lda   [zpRaw],y
                 sta   ObjImgOff
                 beq   :no

                 lda   ObjCd
                 clc
                 adc   #7
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 sta   DstX
                 lda   ObjCd
                 clc
                 adc   #8
                 tay
                 lda   [zpRaw],y
                 and   #$007F
                 asl   a
                 asl   a
                 asl   a
                 sta   DstY
                 lda   ObjCd
                 clc
                 adc   #9
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 sta   BlkW
                 beq   :no
                 lda   ObjCd
                 clc
                 adc   #13
                 tay
                 lda   [zpRaw],y
                 and   #$00F8
                 sta   BlkH
                 beq   :no

                 lda   DstX                 ; has to fit inside
                 clc
                 adc   BlkW
                 cmp   RoomW
                 beq   :altezza
                 bcs   :no
:altezza         lda   DstY
                 clc
                 adc   BlkH
                 cmp   RoomH
                 beq   :ok
                 bcs   :no
:ok              clc
                 rts
:no              sec
                 rts

*=======================================================================
* PuliscoRett - put the clean background back where the object is
*=======================================================================
PuliscoRett      lda   BlkW
                 lsr   a
                 sta   TmpW2                ; bytes to copy per row
                 lda   DstX
                 lsr   a
                 sta   ColByte              ; the column, in bytes
                 lda   DstY
                 sta   Riga
:riga            lda   Riga
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColByte
                 tay
                 ldx   #0
:pix             lda   [zpBg],y
                 sta   [zpPix],y
                 iny
                 iny
                 inx
                 inx
                 cpx   TmpW2
                 bcc   :pix
                 inc   Riga
                 lda   Riga
                 sec
                 sbc   DstY
                 cmp   BlkH
                 bcc   :riga
                 rts

*=======================================================================
* AggiornaOggetto - redraw an object when its state changes
*=======================================================================
* On: the background goes back and the picture is decompressed over it.
* Off: the background alone is enough.
* The object is the one in ObjNo: it is copied into ObjFound too, which
* is where TrovaOggetto reads. Without this, callers coming from
* setState/clearState ended up redrawing the last object that passed by.
AggiornaOggetto  lda   RoomH
                 beq   :fine
                 lda   ObjNo
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :fine
                 jsr   LeggiObj
                 bcs   :fine
                 jsr   PuliscoRett

                 lda   DstX                 ; the piece of room that was
                 sta   AggX                 ; just put back as it was
                 lda   DstY
                 sta   AggY
                 lda   DstX
                 clc
                 adc   BlkW
                 sta   AggR
                 lda   DstY
                 clc
                 adc   BlkH
                 sta   AggB

                 jsr   RidisegnaRett
* There may be a character under that object: putting the background
* back has just erased his legs. Flagging the actors as needing a redraw
* makes the next frame draw them again and put them right.
                 lda   #1
                 sta   ActDirty

                 lda   AggX                 ; what goes to the screen is that
                 sta   DstX                 ; piece, not the last object
                 lda   AggY                 ; that was redrawn
                 sta   DstY
                 lda   AggR
                 sec
                 sbc   AggX
                 sta   BlkW
                 lda   AggB
                 sec
                 sbc   AggY
                 sta   BlkH
                 jsr   SegnaRett
:fine            rts

*=======================================================================
* RidisegnaRett - put back every lit object that touches that piece
*=======================================================================
* Redrawing the object that changed is not enough: there can be another
* lit one in the same place. On the kid-selection screen the white frame
* around the chosen kid and the kid blinking sit exactly on top of each
* other, and whichever went off last took the other with it.
* In the dark the room is black and the objects are not drawn, so putting
* one back after a state change would light it up on its own: the door of
* the library kept showing the lit room behind it, and only a trip through
* the light switch washed it away.
RidisegnaRett    lda   Vars+VO_LIGHTS
                 and   #6
                 bne   :c_eluce
                 rts
:c_eluce         ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   AggNum
                 bne   :cisono
                 rts
:cisono          asl   a
                 sta   AggLen
                 lda   AggNum
                 dec   a
                 asl   a
                 sta   AggIdx

:lp              lda   AggIdx               ; LeggiObj takes the picture from
                 sta   ObjIdx               ; ObjIdx: without this it redraws
                 lda   #28                  ; another object's picture
                 clc
                 adc   AggLen
                 adc   AggIdx
                 tay
                 lda   [zpRaw],y
                 sta   ObjCd
                 beq   :prossimo
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 jsr   GetObjState
                 and   #8
                 beq   :prossimo
                 lda   AggLen
                 sta   PadreLen
                 jsr   PadreOk
                 bcs   :prossimo
                 jsr   LeggiObj
                 bcs   :prossimo

                 lda   DstX                 ; do they touch?
                 cmp   AggR
                 bcs   :prossimo
                 lda   DstX
                 clc
                 adc   BlkW
                 cmp   AggX
                 beq   :prossimo
                 bcc   :prossimo
                 lda   DstY
                 cmp   AggB
                 bcs   :prossimo
                 lda   DstY
                 clc
                 adc   BlkH
                 cmp   AggY
                 beq   :prossimo
                 bcc   :prossimo

                 lda   ObjImgOff
                 sta   SrcOff
                 lda   AggX                 ; only inside the piece being redone
                 sta   ClipX1
                 lda   AggR
                 sta   ClipX2
                 lda   AggY
                 sta   ClipY1
                 lda   AggB
                 sta   ClipY2
                 lda   #1
                 sta   ClipOn
                 jsr   DecodeRLE
                 stz   ClipOn

:prossimo        lda   AggIdx
                 sec
                 sbc   #2
                 sta   AggIdx
                 bmi   :fine
                 brl   :lp
:fine            rts

*=======================================================================
* SegnaRett - mark that only this piece needs blitting to the screen
*=======================================================================
* If there is one already, both are kept by taking the rectangle that
* contains them: they are always few and close, so the count stays one.
SegnaRett        lda   Redraw
                 cmp   #1
                 beq   :fine                ; a full redraw is already due
                 cmp   #2
                 beq   :unisci

                 lda   DstX
                 sta   DirtyX
                 lda   DstY
                 sta   DirtyY
                 lda   DstX
                 clc
                 adc   BlkW
                 sta   DirtyR
                 lda   DstY
                 clc
                 adc   BlkH
                 sta   DirtyB
                 lda   #2
                 sta   Redraw
                 rts

:unisci          lda   DstX
                 cmp   DirtyX
                 bcs   :noleft
                 sta   DirtyX
:noleft          lda   DstY
                 cmp   DirtyY
                 bcs   :notop
                 sta   DirtyY
:notop           lda   DstX
                 clc
                 adc   BlkW
                 cmp   DirtyR
                 bcc   :noright
                 sta   DirtyR
:noright         lda   DstY
                 clc
                 adc   BlkH
                 cmp   DirtyB
                 bcc   :fine
                 sta   DirtyB
:fine            rts

*=======================================================================
* BlitRett - blit only the marked rectangle to the screen
*=======================================================================
BlitRett         jsr   SottoIlPuntatore
                 bcc   :libero
                 _HideCursor
                 jsr   BlitRettReal
                 _ShowCursor
                 rts
:libero          jmp   BlitRettReal

*=======================================================================
* SottoIlPuntatore - does the dirty rectangle pass under the pointer?
*=======================================================================
* Hiding and showing QuickDraw's pointer on every frame makes it blink.
* But that is only needed when what is about to be blitted passes under
* it: the rectangle of a character walking on the other side of the
* screen does not touch it.
SottoIlPuntatore PushPtr PuntoMou
                 _GetMouse
                 lda   PuntoMou             ; the vertical comes first
                 sta   CurY
                 lda   PuntoMou+2
                 sta   CurX

                 lda   DirtyY               ; the rectangle is in coordinates
                 clc                        ; of room: bring it all to
                 adc   #ROOMTOP             ; screen
                 sta   TmpW
                 lda   CurY
                 clc
                 adc   #16                  ; the pointer's height
                 cmp   TmpW
                 bcc   :libero
                 lda   DirtyB
                 clc
                 adc   #ROOMTOP
                 cmp   CurY
                 bcc   :libero

                 lda   DirtyX
                 sec
                 sbc   ScrollX
                 bpl   :sinok
                 lda   #0
:sinok           sta   TmpW
                 lda   CurX
                 clc
                 adc   #16
                 cmp   TmpW
                 bcc   :libero
                 lda   DirtyR
                 sec
                 sbc   ScrollX
                 bmi   :libero
                 cmp   CurX
                 bcc   :libero
                 sec
                 rts
:libero          clc
                 rts

BlitRettReal     lda   DirtyB               ; clip to what is visible
                 cmp   #ROOMROWS
                 bcc   :bassook
                 lda   #ROOMROWS
                 sta   DirtyB
:bassook         lda   DirtyY
                 cmp   DirtyB
                 bcc   :altezzaok
:niente          rts

* the starting column, inside the window on screen
:altezzaok       lda   DirtyX
                 cmp   ScrollX
                 bcs   :dentro
                 lda   ScrollX
:dentro          sta   ClipX
                 sec
                 sbc   ScrollX
                 lsr   a
                 sta   ColScr               ; starting byte on screen
                 lda   ClipX
                 lsr   a
                 sta   ColRoom              ; and in the room buffer

* and the ending one
                 lda   DirtyR
                 sec
                 sbc   ScrollX
                 bmi   :niente
                 cmp   #SCRPIX
                 bcc   :destraok
                 lda   #SCRPIX
:destraok        inc   a                    ; round up to the byte
                 lsr   a
                 cmp   ColScr
                 bcc   :niente
                 beq   :niente
                 sec
                 sbc   ColScr
                 sta   ByteCount            ; how many bytes, not how many times:
                                            ; the loop writes two at a time

                 lda   DirtyY
                 sta   Riga
:riga            lda   Riga
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColRoom
                 tay                        ; Y: the row in the buffer

                 lda   Riga                 ; X: the row on screen,
                 clc                        ; below the speech line
                 adc   #ROOMTOP
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW                 ; row * 32
                 asl   a
                 asl   a                    ; row * 128
                 clc
                 adc   TmpW                 ; row * 160
                 clc
                 adc   ColScr
                 tax

                 stz   TmpW2
:pix             lda   [zpPix],y
                 stal  SHRBASE,x
                 iny
                 iny
                 inx
                 inx
                 inc   TmpW2
                 inc   TmpW2
                 lda   TmpW2
                 cmp   ByteCount
                 bcc   :pix

                 inc   Riga
                 lda   Riga
                 cmp   DirtyB
                 bcc   :riga
                 rts

*=======================================================================
* DrawRoom - blit the whole window that starts at ScrollX
*=======================================================================
DrawRoom         _HideCursor
                 jsr   DrawRoomReal
                 _ShowCursor
                 rts

DrawRoomReal     lda   RoomH
                 bne   :c_e
                 lda   ScrollX
                 sta   ScrollDis
                 jsr   ClearScreen
                 rts

:c_e             jsr   PreparaBuio
                 lda   ScrollX
                 sta   ScrollDis            ; from here on the screen shows
                 lsr   a                    ; this scroll position
                 sta   SrcRow
                 lda   #ROOMOFF
                 sta   DstRow
                 stz   Riga
                 lda   #ROOMOFF2
                 sta   FineRiga

:riga            lda   Riga
                 cmp   RoomH
                 bcc   :dentro
                 brl   :sotto
:dentro          cmp   #ROOMROWS
                 bcc   :dentro2
                 brl   :sotto
:dentro2         lda   BuioOn
                 beq   :normale

                 lda   Riga                 ; the lit piece of the row
                 clc
                 adc   #ROOMTOP
                 jsr   RigaBuia
                 lda   DstRow               ; black on the left
                 sta   FillStart
                 lda   BuioL
                 lsr   a
                 clc
                 adc   DstRow
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 lda   BuioR                ; black on the right
                 lsr   a
                 clc
                 adc   DstRow
                 sta   FillStart
                 lda   FineRiga
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 lda   BuioL                ; and in between it is copied
                 lsr   a
                 clc
                 adc   SrcRow
                 tay
                 lda   BuioR
                 lsr   a
                 clc
                 adc   DstRow
                 sta   FineCopia
                 lda   BuioL
                 lsr   a
                 clc
                 adc   DstRow
                 tax
                 bra   :prova

:normale         ldy   SrcRow
                 ldx   DstRow
                 lda   FineRiga
                 sta   FineCopia
:prova           cpx   FineCopia
                 bcs   :avanza
:pix             lda   [zpPix],y
                 stal  SHRBASE,x
                 iny
                 iny
                 inx
                 inx
                 cpx   FineCopia
                 bcc   :pix

:avanza          lda   SrcRow
                 clc
                 adc   Pitch
                 sta   SrcRow
                 lda   DstRow
                 clc
                 adc   #SCRW
                 sta   DstRow
                 clc
                 adc   #SCRW
                 sta   FineRiga
                 inc   Riga
                 brl   :riga

* below the room it is blacked out down to the panel
:sotto           lda   Riga
                 clc
                 adc   #ROOMTOP
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 asl   a
                 asl   a
                 clc
                 adc   TmpW
                 sta   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 rts

*=======================================================================
* ClearScreen / SetPalette / FillArea
*=======================================================================
ClearScreen      stz   FillStart
                 lda   #PANEND
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 rts

FillArea         ldx   FillStart
:lp              stal  SHRBASE,x
                 inx
                 inx
                 cpx   FillEnd
                 bcc   :lp
                 rts

* V2 has sixteen colours and they are always the same: one palette,
* written into all sixteen so nobody has to remember which one a
* scanline uses.
SetPalette       ldx   #0
                 lda   #$0000
:scb             stal  SHRBASE+SCBOFF,x
                 inx
                 inx
                 cpx   #200
                 bcc   :scb

                 ldx   #0
:pal             txa
                 and   #$001F
                 tay
                 lda   EgaPal,y
                 stal  SHRBASE+PALOFF,x
                 inx
                 inx
                 cpx   #512
                 bcc   :pal
                 rts

*=======================================================================
* hDrawObject - light an object and turn off whoever was in its place
*=======================================================================
* This is how the white frame of the kid selection moves: not with the
* state, but with this opcode. The original engine turns off every object
* occupying exactly the same rectangle and lights the one asked for.
hDrawObject      jsr   VOW1
                 sta   DrawObj
                 jsr   VOB2                 ; new position: 255 means
                 sta   DrawX                ; mean "leave him where he is"
                 jsr   VOB3
                 sta   DrawY

                 lda   DrawObj
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :fine
                 jsr   LeggiObj
                 bcs   :fine
                 lda   DstX
                 sta   RectX
                 lda   DstY
                 sta   RectY
                 lda   BlkW
                 sta   RectW
                 lda   BlkH
                 sta   RectH
                 jsr   SpegniStessoPosto

                 lda   DrawObj              ; and now light this one
                 sta   ObjFound
                 sta   ObjNo
                 jsr   GetObjState
                 ora   #8
                 jsr   PutObjState
                 jsr   AggiornaOggetto
:fine            stz   Esito
                 rts

*=======================================================================
* SpegniStessoPosto - turn off the objects sitting in the same
*                     rectangle as the one about to be lit
*=======================================================================
SpegniStessoPosto
                 ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 bne   :c_e
                 rts
:c_e             asl   a
                 sta   ObjTabLen
                 stz   ScanIdx
:lp              bra   :corpo
:salta           brl   :prossimo            ; trampoline for the short branches
:corpo           lda   ScanIdx
                 sta   ObjIdx
                 jsr   ObjCdDaIdx
                 sta   ObjCd
                 beq   :salta
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 cmp   DrawObj              ; not itself
                 beq   :salta
                 sta   ScanObj
                 sta   ObjNo
                 jsr   GetObjState
                 and   #8
                 beq   :salta            ; already off

                 jsr   LeggiObj
                 bcs   :salta
                 lda   DstX
                 cmp   RectX
                 bne   :salta
                 lda   DstY
                 cmp   RectY
                 bne   :salta
                 lda   BlkW
                 cmp   RectW
                 bne   :salta
                 lda   BlkH
                 cmp   RectH
                 bne   :salta

                 lda   ScanObj              ; same rectangle: turn off
                 sta   ObjNo
                 sta   ObjFound
                 jsr   GetObjState
                 and   #$FFF7
                 jsr   PutObjState
                 jsr   AggiornaOggetto
                 ldy   #20                  ; AggiornaOggetto has put back
                 lda   [zpRaw],y            ; touch the loop variables
                 and   #$00FF
                 asl   a
                 sta   ObjTabLen

:prossimo        lda   ScanIdx
                 clc
                 adc   #2
                 sta   ScanIdx
                 cmp   ObjTabLen
                 bcs   :fine
                 brl   :lp
:fine            rts

*=======================================================================
* ObjectAt - the lit object under (FindX, FindY), or zero
*=======================================================================
ObjectAt         lda   RoomH
                 bne   :c_e
:vuoto           lda   #0
                 rts
:c_e             ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   NumRoomObj
                 beq   :vuoto
                 asl   a
                 sta   ObjTabLen
                 stz   ObjIdx

:lp              bra   :corpo
:salta           brl   :prossimo            ; trampoline for the short branches
:corpo           lda   ObjIdx
                 jsr   ObjCdDaIdx
                 sta   ObjCd
                 beq   :salta
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 sta   ObjWant
                 jsr   GetObjState
                 and   #2                   ; "untouchable": the game
                 bne   :salta            ; skip

* The parent chain: an object inside something can only be clicked if
* that something is in the right state (the cupboard open, and so on).
                 lda   ObjCd
                 sta   ChainCd
:catena          lda   ChainCd
                 clc
                 adc   #8
                 tay
                 lda   [zpRaw],y
                 and   #$0080               ; the state the parent must
                 beq   :attesa0             ; have
                 lda   #8
                 bra   :attesa
:attesa0         lda   #0
:attesa          sta   ParState
                 lda   ChainCd
                 clc
                 adc   #10
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   ParIdx
                 beq   :prova               ; no parent: it can be

                 dec   a                    ; the index counts from one
                 asl   a
                 jsr   ObjCdDaIdx
                 sta   ChainCd
                 beq   :salta
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 jsr   GetObjState
                 and   #8
                 cmp   ParState
                 beq   :catena
                 bra   :salta

:prova           bra   :rett
:salta2          brl   :prossimo            ; second trampoline
:rett            lda   ObjCd                ; the object's rectangle
                 clc
                 adc   #7
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 lda   FindX
                 sec
                 sbc   TmpW
                 bmi   :salta2
                 sta   TmpW2
                 lda   ObjCd
                 clc
                 adc   #9
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 cmp   TmpW2
                 bcc   :salta2
                 beq   :salta2

                 lda   ObjCd
                 clc
                 adc   #8
                 tay
                 lda   [zpRaw],y
                 and   #$007F
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 lda   FindY
                 sec
                 sbc   TmpW
                 bmi   :salta2
                 sta   TmpW2
                 lda   ObjCd
                 clc
                 adc   #13
                 tay
                 lda   [zpRaw],y
                 and   #$00F8
                 cmp   TmpW2
                 bcc   :salta2
                 beq   :salta2
                 lda   ObjWant              ; found
                 rts

:prossimo        lda   ObjIdx
                 clc
                 adc   #2
                 sta   ObjIdx
                 cmp   ObjTabLen
                 bcs   :niente
                 brl   :lp
:niente          lda   #0
                 rts

*=======================================================================
* ObjCdDaIdx - A = index*2 in the table, returns where its description sits
*=======================================================================
ObjCdDaIdx       clc
                 adc   #28
                 adc   ObjTabLen
                 tay
                 lda   [zpRaw],y
                 rts

*=======================================================================
* BlitRect - send only the rectangle that changed to the screen
*=======================================================================
* Redrawing the whole picture for one door opening would be a waste:
* twenty thousand bytes against a few hundred.
BlitRect         lda   BlkH
                 bne   :c_e
                 rts
:c_e             lda   DstX                 ; does it all fit in the window?
                 cmp   ScrollX
                 bcs   :destra
:tutto           lda   #1                   ; overflows: might as well take it all
                 sta   Redraw
                 rts
:destra          clc
                 adc   BlkW
                 sec
                 sbc   ScrollX
                 cmp   #SCRPIX+1
                 bcs   :tutto

                 lda   DstX
                 lsr   a
                 sta   ColByte              ; column in the buffer
                 lda   DstX
                 sec
                 sbc   ScrollX
                 lsr   a
                 sta   TmpW                 ; column on screen
                 lda   BlkW
                 lsr   a
                 sta   TmpW2                ; how many bytes per row

                 lda   DstY                 ; row * 160
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   RigaScr
                 asl   a
                 asl   a
                 clc
                 adc   RigaScr
                 clc
                 adc   TmpW
                 sta   RigaScr
                 lda   DstY
                 sta   Riga

:riga            lda   Riga
                 cmp   #ROOMROWS
                 bcs   :fine
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColByte
                 tay
                 ldx   RigaScr
                 stz   ContaB
:pix             lda   [zpPix],y
                 stal  SHRBASE,x
                 iny
                 iny
                 inx
                 inx
                 inc   ContaB
                 inc   ContaB
                 lda   ContaB
                 cmp   TmpW2
                 bcc   :pix

                 lda   RigaScr
                 clc
                 adc   #SCRW
                 sta   RigaScr
                 inc   Riga
                 lda   Riga
                 sec
                 sbc   DstY
                 cmp   BlkH
                 bcc   :riga
:fine            rts

*=======================================================================
* DrawRoom - blit the whole window that starts at ScrollX
*=======================================================================

*=======================================================================
* The remaining opcodes: consume the arguments and take note
*=======================================================================
* lights(a, b, c): with c zero, a is how the room is lit; with c one, a
* and b are the size of the flashlight cone in strips of eight. Taking
* the first number as the light level always left a dark room lit up like
* day when you carried the flashlight.
hLights          jsr   VOB1
                 sta   LuceA
                 jsr   FetchB
                 sta   LuceB
                 jsr   FetchB
                 bne   :torcia
                 lda   LuceA
                 sta   Vars+VO_LIGHTS
                 bra   :fine
:torcia          lda   LuceA
                 asl   a
                 asl   a
                 asl   a
                 sta   TorciaW
                 lsr   a
                 sta   TorMezzaW
                 lda   LuceB
                 asl   a
                 asl   a
                 asl   a
                 sta   TorciaH
                 lsr   a
                 sta   TorMezzaH
:fine            lda   #1
                 sta   Redraw
                 stz   Esito
                 rts

hRandom          jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 inc   a                    ; the game wants zero to max
                 sta   RndN                 ; inclusive
                 jsr   Casuale
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* Casuale - a number from 0 to RndN-1
*=======================================================================
* The seed is stirred with three shifts and three exclusive-ors: the
* shortest round that gives a long sequence on sixteen bits. Then the big
* number is brought into range by multiplying and keeping the high half,
* which does not have the bias a remainder would.
Casuale          lda   RndSeed
                 bne   :c_e
                 lda   #$ACE1               ; the seed cannot be zero
:c_e             sta   RndX
                 ldy   #7                   ; x = x ^ (x << 7)
:s1              asl   a
                 dey
                 bne   :s1
                 eor   RndX
                 sta   RndX
                 ldy   #9                   ; x = x ^ (x >> 9)
:s2              lsr   a
                 dey
                 bne   :s2
                 eor   RndX
                 sta   RndX
                 ldy   #8                   ; x = x ^ (x << 8)
:s3              asl   a
                 dey
                 bne   :s3
                 eor   RndX
                 sta   RndX
                 sta   RndSeed

* (RndX * RndN) divided by 65536
                 stz   AccLo
                 stz   AccHi
                 lda   RndX
                 sta   ShLo
                 stz   ShHi
                 ldy   #16
:mul             lda   RndN
                 beq   :fatto
                 lsr   a
                 sta   RndN
                 bcc   :salta
                 lda   AccLo
                 clc
                 adc   ShLo
                 sta   AccLo
                 lda   AccHi
                 adc   ShHi
                 sta   AccHi
:salta           asl   ShLo
                 rol   ShHi
                 dey
                 bne   :mul
:fatto           lda   AccHi
                 rts

hRes             jsr   VOB1
                 jsr   FetchB
                 stz   Esito
                 rts

hUnoB            jsr   VOB1
                 stz   Esito
                 rts

hUnoW            jsr   VOW1
                 stz   Esito
                 rts

hDueB            jsr   VOB1
                 jsr   VOB2
                 stz   Esito
                 rts

hDueBW           jsr   VOB1
                 jsr   VOW2
                 stz   Esito
                 rts

hDueWB           jsr   VOW1
                 jsr   VOB2
                 stz   Esito
                 rts

*=======================================================================
* hWalkActor ($0D) - walkActorToActor: stand next to him
*=======================================================================
* The third byte says how far away to stop; $FF means "the right
* distance", which in the real engine comes from the width of the two
* costumes and for V2 works out at about thirty pixels: four eight-wide
* cells.
hWalkActor       jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   TmpW2
                 jsr   FetchB
                 cmp   #$00FF
                 bne   :distok
                 lda   #4
:distok          sta   TmpW

                 lda   TmpW2                ; where the target one is
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fine
                 lda   ActX,x
                 sta   ActArg
                 lda   ActY,x
                 sta   ActArg2

                 lda   ActNo                ; and where the walker is
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fine

                 lda   ActArg               ; stop on the side we come from
                 cmp   ActX,x                ; is reached
                 bcc   :dasinistra
                 sec
                 sbc   TmpW
                 bpl   :xok
                 lda   #0
                 bra   :xok
:dasinistra      lda   ActArg
                 clc
                 adc   TmpW
:xok             sta   ActArg
                 jsr   AvviaCammino
:fine            stz   Esito
                 rts

*=======================================================================
* hVicino ($66) - getClosestObjActor: who is nearest
*=======================================================================
* Walks backwards from VAR_ACTOR_RANGE_MAX to VAR_ACTOR_RANGE_MIN and
* keeps the nearest. Beyond 255 it cannot tell anything apart, like the
* original.
hVicino          jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 sta   DistA
                 lda   #$00FF
                 sta   VicinoChi
                 sta   VicinoQ
                 lda   Vars+VO_ACTMAX
                 sta   VicinoIdx
:lp              lda   VicinoIdx
                 sta   DistB
                 jsr   DistanzaFra
                 cmp   VicinoQ
                 bcs   :avanti
                 sta   VicinoQ
                 lda   VicinoIdx
                 sta   VicinoChi
:avanti          lda   VicinoIdx
                 beq   :basta
                 dec   a
                 sta   VicinoIdx
                 cmp   Vars+VO_ACTMIN
                 bcs   :lp
:basta           lda   VicinoChi
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* hObjName ($54) - setObjectName: the game renames an object
*=======================================================================
* The new name sits in the code right after and holds from here on: it is
* copied into a separate table, which ScriviNomeDi looks at first. If
* there is no room left the new name is lost, but the game carries on.
hObjName         jsr   VOW1
                 sta   NomeNuovo
                 jsr   PostoNome
                 bcs   :senzaposto
                 stx   NomeSlot
                 txa                        ; slot times twenty-four
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW                 ; times twenty-four
                 sta   NameBase2
                 stz   NameLen
:lp              jsr   FetchB
                 beq   :fatto
                 cmp   #$00FE
                 bcc   :normale
                 jsr   FetchB
                 bra   :lp
:normale         cmp   #'@'
                 beq   :lp
                 ldx   NameLen
                 cpx   #23
                 bcs   :lp
                 sta   CopiaByte
                 txa
                 clc
                 adc   NameBase2
                 tax
                 sep   #$20
                 mx    %10
                 lda   CopiaByte
                 sta   NomiBuf,x
                 rep   #$20
                 mx    %00
                 inc   NameLen
                 bra   :lp
:fatto           lda   NameLen
                 clc
                 adc   NameBase2
                 tax
                 sep   #$20
                 mx    %10
                 lda   #0
                 sta   NomiBuf,x
                 rep   #$20
                 mx    %00
                 ldx   NomeSlot
                 txa
                 asl   a
                 tax
                 lda   NomeNuovo
                 sta   NomiObj,x
                 lda   #1
                 sta   InvDirty
                 stz   Esito
                 rts
:senzaposto      jsr   SkipStrZero
                 stz   Esito
                 rts

*=======================================================================
* PostoNome - X = slot for NomeNuovo's name, carry if they are all full
*=======================================================================
* First it checks whether that object already has a replaced name: in
* that case its slot is reused, the way setObjectName does.
PostoNome        ldx   #0
:lp              lda   NomiObj,x
                 cmp   NomeNuovo
                 beq   :preso
                 inx
                 inx
                 cpx   #NNOMI*2
                 bcc   :lp
                 ldx   #0
:vuoto           lda   NomiObj,x
                 beq   :preso
                 inx
                 inx
                 cpx   #NNOMI*2
                 bcc   :vuoto
                 sec
                 rts
:preso           txa
                 lsr   a
                 tax
                 clc
                 rts

*=======================================================================
* NomeSostituito - carry clear if NomeChi has a new name: zpStr points
*                  at it
*=======================================================================
NomeSostituito   ldx   #0
:lp              lda   NomiObj,x
                 beq   :avanti
                 cmp   NomeChi
                 beq   :trovato
:avanti          inx
                 inx
                 cpx   #NNOMI*2
                 bcc   :lp
                 sec
                 rts
:trovato         txa
                 lsr   a                    ; slot times twenty-four
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW
                 clc
                 adc   #NomiBuf
                 sta   zpStr
                 lda   #^NomiBuf
                 sta   zpStr+2
                 clc
                 rts

hObjPrep         jsr   VOW1
                 jsr   FetchB
                 stz   Esito
                 rts

hBoxFlags        jsr   VOB1
                 jsr   FetchB
                 stz   Esito
                 rts

hResB            jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 lda   #0
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hResW            jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 lda   #0
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hTwoB            jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   VOB2
                 lda   #0
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* An object's owner sits in the low four bits of its state byte.
* Fifteen means "it is here in the room", the other numbers are the
* characters carrying it.
*=======================================================================
hGetOwner        jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 sta   ObjNo
                 jsr   GetObjOwner
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

GetObjOwner      lda   ObjNo
                 cmp   #MAXOBJ
                 bcs   :fuori
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 rep   #$20
                 mx    %00
                 and   #$000F
                 rts
:fuori           lda   #0
                 rts

*=======================================================================
* hPickup ($50) - the player character picks an object up
*=======================================================================
* The object's description is copied out of the room, because from now on
* it travels with him: the name and the verb scripts have to stay within
* reach in another room too.
hPickup          jsr   VOW1
                 sta   ObjNo
                 sta   ObjFound
                 sta   NomeChi
                 beq   :fine
                 jsr   GetObjOwner          ; has he got it already?
                 cmp   #$000F
                 bne   :fine
                 jsr   TrovaOggetto         ; is it in this room?
                 bcs   :fine
                 jsr   CopiaInMano
                 bcs   :fine

                 lda   Vars+VO_EGO          ; from now on it is his
                 and   #$000F
                 sta   TmpW
                 lda   ObjNo
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 and   #$F0
                 ora   TmpW
                 sta   ObjFlag,x
                 rep   #$20
                 mx    %00

                 jsr   GetObjState          ; lit and no longer touchable
                 ora   #$000A
                 jsr   PutObjState
                 jsr   AggiornaOggetto      ; and it leaves the room
                 lda   #1
                 sta   InvDirty
:fine            stz   Esito
                 rts

*=======================================================================
* CopiaInMano - copy object ObjCd's obcd into a free slot
*=======================================================================
* The length is in the first word of the obcd itself. Carry set if there
* is no room left or if it is too big.
CopiaInMano      stz   InvIdx
:cerca           ldx   InvIdx
                 lda   InvObj,x
                 beq   :trovato
                 lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcc   :cerca
                 sec
                 rts

:trovato         ldy   ObjCd
                 lda   [zpRaw],y
                 sta   CopiaQ
                 beq   :no
                 cmp   #INVLEN
                 bcc   :ciscappa
                 lda   #INVLEN
                 sta   CopiaQ
:ciscappa        lda   InvIdx               ; InvBuf + slot*256
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   CopiaDst

                 lda   zpRaw                ; where to copy from
                 clc
                 adc   ObjCd
                 sta   zpNome
                 lda   zpRaw+2
                 adc   #0
                 sta   zpNome+2

                 ldy   #0
:giro            lda   [zpNome],y
                 sta   CopiaByte
                 tya
                 clc
                 adc   CopiaDst
                 tax
                 sep   #$20
                 mx    %10
                 lda   CopiaByte
                 sta   InvBuf,x
                 rep   #$20
                 mx    %00
                 iny
                 cpy   CopiaQ
                 bcc   :giro

                 ldx   InvIdx
                 lda   ObjNo
                 sta   InvObj,x
                 clc
                 rts
:no              sec
                 rts

hSetOwner        jsr   VOW1
                 sta   ObjNo
                 jsr   VOB2
                 and   #$000F
                 sta   TmpW
                 lda   ObjNo
                 cmp   #MAXOBJ
                 bcs   :fine
                 tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 and   #$F0
                 ora   TmpW
                 sta   ObjFlag,x
                 rep   #$20
                 mx    %00
                 lda   #1                   ; the inventory may have
                 sta   InvDirty             ; changed
:fine            stz   Esito
                 rts

hGetDist         jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 sta   DistA
                 jsr   VOW2
                 sta   DistB
                 jsr   DistanzaFra
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* DistanzaFra - how far apart DistA and DistB are, which can be
*               characters or objects
*=======================================================================
* This is getObjActToObjActDist, and it is worth saying exactly what it
* measures, because getting it wrong cost a long hunt.
*
* ScummVM keeps a V2 actor's position in the units the scripts use, and
* only multiplies by eight and by two when it needs pixels: getPos()
* scales, getRealPos() does not. getObjectOrActorXY reads getRealPos, and
* an object's walk point goes through the same door (walk_x >> 3,
* walk_y >> 1). So both sides arrive here in script units.
*
* The distance itself is getDist: MAX(|dx|, |dy|). Chebyshev, not
* Pythagoras - a square, not a circle.
*
* Together they explain the numbers the game uses. Script 36 has Edna
* walk to within 2 of her victim and then declares him caught at "<= 2":
* the same 2, in the same units, so the chase ends the moment she gets
* there. Measuring in pixels instead made that 2 unreachable, the chase
* never ended, and getClosestObjActor - which ignores anything farther
* than 255 - answered "nobody" and stopped Edna's script before she had
* said a word.
*
* Whatever cannot be found is as far away as possible ($FF), so the game
* says "I can't reach it" instead of pretending nothing happened. Two
* characters together in some other room count as touching (distance 0),
* as in the original.
DistanzaFra      lda   DistB
                 jsr   ActIndex
                 bcs   :nonatt
                 lda   ActRoom,x
                 sta   DistRB
                 lda   DistA
                 jsr   ActIndex
                 bcs   :nonatt
                 lda   ActRoom,x
                 beq   :nonatt              ; nowhere: measure as usual
                 cmp   DistRB
                 bne   :nonatt
                 cmp   CurRoom
                 beq   :nonatt              ; here: measure as usual
                 lda   #0                   ; elsewhere, but together
                 rts

:nonatt          lda   DistA
                 jsr   DovE
                 bcs   :lontano
                 lda   PosX
                 sta   DistX1
                 lda   PosY
                 sta   DistY1
                 lda   DistB
                 jsr   DovE
                 bcs   :lontano

                 lda   DistX1               ; |x1 - x2|
                 sec
                 sbc   PosX
                 bpl   :xok
                 eor   #$FFFF
                 inc   a
:xok             sta   DistQ

                 lda   DistY1               ; |y1 - y2|
                 sec
                 sbc   PosY
                 bpl   :yok
                 eor   #$FFFF
                 inc   a
:yok             cmp   DistQ                ; keep the larger of the two
                 bcs   :tieni
                 lda   DistQ
:tieni           cmp   #$00FF               ; a byte is all the game reads
                 bcc   :piccolo
:lontano         lda   #$00FF
:piccolo         rts

*=======================================================================
* DovE - A = a character or an object. Returns PosX/PosY, carry if
*        where it is cannot be told.
*=======================================================================
* For a character what counts is where he is now; for an object, the
* point you go and stand on to use it (obcd+11 and obcd+12), in the same
* units.
DovE             sta   NomeChi
                 cmp   #NACT
                 bcs   :oggetto
                 jsr   ActIndex
                 bcs   :no
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :no
                 lda   ActX,x
                 sta   PosX
                 lda   ActY,x
                 sta   PosY
                 clc
                 rts

:oggetto         jsr   CercaObcd
                 bcs   :no
                 ldy   #11
                 lda   [zpNome],y
                 and   #$00FF
                 sta   PosX                 ; already in units of eight
                 ldy   #12
                 lda   [zpNome],y
                 and   #$001F
                 asl   a
                 asl   a                    ; times eight pixels, divided by two
                 sta   PosY
                 clc
                 rts
:no              sec
                 rts

hPseudo          jsr   FetchB
:lp              jsr   FetchB
                 bne   :lp
                 stz   Esito
                 rts

*=======================================================================
* hWalkToObj ($36) - send the character to where the object is used
*=======================================================================
* This was the hole that kept people standing still in front of doors:
* the sentence script sends the character to the object first and only
* runs the verb once he has arrived.
hWalkToObj       jsr   VOB1
                 sta   ActNo
                 jsr   VOW2
                 jsr   DovE
                 bcs   :niente
                 lda   PosX
                 sta   ActArg
                 lda   PosY
                 sta   ActArg2
                 jsr   AvviaCammino
:niente          stz   Esito
                 rts

*=======================================================================
* hPutAtObj ($0E) - put the character there at once, without walking
*=======================================================================
hPutAtObj        jsr   VOB1
                 sta   ActNo
                 jsr   VOW2
                 jsr   DovE
                 bcs   :ripiego
                 lda   PosX
                 sta   ActArg
                 lda   PosY
                 bra   :mettilo
:ripiego         lda   #60
                 sta   ActArg2
                 lda   #30
                 sta   ActArg
                 lda   #60
:mettilo         sta   ActArg2
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 lda   ActArg
                 sta   ActX,x
                 lda   ActArg2
                 sta   ActY,x
                 stz   ActMoving,x
                 stx   ActIdx
                 jsr   MostraUno
:fine            stz   Esito
                 rts

*=======================================================================
* hFaceActor ($09) - turn the character towards something or somebody
*=======================================================================
hFaceActor       jsr   VOB1
                 sta   ActNo
                 jsr   VOW2
                 jsr   DovE
                 bcs   :fine
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 stx   ActIdx
                 lda   PosX                 ; is it to the right or the left?
                 sec
                 sbc   ActX,x
                 beq   :avanti
                 bpl   :destra
                 lda   #0
                 bra   :gira
:destra          lda   #1
                 bra   :gira
:avanti          lda   #2
:gira            jsr   SetFacing
:fine            stz   Esito
                 rts

*=======================================================================
* hActorFromPos ($15) - who is at that point
*=======================================================================
hActorFromPos    jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 sta   CercaX
                 jsr   VOB2
                 sta   CercaY
                 jsr   ChiQui
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

* Who is at (CercaX,CercaY), counted the way the scripts count. The
* first one found there wins, with the usual sprite width.
ChiQui           stz   ActIdx
:lp              ldx   ActIdx
                 lda   ActCost,x
                 beq   :prossimo
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :prossimo
                 lda   ActVis,x
                 beq   :prossimo
                 lda   CercaX               ; three cells wide
                 sec
                 sbc   ActX,x
                 clc
                 adc   #2
                 bmi   :prossimo
                 cmp   #5
                 bcs   :prossimo
                 lda   CercaY               ; and about twenty rows
                 sec
                 sbc   ActY,x
                 clc
                 adc   #24
                 bmi   :prossimo
                 cmp   #26
                 bcs   :prossimo
                 lda   ActIdx
                 lsr   a
                 rts
:prossimo        lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 lda   #0
                 rts

*=======================================================================
* The questions about characters that used to go unanswered
*=======================================================================
hGetMoving       jsr   FetchB               ; $56: is he walking?
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :zero
                 lda   ActMoving,x
                 bra   :metti
:zero            lda   #0
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hGetFacing       jsr   FetchB               ; $63: which way he faces
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :zero
                 lda   ActFace,x
                 bra   :metti
:zero            lda   #0
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hGetCostume      jsr   FetchB               ; $71: which costume he wears
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :zero
                 lda   ActCost,x
                 bra   :metti
:zero            lda   #0
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

hGetBox          jsr   FetchB               ; $7B: which box he stands on
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 jsr   ActIndex
                 bcs   :fuori
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :fuori
                 lda   ActBox,x
                 bra   :metti
:fuori           lda   #$00FF
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* hObjPrepOf ($6C) - the preposition the object wants
*=======================================================================
* It sits in the three high bits of the same byte that carries the y of
* the point you stand on: in, with, on, to.
hObjPrepOf       jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOW1
                 sta   NomeChi
                 jsr   CercaObcd
                 bcs   :fuori
                 ldy   #12
                 lda   [zpNome],y
                 and   #$00FF
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 bra   :metti
:fuori           lda   #$00FF
:metti           ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* hWaitSent ($4C) - wait until the sentence under way has finished
*=======================================================================
hWaitSent        lda   SentN
                 bne   :aspetta
                 lda   #SCR_SENT
                 jsr   GiraScript
                 beq   :fatto
:aspetta         dec   PC                   ; come back to it next time
                 lda   #CEDI
                 sta   Esito
                 rts
:fatto           stz   Esito
                 rts

*=======================================================================
* hFindObject - which object is under that point
*=======================================================================
* findObject receives script units and turns them back into pixels, which
* is how object positions are written.
hFindObject      jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 asl   a
                 asl   a
                 asl   a
                 sta   FindX
                 jsr   VOB2
                 asl   a
                 sta   FindY
                 jsr   ObjectAt
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* hVerbOps - the verb panel: the game says where each verb goes and
*            what it is called, and we draw it where it says
*=======================================================================
hVerbOps         jsr   FetchB
                 sta   VerbCmd
                 bne   :prova
                 jsr   VOB1                 ; zero: delete a verb
                 inc   a
                 jsr   VerbSlot
                 lda   #0
                 sta   VerbId,x
                 sta   VerbOn,x
                 inc   VerbsDirty
                 stz   Esito
                 rts

:prova           cmp   #$00FF
                 bne   :nuovo
                 jsr   FetchB               ; $FF: on or off
                 sta   VerbWanted
                 jsr   FetchB
                 sta   TmpW2
                 jsr   TrovaVerbo
                 bcs   :fatto
                 lda   TmpW2
                 sta   VerbOn,x
                 inc   VerbsDirty
:fatto           stz   Esito
                 rts

:nuovo           jsr   FetchB               ; a new verb
                 asl   a
                 asl   a
                 asl   a
                 sta   VerbXT
                 jsr   FetchB
                 asl   a
                 asl   a
                 asl   a
                 sta   VerbYT
                 jsr   VOB1
                 inc   a
                 jsr   VerbSlot
                 stx   VerbIdx
                 jsr   FetchB               ; preposition: not needed here

                 ldx   VerbIdx
                 lda   VerbCmd
                 sta   VerbId,x
                 lda   VerbXT
                 sta   VerbX,x
                 lda   VerbYT
                 sta   VerbY,x
                 lda   #1
                 sta   VerbOn,x
                 jsr   LeggiNome
                 ldx   VerbIdx
                 lda   NameLen
                 asl   a
                 asl   a
                 asl   a
                 sta   VerbW,x
                 inc   VerbsDirty
                 stz   Esito
                 rts

*=======================================================================
* VerbSlot - A = slot, returns X = index into the tables
*=======================================================================
VerbSlot         cmp   #NVERBS
                 bcc   :ok
                 lda   #NVERBS-1
:ok              asl   a
                 tax
                 rts

*=======================================================================
* TrovaVerbo - look for VerbWanted: X = index, carry if not there
*=======================================================================
TrovaVerbo       ldx   #0
:lp              lda   VerbId,x
                 cmp   VerbWanted
                 beq   :trovato
                 inx
                 inx
                 cpx   #NVERBS*2
                 bcc   :lp
                 sec
                 rts
:trovato         clc
                 rts

*=======================================================================
* LeggiNome - the verb name, which sits in the code right after
*=======================================================================
* The names are padded to a fixed length with at signs: those are not
* part of the name.
LeggiNome        stz   NameLen
                 lda   VerbIdx
                 lsr   a                    ; slot
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW                 ; times three
                 asl   a
                 asl   a                    ; and by four: twelve
                 sta   NameBase             ; slot * 12
:lp              jsr   FetchB
                 beq   :fine
                 cmp   #$00FE
                 bcc   :normale
                 jsr   FetchB
                 bra   :lp
:normale         cmp   #'@'
                 beq   :lp
                 ldx   NameLen
                 cpx   #11
                 bcs   :lp
                 pha
                 txa
                 clc
                 adc   NameBase
                 tax
                 pla
                 sep   #$20
                 mx    %10
                 sta   VerbName,x
                 rep   #$20
                 mx    %00
                 inc   NameLen
                 bra   :lp
:fine            lda   NameLen
                 clc
                 adc   NameBase
                 tax
                 sep   #$20
                 mx    %10
                 lda   #0
                 sta   VerbName,x
                 rep   #$20
                 mx    %00
                 rts

*=======================================================================
* DrawVerbs - the verb panel where the game put it
*=======================================================================
DrawVerbs        _HideCursor
                 jsr   DrawVerbsReal
                 _ShowCursor
                 rts

DrawVerbsReal    lda   #VERBTOP*SCRW
                 sta   FillStart
                 lda   #VERBEND*SCRW
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
* from here down it only writes: for callers that have already cleared
DrawVerbiSoli    stz   VerbIdx
:lp              ldx   VerbIdx
                 lda   VerbId,x
                 beq   :prossimo
                 lda   VerbOn,x
                 beq   :prossimo

* Three colours, as in the DOS version: a verb the game has disabled
* stays written but dim, the one under the pointer lights up, the others
* sit at rest.
                 lda   VerbOn,x
                 cmp   #1
                 beq   :vivo
                 lda   #COLVERBDIM
                 bra   :coloreok
:vivo            lda   VerbIdx
                 inc   a
                 cmp   VerbHover
                 beq   :acceso
                 lda   #COLVERB
                 bra   :coloreok
:acceso          lda   #COLVERBHI
:coloreok        jsr   SetTextColor

                 ldx   VerbIdx
                 lda   VerbX,x
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   TxtX
                 lda   VerbY,x
                 sta   TxtY

                 lda   VerbIdx
                 lsr   a                    ; slot
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW                 ; times three
                 asl   a
                 asl   a                    ; and by four: twelve
                 clc
                 adc   #VerbName
                 sta   zpStr
                 lda   #^VerbName
                 sta   zpStr+2
                 jsr   DrawStr

:prossimo        lda   VerbIdx
                 clc
                 adc   #2
                 sta   VerbIdx
                 cmp   #NVERBS*2
                 bcc   :lp
                 lda   #15
                 jsr   SetTextColor
                 rts

*=======================================================================
* DrawFrase - the line of the sentence being built
*=======================================================================
* Verb, first object, preposition, second object. In the DOS version it
* is purple (EGA's 13) and sits right above the verb panel.
DrawFrase        _HideCursor
                 lda   #SENTTOP*SCRW
                 sta   FillStart
                 lda   #VERBTOP*SCRW
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 jsr   DrawFraseReal
                 _ShowCursor
                 rts

DrawFraseReal    lda   SentHot
                 beq   :riposo
                 lda   #COLSENTHI
                 bra   :coloreok
:riposo          lda   #COLSENT
:coloreok        jsr   SetTextColor
                 stz   TxtX
                 lda   #40
                 sta   TxtMax
                 lda   #SENTTOP
                 sta   TxtY

                 lda   Vars+VO_SENTVERB     ; the verb's name
                 beq   :fine
                 sta   VerbWanted
                 jsr   TrovaVerbo
                 bcs   :fine
                 jsr   ScriviNomeVerbo

                 lda   Vars+VO_SENTOBJ1
                 beq   :fine
                 jsr   Spazio
                 lda   Vars+VO_SENTOBJ1
                 jsr   ScriviNomeDi

                 lda   Vars+VO_SENTPREP     ; in, with, on, to
                 beq   :senzaprep
                 cmp   #5
                 bcs   :senzaprep
                 dec   a
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW                 ; times three
                 asl   a                    ; times six: PREPLEN
                 clc
                 adc   #Preposiz
                 sta   zpStr
                 lda   #^Preposiz
                 sta   zpStr+2
                 jsr   DrawStrFino

:senzaprep       lda   Vars+VO_SENTOBJ2
                 beq   :fine
                 jsr   Spazio
                 lda   Vars+VO_SENTOBJ2
                 jsr   ScriviNomeDi
:fine            lda   #15
                 jmp   SetTextColor

Spazio           inc   TxtX
                 rts

*=======================================================================
* ScriviNomeVerbo - the name of the verb in slot X
*=======================================================================
ScriviNomeVerbo  txa
                 lsr   a                    ; slot
                 sta   TmpW
                 asl   a
                 clc
                 adc   TmpW                 ; times three
                 asl   a
                 asl   a                    ; and by four: twelve
                 clc
                 adc   #VerbName
                 sta   zpStr
                 lda   #^VerbName
                 sta   zpStr+2
                 jmp   DrawStrFino

*=======================================================================
* ScriviNomeDi - A = object or actor number: writes its name
*=======================================================================
ScriviNomeDi     sta   NomeChi
                 jsr   NomeSostituito       ; did the game rename it?
                 bcs   :normale
                 jmp   DrawStrFino
:normale         lda   NomeChi
                 cmp   #NACT                ; low numbers are the characters
                 bcs   :oggetto
                 asl   a
                 sta   TmpW
                 asl   a
                 asl   a
                 asl   a                    ; times sixteen
                 clc
                 adc   #ActName
                 sta   zpStr
                 lda   #^ActName
                 sta   zpStr+2
                 jmp   DrawStrFino

:oggetto         jsr   CercaObcd            ; in hand or in the room
                 bcs   :fine
                 lda   NomeOff              ; obcd+14: where the name starts
                 beq   :fine
                 clc
                 adc   zpNome
                 sta   zpStr
                 lda   zpNome+2
                 adc   #0
                 sta   zpStr+2
                 jmp   DrawStrFino
:fine            rts

*=======================================================================
* CercaObcd - the description of object NomeChi, in hand or in the room
*=======================================================================
* Leaves the obcd's address in zpNome/zpNome+2 and, in NomeOff, the byte
* saying where inside it the name starts.
CercaObcd        stz   ObjDove
                 stz   InvIdx
:lp              ldx   InvIdx
                 lda   InvObj,x
                 beq   :prossimo
                 cmp   NomeChi
                 bne   :prossimo
                 lda   InvIdx               ; he is carrying it: the place
                 asl   a                    ; is InvBuf + slot*INVLEN
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a                    ; slot*2 times 128: that is 256
                 sta   ObjBaseT
                 clc
                 adc   #InvBuf
                 sta   zpNome
                 lda   #^InvBuf
                 sta   zpNome+2
                 lda   #1
                 sta   ObjDove
                 ldy   #14
                 lda   [zpNome],y
                 and   #$00FF
                 sta   NomeOff
                 clc
                 rts
:prossimo        lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcc   :lp

                 lda   NomeChi              ; otherwise it is in the room
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :no
                 lda   ObjCd
                 sta   ObjBaseT
                 clc
                 adc   zpRaw
                 sta   zpNome
                 lda   zpRaw+2
                 adc   #0
                 sta   zpNome+2
                 ldy   #14
                 lda   [zpNome],y
                 and   #$00FF
                 sta   NomeOff
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* DrawInv - the four inventory boxes, and the arrows
*=======================================================================
DrawInv          _HideCursor
                 lda   #INVTOP*SCRW
                 sta   FillStart
                 lda   #DBGTOP*SCRW
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 jsr   DrawInvReal
                 _ShowCursor
                 rts

* Two rows by two columns, as in the DOS version: on the left from 0 to
* 17 characters, on the right from 22 to 39, and the two arrows between.
DrawInvReal      stz   InvVisti
                 stz   InvIdx
:lp              ldx   InvIdx
                 lda   InvObj,x
                 beq   :prossimo
                 jsr   MioOggetto           ; does the player really own it?
                 bcs   :prossimo

                 lda   InvVisti             ; where it is written
                 and   #1
                 beq   :sinistra
                 lda   #40
                 sta   TxtMax
                 lda   #22
                 bra   :xok
:sinistra        lda   #18
                 sta   TxtMax
                 lda   #0
:xok             sta   TxtX
                 lda   InvVisti
                 lsr   a
                 beq   :primariga
                 lda   #INVROW2
                 bra   :yok
:primariga       lda   #INVTOP
:yok             sta   TxtY

                 lda   InvVisti             ; the one under the pointer
                 inc   a                    ; lights up
                 cmp   InvHot
                 bne   :riposo
                 lda   #COLSENTHI
                 bra   :coloreok
:riposo          lda   #COLSENT
:coloreok        jsr   SetTextColor
                 ldx   InvIdx
                 lda   InvObj,x
                 jsr   ScriviNomeDi
                 inc   InvVisti
                 lda   InvVisti
                 cmp   #4
                 bcs   :basta
:prossimo        lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcc   :lp
:basta           lda   #15
                 jmp   SetTextColor

*=======================================================================
* MioOggetto - carry clear if the object in A belongs to the player
*=======================================================================
MioOggetto       sta   ObjNo
                 jsr   GetObjOwner
                 cmp   Vars+VO_EGO
                 beq   :si
                 sec
                 rts
:si              clc
                 rts

*=======================================================================
* VerboSotto - which verb is under the point that was clicked
*=======================================================================
VerboSotto       lda   MouseX
                 sta   PtoX
                 lda   MouseY
                 sta   PtoY
* up to here it prepares the point; from here down it searches

VerboInPunto     stz   VerbIdx
:lp              ldx   VerbIdx
                 lda   VerbId,x
                 beq   :prossimo
                 lda   VerbOn,x
                 cmp   #1                   ; only the lit ones can be
                 bne   :prossimo            ; press: the disabled one is written
                 lda   PtoY                 ; but does not answer
                 sec
                 sbc   VerbY,x
                 bmi   :prossimo
                 cmp   #8
                 bcs   :prossimo
                 lda   PtoX
                 sec
                 sbc   VerbX,x
                 bmi   :prossimo
                 cmp   VerbW,x
                 bcs   :prossimo
                 clc
                 rts
:prossimo        lda   VerbIdx
                 clc
                 adc   #2
                 sta   VerbIdx
                 cmp   #NVERBS*2
                 bcc   :lp
                 sec
                 rts

* GuardaVerbo - the verb under the pointer, so it can be lit
*=======================================================================
* Returns in A the verb's index plus one, and zero if the pointer is not
* touching any: that way the caller compares it with the previous one and
* redraws the panel only when it really changes.
GuardaVerbo      PushPtr PuntoMou
                 _GetMouse
                 lda   PuntoMou             ; in IIGS points the vertical
                 sta   PtoY                 ; the vertical comes first
                 lda   PuntoMou+2
                 sta   PtoX
                 stz   VerbHover
                 stz   SentHot
                 stz   InvHot

                 lda   PtoY
                 cmp   #SENTTOP
                 bcc   :fatto
                 cmp   #VERBTOP
                 bcs   :nonfrase
                 inc   SentHot              ; on the sentence line
                 bra   :fatto

:nonfrase        cmp   #VERBEND
                 bcs   :noninv
                 jsr   VerboInPunto         ; on the verb panel
                 bcs   :fatto
                 lda   VerbIdx
                 inc   a
                 sta   VerbHover
                 bra   :fatto

:noninv          cmp   #DBGTOP
                 bcs   :fatto
                 lda   PtoY                 ; on the inventory boxes
                 sta   MouseSave
                 lda   MouseY
                 pha
                 lda   MouseX
                 pha
                 lda   PtoY
                 sta   MouseY
                 lda   PtoX
                 sta   MouseX
                 jsr   OggettoSotto
                 php
                 lda   InvQuale
                 sta   InvHotT
                 plp
                 pla
                 sta   MouseX
                 pla
                 sta   MouseY
                 bcs   :fatto
                 lda   InvHotT
                 inc   a
                 sta   InvHot

* A single number for all three areas: that way the main loop notices
* with one comparison when the pointer moves somewhere else.
:fatto           lda   InvHot
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   SentHot
                 asl   a
                 clc
                 adc   VerbHover
                 rts

*=======================================================================
* SpegniScena - black out the play area
*=======================================================================
* Loading a room on the IIGS takes nearly a second. Without this the last
* frame of the previous one stays on screen the whole time, and it reads
* as a freeze.
SpegniScena      _HideCursor
                 stz   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 _ShowCursor
                 jsr   DrawMsg              ; and away with the old sentence,
                 rts                        ; at once: not when loading ends

*=======================================================================
* ChangeRoom - A = room number
*=======================================================================
ChangeRoom       sta   CurRoom
                 sta   Vars+VO_ROOM
                 pha
                 jsr   SpegniMsg            ; the old sentence no longer applies
                 jsr   SpegniScena          ; nothing more to do with this room
                 pla
                 ora   #0
                 bne   :c_e
                 brl   :vuota
:c_e             anop

* the scripts that were running inside the old room's file have to go:
* that file is about to be replaced
                 ldx   #0
:pulisci         lda   SlotWhere,x
                 beq   :avanti
                 lda   #MORTO
                 sta   SlotStat,x
                 cpx   CurSlot              ; was it the one running?
                 bne   :avanti
                 lda   #1                   ; then it must stop at once
                 sta   SlotUcciso
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :pulisci

                 lda   CurRoom
                 sta   FileNo
                 jsr   LoadWhole
                 bcs   :vuota

                 jsr   DecodeRoom
                 stz   ScrollX              ; a new room starts from the left

* the camera limits depend on how wide the room is
                 ldx   #0                   ; whoever comes in is reassembled
:novis           stz   ActVis,x
                 inx
                 inx
                 cpx   #NACT*2
                 bcc   :novis
                 jsr   LeggiCaselle
                 jsr   MostraAttori

                 lda   #SCRW2/2
                 sta   Vars+VO_CAMMIN
                 lda   RoomW
                 sec
                 sbc   #SCRW2/2
                 bpl   :largaok
                 lda   #SCRW2/2
:largaok         sta   Vars+VO_CAMMAX
                 lda   #6
                 jsr   NotaCam
                 lda   #CAM_FERMA
                 sta   CamMode
                 stz   CamGo

                 lda   #1
                 sta   Redraw

* and the room's entry script, if there is one
                 ldy   #$1A
                 lda   [zpRaw],y
                 beq   :fine
                 sta   EnterOff
                 jsr   FreeSlot
                 bcs   :fine
                 asl   a
                 tax
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   #DA_STANZA
                 sta   SlotWhere,x
                 lda   #$7FFF               ; a number nobody looks for
                 sta   SlotNum,x
                 lda   #0
                 sta   SlotBaseT,x
                 sta   SlotDelLo,x
                 sta   SlotDelHi,x
                 lda   EnterOff
                 sta   SlotPC,x
:fine            rts
:vuota           stz   RoomW
                 stz   RoomH
                 lda   #1
                 sta   Redraw
                 rts

*=======================================================================
* DecodeRoom - the background, the clean copy, and the lit objects on top
*=======================================================================
DecodeRoom       ldy   #4
                 lda   [zpRaw],y
                 sta   RoomW
                 ldy   #6
                 lda   [zpRaw],y
                 sta   RoomH
                 lda   RoomW
                 lsr   a
                 sta   Pitch

                 lda   RoomW                ; how far it will scroll
                 sec
                 sbc   #SCRPIX
                 bcs   :pos
                 lda   #0
:pos             and   #$FFF8
                 sta   MaxScroll

                 lda   RoomW                ; one bit per pixel: eight pixels
                 lsr   a                    ; in one byte
                 lsr   a
                 lsr   a
                 sta   MaskPitch

* the row -> first byte table, so the decoder never multiplies
                 ldx   #0
                 lda   #0
:righe           sta   RowOff,x
                 clc
                 adc   Pitch
                 inx
                 inx
                 cpx   #ROOMROWS*2
                 bcc   :righe

                 ldx   #0                   ; and the same for the mask
                 lda   #0
:mrighe          sta   MaskRow,x
                 clc
                 adc   MaskPitch
                 inx
                 inx
                 cpx   #ROOMROWS*2
                 bcc   :mrighe

                 ldy   #$0A
                 lda   [zpRaw],y
                 sta   SrcOff
                 stz   DstX
                 stz   DstY
                 lda   RoomW
                 sta   BlkW
                 lda   RoomH
                 sta   BlkH
                 jsr   DecodeRLE
                 jsr   DecodeMaschera       ; right after the pixels

* a copy of the background alone: it is what makes an object disappear
* without decompressing the whole room again
                 jsr   AltezzaByte
                 sta   CopyLen
                 ldy   #0
:copia           lda   [zpPix],y
                 sta   [zpBg],y
                 iny
                 iny
                 cpy   CopyLen
                 bcc   :copia

                 lda   #1                   ; what goes on top of it is put
                 sta   DaComporre           ; together separately
                 lda   #$FFFF
                 sta   BuioStato            ; and the lights are not known yet
                 rts

*=======================================================================
* ComponiStanza - what goes on top of the decoded background
*=======================================================================
* Kept apart from the decoding because it has to happen after the room's
* entry script has run: that script is where the lights are set, and a
* dark room composed before it ran showed one frame of lit room, and its
* characters in their own colours, before turning black. So ChangeRoom
* only decodes, and the main loop composes once the scripts have had
* their say.
*
* With no light and no flashlight the game does not draw the room: it
* stays black and only the characters go on top. Blacking the room held
* in memory, rather than the screen after drawing it, is what lets the
* characters land on top by themselves and keeps the piecewise blit
* working.
ComponiStanza    stz   DaComporre
                 lda   Vars+VO_LIGHTS
                 and   #6
                 sta   BuioStato
                 bne   :c_eluce
                 jsr   AltezzaByte
                 sta   CopyLen
                 ldy   #0
                 lda   #$0000
:lp              sta   [zpPix],y
                 sta   [zpBg],y
                 iny
                 iny
                 cpy   CopyLen
                 bcc   :lp
                 bra   :attori
:c_eluce         jsr   DrawObjects
:attori          jsr   DrawActors
                 rts

*=======================================================================
* DecodeMaschera - the plane saying which background pixels sit in
*                  front of the characters
*=======================================================================
* In V2 it comes right after the pixels, in the same stream, and
* DecodeRLE has already left SrcIdx where it starts. It is one bit per
* pixel, one byte for every eight pixels of a row, and it is read in
* columns of bytes: the whole first strip from top to bottom, then the
* second, and so on.
*
* The format: a count byte. If bit 7 is set, the low seven say how many
* times to repeat the byte that follows; otherwise it says how many
* different bytes come next.
DecodeMaschera   lda   DstX                 ; the strip we start from
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   MskX
                 lda   BlkW
                 lsr   a
                 lsr   a
                 lsr   a
                 clc
                 adc   MskX
                 sta   MskEnd
                 stz   MskRun

:striscia        lda   DstY
                 asl   a
                 tax
                 lda   MaskRow,x
                 clc
                 adc   MskX
                 sta   MskOff
                 stz   MskY

:riga            jsr   ProssimaMask
                 sep   #$20
                 mx    %10
                 ldy   MskOff
                 lda   MskData
                 sta   [zpMask],y
                 rep   #$20
                 mx    %00
                 lda   MskOff
                 clc
                 adc   MaskPitch
                 sta   MskOff
                 inc   MskY
                 lda   MskY
                 cmp   BlkH
                 bcc   :riga

                 inc   MskX
                 lda   MskX
                 cmp   MskEnd
                 bcc   :striscia
                 rts

*=======================================================================
* ProssimaMask - the mask byte due now
*=======================================================================
ProssimaMask     lda   MskRun
                 bne   :ancora
                 ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   TmpW
                 and   #$0080
                 beq   :diversi
                 lda   TmpW                 ; bit 7: always the same byte
                 and   #$007F
                 jsr   MskQuanti
                 sta   MskRun
                 lda   #1
                 sta   MskRep
                 ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   MskData
                 bra   :ancora
:diversi         lda   TmpW                 ; bytes, all different
                 jsr   MskQuanti
                 sta   MskRun
                 stz   MskRep
:ancora          lda   MskRep
                 bne   :pronto
                 ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   MskData
:pronto          dec   MskRun
                 rts

* A count of zero means two hundred and fifty-six, as in the original
* engine's do-while, where the first decrement takes it to 255.
MskQuanti        cmp   #0
                 bne   :ok
                 lda   #256
:ok              rts

* The bit belonging to each of the eight pixels of a mask byte: the
* leftmost is the high one. They are words so that one asl is enough to
* index them.
BitMasc          dw    $0080,$0040,$0020,$0010
                 dw    $0008,$0004,$0002,$0001

*=======================================================================
* MascheraCasella - A = box number, returns its mask byte in A
*                   (zero: nothing covers the character)
*=======================================================================
MascheraCasella  pha
                 lda   NumBox
                 beq   :nessuna
                 pla
                 cmp   NumBox
                 bcs   :fuori
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   BoxOff
                 inc   a
                 clc
                 adc   #6
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 rts
:nessuna         pla
:fuori           lda   #0
                 rts

*=======================================================================
* AltezzaByte - how many bytes the whole room takes
*=======================================================================
AltezzaByte      lda   RoomH
                 sta   TmpW
                 lda   #0
:lp              clc
                 adc   Pitch
                 dec   TmpW
                 bne   :lp
                 rts

*=======================================================================
* DrawObjects - the lit objects, from the last to the first
*=======================================================================
* The game draws them in this order on purpose: the first in the list
* ends up on top of all the others.
DrawObjects      ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 sta   NumRoomObj
                 bne   :cisono
                 rts
:cisono          asl   a
                 sta   ObjTabLen

                 lda   NumRoomObj
                 dec   a
                 asl   a
                 sta   ObjIdx               ; start from the last one
:lp              lda   #28
                 clc
                 adc   ObjTabLen
                 adc   ObjIdx
                 tay
                 lda   [zpRaw],y
                 sta   ObjCd
                 beq   :prossimo

                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 jsr   GetObjState
                 and   #8                   ; off: not drawn
                 beq   :prossimo
* No check on the owner: an object that has been picked up disappears
* because the game lights its own picture, which is a patch of background
* made to cover it (the key under the doormat is drawn inside the rolled
* doormat, and the picture of the "key" object is the piece of floor
* without the key). Skipping it left the key there for ever.
                 lda   ObjTabLen
                 sta   PadreLen
                 jsr   PadreOk
                 bcs   :prossimo

                 jsr   LeggiObj
                 bcs   :prossimo
                 lda   ObjImgOff
                 sta   SrcOff
                 jsr   DecodeRLE
* Objects carry a mask of their own too, and for now it is skipped: they
* light and go out constantly, and without a clean copy to put back
* underneath, the mask of one that went off would stay around and eat
* pieces of character. The room background is enough for railings and
* low walls.

:prossimo        lda   ObjIdx
                 sec
                 sbc   #2
                 sta   ObjIdx
                 bmi   :fine
                 brl   :lp
:fine            rts

*=======================================================================
* DecodeRLE - V2's column-wise compression
*=======================================================================
* One byte at a time, going down a column:
*   bit 7 set     run length in bits 0..6, and the colour is NOT updated
*                 in the column table (this is the dithering: those
*                 pixels take back the colour the previous column had on
*                 that same row)
*   bit 7 clear   run length in bits 4..7; if that comes out zero it is
*                 in the next byte. The colour is always in bits 0..3.
*
* Columns go in pairs: the even one writes the high nibble, the odd one
* sets the low one. To avoid shifting bits on every pixel we keep two
* tables, one with the colour as it is and one already shifted.
*
* In: SrcOff, DstX (even), DstY, BlkW, BlkH.
DecodeRLE        lda   zpRaw
                 clc
                 adc   SrcOff
                 sta   zpSrc
                 lda   zpRaw+2
                 adc   #0
                 sta   zpSrc+2
                 stz   SrcIdx

                 stz   RunLen
                 stz   ColHi
                 stz   ColLo
                 stz   Dither
                 stz   ColX

                 ldx   #0                   ; the dithering table
                 lda   #0                   ; starts clean
:pulisci         sta   DitLo,x
                 sta   DitHi,x
                 inx
                 inx
                 cpx   #ROOMROWS
                 bcc   :pulisci

:colonna         lda   ColX
                 clc
                 adc   DstX
                 lsr   a                    ; two pixels per byte
                 sta   ColByte
                 lda   DstY
                 asl   a
                 tay
                 lda   RowOff,y
                 clc
                 adc   ColByte
                 sta   PixOff
                 stz   Riga

                 lda   ColX
                 and   #1
                 sta   Dispari

:pixel           lda   RunLen
                 bne   :dentro
                 jsr   NextRun
:dentro          lda   Dither
                 bne   :usatab

                 ldx   Riga                 ; new colour: goes into the two
                 sep   #$20                 ; tables, for this row
                 mx    %10
                 lda   ColLo
                 sta   DitLo,x
                 lda   ColHi
                 sta   DitHi,x
                 rep   #$20
                 mx    %00

* When only a piece of the room is being redone, an object must be drawn
* only inside that piece: outside, the pixels are already right, and
* repainting them would put back what was there before. That is how the
* things taken from the refrigerator came back into view: refreshing one
* object's square redrew the whole refrigerator - with its contents -
* over the patches that were covering them.
:usatab          lda   ClipOn
                 beq   :scrivi
                 lda   ColX
                 clc
                 adc   DstX
                 cmp   ClipX1
                 bcc   :niente
                 cmp   ClipX2
                 bcs   :niente
                 lda   Riga
                 clc
                 adc   DstY
                 cmp   ClipY1
                 bcc   :niente
                 cmp   ClipY2
                 bcc   :scrivi
:niente          bra   :scritto2

:scrivi          ldx   Riga
                 ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   Dispari
                 bne   :basso
                 lda   DitHi,x              ; even column: high nibble
                 sta   [zpPix],y
                 bra   :scritto
:basso           lda   DitLo,x              ; odd: the low nibble is set
                 ora   [zpPix],y
                 sta   [zpPix],y
:scritto         rep   #$20
                 mx    %00
:scritto2        anop

                 lda   PixOff               ; down one row
                 clc
                 adc   Pitch
                 sta   PixOff
                 dec   RunLen
                 inc   Riga
                 lda   Riga
                 cmp   BlkH
                 bcc   :pixel

                 inc   ColX
                 lda   ColX
                 cmp   BlkW
                 bcs   :fine
                 brl   :colonna
:fine            rts

*=======================================================================
* NextRun - the next group of identical pixels
*=======================================================================
NextRun          ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   RunByte

                 and   #$000F
                 sta   ColLo
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   ColHi

                 lda   RunByte
                 and   #$0080
                 beq   :normale
                 lda   RunByte
                 and   #$007F
                 sta   RunLen
                 lda   #1
                 sta   Dither
                 bra   :controlla
:normale         lda   RunByte
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   RunLen
                 stz   Dither
:controlla       lda   RunLen
                 bne   :fine
                 ldy   SrcIdx               ; zero: the real length follows
                 lda   [zpSrc],y
                 and   #$00FF
                 sta   RunLen
                 inc   SrcIdx
:fine            rts

*=======================================================================
* The text, in the game's own font
*=======================================================================
* The V2 font is not in the .LFL files: in the DOS version it lives
* inside the executable. It was pulled out of there and travels with us.
*
* A character is 8x8, one bit deep. On the IIGS screen a pixel is half a
* byte, so one character row is four bytes. To avoid looking at the bits
* one by one we keep a table: for each of the sixteen possible font
* nibbles, the word ready to be written to the screen.
*=======================================================================
* SetTextColor - A = colour, prepares the table
*=======================================================================
SetTextColor     and   #$000F
                 sta   TxtCol
                 stz   NibIdx
                 ldx   #0
:nib             stz   Byte0
                 stz   Byte1
                 txa
                 and   #$0008               ; first pixel
                 beq   :p1
                 lda   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   Byte0
:p1              txa
                 and   #$0004               ; second
                 beq   :p2
                 lda   Byte0
                 ora   TxtCol
                 sta   Byte0
:p2              txa
                 and   #$0002               ; third
                 beq   :p3
                 lda   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   Byte1
:p3              txa
                 and   #$0001               ; fourth
                 beq   :salva
                 lda   Byte1
                 ora   TxtCol
                 sta   Byte1
:salva           lda   Byte1
                 xba                        ; the second byte goes high
                 ora   Byte0
                 phx
                 ldx   NibIdx
                 sta   EspTab,x
                 inc   NibIdx
                 inc   NibIdx
                 plx
                 inx
                 cpx   #16
                 bcc   :nib
                 rts

*=======================================================================
* DrawChar - A = character, TxtX in characters, TxtY in pixel rows
*=======================================================================
DrawChar         and   #$007F
                 cmp   #33                  ; space and low codes: blank
                 bcs   :disegna
                 rts
:disegna         asl   a
                 asl   a
                 asl   a                    ; eight bytes per character
                 sta   FontIdx

                 lda   TxtY                 ; row * 160
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW                 ; row * 32
                 asl   a
                 asl   a                    ; row * 128
                 clc
                 adc   TmpW
                 sta   TxtOff
                 lda   TxtX                 ; plus four bytes per column
                 asl   a
                 asl   a
                 clc
                 adc   TxtOff
                 sta   TxtOff

                 stz   Conta8
:riga            ldx   FontIdx
                 sep   #$20
                 mx    %10
                 lda   FontData,x
                 sta   Riga8
                 rep   #$20
                 mx    %00
                 inc   FontIdx

                 lda   Riga8
                 and   #$00F0               ; the four left-hand pixels
                 lsr   a
                 lsr   a
                 lsr   a
                 tay
                 lda   EspTab,y
                 ldx   TxtOff
                 stal  SHRBASE,x

                 lda   Riga8
                 and   #$000F               ; and the right-hand ones
                 asl   a
                 tay
                 lda   EspTab,y
                 ldx   TxtOff
                 inx
                 inx
                 stal  SHRBASE,x

                 lda   TxtOff
                 clc
                 adc   #SCRW
                 sta   TxtOff
                 inc   Conta8
                 lda   Conta8
                 cmp   #8
                 bcc   :riga
                 rts

*=======================================================================
* DrawStr - the long string (zpStr), from TxtX/TxtY
*=======================================================================
*=======================================================================
* DrawStrFino - like DrawStr, but it stops at column TxtMax
*=======================================================================
* The sentence line and the inventory boxes have a width of their own: a
* long sentence wrapping by itself would land on the verb panel, and a
* long name in the inventory would spill into the box next door. Here
* whatever does not fit is cut, the way V2 does it.
DrawStrFino      ldy   #0
:lp              sty   StrIdx
                 lda   TxtX
                 cmp   TxtMax
                 bcs   :fine
                 ldy   StrIdx
                 lda   [zpStr],y
                 and   #$00FF
                 beq   :fine
* Object names are padded to a fixed length with at signs:
* "flashlight@@@@". They are not part of the name and are not written
* (in the game's font they would come out as a row of dashes).
                 cmp   #'@'
                 beq   :avanti
                 jsr   DrawChar
                 inc   TxtX
:avanti          ldy   StrIdx
                 iny
                 bra   :lp
:fine            rts

DrawStr          ldy   #0
:lp              sty   StrIdx
                 lda   [zpStr],y
                 and   #$00FF
                 beq   :fine
                 jsr   DrawChar
                 inc   TxtX
                 lda   TxtX
                 cmp   #40
                 bcc   :avanti
                 stz   TxtX                 ; wraps by itself
                 lda   TxtY
                 clc
                 adc   #8
                 sta   TxtY
:avanti          ldy   StrIdx
                 iny
                 bra   :lp
:fine            rts

*=======================================================================
* DrawMsg - the panel below: the game's message and the credit line
*=======================================================================
DrawMsg          _HideCursor
                 jsr   DrawMsgReal
                 _ShowCursor
                 rts

DrawMsgReal      stz   FillStart            ; the two rows at the top
                 lda   #ROOMOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea

                 lda   MsgColor             ; the speaker's colour
                 bne   :colorato
                 lda   #15
:colorato        jsr   SetTextColor

                 lda   #MSGFONDO
                 sta   MsgFondo

* the message, which wraps by itself every forty characters
                 stz   TxtX
                 lda   #MSGTOP
                 sta   TxtY
                 lda   #MsgText
                 clc
                 adc   MsgPag
                 sta   zpStr
                 lda   #^MsgText
                 adc   #0
                 sta   zpStr+2
                 jsr   DrawStrWrap
                 lda   #15
                 jsr   SetTextColor
                 jmp   DrawPannelloReal

*=======================================================================
* DrawPannello - the whole band below the room
*=======================================================================
* In V2 it is three pieces: the line of the sentence being built, the
* verb panel, and the four inventory boxes. Plus a line at the bottom
* that we use for faults.
DrawPannello     _HideCursor
                 jsr   DrawPannelloReal
                 _ShowCursor
                 rts

DrawPannelloReal lda   #PANOFF
                 sta   FillStart
                 lda   #PANEND
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 jsr   DrawCredit
                 jsr   DrawGuasto
                 jsr   CiSonoVerbi          ; until the game has set up
                 bcs   :fine                ; the verbs there is no panel
                 jsr   DrawFraseReal
                 jsr   DrawInvReal
                 jsr   DrawVerbiSoli
:fine            rts

*=======================================================================
* DrawGuasto - the last line: missing opcodes and room number
*=======================================================================
DrawDbg          _HideCursor
                 lda   #DBGTOP*SCRW
                 sta   FillStart
                 lda   #PANEND
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 jsr   DrawGuasto
                 _ShowCursor
                 rts

DrawGuasto       lda   BadOp
                 beq   :niente
                 brl   :guasto
:niente          lda   DbgOn                ; the room only with the D key
                 bne   :stanza
                 rts
* With debug on, the last line says everything needed to understand the
* camera: where the player character is, where the camera looks, where it
* is going, its right-hand limit, who it follows, and the last three
* commands that touched it.
:stanza          stz   TxtX
                 lda   #DBGTOP
                 sta   TxtY
                 lda   #MsgR
                 jsr   ScriviDbg
                 lda   CurRoom
                 jsr   DrawNum
                 lda   #MsgX
                 jsr   ScriviDbg
                 lda   Vars+VO_EGO
                 jsr   ActIndex
                 bcs   :senzax
                 lda   ActX,x
                 bra   :hox
:senzax          lda   #0
:hox             jsr   DrawNum
                 lda   #MsgC
                 jsr   ScriviDbg
                 lda   CamCur
                 jsr   DrawNum
                 lda   #MsgS
                 jsr   ScriviDbg
                 lda   ScrollX
                 jsr   DrawNum
                 lda   #MsgMax
                 jsr   ScriviDbg
                 lda   Vars+VO_CAMMAX
                 jsr   DrawNum
                 lda   #MsgL                ; how the room is lit
                 jsr   ScriviDbg
                 lda   Vars+VO_LIGHTS
                 jsr   DrawNum
                 lda   #MsgK                ; and which scripts are running
                 jsr   ScriviDbg
                 stz   DbgIdx
* DrawStr wraps at the fortieth column, and the debug line is the last one
* on the screen: wrapping it walked off the bottom and sprayed the whole
* display with rubbish that nothing ever cleaned up again. So stop while
* there is still room.
:copioni         lda   TxtX
                 cmp   #35
                 bcc   :c_eposto
                 rts
:c_eposto        ldx   DbgIdx
                 lda   SlotStat,x
                 beq   :prossimo
                 lda   SlotWhere,x
                 bne   :prossimo            ; only the global ones
                 ldx   DbgIdx
                 lda   SlotNum,x
                 cmp   #$7FFF
                 beq   :prossimo
                 jsr   DrawNum
                 lda   #MsgSpazio
                 jsr   ScriviDbg
:prossimo        lda   DbgIdx
                 clc
                 adc   #2
                 sta   DbgIdx
                 cmp   #SLOTS*2
                 bcc   :copioni
                 rts

* The debug labels all live in the same bank: the low word is enough to
* pick one.
ScriviDbg        sta   zpStr
                 lda   #^MsgR
                 sta   zpStr+2
                 jmp   DrawStr
:guasto          stz   TxtX
                 lda   #DBGTOP
                 sta   TxtY
                 lda   #MsgBad
                 sta   zpStr
                 lda   #^MsgBad
                 sta   zpStr+2
                 jsr   DrawStr
                 lda   BadOp
                 jmp   DrawNum

*=======================================================================
* CiSonoVerbi - carry clear if the game has already set up the panel
*=======================================================================
CiSonoVerbi      stz   VerbIdx
:lp              ldx   VerbIdx
                 lda   VerbId,x
                 bne   :si
                 lda   VerbIdx
                 clc
                 adc   #2
                 sta   VerbIdx
                 cmp   #NVERBS*2
                 bcc   :lp
                 sec
                 rts
:si              clc
                 rts

*=======================================================================
* DrawCredit - who ported it, at the bottom of the screen
*=======================================================================
* Only on the title screen: inside the game that line would get in the
* way of the verb panel.
DrawCredit       lda   CurRoom
                 cmp   #45
                 beq   :forse
                 rts
:forse           lda   MsgLen               ; comes and goes with the text
                 bne   :vai                 ; of the game, not on its own
                 rts
:vai             lda   #7
                 jsr   SetTextColor
                 lda   #CRED1TOP
                 sta   TxtY
                 lda   #MsgCred1
                 sta   zpStr
                 lda   #^MsgCred1
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 lda   #CRED2TOP
                 sta   TxtY
                 lda   #MsgCred2
                 sta   zpStr
                 lda   #^MsgCred2
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 lda   #15
                 jsr   SetTextColor
                 rts

*=======================================================================
* FondoMsg - how far down the game's text may reach
*=======================================================================
* If the verb panel is not there yet (the credits, the title) the message
* can use the whole panel. As soon as the verbs are installed it has to
* stop above them.
FondoMsg         stz   VerbIdx
:lp              ldx   VerbIdx
                 lda   VerbId,x
                 bne   :cisono
                 lda   VerbIdx
                 clc
                 adc   #2
                 sta   VerbIdx
                 cmp   #NVERBS*2
                 bcc   :lp
                 lda   #CRED1TOP            ; no verbs: there is room
                 rts
:cisono          lda   #VERBTOP
                 rts

*=======================================================================
* DrawStrCenter - like DrawStr, but centred on the line
*=======================================================================
DrawStrCenter    ldy   #0
:conta           lda   [zpStr],y
                 and   #$00FF
                 beq   :misurato
                 iny
                 cpy   #40
                 bcc   :conta
:misurato        tya
                 sta   TmpW
                 lda   #40
                 sec
                 sbc   TmpW
                 lsr   a                    ; (40 - length) / 2
                 sta   TxtX
                 jmp   DrawStr

*=======================================================================
* DrawStrWrap - like DrawStr but code $0A breaks the line
*=======================================================================
DrawStrWrap      ldy   #0
:lp              sty   StrIdx
                 lda   [zpStr],y
                 and   #$00FF
                 beq   :fine
                 cmp   #1                   ; the page ends here
                 beq   :fine
                 cmp   #$000A
                 bne   :normale
                 stz   TxtX
                 lda   TxtY
                 clc
                 adc   #8
                 sta   TxtY
                 bra   :avanti
:normale         jsr   DrawChar
                 inc   TxtX
                 lda   TxtX
                 cmp   #40
                 bcc   :avanti
                 stz   TxtX
                 lda   TxtY
                 clc
                 adc   #8
                 sta   TxtY
:avanti          lda   TxtY
                 cmp   MsgFondo             ; do not intrude on the panel
                 bcs   :fine
                 ldy   StrIdx
                 iny
                 bra   :lp
:fine            rts

*=======================================================================
* DrawNum - A, in decimal, from TxtX/TxtY
*=======================================================================
DrawNum          sta   DecVal
                 ldy   #0
:cento           lda   DecVal
                 cmp   #100
                 bcc   :fattoC
                 sec
                 sbc   #100
                 sta   DecVal
                 iny
                 bra   :cento
:fattoC          sty   DecHun
                 ldy   #0
:dieci           lda   DecVal
                 cmp   #10
                 bcc   :fattoD
                 sec
                 sbc   #10
                 sta   DecVal
                 iny
                 bra   :dieci
:fattoD          sty   DecTen

                 lda   DecHun
                 beq   :nocento
                 clc
                 adc   #'0'
                 jsr   DrawChar
                 inc   TxtX
:nocento         lda   DecHun
                 ora   DecTen
                 beq   :nodieci
                 lda   DecTen
                 clc
                 adc   #'0'
                 jsr   DrawChar
                 inc   TxtX
:nodieci         lda   DecVal
                 clc
                 adc   #'0'
                 jsr   DrawChar
                 inc   TxtX
                 rts

*=======================================================================
* SayState - redraw the panel only when it is really needed
*=======================================================================
SayState         lda   MsgNew
                 bne   :scrivi
                 lda   CurRoom
                 cmp   ShownRoom
                 bne   :scrivi
                 lda   BadOp
                 cmp   ShownBad
                 bne   :scrivi
                 rts
:scrivi          stz   MsgNew
                 lda   CurRoom
                 sta   ShownRoom
                 lda   BadOp
                 sta   ShownBad
                 jsr   DrawMsg
                 rts

*=======================================================================
DiskError        _InitCursor
:lp              PushWord #0
                 PushWord #$FFFF
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 beq   :lp
                 lda   EvtWhat
                 cmp   #3
                 bne   :lp
                 bra   Shutdown

NoMem            anop
Shutdown         _EMShutDown
                 _QDShutDown
                 _MTShutDown
                 lda   #0
                 tcd
                 PushLong DPHandle
                 _DisposeHandle
                 PushWord MyID
                 _MMShutDown
                 _TLShutDown

Bye              jsl   $E100A8
                 dw    QuitGS
                 adrl  QuitParm
                 brk   $00

*=======================================================================
QuitParm         dw    $0002
                 adrl  $00000000
                 dw    $0000

OpenParm         dw    $0002
OpenRef          dw    $0000
OpenPath         adrl  $00000000

ReadParm         dw    $0004
ReadRef          dw    $0000
ReadBuf          adrl  $00000000
ReadCount        adrl  $00000000
ReadXfer         adrl  $00000000

MarkParm         dw    $0003
MarkRef          dw    $0000
                 dw    $0000                ; absolute position
MarkPos          adrl  $00000000

CloseParm        dw    $0001
CloseRef         dw    $0000

CreateParm       dw    $0004
CreatePath       adrl  $00000000
                 dw    $00C3                ; access: everything allowed
                 dw    $0006                ; type BIN
                 adrl  $00000000            ; auxtype

DestroyParm      dw    $0001
DestroyPath      adrl  $00000000

OpenWParm        dw    $0003
OpenWRef         dw    $0000
OpenWPath        adrl  $00000000
                 dw    $0003                ; read and write

WriteParm        dw    $0004
WriteRef         dw    $0000
WriteBuf         adrl  $00000000
WriteCount       adrl  $00000000
WriteXfer        adrl  $00000000

* ProDOS names must start with a letter, so the game files on the disk
* are called L00.LFL instead of 00.LFL.
* The digits are rewritten in PathA+6/+7 and PathB+8/+9.
PathA            dw    10
                 asc   'MM/L00.LFL'
PathB            dw    12
                 asc   '1/MM/L00.LFL'

* And the saved games, in the same folder. The digit is rewritten in
* PathS1+9 and PathS2+11.
PathS1           dw    8
                 asc   'MM/SAVE0'
PathS2           dw    10
                 asc   '1/MM/SAVE0'

* The V2 prepositions: they were written inside the engine, not in the
* game files. These are the English ones; other languages have their own.
Preposiz         asc   ' in'
                 hex   000000
                 asc   ' with'
                 hex   00
                 asc   ' on'
                 hex   000000
                 asc   ' to'
                 hex   000000

*=======================================================================
* The pointer
*=======================================================================
* The IIGS stock one gets lost in dark rooms. This is the classic arrow:
* white body and black outline, with the mask keeping the outline opaque,
* so it shows up on light and on black alike.
FrecciaCur       dw    16                   ; rows
                 dw    6                    ; bytes per row (two pixels each)
                 hex   000000000000
                 hex   000000000000
                 hex   0F0000000000
                 hex   0FF000000000
                 hex   0FFF00000000
                 hex   0FFFF0000000
                 hex   0FFFFF000000
                 hex   0FFFFFF00000
                 hex   0FFFFFFF0000
                 hex   0FFFFFFFF000
                 hex   0FFFF0000000
                 hex   0FF0F0000000
                 hex   0F000F000000
                 hex   00000F000000
                 hex   000000F00000
                 hex   000000000000
                 hex   F00000000000
                 hex   FF0000000000
                 hex   FFF000000000
                 hex   FFFF00000000
                 hex   FFFFF0000000
                 hex   FFFFFF000000
                 hex   FFFFFFF00000
                 hex   FFFFFFFF0000
                 hex   FFFFFFFFF000
                 hex   FFFFFFFFFF00
                 hex   FFFFFFFFFF00
                 hex   FFFFFF000000
                 hex   FFF0FFF00000
                 hex   FF00FFF00000
                 hex   F0000FFF0000
                 hex   000000FF0000
                 dw    0                    ; hot spot: the tip
                 dw    0

MsgR             asc   'r'
                 dfb   0
MsgX             asc   ' x'
                 dfb   0
MsgC             asc   ' c'
                 dfb   0
MsgD             asc   ' d'
                 dfb   0
MsgS             asc   ' s'
                 dfb   0
MsgM             asc   ' m'
                 dfb   0
MsgMax           asc   ' M'
                 dfb   0
MsgU             asc   ' u'
                 dfb   0
MsgP             asc   ' P'
                 dfb   0
MsgL             asc   ' L'
                 dfb   0
MsgK             asc   ' k'
                 dfb   0
MsgSpazio        asc   ' '
                 dfb   0
MsgRoom          asc   'room '
                 dfb   0
MsgBad           asc   'unknown opcode: '
                 dfb   0
MsgIIGS          asc   '        Apple IIGS porting by'
                 hex   0A
                 asc   '          Michele Di Paola'
                 hex   00
MsgMusica        asc   '         Apple IIGS music by'
                 hex   0A
                 asc   '      . . . . . . . . . . . .'
                 hex   00
MsgCred1         asc   'Porting to IIGS: Michele Di Paola'
                 dfb   0
MsgCred2         asc   'aka TheDIPO! / JeDiCrack'
                 dfb   0

* The table of the 256 opcodes, generated from the same list verified in
* Python against all 1093 code blocks in the game.
*=======================================================================
* The disk - saving a game and reading it back
*=======================================================================
* I do not draw the screen: it is all in the game. Script 163 loads room
* 50 - the octopus band and the three buttons - and its objects 545 and
* 546 create ten verbs, "Game A" .. "Game J", which are the list of
* saved games; the ones already on disk carry an asterisk.
* The interpreter only has to answer, and the command says what it wants:
*
*    32       get ready, and say which drive the disk is in
*     7       how many more games will fit
*   192 + n   is game n there? (six means yes)
*   128 + n   save into slot n (zero done, two not)
*    64 + n   read slot n back (three done, five not)
*
* The three on a read is not an error: it is how the script knows it must
* close the screen and go back to the game.

hSaveLoad        jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 sta   DiscoCmd
                 jsr   FaiDisco
                 ldx   DestVar
                 sta   Vars,x
                 stz   Esito
                 rts

FaiDisco         lda   DiscoCmd
                 cmp   #32
                 bne   :nonprepara
                 lda   #1                   ; the screen is opening
                 sta   DiscoAperto
                 lda   #0                   ; no disk to swap
                 rts
:nonprepara      cmp   #7
                 bne   :nonquante
                 lda   #NPOS
                 rts
:nonquante       cmp   #192
                 bcc   :nonchiede
                 sec
                 sbc   #192
                 sta   PosI
                 jsr   C_ePos
                 bcs   :nonc_e
                 lda   #6
                 rts
:nonc_e          lda   #0
                 rts
:nonchiede       cmp   #128
                 bcc   :noncarica
                 sec
                 sbc   #128
                 sta   PosI
                 jsr   SalvaPos
                 bcs   :nonsalvata
                 lda   #0
                 rts
:nonsalvata      lda   #2
                 rts
:noncarica       cmp   #64
                 bcc   :niente
                 sec
                 sbc   #64
                 sta   PosI
                 jsr   CaricaPos
                 bcs   :nonletta
                 lda   #3                   ; done: the screen closes
                 rts
:nonletta        lda   #5
                 rts
:niente          lda   #0
                 rts

*=======================================================================
* C_ePos - is game PosI on the disk? Carry set if not.
*=======================================================================
C_ePos           jsr   ApriPosR
                 bcs   :no
                 jsr   LeggiCapo
                 php
                 jsr   ChiudiPos
                 plp
                 bcs   :no
                 jmp   ControllaFirma
:no              sec
                 rts

*=======================================================================
* The blocks that make up a saved game: address and length
*=======================================================================
* Scripts caught mid-run are not there: the game only lets you save
* during normal play, never inside a scene, and on the way back the room
* starts again as it does when you walk in.
* The room is not CurRoom, which by then is the fifty of the screen, but
* the one hCutscene put aside on the way in: the room the player was
* really in.
TabDisco         dw    Vars,512
                 dw    BitVars,512
                 dw    ObjFlag,800
                 dw    ActRoom,50
                 dw    ActX,50
                 dw    ActY,50
                 dw    ActCost,50
                 dw    ActFace,50
                 dw    ActTalk,50
                 dw    ActName,400
                 dw    InvObj,32
                 dw    InvBuf,4096
                 dw    NomiObj,NNOMI*2
                 dw    NomiBuf,NNOMI*24
                 dw    CutRoom,2
                 dw    CutCursor,2
                 dw    CutCam,2
                 dw    0,0

*=======================================================================
* SalvaPos - write slot PosI
*=======================================================================
SalvaPos         jsr   ViaPos               ; if it was there, throw it away
                 jsr   CreaPos
                 bcs   :male
                 jsr   ApriPosW
                 bcs   :male
                 lda   #Firma
                 sta   WriteBuf
                 lda   #^Firma
                 sta   WriteBuf+2
                 lda   #FIRMALEN
                 sta   WriteCount
                 stz   WriteCount+2
                 jsr   ScriviPezzo
                 bcs   :chiudimale
                 stz   DiscoIdx
:lp              ldx   DiscoIdx
                 lda   TabDisco,x
                 beq   :finito
                 sta   WriteBuf
                 lda   #^Vars
                 sta   WriteBuf+2
                 inx
                 inx
                 lda   TabDisco,x
                 sta   WriteCount
                 stz   WriteCount+2
                 inx
                 inx
                 stx   DiscoIdx
                 jsr   ScriviPezzo
                 bcc   :lp
:chiudimale      jsr   ChiudiPos
                 sec
                 rts
:finito          jsr   ChiudiPos
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* CaricaPos - read slot PosI back
*=======================================================================
CaricaPos        jsr   ApriPosR
                 bcs   :male
                 jsr   LeggiCapo
                 bcs   :chiudimale
                 jsr   ControllaFirma
                 bcs   :chiudimale
* from here on the previous game is gone. Everything is stopped except
* the screen's own script, which has to reach the end: it is its
* endCutscene that takes us back to the right room.
                 jsr   SpegniAltri
                 stz   DiscoIdx
:lp              ldx   DiscoIdx
                 lda   TabDisco,x
                 beq   :finito
                 sta   ReadBuf
                 lda   #^Vars
                 sta   ReadBuf+2
                 inx
                 inx
                 lda   TabDisco,x
                 sta   ReadCount
                 stz   ReadCount+2
                 inx
                 inx
                 stx   DiscoIdx
                 jsr   LeggiPezzo
                 bcc   :lp
:chiudimale      jsr   ChiudiPos
                 sec
                 rts
:finito          jsr   ChiudiPos
                 lda   #SCR_VERBI           ; the verb panel the screen
                 jsr   StartScript          ; had wiped
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* SpegniAltri - stop every script except the one running
*=======================================================================
SpegniAltri      ldx   #0
:lp              cpx   CurSlot
                 beq   :avanti
                 lda   #MORTO
                 sta   SlotStat,x
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 rts

ControllaFirma   ldy   #0
                 sep   #$20
                 mx    %10
:lp              lda   Capo,y
                 cmp   Firma,y
                 bne   :no
                 iny
                 cpy   #FIRMALEN
                 bcc   :lp
                 rep   #$20
                 mx    %00
                 clc
                 rts
:no              rep   #$20
                 mx    %00
                 sec
                 rts

*=======================================================================
* The disk calls
*=======================================================================
* The file name is the slot's, in the same folder where OpenLFL found the
* game files.
PosPath          lda   PosI
                 clc
                 adc   #'0'
                 sep   #$20
                 mx    %10
                 sta   PathS1+9
                 sta   PathS2+11
                 rep   #$20
                 mx    %00
                 lda   PathUsata
                 bne   :seconda
                 lda   #PathS1
                 sta   PathPos
                 lda   #^PathS1
                 sta   PathPos+2
                 rts
:seconda         lda   #PathS2
                 sta   PathPos
                 lda   #^PathS2
                 sta   PathPos+2
                 rts

ViaPos           jsr   PosPath
                 lda   PathPos
                 sta   DestroyPath
                 lda   PathPos+2
                 sta   DestroyPath+2
                 jsl   $E100A8
                 dw    DestroyGS
                 adrl  DestroyParm
                 rts                        ; if it was not there, never mind

CreaPos          jsr   PosPath
                 lda   PathPos
                 sta   CreatePath
                 lda   PathPos+2
                 sta   CreatePath+2
                 jsl   $E100A8
                 dw    CreateGS
                 adrl  CreateParm
                 rts

ApriPosW         jsr   PosPath
                 lda   PathPos
                 sta   OpenWPath
                 lda   PathPos+2
                 sta   OpenWPath+2
                 jsl   $E100A8
                 dw    OpenGS
                 adrl  OpenWParm
                 bcs   :male
                 lda   OpenWRef
                 sta   WriteRef
                 sta   ReadRef
                 sta   CloseRef
                 clc
                 rts
:male            sec
                 rts

ApriPosR         jsr   PosPath
                 lda   PathPos
                 sta   OpenPath
                 lda   PathPos+2
                 sta   OpenPath+2
                 jsl   $E100A8
                 dw    OpenGS
                 adrl  OpenParm
                 bcs   :male
                 lda   OpenRef
                 sta   ReadRef
                 sta   CloseRef
                 clc
                 rts
:male            sec
                 rts

LeggiCapo        lda   #Capo
                 sta   ReadBuf
                 lda   #^Capo
                 sta   ReadBuf+2
                 lda   #CAPOLEN
                 sta   ReadCount
                 stz   ReadCount+2
LeggiPezzo       jsl   $E100A8
                 dw    ReadGS
                 adrl  ReadParm
                 rts

ScriviPezzo      jsl   $E100A8
                 dw    WriteGS
                 adrl  WriteParm
                 rts

ChiudiPos        jsl   $E100A8
                 dw    CloseGS
                 adrl  CloseParm
                 rts

Firma            asc   'SCUMMGS1'

OpTab            anop
                 dw    hStop,hPutActor,hUnoB,hActorRoom   ; $00
                 dw    hUnless,hDrawObject,hResB,hSetState   ; $04
                 dw    hUnless,hFaceActor,hMoveInd,hObjPrep   ; $08
                 dw    hRes,hWalkActor,hPutAtObj,hUnlessState   ; $0C
                 dw    hGetOwner,hAnimate,hPanCamera,hActorOps   ; $10
                 dw    hPrint,hActorFromPos,hRandom,hClearState   ; $14
                 dw    hGoto,hSentence,hMove,hSetBit   ; $18
                 dw    hUnoB,hClassOf,hWalkTo,hUnlessState   ; $1C
                 dw    hNop,hPutActor,hSaveLoad,hGetActY   ; $20
                 dw    hRoomEgo,hDrawObject,hVarRange,hSetState   ; $24
                 dw    hUnless,hSetOwner,hAddInd,hUnoB   ; $28
                 dw    hAssignB,hPutInRoom,hDelay,hUnlessState   ; $2C
                 dw    hBoxFlags,hGetBit,hSetCamera,hRoomOps   ; $30
                 dw    hGetDist,hFindObject,hWalkToObj,hSetState   ; $34
                 dw    hUnless,hSentence,hSub,hWaitActor   ; $38
                 dw    hUnoB,hDueB,hWalkTo,hUnlessState   ; $3C
                 dw    hCutscene,hPutActor,hStartScript,hGetActX   ; $40
                 dw    hUnless,hDrawObject,hInc,hClearState   ; $44
                 dw    hUnless,hFaceActor,hChainScript,hObjPrep   ; $48
                 dw    hWaitSent,hWalkActor,hPutAtObj,hUnlessState   ; $4C
                 dw    hPickup,hAnimate,hFollowCam,hActorOps   ; $50
                 dw    hObjName,hActorFromPos,hGetMoving,hSetState   ; $54
                 dw    hOverride,hSentence,hAdd,hSetBit   ; $58
                 dw    hNop,hClassOf,hWalkTo,hUnlessState   ; $5C
                 dw    hCursor,hPutActor,hStopScript,hGetFacing   ; $60
                 dw    hRoomEgo,hDrawObject,hVicino,hClearState   ; $64
                 dw    hIsRunning,hSetOwner,hSubInd,hNop   ; $68
                 dw    hObjPrepOf,hPutInRoom,hNop,hUnlessState   ; $6C
                 dw    hLights,hGetCostume,hLoadRoom,hRoomOps   ; $70
                 dw    hGetDist,hFindObject,hWalkToObj,hClearState   ; $74
                 dw    hUnless,hSentence,hVerbOps,hGetBox   ; $78
                 dw    hResB,hDueB,hWalkTo,hUnlessState   ; $7C
                 dw    hBreak,hPutActor,hUnoB,hActorRoom   ; $80
                 dw    hUnless,hDrawObject,hResB,hSetState   ; $84
                 dw    hUnless,hFaceActor,hMoveInd,hObjPrep   ; $88
                 dw    hRes,hWalkActor,hPutAtObj,hUnlessState   ; $8C
                 dw    hGetOwner,hAnimate,hPanCamera,hActorOps   ; $90
                 dw    hPrint,hActorFromPos,hRandom,hClearState   ; $94
                 dw    hNop,hSentence,hMove,hSetBit   ; $98
                 dw    hUnoB,hClassOf,hWalkTo,hUnlessState   ; $9C
                 dw    hStop,hPutActor,hSaveLoad,hGetActY   ; $A0
                 dw    hRoomEgo,hDrawObject,hVarRange,hSetState   ; $A4
                 dw    hUnless,hSetOwner,hAddInd,hUnoB   ; $A8
                 dw    hNop,hPutInRoom,hWaitMsg,hUnlessState   ; $AC
                 dw    hBoxFlags,hGetBit,hSetCamera,hRoomOps   ; $B0
                 dw    hGetDist,hFindObject,hWalkToObj,hSetState   ; $B4
                 dw    hUnless,hSentence,hSub,hWaitActor   ; $B8
                 dw    hUnoB,hDueB,hWalkTo,hUnlessState   ; $BC
                 dw    hEndCut,hPutActor,hStartScript,hGetActX   ; $C0
                 dw    hUnless,hDrawObject,hInc,hClearState   ; $C4
                 dw    hUnless,hFaceActor,hChainScript,hObjPrep   ; $C8
                 dw    hPseudo,hWalkActor,hPutAtObj,hUnlessState   ; $CC
                 dw    hPickup,hAnimate,hFollowCam,hActorOps   ; $D0
                 dw    hObjName,hActorFromPos,hGetMoving,hSetState   ; $D4
                 dw    hPrintEgo,hSentence,hAdd,hSetBit   ; $D8
                 dw    hNop,hClassOf,hWalkTo,hUnlessState   ; $DC
                 dw    hCursor,hPutActor,hStopScript,hGetFacing   ; $E0
                 dw    hRoomEgo,hDrawObject,hVicino,hClearState   ; $E4
                 dw    hIsRunning,hSetOwner,hSubInd,hNop   ; $E8
                 dw    hObjPrepOf,hPutInRoom,hNop,hUnlessState   ; $EC
                 dw    hLights,hGetCostume,hLoadRoom,hRoomOps   ; $F0
                 dw    hGetDist,hFindObject,hWalkToObj,hClearState   ; $F4
                 dw    hUnless,hSentence,hVerbOps,hGetBox   ; $F8
                 dw    hResB,hDueB,hWalkTo,hUnlessState   ; $FC

* The EGA palette: its values 0, 85, 170 and 255 become 0, 5, 10 and 15
* on the IIGS with nothing lost.
EgaPal           dw    $0000,$000A,$00A0,$00AA
                 dw    $0A00,$0A0A,$0A50,$0AAA
                 dw    $0555,$055F,$05F5,$05FF
                 dw    $0F55,$0F5F,$0FF5,$0FFF

*=======================================================================
MyID             ds    2
DPHandle         ds    4
DPAddr           ds    2
TmpHandle        ds    4
BlockLo          ds    2
BlockHi          ds    2
PixBase          ds    2
RetAddr          ds    2
Attr             ds    2
Size             ds    4

FileNo           ds    2
RawLen           ds    2
IdxPos           ds    2
TabN             ds    2
TabMax           ds    2
TabRoom          ds    2
TabOffs          ds    2
DecN             ds    2
NumObj           ds    2
NumCos           ds    2
NumScr           ds    2
NumSnd           ds    2

CurRoom          ds    2
ShownRoom        ds    2
ShownBad         ds    2
BadOp            ds    2
RoomW            ds    2
RoomH            ds    2
Pitch            ds    2
ScrollX          ds    2
MaxScroll        ds    2
Redraw           ds    2
ScrollDis        ds    2
TxtMax           ds    2
MsgPag           ds    2
PagLen           ds    2
CamChi           ds    2
CamChi2          ds    2
CamChi3          ds    2
CamQuale         ds    2
SlotUcciso       ds    2      ; the script that ordered the pan
SlotFuori        ds    2      ; the running slot was killed from under it
TastoQ           ds    2      ; the key pressed
DiscoCmd         ds    2      ; what the game asks the disk
DiscoIdx         ds    2
PosI             ds    2      ; the slot being worked on
PathPos          ds    4
PathUsata        ds    2      ; which of the two paths worked
Capo             ds    CAPOLEN
CutRoom          ds    2      ; the room before a cutscene
CutCam           ds    2
PadreCd          ds    2      ; walking an object's parent chain
PadreNo          ds    2
PadreMask        ds    2
PadreLen         ds    2
ClipOn           ds    2      ; draw only inside the rectangle
ClipX1           ds    2
ClipX2           ds    2
ClipY1           ds    2
ClipY2           ds    2
SpecialeOra      ds    2      ; a special doSentence verb
NestSlot         ds    2      ; the slot to run here and now
DiscoAperto      ds    2      ; the disk screen is open
LuceA            ds    2      ; the numbers from lights()
LuceB            ds    2
TorciaW          ds    2      ; the flashlight cone, in pixels
TorciaH          ds    2
TorMezzaW        ds    2
TorMezzaH        ds    2
TorOn            ds    2
TorX1            ds    2
TorX2            ds    2
TorY1            ds    2
TorY2            ds    2
BuioY            ds    2
BuioL            ds    2
BuioR            ds    2
BuioSm           ds    2
BuioOn           ds    2      ; the room is dark
FineCopia        ds    2
DistQ            ds    2      ; the x difference, while y is measured
BuioStato        ds    2      ; how it was lit last time
DaComporre       ds    2      ; the room is decoded but not composed
DbgIdx           ds    2      ; the slot the debug line is at
Alive            ds    2
Tick             ds    4
LastTick         ds    2
Elapsed          ds    2
EnterOff         ds    2
DirtyX           ds    2
DirtyY           ds    2
DirtyR           ds    2                    ; right edge
DirtyB           ds    2                    ; bottom edge

PC               ds    2
Op               ds    2
Esito            ds    2
CurSlot          ds    2
SlotIdx          ds    2
SlotIdx2         ds    2
CamCur           ds    2
CamDest          ds    2
CamMode          ds    2
CamFollow        ds    2
CamGo            ds    2
CutCursor        ds    2
DbgOn            ds    2
RndSeed          ds    2
RndX             ds    2
RndN             ds    2
AccLo            ds    2
AccHi            ds    2
ShLo             ds    2
ShHi             ds    2
AggX             ds    2
AggY             ds    2
AggR             ds    2
AggB             ds    2
AggNum           ds    2
AggLen           ds    2
AggIdx           ds    2
DecFrame         ds    2
LimbExtra        ds    2
AnimArg          ds    2
AnimDir          ds    2
AnimChore        ds    2
DefTalk          ds    2
MsgColor         ds    2
MirrorOn         ds    2
MsgFondo         ds    2
VerbLast         ds    2
MsgDopo          ds    2
BoxOff           ds    2
NumBox           ds    2
BoxPtr           ds    2
BoxUy            ds    2
BoxLy            ds    2
BoxUlx           ds    2
BoxUrx           ds    2
BoxLlx           ds    2
BoxLrx           ds    2
BoxSx            ds    2
BoxDx            ds    2
BoxDy            ds    2
BoxDd            ds    2
BoxQx            ds    2
BoxQy            ds    2
BoxQyOld         ds    2
BoxSave          ds    2
BoxCx            ds    2
BoxCy            ds    2
BoxNx            ds    2
BoxNy            ds    2
BoxDist          ds    2
BoxBest          ds    2
BoxI             ds    2
BoxTmp           ds    2
BoxTmp2          ds    2
BoxScelta        ds    2
BoxDa            ds    2
BoxA             ds    2
BoxMat           ds    2
BoxProx          ds    2
EgoObj           ds    2
EgoStanza        ds    2
EgoAndX          ds    2
EgoAndY          ds    2
MulA             ds    2
MulB             ds    2
ProdLo           ds    2
ProdHi           ds    2
DivB             ds    2
DivQ             ds    2
DivR             ds    2
SetLimb          ds    2
WalkDX           ds    2
WalkDY           ds    2
WalkAX           ds    2
WalkAY           ds    2
WalkSX           ds    2
WalkSY           ds    2
ActDirty         ds    2
SprX1            ds    2
SprY1            ds    2
SprX2            ds    2
SprY2            ds    2
OvrPC            ds    2
OvrSlot          ds    2
ScrNo            ds    2
ScrOff           ds    2
ScrRm            ds    2
PoolOff          ds    2
DestVar          ds    2
RangeN           ds    2
CmpA             ds    2
CmpB             ds    2
TmpW             ds    2
DelLo            ds    2
DelHi            ds    2
ObjNo            ds    2
StBit            ds    2
BitBase          ds    2
BitNo            ds    2
BitVal           ds    2
BitMask          ds    2
ActNo            ds    2
ActArg           ds    2
ActArg2          ds    2
ActSub           ds    2
RoomA            ds    2
RoomB            ds    2

SrcOff           ds    2
SrcIdx           ds    2
DstX             ds    2
DstY             ds    2
BlkW             ds    2
BlkH             ds    2
ColX             ds    2
ColByte          ds    2
PixOff           ds    2
Riga             ds    2
RunLen           ds    2
RunByte          ds    2
ColLo            ds    2
ColHi            ds    2
Dither           ds    2
Dispari          ds    2
NumRoomObj       ds    2
ObjTabLen        ds    2
ObjIdx           ds    2
ObjImg           ds    2
ObjCode          ds    2

SrcRow           ds    2
DstRow           ds    2
FineRiga         ds    2
FillStart        ds    2
FillEnd          ds    2
DecVal           ds    2
DecHun           ds    2
DecTen           ds    2
MsgLen           ds    2
MsgNew           ds    2
MsgTimer         ds    2
MsgText          ds    {240}+2
MsgPrev          ds    {240}+2
ChTmp            ds    2
TxtCol           ds    2
TxtX             ds    2
TxtY             ds    2
StrIdx           ds    2
NibIdx           ds    2
Byte0            ds    2
Byte1            ds    2
FontIdx          ds    2
Riga8            ds    2
Conta8           ds    2
TxtOff           ds    2
EspTab           ds    32

VerbId           ds    {16}*2
VerbX            ds    {16}*2
VerbY            ds    {16}*2
VerbW            ds    {16}*2
VerbOn           ds    {16}*2
VerbName         ds    {16}*12
VerbsDirty       ds    2
VerbIdx          ds    2
VerbXT           ds    2
VerbYT           ds    2
VerbCmd          ds    2
VerbHover        ds    2                    ; the verb under the pointer, plus one
PtoX             ds    2                    ; the point to look for a verb at
PtoY             ds    2
PuntoMou         ds    4                    ; where the IIGS writes the pointer
TmpW2            ds    2
NameLen          ds    2

SentVerb         ds    {6}*2
SentObjA         ds    {6}*2
SentObjB         ds    {6}*2
SentN            ds    2

MouseX           ds    2
MouseY           ds    2
FindX            ds    2
FindY            ds    2
ObjFound         ds    2
ObjCd            ds    2
VerbWanted       ds    2
VerbOff          ds    2
SentBT           ds    2
CopyLen          ds    2
DestLo           ds    2
DestHi           ds    2
DestMax          ds    2
ClipX            ds    2
ColScr           ds    2
ColRoom          ds    2
ByteCount        ds    2
NameBase         ds    2
ObjImgOff        ds    2
ObjWant          ds    2
ChainCd          ds    2
ParState         ds    2
ParIdx           ds    2
DrawObj          ds    2
DrawX            ds    2
DrawY            ds    2
RectX            ds    2
RectY            ds    2
RectW            ds    2
RectH            ds    2
ScanIdx          ds    2
ScanObj          ds    2
ActIdx           ds    2
AnimNo           ds    2
AnimPtr          ds    2
NAnim            ds    2
CmdOff           ds    2
LimbMask         ds    2
LimbNo           ds    2
LimbJ            ds    2
LimbCmd          ds    2
FramePtr         ds    2
CelPtr           ds    2
CelSrc           ds    2
CelW             ds    2
CelH             ds    2
CelX             ds    2
CelY             ds    2
CelCol           ds    2
CelRow           ds    2
CelPx            ds    2
CelRun           ds    2
CelColor         ds    2
XMove            ds    2
YMove            ds    2
CostWant         ds    2
CostSlot         ds    2
CostOff          ds    2
CostNext         ds    2
CostNum          ds    {6}*2
ActRoom          ds    {25}*2
ActX             ds    {25}*2
ActY             ds    {25}*2
ActCost          ds    {25}*2
ActFace          ds    {25}*2
ActFrame         ds    {25}*2
ActVis           ds    {25}*2
ActTalk          ds    {25}*2
ActDstX          ds    {25}*2
ActDstY          ds    {25}*2
ActMoving        ds    {25}*2
ActErr           ds    {25}*2
ActOldX          ds    {25}*2
ActOldY          ds    {25}*2
ActBX1           ds    {25}*2
ActBY1           ds    {25}*2
ActBX2           ds    {25}*2
ActBY2           ds    {25}*2
ActBox           ds    {25}*2
ActBoxFin        ds    {25}*2
ActFinX          ds    {25}*2
ActFinY          ds    {25}*2
ActUltima        ds    {25}*2
CostPos          ds    {25}*32
CostStart        ds    {25}*32
CostEnd          ds    {25}*32
CostFrm          ds    {25}*32
CostStop         ds    {25}*2
RigaScr          ds    2
ContaB           ds    2
SentSub          ds    2

DitLo            ds    {128}
DitHi            ds    {128}
RowOff           ds    {128}*2
MaskRow          ds    {128}*2              ; the same table, for the mask
ActName          ds    {25}*16              ; what the characters are called
InvObj           ds    {16}*2               ; what is being carried
InvBuf           ds    {16}*256             ; and their description, copied
InvIdx           ds    2                    ; room they were found in
InvVisti         ds    2
InvQuale         ds    2
NomeChi          ds    2
NomeNuovo        ds    2
NomeSlot         ds    2
NomiObj          ds    NNOMI*2
NomiBuf          ds    NNOMI*24
NomeOff          ds    2
ObjDove          ds    2
ObjBaseT         ds    2
CopiaQ           ds    2
CopiaDst         ds    2
CopiaByte        ds    2
NameBase2        ds    2
SentLast         ds    2
ChiParla         ds    2
ParlaOra         ds    2
DistA            ds    2
DistB            ds    2
DistX1           ds    2
DistY1           ds    2
DistRB           ds    2      ; which room the second one is in
PosX             ds    2
PosY             ds    2
SentHot          ds    2
InvHot           ds    2
InvHotT          ds    2
MouseSave        ds    2
PanDirty         ds    2
TickAcc          ds    2
CercaX           ds    2
CercaY           ds    2
CurX             ds    2
CurY             ds    2
VicinoChi        ds    2
VicinoQ          ds    2
VicinoIdx        ds    2
PassoT           ds    2
InvDirty         ds    2
MaskPitch        ds    2
MascAtt          ds    2                    ; the mask of the box he stands on
CelRy            ds    2                    ; the pixel's row inside the room
MskX             ds    2
MskEnd           ds    2
MskY             ds    2
MskOff           ds    2
MskRun           ds    2
MskRep           ds    2
MskData          ds    2

Vars             ds    {256}*2
BitVars          ds    512
ObjFlag          ds    {800}
ScrRoom          ds    {256}
ScrOffs          ds    {256}*2
CosRoom          ds    {64}
CosOffs          ds    {64}*2
SndRoom          ds    {128}
SndOffs          ds    {128}*2

SlotNum          ds    {12}*2
SlotStat         ds    {12}*2
SlotWhere        ds    {12}*2
SlotPC           ds    {12}*2
SlotBaseT        ds    {12}*2
SlotDelLo        ds    {12}*2
SlotDelHi        ds    {12}*2

EventRec
EvtWhat          ds    2
EvtMessage       ds    4
EvtWhen          ds    4
EvtWhere         ds    4
EvtModifiers     ds    2

                 put   fontdata

