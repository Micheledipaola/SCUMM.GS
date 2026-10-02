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
                 use   4/Util.Macs
                 use   4/Locator.Macs
                 use   4/Mem.Macs
                 use   4/Misc.Macs
                 use   4/Event.Macs
                 use   4/Qd.Macs
                 use   4/Sound.Macs
                 use   4/QdAux.Macs
                 use   4/Window.Macs
                 use   4/Menu.Macs
                 use   4/Ctl.Macs
                 use   4/Line.Macs
                 use   4/Dialog.Macs
                 use   4/List.Macs
                 use   4/Std.Macs

*----- screen ----------------------------------------------------------
SHRBASE          =     $E12000
SCBOFF           =     $7D00
PALOFF           =     $7E00
SCRW             =     160            ; bytes per screen row
SCRW2            =     320            ; and the pixels, which are double
SCRPIX           =     320
ROOMROWS         =     128            ; V2's play area
* Present via bank $01 + PEI slam. Off until timed on a real IIGS:
* the 60 KB room cannot live in the 32 KB shadow, so this only changes
* the visible window copy, and FillArea still writes $E1 unless the
* whole present path is switched together.
PEI_PRESENT      =     0

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
COLFRECCIA       =     6              ; the arrows, as in the original
DBGTOP           =     192            ; the last row, for faults
CRED1TOP         =     146            ; interpreter credit, just under the title
MSGMAX           =     240
NNOMI            =     10             ; renamed objects
INVSLOTS         =     16             ; objects that can be carried
INVLEN           =     256            ; the game's longest obcd fits
PREPLEN          =     6
NACT             =     25             ; the game's actors
NCOST            =     6              ; costumes held in memory at once
* Zak costume 3 (Melissa) is 5049 bytes; 4096 truncated the L6 hood
* cel at +4412 so the TV head never drew. 8K holds every Zak costume.
COSTLEN          =     8192
COSTSIZE         =     49152          ; NCOST * COSTLEN
NVERBS           =     16             ; the game uses fifteen
VERBNAME         =     40             ; Zak's credit lines are this long
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
VAR_LAST_SOUND   =     37
VAR_MUSTIMER     =     17             ; how far the music has got
VAR_MACHSPD      =     6              ; how fast the machine is (Zak intro)
VAR_BACKVERB     =     38             ; the verb to fall back to after a sentence
VAR_KEY          =     39             ; the key pressed, as V2 counts it
VAR_SENTVERB     =     26
VAR_SENTOBJ1     =     27
VAR_SENTOBJ2     =     28
SCR_VERB         =     4              ; the script the game uses for clicks
SCR_SENT         =     2              ; and the one that runs sentences
SCR_ENTRA        =     5              ; the one that runs on entering a room

*----- memory ----------------------------------------------------------
RAWSIZE          =     41472          ; the biggest .LFL: 25510 on DOS,
*                                        but 40861 in the Amiga release,
*                                        whose rooms carry more picture
PIXSIZE          =     65536          ; 960*128 at half a byte = 61440
SLOTS            =     12             ; scripts at once
SLOTLEN          =     $0C00          ; 3072 bytes per script (the
RESSIZE          =     36864          ; biggest real one takes 2674)
MASKSIZE         =     20480          ; 960/8 by 128: one bit per pixel

*----- the game --------------------------------------------------------
MAGICV2          =     $0100          ; signature of the DOS V2 index
MAGICV1          =     $0A31          ; the classic index is SCUMM V1
ZAKOBJ           =     780            ; both enhanced V2 indexes have 780
ZAKSCR           =     155            ; Zak scripts; Maniac's index has 179
ZAKS1SOGNO       =     $0082          ; script 1: office ESC -> dream (ZakEnh)
NVARS            =     256
MAXOBJ           =     800
MAXSCR           =     256
MAXCOS           =     64
MAXSND           =     128
SFXDIR           =     1032           ; GSFX header plus 128 entries of 8
SFXPLAY          =     $8000          ; one 32K DOC bank at a time
SFXALLOC         =     $8100          ; 32K plus a page for alignment
SFXGEN           =     $0101          ; ch 0, generator 1, free-form (TN #37)
SFXSTOP          =     $0002          ; bitmask: generator 1
MUSVOL           =     140            ; DOC volume (0-255); 200 clipped 4 voices
MUSIDX           =     256
MUSSEQ           =     16384

VAR_ROOM         =     4
VAR_OVERRIDE     =     5              ; 1 after ESC skips a cutscene
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
VO_LASTSND        =     VAR_LAST_SOUND*2
VO_MUSTIMER       =     VAR_MUSTIMER*2
VO_MACHSPD        =     VAR_MACHSPD*2
VO_OVERRIDE       =     VAR_OVERRIDE*2

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
GetEOFGS         =     $2019
GetPrefixGS      =     $200A

* The save-game disk
NPOS             =     10             ; the slots on disk, Game A..J
FIRMALEN         =     8
CAPOLEN          =     FIRMALEN
SCR_VERBI_MM     =     164            ; Maniac: rebuilds the verb panel
SCR_VERBI_ZAK    =     19             ; Zak: same job (room 50 exit starts it too)
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
zpSfx            =     $28            ; packed Amiga samples (SFX file)
zpMusI           =     $2C            ; GMUS index (MUSI)
zpMus            =     $30            ; current track events (MUSQ)
zpDoc            =     $34            ; long pointer while copying into DOC RAM
zpPix2           =     $38            ; the picture, at the column being drawn
zpMask0          =     $3C            ; the room's own mask as decoded, kept
*                                       so a piece of it can be put back

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

* The Finder's tools are unloaded when it quits: every application loads
* its own from *:System:Tools, including the RAM patches of the ROM
* tools (QuickDraw, Event Manager, ...), before starting any of them.
                 lda   #1
                 jsr   SfPasso
                 PushPtr ToolList
                 _LoadTools
                 bcc   :tlok
                 sta   SfErr
:tlok
*----- QuickDraw (3), Event Manager, ours, Sound -----------------------
                 PushLong #0
                 PushLong #$0700
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

                 lda   DPAddr
                 clc
                 adc   #$0600
                 sta   SndDP

                 lda   DPAddr
                 clc
                 adc   #$0500
                 sta   GameDP
                 tcd

* 640 for the Standard File dialog, like the Finder; the game switches
* to 320 once a folder has been chosen (Avvia320).
                 lda   #2
                 jsr   SfPasso
                 PushWord DPAddr
                 PushWord #$0080
                 PushWord #640
                 PushWord MyID
                 _QDStartUp

                 lda   DPAddr
                 clc
                 adc   #$0300
                 pha
                 PushWord #20
                 PushWord #0
                 PushWord #640
                 PushWord #0
                 PushWord #200
                 PushWord MyID
                 _EMStartUp

*----- the three memory blocks -----------------------------------------
* No alignment is needed: the 65816's [long pointer],Y addressing carries
* into the bank by itself, and the offsets in here never exceed the
* 61440 bytes of one room.
                 PushLong #RAWSIZE
                 PushWord #$C000            ; locked, fixed, one bank only
                 jsr   GetBlock
                 bcc   :rawok
:nomem0          brl   NoMem
:rawok           anop
                 lda   BlockLo
                 sta   zpRaw
                 lda   BlockHi
                 sta   zpRaw+2

                 PushLong #RESSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem0
                 lda   BlockLo
                 sta   zpRes
                 lda   BlockHi
                 sta   zpRes+2

                 PushLong #PIXSIZE
                 PushWord #$C000            ; locked and fixed
                 jsr   GetBlock
                 bcs   :nomem0
                 lda   BlockLo
                 sta   zpPix
                 sta   PixBase
                 lda   BlockHi
                 sta   zpPix+2

                 PushLong #PIXSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem0
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

* A second copy of the plane, holding the room's own mask with no object
* stamped on it. With it, putting one object's rectangle back costs that
* rectangle instead of decoding the whole room's mask again.
                 PushLong #MASKSIZE
                 PushWord #$C000
                 jsr   GetBlock
                 bcs   :nomem
                 lda   BlockLo
                 sta   zpMask0
                 lda   BlockHi
                 sta   zpMask0+2

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
                 jsr   ScegliGioco
                 bcc   :cartella
                 brl   Shutdown
:cartella        jsr   Avvia320
                 jsr   ClearScreen
                 jsr   SetPalette
                 jsr   SfMostraErr          ; a Toolbox failure is said, not hidden
                 jsr   InitEspPal
                 _InitCursor
                 PushPtr FrecciaCur
                 ldx   #$1104               ; SetCursor: game arrow after the dialog
                 jsl   $E10000
                 jsr   AvviaSuono
                 jsr   LoadIndex
                 bcc   :indexok
                 jsr   IdxMsg
                 brl   DiskError
:indexok         jsr   LoadSfx
                 jsr   LoadMus
                 jsr   ResetVM

* At power-on the lights are on: variable 12 starts at zero, which means
* pitch dark, and without this the title screen came up black.
                 lda   #11
                 sta   Vars+VO_LIGHTS
                 sta   BuioStato

* until a script says otherwise the panel shows everything: sentence
* line, inventory and verbs
                 lda   #$00E0
                 sta   UserIface

                 lda   #1                   ; the boot script
                 jsr   StartScript

*=======================================================================
MainLoop         jsr   Orologio
                 jsr   SuonoTick
                 jsr   MsgTick
                 jsr   TickMusFinta
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
* Animation advances on the game clock - four ticks, fifteen frames a
* second - but repairing the picture does not. An object animating under
* a character rubs out a piece of him on any pass, and the window goes to
* the screen on every pass too, so waiting for the next game frame to put
* him back is a piece of character missing on screen in between: the
* aliens' necks under their heads, the baker flashing at his window.
* RidisegnaAttori does nothing at all unless something is dirty, so
* asking it every pass costs nothing when nothing broke.
:nocam           jsr   RidisegnaAttori

* The F key: compose the whole room every frame, the way every object
* state change used to. This has to be looked at here, on the way
* through - inside the lights test below it is jumped over whenever the
* lights have not changed, which is almost always.
                 lda   SempreCompone
                 beq   :nofull
                 sta   DaComporre
:nofull          anop

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
                 jsr   AltezzaByte          ; it was dark: zpPix was blacked,
                 sta   CopyLen              ; zpBg still has the room
                 jsr   CopiaBgPix
:bastacomporre   lda   #1
                 sta   DaComporre           ; objects go back on top
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
:nodraw          lda   IsZak                ; Zak D-debug: refresh every
                 beq   :nodbgz              ; frame so elev/xy stay live
                 lda   DbgOn                ; in cutscenes (no PanDirty)
                 beq   :nodbgz
                 jsr   DrawDbg
:nodbgz          jsr   GuardaVerbo
                 jsr   AggiornaMouseVirt
                 jsr   FraseSottoPuntatore
* Hover is not a panel rebuild: only the verb that goes dark and the one
* that lights up are rewritten. verbOps still sets VerbsDirty for a
* full redraw (new names, on/off).
                 lda   VerbsDirty
                 bne   :tutti
                 lda   VerbHover
                 cmp   VerbHoverLast
                 beq   :noverb
                 jsr   DipingiCambioVerbo
                 bra   :noverb
:tutti           stz   VerbsDirty
                 jsr   DrawVerbs
                 lda   VerbHover
                 sta   VerbHoverLast

* the sentence being built: if one of its four parts changed it is
* rewritten, without touching the rest of the panel
:noverb          lda   SentHot
                 cmp   SentHotLast
                 beq   :fraseok
                 sta   SentHotLast
                 lda   #1
                 sta   PanDirty
:fraseok         lda   InvHot
                 cmp   InvHotLast
                 beq   :invok
                 sta   InvHotLast
                 lda   #1
                 sta   InvDirty
:invok           lda   Vars+VO_SENTVERB
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
:nopan           jsr   AggiornaCredit
                 lda   InvDirty
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
                 brl   :vivi
:nonclic         cmp   #3
                 beq   :tasto
                 cmp   #5
                 beq   :tasto
                 brl   :vivi
:tasto           lda   EvtMessage
                 and   #$00FF
                 sta   TastoQ
                 cmp   #$1B
                 beq   :esc
                 cmp   #'q'
                 beq   :chiedi
                 cmp   #'Q'
                 beq   :chiedi
                 cmp   #' '
                 beq   :pausa
                 lda   EvtModifiers
                 and   #$0100
                 beq   :no8
                 lda   TastoQ
                 cmp   #'8'
                 beq   :riparti
                 jsr   TastoAudio
                 bcc   :no8
                 brl   :vivi
:no8             lda   TastoQ
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
                 cmp   #'f'                 ; F: compose the whole room every
                 beq   :full                ; frame, the way a state change
                 cmp   #'F'                 ; used to. Slow on purpose: it is
                 beq   :full                ; there to tell a drawing bug from
                 jsr   TastoGioco
                 brl   :vivi
:esc             jsr   TastoEsc
                 brl   :vivi
:chiedi          jsr   ChiediUscita
                 brl   :vivi
:pausa           jsr   PausaGioco
                 brl   :vivi
:riparti         jsr   ChiediRestart
                 brl   :vivi
:debug           lda   DbgOn
                 eor   #1
                 sta   DbgOn
                 jsr   DrawDbg
                 brl   :vivi
* a missing-redraw one. If something appears only with F held on, the
* piece-by-piece path is not covering it.
:full            lda   SempreCompone
                 eor   #1
                 sta   SempreCompone
                 lda   #1
                 sta   DaComporre
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
                 brl   :vivi

* Even when no script is alive any more we do not quit: whatever is on
* screen stays, so it can be looked at. Q asks; ESC skips a cutscene if
* the script left an override, otherwise it asks too.
:vivi            brl   MainLoop

*=======================================================================
* TastoEsc - ESC: skip the override if there is one, else maybe quit
*=======================================================================
* Auto-repeat (event 5) must not skip and must not quit: the office
* override to the dream is followed at once by another to gameplay,
* and a held ESC jumped both, then asked to leave on a black room-0
* once endCutscene had already cleared CutLiv.
* While the panel is hidden, room 0 is up, a cutscene is live, or
* boot script 1 / Zak's post-intro 108 is still running, ESC only
* skips. Nested skip stays: office -> dream, then -> gameplay.
TastoEsc         lda   IsZak
                 bne   :zak
                 jsr   SaltaScena
                 bcc   :chiedi
                 rts
:zak             lda   #$001B
                 sta   Vars+VO_KEY
                 jsr   TaciMsg              ; no StartAnim: mouth stop hung ESC
                 lda   EvtWhat
                 cmp   #5
                 beq   :fine
                 lda   IsZak
                 beq   :ovr
                 lda   #127                 ; office dialogue is live
                 jsr   GiraScript
                 beq   :ovr
                 jmp   SaltaUfficio
:ovr             jsr   SaltaScena
                 bcs   :fine
                 lda   UserIface
                 beq   :fine
                 lda   CurRoom
                 beq   :fine
                 lda   CutLiv
                 bne   :fine
                 lda   #1
                 jsr   GiraScript
                 bne   :fine
                 lda   IsZak
                 beq   :chiedi
                 lda   #108
                 jsr   GiraScript
                 bne   :fine
:chiedi          jmp   ChiediUscita
:fine            rts

* Office ESC: do not trust OvrSlot. Script 1's override at $0074 is
* goto $0082; we land there, kill 127, and run it now so the dream
* path starts before the next auto-key.
SaltaUfficio     ldx   #0
:cerca           lda   SlotStat,x
                 beq   :avanti
                 lda   SlotWhere,x
                 bne   :avanti
                 lda   SlotNum,x
                 cmp   #1
                 beq   :ok
:avanti          inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :cerca
                 rts
:ok              lda   #ZAKS1SOGNO
                 sta   SlotPC,x
                 stz   SlotDelLo,x
                 stz   SlotDelHi,x
                 lda   #1
                 sta   Vars+VO_OVERRIDE
                 stz   OvrPC
                 phx
                 lda   #127
                 jsr   FermaScript
                 ldx   #0
:kdel            stz   SlotDelLo,x
                 stz   SlotDelHi,x
                 inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :kdel
                 ldx   #0
:kcam            stz   ActMoving,x
                 inx
                 inx
                 cpx   #NACT*2
                 bcc   :kcam
                 plx
                 txa
                 lsr   a
                 jsr   ExecSlot
                 jsr   DrawMsg
* Script 1 at $0082: loadRoom(0), then the three keep-prints with
* delay(120/180), then loadRoom(58). Leaving this loop on CurRoom<>0
* dropped us back into MainLoop with Redraw wiping the line and the
* delay often still sitting in SlotDelHi. Stay until the dream room
* or script 1 is done, and tick that slot here (Zak office skip only).
:attendi         rep   #$30
                 mx    %00
                 lda   CurRoom
                 beq   :gap
                 cmp   #58
                 beq   :fatto
                 cmp   #51
                 beq   :fatto
                 cmp   #49
                 beq   :fatto
                 cmp   #55
                 beq   :fatto
:gap             lda   #1
                 jsr   GiraScript
                 beq   :fatto
                 jsr   Orologio
                 rep   #$30
                 mx    %00
                 lda   #1
                 sta   Elapsed
                 jsr   MsgTick
                 jsr   PompaSogno
                 lda   MsgNew
                 beq   :attendi
                 stz   MsgNew
                 jsr   DrawMsg
                 bra   :attendi
:fatto           rts

* Decrement script 1's delay and run it when it hits 0, same pass.
* SlotDelHi is forced 0: a leftover $FF from the 24-bit invert made
* delay(120) last forever and froze on "Later that night".
PompaSogno       ldx   #0
:lp              lda   SlotStat,x
                 beq   :av
                 lda   SlotWhere,x
                 bne   :av
                 lda   SlotNum,x
                 cmp   #1
                 beq   :ok
:av              inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :lp
                 rts
:ok              stz   SlotDelHi,x
                 lda   SlotDelLo,x
                 beq   :run
                 sec
                 sbc   Elapsed
                 bcs   :resta
                 lda   #0
:resta           sta   SlotDelLo,x
                 bne   :fine
:run             phx
                 txa
                 lsr   a
                 jsr   ExecSlot
                 plx
:fine            rts

*=======================================================================
* SaltaScena - ESC during a cutscene: jump to the override, carry set
*=======================================================================
SaltaScena       lda   OvrPC
                 beq   :no
                 ldx   OvrSlot
                 sta   SlotPC,x
                 lda   IsZak
                 bne   :zak
                 stz   OvrPC
                 sec
                 rts
:zak             lda   #1
                 sta   Vars+VO_OVERRIDE
                 stz   OvrPC
                 jsr   SpegniMsg            ; the line on screen is over
                 ldx   #0                   ; every delay, not only ours:
:kdel            stz   SlotDelLo,x          ; a leftover wait would freeze
                 stz   SlotDelHi,x          ; the skip on the office frame
                 inx
                 inx
                 cpx   #SLOTS*2
                 bcc   :kdel
                 ldx   #0                   ; leftover walks must not
:kcam            stz   ActMoving,x          ; waitForActor after the skip
                 inx
                 inx
                 cpx   #NACT*2
                 bcc   :kcam
                 sec
                 rts
:no              clc
                 rts

*=======================================================================
* ChiediUscita - not in the scripts: Y quits, N or ESC stay
*=======================================================================
ChiediUscita     _HideCursor
                 lda   #ROOMOFF
                 sta   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 lda   #15
                 jsr   SetTextColor
                 lda   #ROOMTOP+52
                 sta   TxtY
                 lda   #MsgQuit1
                 sta   zpStr
                 lda   #^MsgQuit1
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 lda   #ROOMTOP+68
                 sta   TxtY
                 lda   #MsgQuit2
                 sta   zpStr
                 lda   #^MsgQuit2
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 _ShowCursor
:attendi         PushWord #0
                 PushWord #$FFFF
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 beq   :attendi
                 lda   EvtWhat
                 cmp   #1
                 beq   :no
                 cmp   #3
                 beq   :tasto
                 cmp   #5
                 bne   :attendi
:tasto           lda   EvtMessage
                 and   #$00FF
                 cmp   #'y'
                 beq   :si
                 cmp   #'Y'
                 beq   :si
                 cmp   #'q'
                 beq   :si
                 cmp   #'Q'
                 beq   :si
                 cmp   #'n'
                 beq   :no
                 cmp   #'N'
                 beq   :no
                 cmp   #$1B
                 bne   :attendi
:no              lda   RoomH
                 beq   :niente
                 jsr   DrawRoom
:niente          jsr   DrawMsg
                 rts
:si              brl   Shutdown

*=======================================================================
* PausaGioco - SPACE, as in the DOS interpreter. The picture stays.
*=======================================================================
PausaGioco       _HideCursor
                 stz   FillStart
                 lda   #ROOMOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 lda   #15
                 jsr   SetTextColor
                 lda   #MSGTOP
                 sta   TxtY
                 lda   #MsgPausa
                 sta   zpStr
                 lda   #^MsgPausa
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 _ShowCursor
:attendi         PushWord #0
                 PushWord #$FFFF
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 beq   :attendi
                 lda   EvtWhat
                 cmp   #3
                 bne   :attendi
                 lda   EvtMessage
                 and   #$00FF
                 cmp   #' '
                 beq   :via
                 cmp   #$1B
                 bne   :attendi
:via             jsr   DrawMsg
                 rts

*=======================================================================
* ChiediRestart - Apple-8, the IIGS stand-in for F8
*=======================================================================
ChiediRestart    _HideCursor
                 lda   #ROOMOFF
                 sta   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 lda   #15
                 jsr   SetTextColor
                 lda   #ROOMTOP+52
                 sta   TxtY
                 lda   #MsgRest1
                 sta   zpStr
                 lda   #^MsgRest1
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 lda   #ROOMTOP+68
                 sta   TxtY
                 lda   #MsgQuit2
                 sta   zpStr
                 lda   #^MsgQuit2
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 _ShowCursor
:attendi         PushWord #0
                 PushWord #$FFFF
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 beq   :attendi
                 lda   EvtWhat
                 cmp   #1
                 beq   :no
                 cmp   #3
                 beq   :tasto
                 cmp   #5
                 bne   :attendi
:tasto           lda   EvtMessage
                 and   #$00FF
                 cmp   #'y'
                 beq   :si
                 cmp   #'Y'
                 beq   :si
                 cmp   #'n'
                 beq   :no
                 cmp   #'N'
                 beq   :no
                 cmp   #$1B
                 bne   :attendi
:no              jsr   DrawRoom
                 jsr   DrawMsg
                 clc
                 rts
:si              jsr   RiavviaGioco
                 sec
                 rts

*=======================================================================
* RiavviaGioco - same start as after LoadIndex
*=======================================================================
RiavviaGioco     jsr   StopMus
                 jsr   StopSfx
                 jsr   SpegniMsg
                 jsr   ResetVM
                 lda   #11
                 sta   Vars+VO_LIGHTS
                 sta   BuioStato
                 lda   #$00E0
                 sta   UserIface
                 lda   #1
                 sta   VerbsDirty
                 sta   PanDirty
                 jsr   ClearScreen
                 jsr   SetPalette
                 lda   #1
                 jmp   StartScript

*=======================================================================
* TastoGioco - the keys the game expects. A = the character.
*=======================================================================
* The DOS version uses the function keys: F1, F2 and F3 to switch
* between kids, F5 for the disk, F6 music on/off, F8 to restart. The
* IIGS has no such keys, so they come in through the Apple key:
* Apple-1, 2, 3, 5. Apple-6/7/9 and Apple--/= are audio (main loop).
* Apple-8 is caught in the main loop, not here: restart is not a game key.
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

* Apple-6 = F6 music on/off. Apple-7/9 music volume. Apple--/= SFX volume.
* Carry set if the key was ours (do not send it to the scripts).
TastoAudio       lda   EvtModifiers
                 and   #$0100
                 beq   :no
                 lda   TastoQ
                 cmp   #'6'
                 beq   :tog
                 cmp   #'7'
                 beq   :mdn
                 cmp   #'9'
                 beq   :mup
                 cmp   #'-'
                 beq   :sdn
                 cmp   #'='
                 beq   :sup
:no              clc
                 rts
:tog             lda   EvtWhat
                 cmp   #3
                 bne   :ok
                 lda   MusMute
                 eor   #1
                 sta   MusMute
                 jsr   MusApplyVol
:ok              sec
                 rts
:mdn             lda   MusLvl
                 beq   :ok
                 dec   a
                 sta   MusLvl
                 stz   MusMute
                 jsr   MusApplyVol
                 sec
                 rts
:mup             lda   MusLvl
                 cmp   #8
                 bcs   :ok
                 inc   a
                 sta   MusLvl
                 stz   MusMute
                 jsr   MusApplyVol
                 sec
                 rts
:sdn             lda   SfxLvl
                 beq   :ok
                 dec   a
                 sta   SfxLvl
                 sec
                 rts
:sup             lda   SfxLvl
                 cmp   #8
                 bcs   :ok
                 inc   a
                 sta   SfxLvl
                 sec
                 rts

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
                 bcs   :fuori
                 lda   MouseY
                 cmp   #200
                 bcc   :dentro
:fuori           rts
:dentro          anop

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
                 lda   MouseX               ; the strip between the two
                 cmp   #144                 ; columns holds the arrows
                 bcc   :nonfreccia
                 cmp   #176
                 bcs   :nonfreccia
                 jsr   ScorriInv
                 bra   :fine
:nonfreccia      jsr   OggettoSotto
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
:colonnaok       lda   InvQuale             ; the boxes show the four from
                 clc                        ; InvOff on
                 adc   InvOff
                 sta   InvQuale
                 stz   InvVisti
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
                 beq   :v2
                 cmp   #MAGICV1
                 bne   :kaputt
                 lda   #1
                 sta   IdxV1
                 bra   :kaputt

* how many objects, and their initial state (owner low, state high)
:v2              ldy   #2
                 lda   [zpRaw],y
                 sta   NumObj
                 stz   IsZak
                 lda   NumObj
                 cmp   #MAXOBJ+1
                 bcs   :kaputt

                 ldy   #4
                 ldx   #0
                 lda   #0
:azzera          sta   ObjFlag,x
                 sta   ObjInit,x
                 inx
                 inx
                 cpx   #MAXOBJ
                 bcc   :azzera
                 ldx   #0
                 sep   #$20
                 mx    %10
:obj             lda   [zpRaw],y
                 sta   ObjFlag,x
                 sta   ObjInit,x
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
* Both enhanced V2 games have 780 objects. Zak has 155 global scripts,
* Maniac 179: that is the split. Palette, title credit, dream mask
* and the other Zak-only bits all look at IsZak after this.
                 stz   IsZak
                 lda   #SCR_VERBI_MM        ; default Maniac panel rebuild
                 sta   ScrVerbi
                 lda   NumScr
                 cmp   #ZAKSCR
                 bne   :nozak
                 inc   IsZak
                 lda   #SCR_VERBI_ZAK
                 sta   ScrVerbi
:nozak           jsr   PalettaAttori

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
                 and   #3
                 beq   :gruppi
                 tax                        ; leftover words, 1..3
:resto           lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 dex
                 bne   :resto
:gruppi          lda   DecN
                 lsr   a
                 lsr   a
                 beq   :fine
                 tax
:lp              lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 lda   [zpStr],y
                 eor   #$FFFF
                 sta   [zpStr],y
                 iny
                 iny
                 dex
                 bne   :lp
:fine            rts

*=======================================================================
* OpenLFL - open file FileNo from the folder chosen at startup.
* Tries GamePre/Lnn.LFL, then 1/GamePre/Lnn.LFL.
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
                 pha
                 lda   #'L'
                 sta   PathTail
                 tya
                 clc
                 adc   #'0'
                 sta   PathTail+1
                 pla
                 clc
                 adc   #'0'
                 sta   PathTail+2
                 lda   #'.'
                 sta   PathTail+3
                 lda   #'L'
                 sta   PathTail+4
                 lda   #'F'
                 sta   PathTail+5
                 lda   #'L'
                 sta   PathTail+6
                 stz   PathTail+7
                 rep   #$20
                 mx    %00
                 jmp   OpenTail

OpenTail         jsr   MkPaths
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

* GamePre + '/' + PathTail -> PathA;  '1/' + that -> PathB.
MkPaths          sep   #$20
                 mx    %10
                 ldx   #0
                 lda   GamePre
                 beq   :tail
:gpre            cpx   GamePre
                 bcs   :slash
                 lda   GamePre+2,x
                 sta   PathA+2,x
                 inx
                 bra   :gpre
:slash           lda   #'/'
                 sta   PathA+2,x
                 inx
:tail            ldy   #0
:tlp             lda   PathTail,y
                 beq   :endt
                 sta   PathA+2,x
                 inx
                 iny
                 cpy   #15
                 bcc   :tlp
:endt            stx   PathA
                 stz   PathA+1
                 txa
                 clc
                 adc   #2
                 sta   PathB
                 stz   PathB+1
                 lda   #'1'
                 sta   PathB+2
                 lda   #'/'
                 sta   PathB+3
                 ldx   #0
:copy            cpx   PathA
                 bcs   :done
                 lda   PathA+2,x
                 sta   PathB+4,x
                 inx
                 bra   :copy
:done            rep   #$20
                 mx    %00
                 rts

CopiaSuf         sep   #$20
                 mx    %10
                 ldy   #0
:lp              lda   [zpStr],y
                 sta   PathTail,y
                 beq   :fine
                 iny
                 cpy   #15
                 bcc   :lp
                 lda   #0
                 sta   PathTail,y
:fine            rep   #$20
                 mx    %00
                 rts

TryOpen          jsl   $E100A8
                 dw    OpenGS
                 adrl  OpenParm
                 rts

*=======================================================================
* ScegliGioco - Standard File on a Finder-style desktop, 640 mode.
* Start order as in Apple's samples: Window, Control, LineEdit, Dialog,
* Menu, List, Standard File (each needs the ones before it).
* The step number goes to $00/0300: after a crash, "0/300" in the
* monitor says which call it was.
* After OK, prefix 0 is the folder that holds L00.LFL.
* Return carry set if the player cancelled.
*=======================================================================
ScegliGioco      lda   SfErr
                 bne   SfKeepMM              ; LoadTools failed: said later
                 jsr   AvviaSf
                 bcs   SfKeepMM
                 lda   #20
                 jsr   SfPasso
                 _InitCursor
                 PushWord #120               ; whereX
                 PushWord #40                ; whereY
                 PushPtr SfPrompt
                 PushLong #0                 ; no filter
                 PushLong #0                 ; no type list: every file
                 PushPtr SfReply
                 _SFGetFile
                 lda   #21
                 jsr   SfPasso
                 jsr   FermaSf
                 lda   SfGood
                 beq   SfCancel
                 stz   GamePre               ; prefix 0 is the game folder
                 clc
                 rts
SfKeepMM         jsr   FermaSf
                 clc
                 rts
SfCancel         sec
                 rts

AvviaSf          stz   SfOn
                 lda   #10
                 jsr   SfPasso
                 PushLong #0
                 PushLong #$0400             ; Control, LineEdit, Menu, SF
                 PushWord MyID
                 PushWord #$C005
                 PushLong #0
                 _NewHandle
                 PullLong SfDPHandle
                 bcc   SfDPok
                 sta   SfErr
                 sec
                 rts
SfDPok           lda   SfDPHandle
                 sta   $F0
                 lda   SfDPHandle+2
                 sta   $F2
                 lda   [$F0]
                 sta   SfDPAddr

                 lda   #11
                 jsr   SfPasso
                 _QDAuxStartUp
                 lda   #12
                 jsr   SfPasso
                 PushWord MyID
                 _WindStartUp
                 PushLong #0
                 _RefreshDesktop             ; the system desktop pattern
                 lda   #13
                 jsr   SfPasso
                 PushWord MyID
                 lda   SfDPAddr
                 pha
                 _CtlStartUp
                 lda   #14
                 jsr   SfPasso
                 PushWord MyID
                 lda   SfDPAddr
                 clc
                 adc   #$0100
                 pha
                 _LEStartUp
                 lda   #15
                 jsr   SfPasso
                 PushWord MyID
                 _DialogStartUp
                 lda   #16
                 jsr   SfPasso
                 PushWord MyID
                 lda   SfDPAddr
                 clc
                 adc   #$0200
                 pha
                 _MenuStartUp
                 _DrawMenuBar                ; the empty bar, as on the desktop
                 lda   #17
                 jsr   SfPasso
                 _ListStartup
                 lda   #18
                 jsr   SfPasso
                 PushWord MyID
                 lda   SfDPAddr
                 clc
                 adc   #$0300
                 pha
                 _SFStartUp
                 lda   #1
                 sta   SfOn
                 clc
                 rts

FermaSf          lda   SfOn
                 beq   SfFermaMem
                 _SFShutDown
                 _ListShutDown
                 _MenuShutDown
                 _DialogShutDown
                 _LEShutDown
                 _CtlShutDown
                 _WindShutDown
                 _QDAuxShutDown
                 stz   SfOn
SfFermaMem       lda   SfDPHandle
                 ora   SfDPHandle+2
                 beq   SfFermaOk
                 PushLong SfDPHandle
                 _DisposeHandle
                 stz   SfDPHandle
                 stz   SfDPHandle+2
SfFermaOk        rts

* The game is 320 SHR: restart QuickDraw and the Event Manager in 320.
Avvia320         lda   #30
                 jsr   SfPasso
                 _EMShutDown
                 _QDShutDown
                 PushWord DPAddr
                 PushWord #$0000
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
                 lda   #31
                 jsr   SfPasso
                 rts

SfPasso          sep   #$20
                 mx    %10
                 stal  $000300
                 rep   #$20
                 mx    %00
                 rts

* If the Toolbox could not be set up, say so on the game screen and wait
* for a key; the game then starts from the MM folder.
SfMostraErr      lda   SfErr
                 bne   :dire
                 rts
:dire            lda   #15
                 jsr   SetTextColor
                 stz   TxtX
                 lda   #80
                 sta   TxtY
                 lda   #MsgSfErr
                 sta   zpStr
                 lda   #^MsgSfErr
                 sta   zpStr+2
                 jsr   DrawCStr
                 lda   SfErr
                 jsr   DrawHex4
                 stz   TxtX
                 lda   #96
                 sta   TxtY
                 lda   #MsgSfTasto
                 sta   zpStr
                 lda   #^MsgSfTasto
                 sta   zpStr+2
                 jsr   DrawCStr
:lp              PushWord #0
                 PushWord #$0028             ; key down, auto-key
                 PushPtr EventRec
                 _GetNextEvent
                 pla
                 beq   :lp
                 rts

* A as four hex digits at TxtX/TxtY.
DrawHex4         sta   HexVal
                 ldx   #4
:cifra           lda   HexVal
                 xba
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 and   #$000F
                 cmp   #10
                 bcc   :num
                 adc   #'A'-10-1
                 bra   :out
:num             adc   #'0'
:out             phx
                 jsr   DrawCharInk
                 plx
                 inc   TxtX
                 lda   HexVal
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   HexVal
                 dex
                 bne   :cifra
                 rts

* Loaded from *:System:Tools: minimum version 0 = whatever is there.
ToolList         dw    10
                 dw    4,0                   ; QuickDraw II (patch)
                 dw    6,0                   ; Event Manager (patch)
                 dw    14,0                  ; Window Manager
                 dw    15,0                  ; Menu Manager
                 dw    16,0                  ; Control Manager
                 dw    18,0                  ; QuickDraw Auxiliary
                 dw    20,0                  ; LineEdit
                 dw    21,0                  ; Dialog Manager
                 dw    23,0                  ; Standard File
                 dw    28,0                  ; List Manager

*=======================================================================
* Sound: Amiga samples via the Sound Manager free-form synth (gen 1).
* Music: Amiga 50/58 scores on DOC oscillators 28-31, waves at $8000.
* Apple-6 toggles music (F6); Apple-7/9 music volume; Apple--/= SFX volume.
*=======================================================================
AvviaSuono       stz   SndOn
                 stz   SfxOn
                 stz   PlayingId
                 stz   MusOn
                 stz   MusReady
                 stz   MusId
                 stz   MusPend
                 stz   MusMute
                 stz   CometHold
                 stz   MusLoadDuck
                 lda   #7
                 sta   MusLvl
                 lda   #8
                 sta   SfxLvl
                 lda   #$FFFF
                 sta   MusEgoLast
                 stz   SndWaitT
                 stz   SndWaitId
                 stz   SndTried
                 stz   SndPlays
                 stz   SndErr
                 stz   SfxErr
                 PushWord #8
                 PushWord #0
                 _LoadOneTool
                 bcc   :tool
                 lda   #1                   ; no TOOL.008 on this boot
                 sta   SndErr
                 rts
:tool            lda   SndDP
                 pha
                 _SoundStartUp
                 bcc   :ok
                 lda   #2                   ; SoundStartUp refused the DP
                 sta   SndErr
                 rts
:ok              lda   #1
                 sta   SndOn
                 rts

LoadSfx          stz   SfxOn
                 stz   zpSfx
                 stz   zpSfx+2
                 stz   SfxErr
                 lda   #$FFFF
                 sta   SfxHave
                 jsr   ApriSfxI
                 bcc   :aperto
                 lda   #3                   ; MM/SFXI not found
                 sta   SfxErr
                 rts
:aperto          anop
                 PushLong #SFXDIR
                 PushWord #$C000
                 jsr   GetBlock
                 bcc   :gotidx
                 lda   #4                   ; no RAM for the index
                 sta   SfxErr
                 bra   :chiudi
:gotidx          lda   BlockLo
                 sta   zpSfx
                 lda   BlockHi
                 sta   zpSfx+2
                 sta   ReadBuf+2
                 lda   BlockLo
                 sta   ReadBuf
                 lda   #SFXDIR
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 ldy   #0
                 lda   [zpSfx],y
                 cmp   #$5347               ; 'G','S'
                 bne   :nomagic
                 iny
                 iny
                 lda   [zpSfx],y
                 cmp   #$5846               ; 'F','X'
                 bne   :nomagic
                 PushLong #SFXALLOC
                 PushWord #$C000
                 jsr   GetBlock
                 bcc   :gotplay
                 lda   #6                   ; no RAM for a 32K bank
                 sta   SfxErr
                 rts
:gotplay         lda   BlockLo
                 clc
                 adc   #255                 ; DOC wants a 256-byte page
                 and   #$FF00
                 sta   SfxPlayLo
                 lda   BlockHi
                 sta   SfxPlayHi
                 lda   #1
                 sta   SfxOn
                 jsr   PrefetchClk          ; clock bank, before the foyer
                 rts
:nomagic         lda   #5                   ; SFXI is not GSFX
                 sta   SfxErr
                 rts
:chiudi          jsl   $E100A8
                 dw    CloseGS
                 adrl  CloseParm
                 rts

ApriSfxI         lda   #SufSfxI
                 sta   zpStr
                 lda   #^SufSfxI
                 sta   zpStr+2
                 jsr   CopiaSuf
                 jmp   OpenTail

ApriSfxB         ldx   #0
:c               lda   SufSfx,x
                 and   #$00FF
                 sta   PathTail,x
                 inx
                 cpx   #3
                 bcc   :c
                 lda   SndBank
                 clc
                 adc   #'0'
                 sep   #$20
                 mx    %10
                 sta   PathTail+3
                 stz   PathTail+4
                 rep   #$20
                 mx    %00
                 jmp   OpenTail

* Load the bank that holds sound 28 so the first foyer ticks are not
* eaten by a 32K GS/OS read.
PrefetchClk      lda   SfxOn
                 beq   :no
                 lda   #28
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   #8
                 tay
                 iny
                 iny                        ; pages
                 lda   [zpSfx],y
                 and   #$00FF
                 beq   :no
                 iny
                 iny                        ; vol / bank
                 lda   [zpSfx],y
                 xba
                 and   #$00FF
                 sta   SndBank
                 jsr   ApriSfxB
                 bcs   :no
                 lda   SfxPlayLo
                 sta   ReadBuf
                 lda   SfxPlayHi
                 sta   ReadBuf+2
                 lda   #SFXPLAY
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 lda   SndBank
                 sta   SfxHave
:no              rts

StopSfx          lda   SndOn
                 beq   :fine
                 PushWord #SFXSTOP          ; generator 1 only; leave the music
                 _FFStopSound
                 stz   PlayingId
:fine            rts

SuonoTick        lda   SndWaitT
                 beq   :nowait
                 sec
                 sbc   Elapsed
                 beq   :fuoco
                 bcc   :fuoco
                 sta   SndWaitT
                 bra   :nowait
:fuoco           stz   SndWaitT
                 lda   SndWaitId
                 stz   SndWaitId
                 sta   SndWant
                 jsr   PlayOra              ; delayed comet / door, not through PlaySfx
:nowait          lda   PlayingId
                 beq   :sfxdone
                 lda   SndLoop
                 bne   :sfxdone
                 pha
                 PushWord #1
                 _FFSoundDoneStatus
                 pla
                 beq   :sfxdone
                 stz   PlayingId
:sfxdone         lda   MusPend
                 beq   :nopend
                 stz   MusPend
                 jsr   PlayMus
:nopend          jsr   MusTick
                 jsr   MusWatchEgo
                 rts

* GSFX index: 8-byte header then 128 records of 8:
* +0 freq, +2 pages (lo) / flags (hi), +4 vol (lo) / bank (hi),
* +6 page in the 32K bank. Samples live in MM/SFX0..n, one bank each.

PlaySfx          sta   SndWant
                 sta   Vars+VO_LASTSND
                 inc   SndTried
                 lda   SfxOn
                 bne   :s1
                 rts
:s1              lda   SndOn
                 bne   :s2
                 rts
:s2              lda   SndWant
                 bne   :s3
                 rts
:s3              cmp   #MAXSND
                 bcc   :s4
                 rts
:s4              cmp   #56                  ; one slow swoosh near the impact
                 bne   :chkd
                 lda   SndWaitId
                 cmp   #56
                 beq   :giaatt
                 lda   #500                 ; meteor is on screen by then
                 sta   SndWaitT
                 lda   #56
                 sta   SndWaitId
:giaatt          rts
:chkd            cmp   #8
                 beq   :porta
                 cmp   #9
                 bne   :subito
:porta           lda   #1                   ; a hair after the graphic
                 sta   SndWaitT
                 lda   SndWant
                 sta   SndWaitId
                 rts
:subito          stz   SndWaitT
                 stz   SndWaitId
                 lda   SndWant
                 cmp   #57
                 bne   PlayOra
                 stz   CometHold            ; impact: stop filling with 56
PlayOra          jsr   StopSfx
                 lda   SndWant
                 asl   a
                 asl   a
                 asl   a                    ; *8
                 clc
                 adc   #8
                 tay
                 lda   [zpSfx],y            ; freq
                 sta   FFFreq
                 iny
                 iny
                 lda   [zpSfx],y            ; pages / flags
                 sta   FFPages
                 and   #$00FF
                 beq   :no
                 lda   [zpSfx],y
                 xba
                 and   #$00FF
                 sta   SndLoop
                 lda   SndWant
                 cmp   #56
                 bne   :keep
                 stz   SndLoop              ; one cycle, not an alarm
:keep            iny
                 iny
                 lda   [zpSfx],y            ; vol / bank
                 and   #$00FF
                 sta   SndVol
                 lda   [zpSfx],y
                 xba
                 and   #$00FF
                 sta   SndBank
                 iny
                 iny
                 lda   [zpSfx],y
                 and   #$00FF
                 sta   SndPage
                 lda   SndBank
                 cmp   SfxHave
                 beq   :gia
                 jsr   ApriSfxB
                 bcc   :load
:no              rts
:load            anop
                 lda   SfxPlayLo
                 sta   ReadBuf
                 lda   SfxPlayHi
                 sta   ReadBuf+2
                 lda   #SFXPLAY
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 lda   SndBank
                 sta   SfxHave
:gia             lda   SndWant
                 cmp   #54                  ; kids: first 2 pages, Start: the high note
                 bne   :lunghi
                 lda   #2
                 sta   FFPages
                 jsr   ChiStart
                 bcc   :due
                 lda   SndPage
                 clc
                 adc   #2
                 sta   SndPage
:due             lda   #2
                 bra   :corto
:lunghi          lda   SndWant
                 cmp   #57                  ; impact: the body is at the end
                 beq   :coda
                 cmp   #56
                 beq   :coda                ; swoosh: tail of the sample, once
                 lda   FFPages
                 and   #$00FF
                 cmp   #9
                 bcc   :corto
                 lda   #8                   ; long wave: first 2K (no IRQ)
                 bra   :corto
:coda            lda   FFPages
                 and   #$00FF
                 cmp   #9
                 bcc   :corto
                 sec
                 sbc   #8
                 clc
                 adc   SndPage
                 sta   SndPage
                 lda   #8
:corto           sta   FFPages
                 lda   SndPage
                 xba                        ; page * 256
                 clc
                 adc   SfxPlayLo
                 sta   FFWave
                 lda   SfxPlayHi
                 adc   #0
                 sta   FFWave+2
                 lda   #$0800
                 sta   FFBuf
                 lda   #$2000
                 sta   FFDoc
                 lda   SndVol
                 ldx   SfxLvl
                 jsr   ScaleVol
                 sta   FFVol
                 stz   FFNext
                 stz   FFNext+2
                 jsr   StopSfx
                 PushWord #SFXGEN
                 PushPtr FFSynth
                 _FFStartSound
                 inc   SndPlays
                 lda   SndWant
                 sta   PlayingId
                 rts

* Carry set if this click is the kid-select Start button (object 395 or 403).
ChiStart         ldx   CurSlot
                 lda   SlotNum,x
                 jsr   EStartId
                 bcs   :si
                 lda   ObjFound
                 jsr   EStartId
                 bcs   :si
                 lda   Vars+VO_ACTOBJ1
                 jsr   EStartId
:si              rts
EStartId         cmp   #395
                 beq   :yes
                 cmp   #403
                 beq   :yes
                 clc
                 rts
:yes             sec
                 rts

hStartSound      jsr   VOB1
                 pha
                 jsr   TryMus
                 bcc   :mus
                 pla
                 jsr   PlaySfx
                 bra   :ok
:mus             pla
:ok              stz   Esito
                 rts

* startMusic. Zak's intro waits on the music timer: with no score to play
* that timer would never move, so it counts seconds instead.
hStartMusic      jsr   VOB1
                 pha
                 jsr   TryMus
                 bcc   :mus
                 pla
                 jsr   PlaySfx
                 lda   IsZak
                 beq   :ok
                 lda   #1
                 sta   MusFinta
                 stz   MusFintaT
                 stz   Vars+VO_MUSTIMER
                 bra   :ok
:mus             pla
                 stz   MusFinta
:ok              stz   Esito
                 rts

* One step of the stand-in music timer, once a second.
TickMusFinta     lda   MusFinta
                 beq   :fine
                 lda   MusFintaT
                 clc
                 adc   Elapsed
:ancora          cmp   #60
                 bcc   :resto
                 sec
                 sbc   #60
                 inc   Vars+VO_MUSTIMER
                 bra   :ancora
:resto           sta   MusFintaT
:fine            rts

hStopMusic       stz   MusFinta
                 jsr   StopMus
                 lda   PlayingId
                 cmp   #50
                 beq   :sfx
                 cmp   #58
                 bne   :ok
:sfx             jsr   StopSfx
:ok              stz   Esito
                 rts

hStopSound       jsr   VOB1
                 cmp   SndWaitId
                 bne   :play
                 stz   SndWaitT
                 stz   SndWaitId
:play            pha
                 jsr   TryStopMus
                 pla
                 cmp   PlayingId
                 bne   :fine
                 jsr   StopSfx
:fine            stz   Esito
                 rts

hIsSound         jsr   FetchB
                 jsr   ResolveVar
                 stx   DestVar
                 jsr   VOB1
                 sta   MusTmp
* No sample in the GSFX index: not running. Zak's intro waits on
* sound 81 (credits sting) which we do not pack; treating a stale
* PlayingId as live froze ESC-from-the-office on a dead wait.
                 lda   zpSfx
                 ora   zpSfx+2
                 beq   :nosfx
                 lda   MusTmp
                 cmp   #MAXSND
                 bcs   :nosfx
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   #8
                 tay
                 iny
                 iny
                 lda   [zpSfx],y
                 and   #$00FF
                 bne   :cplay
:nosfx           lda   MusTmp
                 cmp   PlayingId
                 bne   :cmus
                 stz   PlayingId
                 bra   :cmus
:cplay           lda   MusTmp
                 ldx   DestVar
                 cmp   PlayingId
                 beq   :si
:cmus            lda   MusReady
                 beq   :zero
                 lda   MusTmp
                 cmp   MusId
                 beq   :muson
                 lda   MusTmp
                 cmp   #58
                 bne   :c50
                 ldy   #12
                 lda   [zpMusI],y
                 cmp   MusId
                 beq   :muson
                 bra   :zero
:c50             cmp   #50
                 bne   :zero
                 ldy   #10
                 lda   [zpMusI],y
                 cmp   MusId
                 bne   :zero
:muson           lda   MusOn
                 beq   :zero
:si              ldx   DestVar
                 lda   #1
                 sta   Vars,x
                 stz   Esito
                 rts
:zero            ldx   DestVar
                 lda   #0
                 sta   Vars,x
                 stz   Esito
                 rts

*=======================================================================
* Music - Amiga V2 scores, 4 DOC voices (osc 28-31), wavetables in
* DOC RAM at $8000. SFX stay on Sound Manager generator 1 / $2000.
* Do not write $E1: that register belongs to the Sound Manager; touching
* it (or filling DOC RAM from $0000) silences both music and SFX.
* Index MUSI, samples MUS0, one track from MUSQ. music/map.txt chooses
* which id is intro / house / each ego.
*=======================================================================
LoadMus          stz   MusReady
                 stz   MusOn
                 rts                   ; no score: Amiga samples and DOS PCjr both sounded wrong

ApriMus0         lda   #SufMus0
                 sta   zpStr
                 lda   #^SufMus0
                 sta   zpStr+2
                 jsr   CopiaSuf
                 jmp   OpenTail

ApriMusQ         lda   #SufMusQ
                 sta   zpStr
                 lda   #^SufMusQ
                 sta   zpStr+2
                 jsr   CopiaSuf
                 jmp   OpenTail

TryMus           sta   MusWant
                 lda   MusReady
                 beq   :no
                 lda   MusWant
                 cmp   #50
                 bne   :c58
                 ldy   #10
                 lda   [zpMusI],y
                 bra   :use
:c58             cmp   #58
                 bne   :as
                 ldy   #12
                 lda   [zpMusI],y
:use             sta   MusWant
:as              lda   MusWant
                 beq   :no
                 jsr   FindTrack
                 bcs   :no
                 lda   #1
                 sta   MusPend              ; load on the next tick, not in the script
                 clc
                 rts
:no              sec
                 rts

TryStopMus       cmp   MusId
                 beq   :go
                 cmp   #50
                 beq   :go
                 cmp   #58
                 beq   :go
                 rts
:go              jmp   StopMus

FindTrack        ldy   #4
                 lda   [zpMusI],y
                 sta   MusTmp
                 ldy   #48
:lp              lda   MusTmp
                 beq   :miss
                 lda   [zpMusI],y
                 cmp   MusWant
                 beq   :hit
                 tya
                 clc
                 adc   #8
                 tay
                 dec   MusTmp
                 bra   :lp
:hit             iny
                 iny
                 lda   [zpMusI],y
                 sta   MusTLen
                 iny
                 iny
                 lda   [zpMusI],y
                 sta   MarkPos
                 iny
                 iny
                 lda   [zpMusI],y
                 sta   MarkPos+2
                 clc
                 rts
:miss            sec
                 rts

PlayMus          lda   MusReady
                 bne   :go
                 rts
:go              jsr   StopMus
                 jsr   ApriMusQ
                 bcc   :rd
                 rts
:rd              jsl   $E100A8
                 dw    SetMarkGS
                 adrl  MarkParm
                 lda   zpMus
                 sta   ReadBuf
                 lda   zpMus+2
                 sta   ReadBuf+2
                 lda   MusTLen
                 sta   ReadCount
                 stz   ReadCount+2
                 jsr   ReadAndClose
                 ldy   #0
                 lda   [zpMus],y
                 sta   MusN
                 iny
                 iny
                 lda   [zpMus],y
                 sta   MusN+2
                 iny
                 iny
                 lda   [zpMus],y
                 sta   MusN+4
                 iny
                 iny
                 lda   [zpMus],y
                 sta   MusN+6
                 lda   #8
                 sta   MusPtr
                 lda   MusN
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   #8
                 sta   MusPtr+2
                 lda   MusN+2
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   MusPtr+2
                 sta   MusPtr+4
                 lda   MusN+4
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   MusPtr+4
                 sta   MusPtr+6
                 ldx   #0
:z               stz   MusEnd,x
                 lda   #$FFFF
                 sta   MusLastPg,x
                 inx
                 inx
                 cpx   #8
                 bcc   :z
                 stz   MusClock
                 lda   MusWant
                 sta   MusId
                 ldy   #8
                 lda   [zpMusI],y          ; house id
                 cmp   MusWant
                 bne   :noloop
                 lda   #1
                 bra   :lp
:noloop          lda   #0
:lp              sta   MusLoop
                 lda   #1
                 sta   MusOn
:no              rts

StopMus          stz   MusPend
                 lda   MusOn
                 beq   :off
                 jsr   DocHaltAll
:off             stz   MusOn
                 stz   MusId
                 rts

MusWatchEgo      lda   MusReady
                 beq   :no
                 lda   Vars+VO_ROOM
                 cmp   #45                  ; kid select
                 beq   :no
                 cmp   #33                  ; meteor / tree
                 beq   :no
                 cmp   #49                  ; fly-over after the tree
                 beq   :no
                 lda   Vars+VO_EGO
                 cmp   MusEgoLast
                 beq   :no
                 sta   MusEgoLast
                 cmp   #1
                 bcc   :no
                 cmp   #8
                 bcs   :no
                 asl   a
                 clc
                 adc   #16
                 tay
                 lda   [zpMusI],y
                 beq   :no
                 sta   MusWant
                 jsr   FindTrack
                 bcs   :no
                 jsr   PlayMus
:no              rts

MusTick          lda   MusOn
                 bne   :on
                 rts
:on              lda   Elapsed
                 beq   :rts                 ; busy-loop: do not eat the score
                 cmp   #4
                 bcc   :add
                 lda   #3                   ; hitch: lag a little, never fast-forward
:add             clc
                 adc   MusClock
                 sta   MusClock
                 ldx   #0
:ch              jsr   MusChan
                 inx
                 inx
                 cpx   #8
                 bcc   :ch
                 jsr   MusMaybeEnd
:rts             rts

* X = channel * 2. Fire every due event; halt the oscillator when done.
MusChan          phx
                 lda   MusN,x
                 beq   :hold
                 lda   #24
                 sta   MusBurst
:more            lda   MusBurst
                 beq   :hold
                 dec   MusBurst
                 lda   MusPtr,x
                 tay
                 lda   [zpMus],y            ; tick
                 cmp   MusClock
                 beq   :fire
                 bcc   :fire
                 bra   :hold
:fire            lda   MusN,x
                 beq   :hold
                 jsr   MusNote
                 lda   MusPtr,x
                 clc
                 adc   #8
                 sta   MusPtr,x
                 lda   MusN,x
                 dec   a
                 sta   MusN,x
                 bne   :more
:hold            lda   MusEnd,x
                 beq   :rts
                 cmp   MusClock
                 beq   :cut
                 bcs   :rts
:cut             jsr   MusQuiet
                 stz   MusEnd,x
:rts             plx
                 rts

MusNote          phx
                 phy
                 lda   [zpMus],y            ; tick
                 sta   MusEvTick
                 iny
                 iny
                 lda   [zpMus],y            ; DOC frequency
                 sta   MusFreq
                 iny
                 iny
                 lda   [zpMus],y            ; dur
                 clc
                 adc   MusEvTick            ; absolute end, not MusClock+dur
                 sta   MusEnd,x
                 iny
                 iny
                 lda   [zpMus],y            ; inst
                 and   #$00FF
                 sta   MusSlot
                 iny
                 lda   [zpMus],y            ; flags: bit0 = oneshot
                 and   #$0001
                 sta   MusOneShot
                 lda   MusSlot
                 asl   a
                 clc
                 adc   #32
                 tay
                 lda   [zpMusI],y
                 and   #$00FF
                 sta   MusPage
                 lda   [zpMusI],y
                 xba
                 and   #$00FF
                 beq   :ply
                 lda   MusEnd,x
                 cmp   MusClock
                 beq   :ply
                 bcc   :ply
                 jsr   DocSize
                 sta   MusWSize
                 jsr   DocNote
:ply             ply
                 plx
                 rts

MusQuiet         jmp   DocHalt

MusMaybeEnd      ldx   #0
:lp              lda   MusN,x
                 bne   :busy
                 lda   MusEnd,x
                 bne   :busy
                 inx
                 inx
                 cpx   #8
                 bcc   :lp
                 lda   MusLoop
                 beq   :house
                 lda   MusId
                 sta   MusWant
                 jsr   FindTrack
                 bcs   :die
                 lda   #1
                 sta   MusPend
                 rts
:house           ldy   #6
                 lda   [zpMusI],y          ; flags
                 and   #1
                 beq   :die
                 ldy   #8
                 lda   [zpMusI],y
                 beq   :die
                 cmp   MusId
                 beq   :die
                 sta   MusWant
                 jsr   FindTrack
                 bcs   :die
                 lda   #1
                 sta   MusPend
                 rts
:die             jsr   StopMus
:busy            rts

* Osc 28-31: last four, above the Sound Manager's generators.
MusOscT          dw    28,29,30,31
MusCtlT          dw    $0000,$0010,$0000,$0010

* A = wavetable pages (1,2,4,8) -> DOC $C0 size field, RES=0.
DocSize          phx
                 ldx   #0
:lp              cmp   #2
                 bcc   :ok
                 lsr   a
                 inx
                 bra   :lp
:ok              txa
                 asl   a
                 asl   a
                 asl   a
                 plx
                 rts

DocHaltAll       ldx   #0
:lp              jsr   DocHalt
                 inx
                 inx
                 cpx   #8
                 bcc   :lp
                 rts

DocHalt          phx
                 lda   #$FFFF
                 sta   MusLastPg,x
                 lda   SndOn
                 beq   :no
                 lda   MusOscT,x
                 clc
                 adc   #$00A0
                 tay
                 lda   MusCtlT,x
                 ora   #$0001
                 tyx
                 jsr   DocWr
:no              plx
                 rts

* X = channel*2. Retrigger without halt unless the wavetable changed.
DocNote          lda   SndOn
                 bne   :go
                 rts
:go              phx
                 php
                 sei
                 stx   MusCh
                 lda   MusLastPg,x
                 cmp   MusPage
                 beq   :same
                 jsr   DocHalt
                 ldx   MusCh
                 lda   MusPage
                 sta   MusLastPg,x
:same            lda   MusOscT,x
                 sta   MusOsc
                 tax
                 lda   MusFreq
                 and   #$00FF
                 jsr   DocWr
                 lda   MusOsc
                 clc
                 adc   #$0020
                 tax
                 lda   MusFreq
                 xba
                 and   #$00FF
                 jsr   DocWr
                 lda   MusOsc
                 clc
                 adc   #$0040
                 pha
                 jsr   MusDocVol
                 plx
                 jsr   DocWr
                 lda   MusOsc
                 clc
                 adc   #$0080
                 tax
                 lda   MusPage
                 clc
                 adc   #$0080
                 and   #$00FF
                 jsr   DocWr
                 lda   MusOsc
                 clc
                 adc   #$00C0
                 tax
                 lda   MusWSize
                 jsr   DocWr
                 ldx   MusCh
                 lda   MusCtlT,x
                 ldx   MusOneShot
                 beq   :free
                 ora   #$0002               ; oneshot, then auto-halt
:free            pha
                 lda   MusOsc
                 clc
                 adc   #$00A0
                 tax
                 pla
                 jsr   DocWr
                 plp
                 plx
                 rts

* A = byte, X = DOC register (0-255). I/O in bank $E1.
DocWr            php
                 sei
                 sep   #$20
                 mx    %10
                 pha
:w               lda   >$E1C03C
                 bmi   :w
                 lda   #$0F
                 sta   >$E1C03C
:w2              lda   >$E1C03C
                 bmi   :w2
                 txa
                 sta   >$E1C03E
:w3              lda   >$E1C03C
                 bmi   :w3
                 pla
                 sta   >$E1C03D
                 plp
                 mx    %00
                 rts

* Pages actually used in MUS0 (max of page+pages in the 8 slots).
DocWaveLen       ldy   #32
                 stz   MusTmp
                 lda   #8
                 sta   MusCh
:lp              lda   [zpMusI],y
                 pha
                 and   #$00FF
                 sta   MusPage
                 pla
                 xba
                 and   #$00FF
                 clc
                 adc   MusPage
                 cmp   MusTmp
                 bcc   :n
                 sta   MusTmp
:n               iny
                 iny
                 dec   MusCh
                 bne   :lp
                 lda   MusTmp
                 rts

* Copy MUS0 into DOC RAM $8000. 16-bit store to $C03E so the high
* address actually lands in $C03F; a 32K fill from $0000 had wiped
* the Sound Manager's wavetable at $2000 (SFX and music both gone).
DocCopyWaves     lda   SndOn
                 bne   :len
                 rts
:len             jsr   DocWaveLen
                 beq   :no
                 sta   MusTmp
                 lda   MusPlayLo
                 sta   zpDoc
                 lda   MusPlayHi
                 sta   zpDoc+2
                 php
                 sei
                 sep   #$20
                 mx    %10
:w               lda   >$E1C03C
                 bmi   :w
                 lda   #$4F                 ; RAM, no autoinc, vol 15
                 sta   >$E1C03C
:w2              lda   >$E1C03C
                 bmi   :w2
                 rep   #$20
                 mx    %00
                 lda   #$8000
                 sta   >$E1C03E
                 sep   #$30
                 mx    %11
:w3              lda   >$E1C03C
                 bmi   :w3
                 lda   #$6F                 ; RAM + autoinc
                 sta   >$E1C03C
                 ldx   MusTmp               ; pages (lo)
                 ldy   #$00
:lp              lda   >$E1C03C
                 bmi   :lp
                 lda   [zpDoc],y
                 sta   >$E1C03D
                 iny
                 bne   :lp
                 inc   zpDoc+1
                 dex
                 bne   :lp
:w4              lda   >$E1C03C
                 bmi   :w4
                 lda   #$0F                 ; DOC registers, vol 15
                 sta   >$E1C03C
                 plp
                 mx    %00
:no              rts

* A = 0-255, X = 0-8  ->  A * X / 8
ScaleVol         and   #$00FF
                 cpx   #0
                 beq   :z
                 cpx   #8
                 beq   :ok
                 sta   VolTmp
                 lda   #0
:lp              clc
                 adc   VolTmp
                 dex
                 bne   :lp
                 lsr   a
                 lsr   a
                 lsr   a
:ok              rts
:z               lda   #0
                 rts

MusDocVol        lda   MusMute
                 ora   MusLoadDuck
                 bne   :z
                 lda   #MUSVOL
                 ldx   MusLvl
                 jmp   ScaleVol
:z               lda   #0
                 rts

MusApplyVol      lda   MusOn
                 beq   :no
                 ldx   #0
:lp              phx
                 lda   MusOscT,x
                 clc
                 adc   #$0040
                 pha
                 jsr   MusDocVol
                 plx
                 jsr   DocWr
                 plx
                 inx
                 inx
                 cpx   #8
                 bcc   :lp
:no              rts

MusDuck          lda   #1
                 sta   MusLoadDuck
                 jmp   MusApplyVol          ; mute; do not halt (score stays in time)

MusUnduck        lda   MusLoadDuck
                 bne   :go
                 rts
:go              lda   MusOn
                 beq   :vol
                 PushLong #0
                 _GetTick
                 PullLong Tick
                 lda   Tick
                 sec
                 sbc   LastTick
                 beq   :vol
                 cmp   #120
                 bcc   :n
                 lda   #120
:n               sta   MusCatch
:lp              lda   MusCatch
                 beq   :caught
                 dec   MusCatch
                 lda   #1
                 sta   Elapsed
                 jsr   MusTick
                 bra   :lp
:caught          lda   Tick
                 sta   LastTick
:vol             stz   MusLoadDuck
                 jmp   MusApplyVol

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
                 bne   :avanti
                 brl   :trovato
:avanti          inx
                 inx
                 cpx   #NCOST*2
                 bcc   :cerca

* not there: load it over the oldest one
                 lda   CostWant
                 cmp   NumCos
                 bcc   :numok
                 brl   :male
:numok           asl   a
                 tax
                 lda   CosOffs,x
                 sta   ScrOff
                 bne   :offok
                 brl   :male
:offok           cmp   #$FFFF
                 bne   :offok2
                 brl   :male
:offok2          ldx   CostWant
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

                 lda   CostSlot             ; slot * COSTLEN (8192)
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
                 asl   a                    ; (slot*2)<<12 = slot*8192
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
                 bcc   :caricato
                 brl   :male
:caricato        anop
* Zak costume 31: stock LFL leaves the pointing cel's armpit hollow
* (cols 7-14, rows 16-18). Patch the RAM copy after decipher so the
* fix lands even when SFGet pointed at an unpatched ZakEnh folder.
                 lda   IsZak
                 beq   :segnato
                 lda   CostWant
                 cmp   #31
                 bne   :segnato
                 jsr   PatchCost31Arm
:segnato         ldx   CostSlot
                 lda   CostWant
                 sta   CostNum,x
                 clc
                 rts
:trovato         clc
                 rts
:male            sec
                 rts

* PatchCost31Arm - overwrite cel +104 in the buffer at zpStr (just
* loaded). Cel31Arm lives with the other tables; keep this stub short
* so SlotCostume's bcs :male still fits in a branch.
CEL31ARM_OFF     =     104
CEL31ARM_LEN     =     141
PatchCost31Arm   ldx   #0
                 ldy   #CEL31ARM_OFF
                 sep   #$20
                 mx    %10
:lp              lda   Cel31Arm,x
                 sta   [zpStr],y
                 inx
                 iny
                 cpx   #CEL31ARM_LEN
                 bcc   :lp
                 rep   #$20
                 mx    %00
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
                 asl   a                    ; (slot*2)<<12 = slot*8192
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
                 rep   #$30
                 mx    %00
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
                 cmp   NAnim                ; NAnim is a count: 0..NAnim-1
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
                 jmp   SegnaAttore

*=======================================================================
* SetFacing - A = facing (0 left, 1 right, 2 front, 3 back)
*=======================================================================
* Turning means redoing every limb with the same animation as before but
* the new facing.
SetFacing        ldx   ActIdx
                 cmp   ActFace,x
                 bne   :cambia
                 rts
* CostDecode walks LimbNo itself, so this loop has its own counter.
* Each limb may come from a different chore (head vs walk). Calling
* StartAnim once per limb re-decoded the same chore up to sixteen times;
* we remember which frame numbers we have already applied.
:cambia          sta   ActFace,x
                 jsr   SegnaAttore
                 ldx   #62
                 lda   #0
:clr             sta   AnimSeen,x
                 dex
                 dex
                 bpl   :clr
                 stz   SetLimb
:lp              lda   SetLimb
                 sta   LimbNo
                 jsr   LimbOff
                 lda   CostFrm,x
                 cmp   #$FFFF
                 beq   :avanti
                 lsr   a                    ; the facing was in the two bits
                 lsr   a                    ; low: the frame is left
                 sta   DecFrame
                 cmp   #64
                 bcs   :ridecod             ; rare: no room in the seen table
                 tax
                 sep   #$20
                 mx    %10
                 lda   AnimSeen,x
                 bne   :gia8
                 lda   #1
                 sta   AnimSeen,x
                 rep   #$20
                 mx    %00
                 lda   DecFrame
                 jsr   CostDecode
                 bra   :avanti
:gia8            rep   #$20
                 mx    %00
                 bra   :avanti
:ridecod         jsr   CostDecode
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
ShowActor        lda   IsZak
                 bne   :zak
                 jsr   ResetLimbs
                 ldx   ActIdx
                 lda   ActFace,x            ; anyone who never turned
                 bne   :hagia               ; looks forward
                 lda   #2
                 sta   ActFace,x
:hagia           lda   #1
                 jsr   StartAnim
                 lda   #2
                 jsr   StartAnim
                 lda   #4
                 jsr   StartAnim
                 bra   :vis
:zak             jsr   ApplicaPalCost
                 jsr   FermaPose
                 jsr   AssegnaCasella
:vis             ldx   ActIdx
                 lda   #1
                 sta   ActVis,x
                 lda   ActX,x
                 sta   ActOldX,x
                 lda   ActY,x
                 sta   ActOldY,x
                 rts

* Standing still: drop leftover walk limbs, then the three V2 layers
* (body, head, mouth). StartAnim 1 alone leaves the legs walking.
FermaPose        jsr   ResetLimbs
                 lda   #1
                 jsr   StartAnim
                 lda   #2
                 jsr   StartAnim
                 lda   #4
                 jmp   StartAnim

* actorOps Color: costume colour index -> the colour that is drawn.
* V2 (both games) starts from identity 0..15, then Color(index, colour)
* writes ActPal[index]=colour. DrawPal is that table plus the two
* ClassicCostumeRenderer rules: index 12 is skin ($0C), and the
* costume's single colour byte is replaced with palette[0].
RemapColore      lda   CelColor
                 and   #$000F
                 tax
                 lda   DrawPal,x
                 and   #$00FF
                 sta   CelColor
                 rts

ResetPalUno      lda   ActIdx               ; identity 0..15 for one actor
                 asl   a
                 asl   a
                 asl   a
                 tax
                 ldy   #0
                 sep   #$20
                 mx    %10
:b               tya
                 sta   ActPal,x
                 inx
                 iny
                 cpy   #16
                 bcc   :b
                 rep   #$20
                 mx    %00
                 rts

PreparaPalAttore lda   ActIdx
                 asl   a
                 asl   a
                 asl   a
                 tax
                 ldy   #0
                 sep   #$20
                 mx    %10
:c               lda   ActPal,x
                 sta   DrawPal,y
                 inx
                 iny
                 cpy   #16
                 bcc   :c
                 lda   #12                  ; V2 EGA: colour 12 is always skin
                 sta   DrawPal+12
                 ldy   #6
                 lda   [zpStr],y            ; costume colour byte: that
                 and   #$0F                 ; index is drawn as palette[0]
                 tay
                 lda   DrawPal
                 sta   DrawPal,y
                 rep   #$20
                 mx    %00
                 rts

PalettaAttori    stz   ActIdx
:lp              jsr   ResetPalUno
                 lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 lda   IsZak
                 beq   :fine
                 sep   #$20
                 mx    %10
                 lda   #0                   ; Zak's suit (9, 14) is black
                 sta   ActPal+16+1          ; and so is colour 1 (hair /
                 sta   ActPal+16+9          ; outline). Other actors keep
                 sta   ActPal+16+14         ; their colours (the flying hat)
                 rep   #$20
                 mx    %00
:fine            rts

* Costume colours that the scripts only remap on one actor, or that
* vanish into the background (dream cloud, office carpet).
ApplicaPalCost   lda   IsZak
                 bne   :c_e
                 rts
:c_e             ldx   ActIdx
                 lda   ActElev,x
                 sta   TmpW2                ; 0: pointing alien, else the hat
                 lda   ActCost,x
                 sta   TmpW
                 txa
                 asl   a
                 asl   a
                 asl   a
                 tax
                 sep   #$20
                 mx    %10
                 lda   TmpW
                 cmp   #32
                 bne   :n32
                 lda   #0
                 sta   ActPal+1,x
                 sta   ActPal+9,x
                 sta   ActPal+14,x
                 bra   :zak1
:n32             cmp   #28              ; the two aliens: the suit is
                 beq   :nero28              ; colour 1 (and 6). DOS paints
                 cmp   #31                  ; both suits black. Leave 4,
                 bne   :zak1                ; 12 and 14: tie, cuff, skin.
* Costume 31 (flying hat): colour 1 = glasses band + stems. DOS paints
* it black (palette 0 is still drawn — file-0 alone is transparent).
* Keep pal[6]=6 (brim shading).
                 lda   #0
                 sta   ActPal+1,x
                 lda   #6
                 sta   ActPal+6,x
                 lda   #9
                 sta   ActPal+9,x
                 lda   #8
                 sta   ActPal+8,x
                 bra   :zak1
:nero28          lda   #0
                 sta   ActPal+1,x
                 sta   ActPal+6,x
:zak1            ldx   ActIdx
                 cpx   #2
                 bne   :8ok
                 lda   TmpW                 ; office blacks: costume 1, or 30
                 cmp   #1                   ; which the boot script uses with
                 beq   :nero                ; Color(9,0). Identity here made
                 cmp   #30                  ; the suit blue and ate the feet.
                 beq   :nero
                 cmp   #32
                 bne   :8ok
:nero            lda   #0
                 sta   ActPal+16+1
                 sta   ActPal+16+9
                 sta   ActPal+16+14
:8ok             rep   #$20
                 mx    %00
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
* V2 paints back to front by feet Y. Drawing in actor-number order left
* Sandy stuck on top of Dr Fred in the intro: he walked "behind" her.
DrawActors       lda   RoomH
                 bne   :c_e
                 rts
:c_e             stz   DrawSoloSporco
                 jsr   RiempiOrdine
                 jsr   OrdinaPerY
                 jmp   DisegnaOrdine

DrawAttoriSporchi lda  RoomH
                 bne   :c_e
                 rts
:c_e             lda   #1
                 sta   DrawSoloSporco
                 jsr   RiempiOrdine
                 jsr   OrdinaPerY
                 jmp   DisegnaOrdine

RiempiOrdine     stz   ActNOrd
                 ldx   #0
:lp              lda   ActCost,x
                 beq   :n
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :n
                 lda   ActVis,x
                 beq   :n
                 lda   DrawSoloSporco
                 beq   :add
                 lda   ActSporco,x
                 beq   :n
:add             ldy   ActNOrd
                 txa
                 sta   ActOrd,y
                 iny
                 iny
                 sty   ActNOrd
:n               inx
                 inx
                 cpx   #NACT*2
                 bcc   :lp
                 rts

* Insertion sort: smaller ActY first (further away), then actor number.
OrdinaPerY       lda   ActNOrd
                 cmp   #4
                 bcc   :fine
                 lda   #2
                 sta   OrdI
:outer           ldx   OrdI
                 lda   ActOrd,x
                 sta   OrdAct
                 tax
                 lda   ActY,x
                 sta   OrdY
                 lda   OrdI
                 sta   OrdJ
:inner           lda   OrdJ
                 beq   :place
                 tax
                 sec
                 sbc   #2
                 tay
                 lda   ActOrd,y
                 sta   OrdTmp
                 tax
                 lda   ActY,x
                 cmp   OrdY
                 beq   :place
                 bcc   :place
                 lda   OrdTmp
                 ldx   OrdJ
                 sta   ActOrd,x
                 sty   OrdJ
                 bra   :inner
:place           lda   OrdAct
                 ldx   OrdJ
                 sta   ActOrd,x
                 lda   OrdI
                 clc
                 adc   #2
                 sta   OrdI
                 cmp   ActNOrd
                 bcc   :outer
:fine            rts

DisegnaOrdine    ldx   #0
:lp              cpx   ActNOrd
                 bcs   :fine
                 lda   ActOrd,x
                 sta   ActIdx
                 phx
                 jsr   DrawActor
                 plx
                 inx
                 inx
                 bra   :lp
:fine            rts

*=======================================================================
* DrawActor - one character, limb by limb
*=======================================================================
* The walk box the actor stands on says whether any of the background
* passes in front of him: that is the box's mask byte, and it holds for
* the whole drawing.
DrawActor        rep   #$30
                 mx    %00
                 jsr   ApplicaPalCost
                 stz   MascAtt
                 stz   TvSoftMask
                 lda   NumBox
                 bne   :cisono
                 brl   :senza
:cisono          anop
* Zak room 49's box is the whole cloud with mask 3. Zak (costume
* 30) stands on the ground: without the mask he is drawn in front
* of the cross. Costume 31 (pointing alien and flying hat) must
* not use that plane: it ate the arm, and the same mask punched
* a black hole in the hat.
                 lda   IsZak
                 beq   :conmask
                 lda   CurRoom
                 cmp   #49
                 bne   :conmask
                 ldx   ActIdx
                 lda   ActCost,x
                 and   #$00FF
                 cmp   #31
                 bne   :conmask
                 brl   :senza
:conmask         lda   #1
                 sta   BoxLockOk
                 ldx   ActIdx
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 lda   IsZak
                 beq   :mmfoot
* Prefer ActBox when the feet are still inside it. Room 3 stairs box 0
* (mask 3) overlaps box 1 by one Y of slack: CasellaDelPunto alone kept
* mask 3 on the bottom step and left a doorway trail while walking down.
                 lda   ActBox,x
                 cmp   #$FFFF
                 beq   :mmfoot
                 cmp   NumBox
                 bcs   :mmfoot
                 jsr   DentroCasella
                 bcs   :mmfoot
                 ldx   ActIdx
                 lda   ActBox,x
                 bra   :gottmp
:mmfoot          jsr   CasellaDelPunto
:gottmp          stz   BoxLockOk
                 sta   TmpW
                 cmp   #$FFFF
                 bne   :trovata
                 ldx   ActIdx
                 lda   ActBox,x
                 bra   :hobox
* Living-room TV (room 2, locked box 4): Annie and Melissa (spacesuit)
* are putActor'd there and must keep mask 3. Zak walking past must NOT
* pick up that box from underfoot or he is drawn inside the set.
:trovata         lda   IsZak
                 beq   :usatmp
                 lda   CurRoom
                 cmp   #2
                 bne   :usatmp
                 ldx   ActIdx
                 lda   ActBox,x
                 cmp   #4
                 beq   :intv                ; stored TV box wins
                 lda   TmpW
                 cmp   #4
                 bne   :usatmp
                 lda   ActBox,x             ; underfoot is TV, actor is not
                 cmp   NumBox
                 bcc   :hobox
                 lda   #0
                 bra   :hobox
:intv                             lda   #4
                 jsr   CasellaN             ; glass = objs 114-116 @ (120,32)
                 lda   #28                  ; 64x32; hood peeks at ~y30
                 sta   TvSoftY1
                 lda   #64                  ; screen bottom (was 72: overdraw
                 sta   TvSoftY2             ; on the silver TV lip)
* CelPx is room space; do NOT add ScrollX.
                 lda   #112                 ; 120-8 slack
                 sta   TvSoftX1
                 lda   #192                 ; 120+64+8 slack
                 sta   TvSoftX2
                 lda   #1
                 sta   TvSoftMask
                 lda   #4
                 bra   :hobox
:usatmp          lda   TmpW
:hobox           sta   TmpW                 ; keep box number
* The box says whether the background covers this character. Stepping
* through a door or a window he is outside every box for a frame or two,
* and losing the box must not be read as "nothing covers him": the baker
* going back in through his window flashed over the bakery door that is
* supposed to hide him. Keep the mask he had until he stands somewhere
* again. ScummVM does the same by never letting a walkbox go invalid.
:domask          lda   TmpW
                 cmp   NumBox
                 bcc   :boxbuona
                 ldx   ActIdx
                 lda   ActMasc,x
                 sta   MascAtt
                 bra   :senza
:boxbuona        jsr   MascheraCasella
                 sta   MascAtt
                 ldx   ActIdx
                 sta   ActMasc,x

:senza           ldx   ActIdx
                 lda   ActCost,x
                 jsr   SlotCostume
                 bcc   :ok
                 rts
:ok              jsr   BaseCostume          ; zpStr = start of the costume
                 jsr   PreparaPalAttore
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
                 bne   :c_eframe
                 rts
:c_eframe        lda   LimbCmd
                 asl   a
                 clc
                 adc   FramePtr
                 tay
                 lda   [zpStr],y
                 sta   CelPtr

                 lda   CelPtr               ; a frame table that landed on
                 cmp   #12                  ; the header is not a picture
                 bcs   :c_eptr
                 rts
:c_eptr          cmp   #COSTLEN-12          ; nor is one past the slot
                 bcc   :c_eslot
                 rts
:c_eslot         ldy   CelPtr               ; sizes and offsets
                 lda   [zpStr],y
                 sta   CelW
                 bne   :c_ew
                 rts
:c_ew            cmp   #80                  ; a garbled limb is 200+ wide and
                 bcc   :c_ewok              ; paints the room with the costume
                 rts
:c_ewok          ldy   CelPtr
                 iny
                 iny
                 lda   [zpStr],y
                 sta   CelH
                 bne   :c_eh
                 rts
:c_eh            cmp   #100
                 bcc   :alta
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
* The anchor is the actor's x times eight: the cel's own xmove is added
* to it, and a mirrored cel is laid out backwards from the same anchor.
* Nothing is added on top of that. An earlier +8 (+16 facing left) broke
* the left/right pair out of mirror symmetry about the anchor and pushed
* Zak a whole strip to the right, which is what put him behind the room-3
* door jamb instead of in the opening.
                 ldx   ActIdx
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
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
                 pha
                 lda   IsZak
                 bne   :elev
                 pla
                 clc
                 adc   CelY
                 sta   CelY
                 bra   :gy
:elev            pla
                 sec
                 sbc   ActElev,x            ; setActorElevation, in pixels
                 clc
                 adc   CelY
                 sta   CelY
:gy              anop
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
* Zak costume 31 is the flying hat only (dream). Side view is 20x22:
* colour-1 glasses band on the crown (keep) + thin stems below the brim.
* The cel's row 15 is a solid colour-1 bar that reads as a black blob and
* swallows the stems — HatClip+HatRowSkip punch only that band (and any
* leftover gap fill), never the crown band on rows 9-11.
* Front/back hat is 18x22 (chin scrap only). Tiny 4x2 crumbs are dropped.
                 stz   HatClip
                 lda   IsZak
                 beq   :paint
                 ldx   ActIdx
                 lda   ActCost,x
                 and   #$00FF
                 cmp   #31
                 bne   :paint
                 lda   CelW
                 cmp   #20
                 beq   :w20
                 cmp   #18
                 beq   :cappello
                 lda   CelH                 ; 4x2 crumbs only
                 cmp   #3
                 bcs   :paint
                 rts
:w20             ldx   ActIdx               ; side face: clip stem-blob bar
                 lda   ActFace,x
                 cmp   #2
                 bcs   :paint
                 lda   #1
                 sta   HatClip
                 bra   :paint
:cappello        lda   #1                   ; 18x22: chin scrap via HatRowSkip
                 sta   HatClip
:paint           jsr   PaintCel
                 stz   HatClip
                 rts

*=======================================================================
* PaintCel - the compressed picture, column by column
*=======================================================================
* Same scheme as the backgrounds but with colour and run length in the
* same byte, and with colour zero meaning "transparent".
* The pending run must be cleared: it lasts to the end of the cel, no
* further.
PaintCel         stz   CelCol
                 stz   CelRun
                 lda   Vars+VO_LIGHTS
                 and   #8
                 sta   CelLit
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
* Colour 0 in the file is transparent. actorOps Color may paint a real
* colour as 0 (Zak's black suit): that pixel must still be drawn.
                 stz   CelSkip
                 lda   CelColor
                 beq   :era0
                 jsr   RemapColore
                 bra   :doporemap
:era0            lda   #1
                 sta   CelSkip
:doporemap       lda   CelLit
                 bne   :coloreok
                 lda   CelSkip
                 bne   :coloreok
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

:dentro          lda   CelH
                 sec
                 sbc   CelRow
                 bne   :ceriga
                 brl   :finecol
:ceriga          sta   RunNow
                 lda   CelRun
                 cmp   RunNow
                 bcs   :cap
                 sta   RunNow
:cap             lda   CelRun
                 sec
                 sbc   RunNow
                 sta   CelRun

                 lda   CelSkip
                 beq   :opaco
                 bra   :trasp
:opaco           lda   MascAtt
                 bne   :lento
:veloce          lda   CelPx
                 bmi   :trasp
                 cmp   RoomW
                 bcs   :trasp
                 jsr   CelRunFast
                 bra   :dopo
:lento           jsr   CelRunMask
                 bra   :dopo
:trasp           lda   CelRow
                 clc
                 adc   RunNow
                 sta   CelRow
:dopo            lda   CelRow
                 cmp   CelH
                 bcs   :finecol
                 brl   :pixel

:finecol         inc   CelCol
                 lda   CelCol
                 cmp   CelW
                 bcs   :fine
                 brl   :colonna
:fine            rts

* HatRowSkip - carry set: skip a hat pixel.
* Side face (0/1): skip remapped-black (costume 1→0) on rows 15-18,
* cols 7-14 — solid bar under the brim. Keeps crown glasses and stems.
* Front 18x22: skip only remapped-black on rows 18+ (chin scrap). Do NOT
* skip colour C/4 — that is the nose (rows 18-20); skipping all pixels
* there left a stub nose.
HatRowSkip       lda   HatClip
                 beq   :hno
                 ldx   ActIdx
                 lda   ActFace,x
                 cmp   #2
                 bcs   :front
* side: blob band
                 lda   CelColor
                 bne   :hno
                 lda   CelRow
                 cmp   #15
                 bcc   :hno
                 cmp   #19
                 bcs   :hno
                 lda   CelCol
                 cmp   #7
                 bcc   :hno
                 cmp   #15
                 bcs   :hno
                 bra   :hsi
:front           lda   CelW
                 cmp   #18
                 bne   :hno
                 lda   CelRow
                 cmp   #18
                 bcc   :hno
                 lda   CelColor             ; 0 = chin scrap after remap
                 bne   :hno                 ; keep nose (C, 4, …)
:hsi             sec
                 rts
:hno             clc
                 rts

* TvMaskPunch - carry clear: paint through walkbehind inside the TV glass.
* Only overrides a set mask bit; never skips pixels outside the rect.
TvMaskPunch      lda   TvColOk              ; the column was tested once, at
                 beq   :tno                 ; the top of CelRunMask
                 lda   SoftY
                 cmp   TvSoftY1
                 bcc   :tno
                 cmp   TvSoftY2
                 bcs   :tno
                 clc
                 rts
:tno             sec
                 rts

* CelRunFast - RunNow opaque pixels, no walk-box mask, CelPx on screen.
* Clip to the visible rows once. CelRow still advances by the full run
* (PaintCel has already eaten that many pixels from the stream). The
* pixel loop only writes; it does not use X as a counter.
CelRunFast       lda   CelRow
                 clc
                 adc   CelY
                 sta   CelRy
                 lda   CelPx
                 bmi   :tuttofuori
                 cmp   RoomW
                 bcs   :tuttofuori
                 lsr   a
                 sta   TmpW
                 lda   CelPx
                 and   #1
                 sta   Dispari
                 lda   CelColor
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW2
:skip            lda   RunNow
                 bne   :c_e
                 rts
:c_e             jsr   HatRowSkip
                 bcs   :salta
                 lda   CelRy
                 bmi   :salta
                 cmp   RoomH
                 bcs   :tuttofuori
                 cmp   #ROOMROWS
                 bcs   :tuttofuori
* HatClip needs a per-row re-check: a vertical colour-1 run that starts
* above the blob band would otherwise paint the whole run in :pronto.
                 lda   HatClip
                 bne   :uno
                 bra   :pronto
:salta           inc   CelRy
                 inc   CelRow
                 dec   RunNow
                 bra   :skip
:tuttofuori      lda   CelRow
                 clc
                 adc   RunNow
                 sta   CelRow
                 rts

:uno             lda   CelRy
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   TmpW
                 tay
                 lda   Dispari
                 bne   :unoB
                 sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$0F
                 ora   TmpW2
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
                 bra   :unoAv
:unoB            sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$F0
                 ora   CelColor
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
:unoAv           inc   CelRy
                 inc   CelRow
                 dec   RunNow
                 brl   :skip

:pronto          lda   RoomH
                 cmp   #ROOMROWS
                 bcc   :hok
                 lda   #ROOMROWS
:hok             sec
                 sbc   CelRy
                 beq   :resto
                 bcc   :resto
                 cmp   RunNow
                 bcc   :vis
                 lda   RunNow
:vis             sta   CelVis
                 lda   CelRy
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   TmpW
                 tay
                 lda   Dispari
                 bne   :lpbasso

:lpalto          sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$0F
                 ora   TmpW2
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
                 tya
                 clc
                 adc   Pitch
                 tay
                 dec   CelVis
                 bne   :lpalto
                 bra   :resto

:lpbasso         sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$F0
                 ora   CelColor
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
                 tya
                 clc
                 adc   Pitch
                 tay
                 dec   CelVis
                 bne   :lpbasso

:resto           lda   CelRow
                 clc
                 adc   RunNow
                 sta   CelRow
                 rts

* CelRunMask - same clip, then the walk-box bit (fence, furniture).
* The column's mask bit and nibble stay fixed; Dispari is not retested.
CelRunMask       lda   CelRow
                 clc
                 adc   CelY
                 sta   CelRy
                 lda   CelPx
                 bmi   :tuttofuori
                 cmp   RoomW
                 bcs   :tuttofuori
                 lsr   a
                 sta   TmpW
                 lda   CelPx
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   CelMcol
                 lda   CelPx
                 and   #7
                 asl   a
                 tax
                 lda   BitMasc,x
                 sta   CelMbit
                 lda   CelPx
                 and   #1
                 sta   Dispari
                 lda   CelColor
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW2
* The television punches a hole in the walkbehind inside the glass. Which
* column that is does not change down a run, so it is settled here once
* instead of twice for every masked pixel of everyone on the set.
                 stz   TvColOk
                 lda   TvSoftMask
                 beq   :tvfatto
                 lda   CelPx
                 cmp   TvSoftX1
                 bcc   :tvfatto
                 cmp   TvSoftX2
                 bcs   :tvfatto
                 lda   #1
                 sta   TvColOk
:tvfatto         anop
:skip            lda   RunNow
                 bne   :c_e
                 rts
:c_e             jsr   HatRowSkip
                 bcs   :salta
                 lda   CelRy
                 bmi   :salta
                 cmp   RoomH
                 bcs   :tuttofuori
                 cmp   #ROOMROWS
                 bcs   :tuttofuori
                 lda   HatClip
                 bne   :unoM
                 brl   :pronto
:salta           inc   CelRy
                 inc   CelRow
                 dec   RunNow
                 bra   :skip
:tuttofuori      lda   CelRow
                 clc
                 adc   RunNow
                 sta   CelRow
                 rts

* One pixel when HatClip (same reason as CelRunFast).
:unoM            lda   CelRy
                 sta   SoftY
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   TmpW
                 sta   PixOff
                 lda   MaskRow,x
                 clc
                 adc   CelMcol
                 sta   MskOff
                 lda   Dispari
                 bne   :unoMB
                 ldy   MskOff
                 lda   [zpMask],y
                 and   CelMbit
                 beq   :uAdraw
                 lda   TvColOk              ; the common case is "masked pixel,
                 beq   :uAav                ; skip it": no call for that
                 jsr   TvMaskPunch
                 bcs   :uAav
:uAdraw          ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$0F
                 ora   TmpW2
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
                 bra   :uAav
:unoMB           ldy   MskOff
                 lda   [zpMask],y
                 and   CelMbit
                 beq   :uBdraw
                 lda   TvColOk
                 beq   :uAav
                 jsr   TvMaskPunch
                 bcs   :uAav
:uBdraw          ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$F0
                 ora   CelColor
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
:uAav            inc   CelRy
                 inc   CelRow
                 dec   RunNow
                 brl   :skip

:pronto          lda   RoomH
                 cmp   #ROOMROWS
                 bcc   :hok
                 lda   #ROOMROWS
:hok             sec
                 sbc   CelRy
                 bne   :nz
                 brl   :resto
:nz              bcs   :cvis
                 brl   :resto
:cvis            cmp   RunNow
                 bcc   :vis
                 lda   RunNow
:vis             sta   CelVis
                 lda   CelRy
                 sta   SoftY
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   TmpW
                 sta   PixOff
                 lda   MaskRow,x
                 clc
                 adc   CelMcol
                 sta   MskOff
                 lda   Dispari
                 bne   :lpbasso

:lpalto          ldy   MskOff
                 lda   [zpMask],y
                 and   CelMbit
                 beq   :drawA
                 lda   TvColOk
                 beq   :sa
                 jsr   TvMaskPunch
                 bcs   :sa
:drawA           ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$0F
                 ora   TmpW2
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
:sa              lda   PixOff
                 clc
                 adc   Pitch
                 sta   PixOff
                 lda   MskOff
                 clc
                 adc   MaskPitch
                 sta   MskOff
                 inc   SoftY
                 dec   CelVis
                 bne   :lpalto
                 bra   :resto

:lpbasso         ldy   MskOff
                 lda   [zpMask],y
                 and   CelMbit
                 beq   :drawB
                 lda   TvColOk
                 beq   :sb
                 jsr   TvMaskPunch
                 bcs   :sb
:drawB           ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   [zpPix],y
                 and   #$F0
                 ora   CelColor
                 sta   [zpPix],y
                 rep   #$20
                 mx    %00
:sb              lda   PixOff
                 clc
                 adc   Pitch
                 sta   PixOff
                 lda   MskOff
                 clc
                 adc   MaskPitch
                 sta   MskOff
                 inc   SoftY
                 dec   CelVis
                 bne   :lpbasso

:resto           lda   CelRow
                 clc
                 adc   RunNow
                 sta   CelRow
                 rts

*=======================================================================
* ResetVM - variables to zero, no script alive
*=======================================================================
ResetVM          lda   #$FFFF               ; no room's mask is cached yet
                 sta   Masc0Room
                 ldx   #0
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
                 sta   ActElev,x
                 sta   ActFrame,x
                 sta   ActVis,x
                 lda   #2                   ; facing 0 is left, not "unset"
                 sta   ActFace,x
                 lda   #$FFFF
                 sta   ActBox,x
                 lda   #0
                 sta   ActMasc,x
                 lda   #0
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

                 ldx   #0
:obj             lda   ObjInit,x
                 sta   ObjFlag,x
                 inx
                 inx
                 cpx   #MAXOBJ
                 bcc   :obj
                 lda   #0
                 ldx   #0
:inv             sta   InvObj,x
                 inx
                 inx
                 cpx   #INVSLOTS*2
                 bcc   :inv
                 stz   SentN
                 stz   DiscoAperto

                 stz   CurRoom
                 stz   Redraw
                 stz   ActTutti
                 stz   VerbHoverLast
                 stz   SentHotLast
                 stz   InvHotLast
                 stz   HoverNow
                 stz   OvrPC
                 stz   CutLiv
                 lda   #$FFFF
                 sta   TxtYCache
                 lda   #80                  ; Zak's intro: the slow zoom and
                 sta   Vars+VO_MACHSPD      ; the long dream both want > 40
                 stz   CredVis
                 stz   CutIface
                 jsr   PalettaAttori
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
* TaciMsg - drop the line without StartAnim (ESC). SpegniMsg still
* closes the mouth: Maniac room changes need that.
TaciMsg          stz   ParlaOra
SpegniMsg        jsr   SmettiParlare
                 stz   MsgKeep
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

* $98 is o2_restart: no operands. Apple-8 asks first; the opcode does
* the same. After a yes the VM must not keep reading the old script:
* ResetVM has already killed this slot, but ExecSlot would still step.
hRestart         jsr   ChiediRestart
                 bcc   :no
                 lda   #1
                 sta   SlotFuori
:no              stz   Esito
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
* VAR_CAMERA_POS_X is in the same units as x, not in pixels, and the
* three scripts that read it all say so. Script 9 hands it straight back
* to setCameraAt, which multiplies by eight: that only stands still if
* the value was divided. Script 124 asks whether it equals 20, and 20 is
* half a screen - the leftmost the camera ever goes. And Edna's script
* 153 waits for 47, which in this kitchen is the sink, about where the
* counter ends: pass it and she notices you, with the width of the room
* still between you. In pixels 47 would be true before you had taken a
* step, and she would set off the moment you came through the door.
:uguale          lda   CamCur
                 lsr   a
                 lsr   a
                 lsr   a
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
                 lda   #CAM_FERMA           ; stop following, or the office
                 sta   CamMode              ; camera walks away with Zak
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
                 bcc   :okact
                 brl   :fine
:okact           stx   ActIdx
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
                 lda   AnimChore            ; V2: the chore is anim>>2, as-is
* Zak Melissa TV: animate 32 = chore 8. That turns L2 off and lights L6,
* the 32x19 hood/visor cel ScummVM shows (not chore 9's small helmet).
                 jsr   StartAnim
                 bra   :fine
:ferma           ldx   ActIdx
                 stz   ActMoving,x
                 jsr   FermaPose
                 bra   :fine
:verso           ldx   ActIdx
                 stz   ActMoving,x
* Zak Melissa on TV: chore 8 lights L6 (hood). Talking does StartAnim 4/5
* and overwrites ActFrame, so we must not key off ActFrame — look at L6's
* CostFrm. FermaPose would wipe the hood until the next animate 32.
                 lda   IsZak
                 beq   :vpose
                 lda   ActCost,x
                 and   #$00FF
                 cmp   #3
                 bne   :vpose
                 lda   #6
                 sta   LimbNo
                 jsr   LimbOff              ; X = limb-6 slot
                 lda   CostFrm,x
                 cmp   #$FFFF
                 beq   :vpose               ; hood not on
                 lsr   a
                 lsr   a
                 cmp   #8
                 bne   :vpose
                 lda   AnimDir
                 jsr   SetFacing
                 lda   #8
                 jsr   StartAnim
                 bra   :fine
:vpose           ldx   ActIdx
                 lda   AnimDir
                 sta   ActFace,x
                 jsr   FermaPose
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

AnimUno          rep   #$30
                 mx    %00
                 ldx   ActIdx
                 lda   ActMoving,x          ; leftover walk cycle: stand
                 bne   :okcam
                 lda   ActFrame,x
                 bne   :okcam
                 jsr   FermaPose
                 rts
:okcam           ldx   ActIdx
                 lda   ActCost,x            ; this costume's commands
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
                 jsr   SegnaAttore
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

:cammina         ldx   ActIdx
                 lda   ActX,x
                 sta   BoxNx                ; before the step, for a revert
                 lda   ActY,x
                 sta   BoxNy
                 lda   WalkDX               ; the sign and the absolute value
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

* If this step landed in a walk box, that box is where he is now.
* Zak: a Bresenham step through the air (window to the door, across
* the facade) is not a walk. Try one axis, then the other; if both
* leave the boxes, stay put and ask for another gate.
* Do not zero BoxLockOk: the baker is put on window box 9 ($A0) and
* walks (18,22)->(23,22) inside it. A step with lock=0 cannot see that
* box, RimettiInBox snaps him onto the sidewalk, and the costume is
* drawn down the facade.
:fatto           lda   IsZak
                 bne   :zakfatto
                 jmp   SegnaAttore          ; MM: no box rewrite mid-step
:zakfatto        jsr   LockSeInvis
                 ldx   ActIdx
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :inbox
* Floor walk (office pacing, stairs): a gap cell must not abort
* the trip. ProssimaTappa with ActUltima=1 is :finita, waitForActor
* returns at once, and object 671's 45<->74 loop only flips facing.
                 lda   BoxLockOk
                 beq   :resta
                 lda   WalkAX
                 beq   :soloy
                 ldx   ActIdx
                 lda   BoxNx
                 clc
                 adc   WalkSX
                 sta   ActX,x
                 lda   BoxNy
                 sta   ActY,x
                 sta   BoxQy
                 lda   ActX,x
                 sta   BoxQx
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :inbox
:soloy           lda   WalkAY
                 beq   :fuori
                 ldx   ActIdx
                 lda   BoxNx
                 sta   ActX,x
                 lda   BoxNy
                 clc
                 adc   WalkSY
                 sta   ActY,x
                 sta   BoxQy
                 lda   ActX,x
                 sta   BoxQx
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :inbox
:fuori           ldx   ActIdx
                 lda   BoxNx
                 sta   ActX,x
                 lda   BoxNy
                 sta   ActY,x
                 jsr   RimettiInBox
                 jsr   ProssimaTappa
                 jmp   SegnaAttore
:inbox           ldx   ActIdx
                 sta   ActBox,x
:resta           jmp   SegnaAttore

ArrivatoQui      ldx   ActIdx
                 lda   ActUltima,x          ; was it only a waypoint?
                 bne   :basta
                 jsr   ProssimaTappa
                 ldx   ActIdx
                 lda   ActMoving,x
                 beq   :basta
                 jsr   VersoCammino
                 jmp   SegnaAttore
:basta           ldx   ActIdx
                 stz   ActMoving,x
                 stz   ActErr,x
                 stz   ActUltima,x
                 jsr   FermaPose
                 rts
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
* A is the box number: must survive the IsZak test (pha). Without that,
* Zak always probed box 1 and Annie never sat in the locked TV box.
DentroCasella    pha
                 lda   IsZak
                 bne   :zak
                 pla
                 jsr   CasellaN
                 lda   BoxQy
                 cmp   BoxUy
                 bcc   :nomm
                 lda   BoxLy
                 cmp   BoxQy
                 bcc   :nomm
                 jsr   LatiACasella
                 lda   BoxQx
                 cmp   BoxSx
                 bcc   :nomm
                 lda   BoxDx
                 cmp   BoxQx
                 bcc   :nomm
                 clc
                 rts
:nomm            sec
                 rts
:zak             pla
                 jsr   CasellaN
                 ldy   BoxPtr               ; bit 7 = invisible (TV / window).
                 iny                        ; Locked ($40) still counts as
                 iny                        ; inside: ScummVM only blocks
                 iny                        ; walking *into* it (ProssimaTappa).
                 iny
                 iny
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$0080
                 beq   :sbloccata
                 lda   BoxLockOk            ; 0: skip locked (walk)
                 beq   :no
                 bra   :aperto              ; 1 or 2: locked matches
:sbloccata       lda   BoxLockOk
                 cmp   #2                   ; 2: only locked (Annie)
                 beq   :no
:aperto          anop
                 lda   BoxQy                ; one cell of slack above and on
                 inc   a                    ; the sides: the door, the card
                 cmp   BoxUy                ; and the rug sit on the edge.
                 bcc   :no                  ; No slack below: room 3 stairs
                 lda   BoxLy                ; box0 (mask 3) must not keep the
                 cmp   BoxQy                ; feet at y=Ly+1, or the doorway
                 bcc   :no                  ; trails while walking down.
                 jsr   LatiACasella
                 lda   BoxQx
                 inc   a
                 cmp   BoxSx
                 bcc   :no
                 lda   BoxDx
                 inc   a
                 cmp   BoxQx
                 bcc   :no
                 clc
                 rts
:no              sec
                 rts

* If he is standing in a hole between boxes (Zak's desk), put him
* back on the nearest walkable point so getDist is not forever > 2.
RimettiInBox     ldx   ActIdx
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 beq   :fuori
                 rts
:fuori           jsr   AvvicinaPunto
                 lda   BoxScelta
                 cmp   #$FFFF
                 bne   :ok
                 rts
:ok              ldx   ActIdx
                 lda   BoxQx
                 sta   ActX,x
                 lda   BoxQy
                 sta   ActY,x
                 lda   BoxScelta
                 sta   ActBox,x
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
:cerca           lda   IsZak
                 beq   :misura              ; MM: every box, as before
                 lda   BoxI
                 jsr   CasellaN
                 ldy   BoxPtr               ; bit 7: invisible (room 3 window,
                 iny                        ; TV). Walking must not snap onto
                 iny                        ; it: the matrix then flies down
                 iny                        ; the facade instead of the stairs.
                 iny                        ; Locked ($40) is fine to snap to;
                 iny                        ; ProssimaTappa refuses to enter.
                 iny
                 iny
                 lda   [zpRaw],y
                 and   #$0080
                 beq   :sbloccata
                 lda   BoxLockOk
                 beq   :prossima
                 bra   :misura
:sbloccata       lda   BoxLockOk
                 cmp   #2
                 beq   :prossima
:misura          lda   BoxI
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

* The box the actor occupies. Walk never assigns locked boxes.
* In Zak a putActor onto a locked box (Annie / Melissa in the TV) must
* keep that box, or they are drawn in front of the set. Maniac
* only looks at walkable boxes.
* Zak putActor can land one cell past a flat box (phone clerk at
* (22,52) vs box 3 at y=50): ScummVM's adjustActorPos snaps onto the
* nearest box so the mask keeps him behind the counter. Without that
* ActBox stays $FFFF and he is drawn in front.
AssegnaCasella   ldx   ActIdx
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :niente
                 lda   NumBox
                 beq   :niente
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 lda   IsZak
                 beq   :walk
                 lda   #2
                 sta   BoxLockOk
                 jsr   CasellaDelPunto
                 stz   BoxLockOk
                 cmp   #$FFFF
                 bne   :ok
:walk            jsr   CasellaDelPunto
:ok              ldx   ActIdx
                 sta   ActBox,x
                 cmp   #$FFFF
                 bne   :niente
                 lda   IsZak
                 beq   :niente
                 jsr   RimettiInBox
:niente          rts

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
* If he already stands on a locked/invisible box (putActor: baker in
* the window, Annie in the TV), walking must keep that box. Snapping
* it to the sidewalk sent the baker out of his box and made the room-3
* matrix fly down the facade. Other walks still skip bit-7 boxes.
LockSeInvis      stz   BoxLockOk
                 ldx   ActIdx
                 lda   ActBox,x
                 cmp   #$FFFF
                 beq   :no
                 cmp   NumBox
                 bcs   :no
                 jsr   CasellaN
                 lda   BoxPtr
                 clc
                 adc   #7
                 tay
                 lda   [zpRaw],y
                 and   #$0080               ; invisible only (baker / TV)
                 beq   :no
                 lda   #1
                 sta   BoxLockOk
:no              rts

AvviaCamminoQui  lda   IsZak
                 bne   :zak
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
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 jsr   CasellaDelPunto
                 cmp   #$FFFF
                 bne   :mmbox
                 jsr   AvvicinaPunto
                 lda   BoxScelta
:mmbox           ldx   ActIdx
                 sta   ActBox,x
                 stz   ActUltima,x
                 stz   ActErr,x
                 lda   #1
                 sta   ActMoving,x
                 jsr   ProssimaTappa
                 ldx   ActIdx
                 lda   ActMoving,x
                 beq   :mmfine
                 lda   ActDstX,x
                 cmp   ActX,x
                 bne   :mmcam
                 lda   ActDstY,x
                 cmp   ActY,x
                 bne   :mmcam
                 jmp   ArrivatoQui
:mmcam           jsr   VersoCammino
                 lda   #0
                 jsr   StartAnim
:mmfine          rts
:zak             jsr   LockSeInvis
                 lda   ActArg
                 sta   BoxQx
                 lda   ActArg2
                 sta   BoxQy
                 jsr   AvvicinaPunto
                 ldx   ActIdx
                 lda   ActArg
                 sec
                 sbc   BoxQx
                 bpl   :dax
                 eor   #$FFFF
                 inc   a
:dax             sta   WalkAX
                 lda   ActArg2
                 sec
                 sbc   BoxQy
                 bpl   :day
                 eor   #$FFFF
                 inc   a
:day             cmp   WalkAX
                 bcs   :dmag
                 lda   WalkAX
:dmag            cmp   #2
                 bcs   :usasnapp
                 lda   ActArg
                 sta   BoxQx
                 lda   ActArg2
                 sta   BoxQy
:usasnapp        ldx   ActIdx
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
                 ldx   ActIdx               ; and stand on it, or every walk
                 lda   BoxQx                ; from a gap (the desk in room 1)
                 sta   ActX,x               ; starts and ends on the same
                 lda   BoxQy                ; snapped point and never moves.
                 sta   ActY,x
                 lda   BoxScelta
:hocasella       ldx   ActIdx
                 sta   ActBox,x
                 stz   ActUltima,x
                 stz   ActErr,x
                 stz   ActStuck,x
                 lda   #1
                 sta   ActMoving,x
                 jsr   ProssimaTappa
                 ldx   ActIdx
                 lda   ActMoving,x
                 beq   :fine
                 lda   ActDstX,x            ; already there: do not start
                 cmp   ActX,x               ; the walk cycle on the spot
                 bne   :cammina
                 lda   ActDstY,x
                 cmp   ActY,x
                 bne   :cammina
                 jmp   ArrivatoQui
:cammina         jsr   VersoCammino
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
ProssimaTappa    lda   IsZak
                 beq   :mm
                 brl   :zak
:mm              ldx   ActIdx
                 lda   ActUltima,x
                 beq   :mmav
                 brl   :finita
:mmav            lda   ActBoxFin,x
                 cmp   #$FFFF
                 bne   :mmfinok
                 brl   :dritto
:mmfinok         cmp   ActBox,x
                 bne   :mmpath
                 brl   :dritto
:mmpath          sta   BoxA
                 lda   ActBox,x
                 sta   BoxDa
                 jsr   ProssimaCasella
                 cmp   #$FFFF
                 bne   :mmprox
                 brl   :dritto
:mmprox          sta   BoxProx
                 ldx   ActIdx
                 lda   ActX,x
                 sta   BoxQx
                 lda   ActY,x
                 sta   BoxQy
                 lda   BoxProx
                 jsr   PuntoNellaCasella
                 lda   BoxCx
                 sta   BoxQx
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
                 lda   BoxProx              ; MM: already across, as before
                 sta   ActBox,x
                 stz   ActErr,x
:mmctrl          ldx   ActIdx
                 lda   ActDstX,x
                 cmp   ActX,x
                 beq   :mmy
                 brl   :muovi
:mmy             lda   ActDstY,x
                 cmp   ActY,x
                 beq   :mmult
                 brl   :muovi
:mmult           lda   ActUltima,x
                 beq   :mmagain
                 brl   :finita
:mmagain         brl   :dritto
:zak             ldx   ActIdx
                 lda   ActBox,x
                 cmp   #$FFFF
                 bne   :c_box
                 jsr   RimettiInBox
:c_box           ldx   ActIdx
                 lda   ActUltima,x
                 beq   :avanti
                 brl   :finita
:avanti          lda   ActBoxFin,x
                 cmp   #$FFFF
                 bne   :finok
                 brl   :dritto
:finok           cmp   ActBox,x
                 bne   :path
                 brl   :dritto
:path            sta   BoxA
                 lda   ActBox,x
                 sta   BoxDa
                 jsr   ProssimaCasella
                 cmp   #$FFFF
                 bne   :c_prox
                 brl   :dritto              ; no matrix: walk straight
:c_prox          sta   BoxProx
* ScummVM Actor_v2: cannot walk into a kBoxLocked ($40) box
* (phone-company counter door = room 4 box 2). Stop here.
                 jsr   CasellaN
                 lda   BoxPtr
                 clc
                 adc   #7
                 tay
                 lda   [zpRaw],y
                 and   #$0040
                 beq   :okprox
                 ldx   ActIdx               ; stop at the gate, do not enter
                 stz   ActMoving,x
                 stz   ActUltima,x
                 stz   ActErr,x
                 jsr   FermaPose
                 rts
:okprox          ldx   ActIdx
                 lda   BoxProx
                 cmp   ActBox,x             ; "stay in this box": go to
                 bne   :gate                ; the goal, do not spin here
                 brl   :dritto
:gate            ldx   ActIdx               ; the point of the next
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
                 lda   BoxProx              ; already in the next box, as MM
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
                 brl   :dritto
:finita          ldx   ActIdx
                 stz   ActMoving,x
                 rts
:muovi           lda   #1
                 sta   ActMoving,x
                 rts

*=======================================================================
* hWaitActor ($3B) - wait until he has finished walking
*=======================================================================
* ActDst is the current gate, not the walk point. Script 2 calls this
* every frame, and MainLoop runs scripts BEFORE MoveActors. The frame
* he steps onto a gate, dest==pos but ProssimaTappa has not run yet:
* treating that as "arrived" stopped him in the bedroom one box short
* of the door (30,55 instead of 35,56). Wait on ActMoving only.
hWaitActor       jsr   VOB1
                 jsr   ActIndex
                 bcs   :libero
                 lda   ActMoving,x
                 beq   :libero
                 lda   IsZak
                 beq   :aspetta
                 lda   ActRoom,x            ; Zak: left the room, he is done
                 cmp   CurRoom
                 beq   :aspetta
                 stz   ActMoving,x
                 bra   :libero
:aspetta         dec   PC                   ; put the opcode back and
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
:cerca           lda   MsgText,x            ; last letter of a word has $80
                 and   #$007F
                 cmp   #'I'
                 bne   :avanti
                 lda   MsgText+1,x
                 and   #$007F
                 cmp   #'B'
                 bne   :avanti
                 lda   MsgText+2,x
                 and   #$007F
                 cmp   #'M'
                 beq   :ibm
:avanti          inx
                 cpx   #MSGMAX-3
                 bcc   :cerca
                 ldx   #0
:cerca2          lda   MsgText,x            ; only the music names
                 and   #$007F               ; ("... Hayes, & Dave Warhol")
                 cmp   #'H'                 ; "Kane" also sits on the
                 bne   :av2                 ; design and program lines
                 lda   MsgText+1,x
                 and   #$007F
                 cmp   #'a'
                 bne   :av2
                 lda   MsgText+2,x
                 and   #$007F
                 cmp   #'y'
                 beq   :nomi
:av2             inx
                 cpx   #MSGMAX-3
                 bcc   :cerca2
                 rts

:ibm             lda   #MsgIIGS
                 sta   zpStr
                 lda   #^MsgIIGS
                 sta   zpStr+2
                 jmp   CopiaMsg

:nomi            lda   #MsgMusica
                 sta   zpStr
                 lda   #^MsgMusica
                 sta   zpStr+2
                 jmp   CopiaMsg

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

RidisegnaAttori  rep   #$30
                 mx    %00
                 lda   RoomH
                 bne   :c_e
                 rts
:c_e             lda   ActDirty
                 bne   :lavoro
                 rts

* Two passes. In the first, dirty characters (and anyone whose box
* touches theirs) are erased from where they were. Then only those are
* redrawn. Idle people on the other side of the room stay in the buffer.
:lavoro          lda   ActTutti
                 beq   :pochi
                 jsr   MarcaTuttiAttori
                 bra   :via
:pochi           jsr   EspandiAttori
:via             stz   ActDirty
                 stz   ActTutti
                 stz   ActIdx
:pulisci         jsr   AttoreInScena
                 bcs   :pross1
                 ldx   ActIdx
                 lda   ActSporco,x
                 beq   :pross1
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

                 jsr   DrawAttoriSporchi

                 stz   ActIdx
:segna           jsr   AttoreInScena
                 bcs   :pross2
                 ldx   ActIdx
                 lda   ActSporco,x
                 beq   :pulito
                 jsr   ScatolaVecchia
                 bcs   :pulito
                 jsr   SegnaRett
:pulito          ldx   ActIdx
                 stz   ActSporco,x
:pross2          lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :segna
                 rts

*=======================================================================
* SegnaAttore - this actor's picture changed
*=======================================================================
SegnaAttore      ldx   ActIdx
                 lda   #1
                 sta   ActSporco,x
                 sta   ActDirty
                 rts

MarcaTuttiAttori lda   ActIdx
                 pha
                 stz   ActIdx
:lp              jsr   AttoreInScena
                 bcs   :avanti
                 ldx   ActIdx
                 lda   #1
                 sta   ActSporco,x
:avanti          lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 pla
                 sta   ActIdx
                 rts

* Two passes: a dirty walker must also refresh whoever he walks onto
* (new feet) and whoever he leaves (old box).
EspandiAttori    lda   #2
                 sta   EspandiN
:pass            lda   ActIdx
                 pha
                 stz   ActIdx
:lp              jsr   AttoreInScena
                 bcs   :avanti
                 ldx   ActIdx
                 lda   ActSporco,x
                 beq   :avanti
                 jsr   ScatolaVecchia
                 bcs   :piedi
                 jsr   CopiaDstAgg
                 jsr   MarcaToccatiDaAgg
:piedi           jsr   ScatolaPiedi
                 bcs   :avanti
                 jsr   CopiaDstAgg
                 jsr   MarcaToccatiDaAgg
:avanti          lda   ActIdx
                 clc
                 adc   #2
                 sta   ActIdx
                 cmp   #NACT*2
                 bcc   :lp
                 pla
                 sta   ActIdx
                 dec   EspandiN
                 bne   :pass
                 rts

CopiaDstAgg      lda   DstX
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
                 rts

* Both boxes, for the same reason as MarcaToccatiTutti: the box he was
* last drawn in and the one he stands in now. Asking only the old one
* misses whoever has moved since, and the piece of him that the walker's
* cleanup just rubbed out is never put back.
MarcaToccatiDaAgg lda  ActIdx
                 sta   TmpAct
                 stz   ActScan
:lp              lda   ActScan
                 cmp   TmpAct
                 beq   :avanti
                 sta   ActIdx
                 jsr   AttoreInScena
                 bcs   :avanti
                 jsr   ScatolaVecchia
                 bcs   :piedi
                 jsr   IntersecaAgg
                 bcc   :segna
:piedi           jsr   ScatolaPiedi
                 bcs   :avanti
                 jsr   IntersecaAgg
                 bcs   :avanti
:segna           ldx   ActScan
                 lda   #1
                 sta   ActSporco,x
:avanti          lda   ActScan
                 clc
                 adc   #2
                 sta   ActScan
                 cmp   #NACT*2
                 bcc   :lp
                 lda   TmpAct
                 sta   ActIdx
                 rts

* Like MarcaToccatiDaAgg but with nobody left out: for a piece of room
* that changed on its own (an object lighting up), not for a character
* who moved.
* Both boxes have to be asked about: the one he was last drawn in and the
* one he stands in now. A character who has moved since the last frame
* has a stale old box, and if only that is tested the piece of him the
* object's square just rubbed out is never put back - a shoulder, the
* neck under a head. Whoever walks is exactly the one who needs it.
MarcaToccatiTutti lda  ActIdx
                 pha
                 stz   ActScan
:lp              lda   ActScan
                 sta   ActIdx
                 jsr   AttoreInScena
                 bcs   :avanti
                 jsr   ScatolaVecchia
                 bcs   :piedi
                 jsr   IntersecaAgg
                 bcc   :segna
:piedi           jsr   ScatolaPiedi
                 bcs   :avanti
                 jsr   IntersecaAgg
                 bcs   :avanti
:segna           ldx   ActScan
                 lda   #1
                 sta   ActSporco,x
:avanti          lda   ActScan
                 clc
                 adc   #2
                 sta   ActScan
                 cmp   #NACT*2
                 bcc   :lp
                 pla
                 sta   ActIdx
                 rts

* Carry set if Dst rectangle misses Agg.
IntersecaAgg     lda   DstX
                 cmp   AggR
                 bcs   :no
                 lda   DstX
                 clc
                 adc   BlkW
                 cmp   AggX
                 beq   :no
                 bcc   :no
                 lda   DstY
                 cmp   AggB
                 bcs   :no
                 lda   DstY
                 clc
                 adc   BlkH
                 cmp   AggY
                 beq   :no
                 bcc   :no
                 clc
                 rts
:no              sec
                 rts

*=======================================================================
* CancellaAttore - rub character ActIdx off the room he is in
*=======================================================================
* The same two steps the redrawing pass uses for somebody who has moved:
* the background and the objects go back over the box he last occupied,
* and that box is marked so it reaches the screen. Then the box is
* emptied, so nothing tries to clean it a second time.
CancellaAttore   lda   ActVis,x
                 bne   :c_e
                 rts
:c_e             jsr   ScatolaVecchia
                 bcc   :c_ebox
                 rts
:c_ebox          jsr   PuliscoRett
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
                 ldx   ActIdx               ; nothing left to clean here
                 lda   #0
                 sta   ActBX1,x
                 sta   ActBX2,x
                 sta   ActBY1,x
                 sta   ActBY2,x
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
SPRW             =     88             ; the whole body, not just the feet
SPRH             =     120            ; a 176-wide box redrew the room
*                                     ; and the pointer blinked

ScatolaVecchia   ldx   ActIdx
                 lda   ActBX2,x
                 sec
                 sbc   ActBX1,x
                 beq   :grande
                 bmi   :grande
                 sta   BlkW
                 cmp   #200                 ; a bad limb must not dirty
                 bcs   :grande              ; the whole room
                 lda   ActBY2,x
                 sec
                 sbc   ActBY1,x
                 beq   :grande
                 bmi   :grande
                 sta   BlkH
                 cmp   #200
                 bcs   :grande
                 lda   ActBX1,x
                 sta   DstX
                 lda   ActBY1,x
                 sta   DstY
                 jmp   GonfiaScatola

:grande          jmp   ScatolaPiedi
:vuota           sec
                 rts

ScatolaPiedi     ldx   ActIdx
                 lda   ActX,x
                 asl   a
                 asl   a
                 asl   a
                 sec
                 sbc   #40
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
                 pha
                 lda   IsZak
                 beq   :noelev
                 pla
                 sec
                 sbc   ActElev,x            ; he may be in the air
                 pha
:noelev          pla
                 sec
                 sbc   #104
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

* A walk step is eight pixels, and the next frame's arm sticks out
* past the box we measured. Grow it or the old picture stays behind.
GonfiaScatola    lda   DstX
                 sec
                 sbc   #8
                 bpl   :sx
                 lda   #0
:sx              and   #$FFFC
                 sta   DstX
                 lda   BlkW
                 clc
                 adc   #16
                 sta   BlkW
                 lda   DstX
                 clc
                 adc   BlkW
                 cmp   RoomW
                 bcc   :dxok
                 lda   RoomW
                 sec
                 sbc   DstX
                 sta   BlkW
:dxok            lda   DstY
                 sec
                 sbc   #8
                 bpl   :su
                 lda   #0
:su              sta   DstY
                 lda   BlkH
                 clc
                 adc   #16
                 sta   BlkH
                 lda   DstY
                 clc
                 adc   BlkH
                 cmp   #ROOMROWS
                 bcc   :ok
                 lda   #ROOMROWS
                 sec
                 sbc   DstY
                 sta   BlkH
:ok              lda   BlkW
                 beq   :vuota
                 bmi   :vuota
                 lda   BlkH
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
hCutscene        lda   IsZak
                 beq   :mm
                 inc   CutLiv
                 lda   UserIface
                 sta   CutIface
:mm              lda   Vars+VO_CURSOR
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

hEndCut          lda   IsZak
                 beq   :gia
                 lda   CutLiv
                 beq   :gia
                 dec   CutLiv
:gia             stz   OvrPC
                 lda   CutCam
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
                 lda   IsZak
                 beq   :nienteui
                 lda   CutIface
                 bne   :iface
                 lda   #$00E0
:iface           sta   UserIface
:nienteui        lda   #1
                 sta   Redraw
                 sta   PanDirty
                 sta   VerbsDirty
* On entering the disk screen the game deletes the verb panel to make
* room for the list of saved games, and on the way out it does not
* rebuild it: in the original interpreter the "user state" handling took
* care of that, and I have none. ScrVerbi is 164 (Maniac) or 19 (Zak).
* Zak room 50's exit also starts 19; starting it here covers Cancel paths
* where the camera was already following and FollowCamera left via ego.
                 lda   DiscoAperto
                 beq   :niente
                 stz   DiscoAperto
                 lda   ScrVerbi
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
hOverride        stz   Vars+VO_OVERRIDE     ; not skipped, until ESC
                 lda   PC
                 sta   OvrPC
                 lda   CurSlot
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
*=======================================================================
* hStartScript ($42) - startScript: and it runs at once
*=======================================================================
* Not on the next frame: runScript ends with runScriptNested, so the
* script that has just been started runs here and now, until it stops or
* asks to wait, and only then does the one that started it carry on.
* Waiting for the next frame put everything half a beat out of step.
* Script 37 is where it showed: it sets Var[109], starts script 146 to
* turn it into a place in the cell, and two instructions later puts the
* captured kid at that place - which was still the previous one, so he
* landed in the far corner instead of next to Edna.
hStartScript     jsr   VOB1
                 jsr   StartScript
                 bcs   :fine
                 lda   SlotIdx
                 sta   NestSlot
                 jsr   GiraSubito
:fine            stz   Esito
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
                 jsr   FetchB               ; Color(index, colour)
                 sta   ActArg2
                 lda   ActNo
                 jsr   ActIndex
                 bcc   :colok
                 brl   :fine
:colok           stx   ActIdx
                 lda   ActArg2              ; Color(index, colour): index
                 and   #$000F               ; is the extra byte, colour is
                 sta   TmpW                 ; PARAM_2 (same as ScummVM)
                 txa
                 asl   a
                 asl   a
                 asl   a                    ; actor*16
                 clc
                 adc   TmpW
                 tax
                 sep   #$20
                 mx    %10
                 lda   ActArg
                 sta   ActPal,x
                 rep   #$20
                 mx    %00
                 jsr   SegnaAttore
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
                 brl   :fine
:saltanome       jsr   SkipStrZero
                 brl   :fine
:costume         cmp   #4
                 beq   :costc_e
                 brl   :voce
:costc_e         lda   ActNo                ; it is the costume: note it
                 jsr   ActIndex
                 bcc   :costidx
                 brl   :fine
:costidx         lda   ActArg
                 sta   ActCost,x
                 stx   ActIdx
                 jsr   ResetLimbs           ; old chore must not keep its
                 ldx   ActIdx               ; limbs: costume 31 leftovers
                 phx                        ; on 17 painted a strip in the door
                 jsr   ResetPalUno          ; V2: a new costume resets 0..15
                 lda   IsZak
                 beq   :costx
                 jsr   ApplicaPalCost
:costx           plx
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
                 stx   ActIdx
                 lda   ActArg
                 sta   ActX,x
                 lda   ActArg2
                 sta   ActY,x
                 lda   IsZak
                 beq   :mostra
                 lda   ActMoving,x          ; putActor stops a walk: the
                 beq   :giafermo            ; cycle has to stand too, or
                 stz   ActMoving,x          ; he keeps marching in place
                 jsr   FermaPose
                 bra   :messo
:giafermo        stz   ActMoving,x
:messo           stz   ActElev,x
                 jsr   AssegnaCasella
:mostra          jsr   MostraUno
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

*=======================================================================
* hPutInRoom ($2D) - putActorInRoom: a character changes room
*=======================================================================
* Taking somebody out of the room he is standing in means rubbing him
* off the picture first. The erasing pass only looks at characters whose
* room is this one, so once the room number has changed nobody ever
* cleans up after him and what was drawn stays there for good: at the end
* of Edna's cutscene the doctor left his feet on the floor of the cell.
hPutInRoom       jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 stx   ActIdx
                 lda   ActRoom,x            ; where he is leaving from
                 cmp   CurRoom
                 bne   :nonquesta
                 lda   ActArg
                 cmp   CurRoom
                 beq   :nonquesta           ; he is not really leaving
                 jsr   CancellaAttore
* And the whole window goes to the screen, exactly as it does below when
* somebody arrives. Rubbing him out of the buffer works - that much is
* measured, the buffer is clean on the next frame - but leaving it to the
* piece-by-piece path left the baker on screen beside his window after
* going back in. Somebody leaving the room is a rare event and the same
* kind of event as somebody arriving; the comment below says why that one
* is not trusted to a rectangle either.
                 lda   #1
                 sta   Redraw
:nonquesta       ldx   ActIdx
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
*=======================================================================
* hCursor ($60) - cursorCommand: the pointer, and what the panel shows
*=======================================================================
* One word with two halves. The low byte is the cursor mode the game
* keeps in variable 21 and looks at to know where it is (3 = the opening
* screen). The high byte is setUserState, and it was being thrown away:
*
*   $01 act on the freeze  $08 and freeze if set
*   $02 act on the cursor  $10 and show it if set
*   $04 act on the panel   $20 sentence  $40 inventory  $80 verbs
*
* The three panel bits are the whole state, not a change: what is not
* named is turned off. That is how the save screen hides the inventory
* and the sentence line and leaves only its own ten verbs - it asks for
* $9F, and the inventory bit is not in it. Freezing is left alone: the
* cutscene opcodes already take care of that here.
hCursor          jsr   VOW1
                 sta   TmpW
                 and   #$00FF
                 beq   :nientecur
                 sta   Vars+VO_CURSOR
:nientecur       lda   TmpW
                 xba                        ; the high half
                 and   #$00FF
                 sta   UserSt
                 and   #$0004               ; is it speaking about the panel?
                 beq   :fine
                 lda   UserSt
                 and   #$00E0
                 cmp   UserIface
                 beq   :fine                ; nothing changed
                 sta   UserIface
                 jsr   PuliscoPan           ; away with what was there, then
                 lda   #1                   ; whatever is on comes back
                 sta   PanDirty
                 sta   VerbsDirty
                 sta   InvDirty
:fine            stz   Esito
                 rts

*=======================================================================
* PuliscoPan - blank the whole panel
*=======================================================================
PuliscoPan       _HideCursor
                 lda   #SENTTOP*SCRW
                 sta   FillStart
                 lda   #DBGTOP*SCRW
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 _ShowCursor
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
* Code 1 is the line break. '^' is not a terminator: V2's EGA font draws
* an ellipsis in that slot, one character wide (Dave's opening "....").
* Code 2 keeps the text: the next print carries on after it, as Zak's
* "Later that night, Zak's in bed... alone... again." is built.
CatchStr         stz   MsgLen
                 stz   MsgDa
                 lda   MsgKeep
                 beq   :lp
                 stz   MsgKeep
                 ldx   #0
:coda            lda   MsgText,x
                 and   #$00FF
                 beq   :incoda
                 inx
                 cpx   #MSGMAX
                 bcc   :coda
:incoda          stx   MsgLen
                 stx   MsgDa
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
:noncapo         cmp   #2
                 bne   :noncont
                 lda   #1                   ; 2: the next print goes on from here
                 sta   MsgKeep
                 bra   :noacapo
:noncont         cmp   #3
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
                 ldy   PC                   ; bit 7 is "space follows",
                 lda   [zpCode],y           ; except before a control code
                 and   #$007F               ; or the end of the string:
                 cmp   #8                   ; that extra space made Annie's
                 bcc   :lp                  ; TV lines 41 characters and
                 lda   #' '                 ; they ran off the screen.
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
                 lda   MsgDa                ; carrying on: same page
                 bne   :stessapag
                 stz   MsgPag               ; start from the first page
:stessapag       lda   MsgDopo              ; if another follows, this one
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
                 lda   MsgLen
                 sec
                 sbc   MsgDa
                 clc
                 adc   Vars+VO_CHARCNT
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
GiraSubito       lda   NestLiv              ; a script that keeps starting
                 cmp   #8                   ; scripts must not eat the stack
                 bcc   :c_eposto
                 rts
:c_eposto        inc   NestLiv

                 lda   CurSlot              ; put aside the one running
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
                 ldx   CurSlot              ; and who he was, to tell later
                 lda   SlotNum,x            ; whether he is still there
                 pha
                 lda   SlotWhere,x
                 pha
                 lda   PC                   ; his place in the code goes back
                 sta   SlotPC,x             ; into the slot, as updateScriptPtr

                 stz   SlotFuori
                 lda   NestSlot
                 jsr   ExecSlot

                 pla
                 sta   NestWhere
                 pla
                 sta   NestNum
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
                 dec   NestLiv

* runScriptNested picks the caller up again only if his slot still holds
* the same script and it is still alive: the script we just ran may have
* stopped him, or taken his slot for something else. Carrying on in his
* place would then run whatever landed there.
                 ldx   CurSlot
                 lda   SlotStat,x
                 beq   :sparito
                 lda   SlotNum,x
                 cmp   NestNum
                 bne   :sparito
                 lda   SlotWhere,x
                 cmp   NestWhere
                 bne   :sparito
                 rts
:sparito         lda   #1
                 sta   SlotFuori
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
                 bne   :hasimg
                 brl   :esci
:hasimg          anop

* A hundred and seventy-one objects in the game have no picture of their
* own: the easel and the crate in the studio, the stairs, the things
* that are simply painted into the background. Their entry in the
* picture table is not zero, as one would hope - it points at where the
* descriptions begin, just past the last real picture. Decoding from
* there reads the descriptions as if they were pixels, and since an
* object lays its own mask down as well, it sprays the mask plane with
* nonsense: whoever walks past comes out full of holes. So: a picture
* that does not begin before the descriptions is not a picture.
                 lda   ObjImgOff            ; ObjConfine: set by DecodeRoom
                 cmp   ObjConfine
                 bcc   :inconfine
                 brl   :esci
:inconfine       anop

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
                 bne   :hasw
                 brl   :esci
:hasw            lda   ObjCd
                 clc
                 adc   #13
                 tay
                 lda   [zpRaw],y
                 and   #$00F8
                 sta   BlkH
                 bne   :hash
                 brl   :esci
:hash            anop

* Room 3 stairs (#134) shares door #135's OBIM but claims 56x80; decoding
* that many strips runs off the real 48x64 phone-office image and paints
* garbage (looks like an "exploded" Zak) into the apartment doorway. The
* stairs are already in the room background — #134 is hotspot-only.
* Belt: the id test, and the size and place it lands at.
                 lda   IsZak
                 beq   :gemcheck
                 lda   CurRoom
                 cmp   #3
                 bne   :gemcheck
                 lda   ObjCd
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y            ; object id (byte)
                 and   #$00FF
                 cmp   #134
                 beq   :skip134
* Oversized twin of the phone-office door OBIM in the doorway strip:
* even if the id byte were wrong, BlkH 80 at x≈304 is the spray.
                 lda   BlkH
                 cmp   #72
                 bcc   :gemcheck
                 lda   DstX
                 cmp   #300
                 bcc   :gemcheck
                 cmp   #370
                 bcs   :gemcheck
:skip134         brl   :esci
:gemcheck        anop

* There used to be a general rule here: if another object shares this
* OBIM and is smaller, this one is the oversized fake, skip it. It was
* written for #134 above and then asked of every object in every room -
* and sharing an OBIM is ordinary in V2. It threw away 177 objects in Zak
* and 162 in Maniac: the television, the refrigerator, the bus, the
* Golden Gate Bridge, the front door, the nuclear reactor. Mostly
* invisible, because those objects are usually off; but when a script
* lights one, nothing is drawn. The power outlet is such a twin of the
* infrared sensor, which is why using the cord on it set the state and
* drew nothing. In room 3 it would have taken the bus and the bridge too.
* The two explicit tests above name the one object that is really wrong.
:gemok           anop

                 lda   DstX                 ; has to fit inside
                 clc
                 adc   BlkW
                 cmp   RoomW
                 beq   :altezza
                 bcc   :altezza
                 brl   :esci
:altezza         lda   DstY
                 clc
                 adc   BlkH
                 cmp   RoomH
                 beq   :ok
                 bcc   :ok
                 brl   :esci
:ok              clc
                 rts
:esci            sec
                 rts

* CalcA * CalcB -> A (8-bit factors, product fits in 16 bits for objects)
Mul8             lda   CalcA
                 sta   TmpW
                 lda   #0
                 ldx   CalcB
                 beq   :z
:m               clc
                 adc   TmpW
                 dex
                 bne   :m
:z               rts

*=======================================================================
* PuliscoRett - put the clean background back where the object is
*=======================================================================
* In the dark zpBg still holds the lit room (so the light switch can
* restore it). Copying it here is what left a trail of doorway and floor
* behind the kid in the library.
PuliscoRett      lda   Vars+VO_LIGHTS
                 and   #6
                 bne   :luce
                 jmp   NeroRett
:luce            lda   BlkW
                 lsr   a
                 sta   TmpW2                ; bytes to copy per row
                 beq   :fine
                 dec   a
                 sta   MvnC
                 lda   zpBg
                 sta   MvnPtrS
                 lda   zpPix
                 sta   MvnPtrD
                 lda   zpBg+2
                 sta   MvnSrcB
                 lda   zpPix+2
                 sta   MvnDstB
                 lda   DstX
                 lsr   a
                 sta   ColByte              ; the column, in bytes
                 lda   DstY
                 sta   Riga
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColByte
                 sta   MvnS
:riga            jsr   MvnZp
                 bcs   :lento
:okriga          inc   Riga
                 lda   Riga
                 sec
                 sbc   DstY
                 cmp   BlkH
                 bcs   :fine
                 lda   MvnS
                 clc
                 adc   Pitch
                 sta   MvnS
                 bra   :riga
:fine            rts

:lento           ldy   MvnS
                 ldx   #0
:pix             lda   [zpBg],y
                 sta   [zpPix],y
                 iny
                 iny
                 inx
                 inx
                 cpx   TmpW2
                 bcc   :pix
                 bra   :okriga

* NeroRett - the same rectangle, black, for a dark room
NeroRett         lda   BlkW
                 lsr   a
                 sta   TmpW2
                 beq   :fine
                 lda   DstX
                 lsr   a
                 sta   ColByte
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
                 lda   #0
:pix             sta   [zpPix],y
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
:fine            rts

*=======================================================================
* AggiornaOggetto - redraw an object when its state changes
*=======================================================================
* On: the background goes back and the picture is decompressed over it.
* Off: the background alone is enough.
* The object is the one in ObjNo: it is copied into ObjFound too, which
* is where TrovaOggetto reads. Without this, callers coming from
* setState/clearState ended up redrawing the last object that passed by.
* The object's own square is redrawn here. When that cannot be done -
* the object is not in this room, or has no picture of its own - the
* whole room is composed again instead.
*
* That fallback matters. Before, every state change ended in a full
* compose, so an object that this routine could not draw was picked up
* by the next one anywhere in the room. Without it, such an object would
* simply never appear again, which is a worse bug than a slow frame.
AggiornaOggetto  lda   RoomH
                 beq   :fine
                 lda   ObjNo
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :tutta
                 jsr   LeggiObj
                 bcc   :posso
:tutta           lda   #1
                 sta   DaComporre
                 lda   #1
                 sta   ActDirty
                 sta   ActTutti
                 rts
:posso           jsr   PuliscoRett

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

* The masks in that square are stale too: put the room's own plane back
* there and let RidisegnaRett stamp the lit objects' masks over it. This
* used to be a DaComporre, that is a whole-room compose - copying the
* 51200 bytes of the picture and decoding the whole mask again for one
* button lighting up. In the aliens' room that was 79% of the time.
                 lda   #1
                 sta   MascRett
                 jsr   BaseMascRett
                 jsr   RidisegnaRett
                 stz   MascRett
* There may be a character under that object: putting the background
* back has just erased his legs. Only the ones the square actually
* touches, though. ActTutti repainted every costume in the room on every
* object state change, so in the kitchen three characters were redrawn
* for each frame of what the television was showing.
                 jsr   MarcaToccatiTutti
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
                 bne   :c_eobj
                 brl   :prossimo
:c_eobj          clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 jsr   GetObjState
                 and   #8
                 bne   :acceso
                 brl   :prossimo
:acceso          lda   AggLen
                 sta   PadreLen
                 jsr   PadreOk
                 bcc   :padreok
                 brl   :prossimo
:padreok         jsr   LeggiObj
                 bcc   :letto
                 brl   :prossimo
:letto           anop

                 lda   DstX                 ; do they touch?
                 cmp   AggR
                 bcc   :xok1
                 brl   :prossimo
:xok1            lda   DstX
                 clc
                 adc   BlkW
                 cmp   AggX
                 beq   :prossl
                 bcc   :prossl
                 lda   DstY
                 cmp   AggB
                 bcs   :prossl
                 lda   DstY
                 clc
                 adc   BlkH
                 cmp   AggY
                 beq   :prossl
                 bcc   :prossl
                 bra   :tocca
:prossl          brl   :prossimo
:tocca           lda   ObjImgOff
                 sta   SrcOff
                 lda   DstX
                 cmp   AggX
                 bcc   :clip
                 lda   DstY
                 cmp   AggY
                 bcc   :clip
                 lda   DstX
                 clc
                 adc   BlkW
                 cmp   AggR
                 beq   :dentro
                 bcs   :clip
:dentro          lda   DstY
                 clc
                 adc   BlkH
                 cmp   AggB
                 beq   :noclip
                 bcs   :clip
:noclip          stz   ClipOn
                 bra   :decod
:clip            lda   AggX
                 sta   ClipX1
                 lda   AggR
                 sta   ClipX2
                 lda   AggY
                 sta   ClipY1
                 lda   AggB
                 sta   ClipY2
                 lda   #1
                 sta   ClipOn
:decod           jsr   PrepSkipCloud8
                 jsr   DecodeRLE
                 stz   SkipCloud8
* DecodeRLE always runs the whole stream (clipping only drops the stores),
* so SrcIdx is where this object's own mask begins. Clipping does not
* apply to the plane: stamping the object's whole mask is what the full
* compose did anyway, and it is the same bytes every time.
                 lda   MascRett
                 beq   :nomasc
                 jsr   DecodeMaschera
:nomasc          stz   ClipOn

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
* Up to four rectangles. Two people talking at opposite ends of the
* room used to become one strip the width of the screen, and the pointer
* blinked on every mouth frame. Distant boxes stay apart; only those
* that touch (or nearly) are merged.
NDIRTYMAX        =     4
MARGINE          =     0              ; merge only if the boxes really touch

SegnaRett        lda   Redraw
                 cmp   #1
                 bne   :c_e
                 rts
:c_e             cmp   #2
                 beq   :gia
                 lda   DstX
                 sta   DirtyXs
                 lda   DstY
                 sta   DirtyYs
                 lda   DstX
                 clc
                 adc   BlkW
                 sta   DirtyRs
                 lda   DstY
                 clc
                 adc   BlkH
                 sta   DirtyBs
                 lda   #1
                 sta   DirtyN
                 lda   #2
                 sta   Redraw
                 rts

:gia             stz   DirtyI
:prova           ldx   DirtyI
                 lda   DirtyRs,x
                 clc
                 adc   #MARGINE
                 cmp   DstX
                 bcc   :no
                 lda   DstX
                 clc
                 adc   BlkW
                 clc
                 adc   #MARGINE
                 cmp   DirtyXs,x
                 bcc   :no
                 lda   DirtyBs,x
                 clc
                 adc   #MARGINE
                 cmp   DstY
                 bcc   :no
                 lda   DstY
                 clc
                 adc   BlkH
                 clc
                 adc   #MARGINE
                 cmp   DirtyYs,x
                 bcc   :no
                 brl   UniInX
:no              lda   DirtyI
                 clc
                 adc   #2
                 sta   DirtyI
                 lda   DirtyN
                 asl   a
                 cmp   DirtyI
                 bne   :prova
                 lda   DirtyN
                 cmp   #NDIRTYMAX
                 bcs   :forza
                 asl   a
                 tax
                 lda   DstX
                 sta   DirtyXs,x
                 lda   DstY
                 sta   DirtyYs,x
                 lda   DstX
                 clc
                 adc   BlkW
                 sta   DirtyRs,x
                 lda   DstY
                 clc
                 adc   BlkH
                 sta   DirtyBs,x
                 inc   DirtyN
                 rts
:forza           ldx   #0
UniInX           lda   DstX
                 cmp   DirtyXs,x
                 bcs   :nl
                 sta   DirtyXs,x
:nl              lda   DstY
                 cmp   DirtyYs,x
                 bcs   :nt
                 sta   DirtyYs,x
:nt              lda   DstX
                 clc
                 adc   BlkW
                 cmp   DirtyRs,x
                 bcc   :nr
                 sta   DirtyRs,x
:nr              lda   DstY
                 clc
                 adc   BlkH
                 cmp   DirtyBs,x
                 bcc   :nf
                 sta   DirtyBs,x
:nf              rts

*=======================================================================
* BlitRett - blit only the marked rectangle(s) to the screen
*=======================================================================
BlitRett         lda   DirtyN
                 beq   :fine
                 stz   DirtyI
:lp              ldx   DirtyI
                 lda   DirtyXs,x
                 sta   DirtyX
                 lda   DirtyYs,x
                 sta   DirtyY
                 lda   DirtyRs,x
                 sta   DirtyR
                 lda   DirtyBs,x
                 sta   DirtyB
                 jsr   BlitUno
                 lda   DirtyI
                 clc
                 adc   #2
                 sta   DirtyI
                 lda   DirtyN
                 asl   a
                 cmp   DirtyI
                 bne   :lp
:fine            rts

BlitUno          jsr   SottoIlPuntatore
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
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColRoom
                 sta   MvnS
                 lda   DirtyY
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
                 clc
                 adc   ColScr
                 sta   MvnD
                 lda   ByteCount
                 dec   a
                 sta   MvnC
:riga            jsr   MvnRiga
                 inc   Riga
                 lda   Riga
                 cmp   DirtyB
                 bcs   :blitok
                 lda   MvnS
                 clc
                 adc   Pitch
                 sta   MvnS
                 lda   MvnD
                 clc
                 adc   #SCRW
                 sta   MvnD
                 bra   :riga
:blitok          rts

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
                 rts                        ; room 0: keep the last picture

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
                 stx   MvnD
                 sty   MvnS
                 lda   FineCopia
                 sec
                 sbc   MvnD
                 dec   a                    ; the move counts from zero
                 sta   MvnC
                 jsr   MvnRiga

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
* MvnRiga - one row of the picture, from the room buffer to the screen
*=======================================================================
* In: MvnS = where it comes from, MvnD = where it goes, MvnC = how many
*     bytes, less one
*
* A block move does seven cycles a byte where the copy loop did
* twenty-nine every two: sixteen of those twenty-nine were iny, inx, cpx
* and bcc, that is advancing and comparing rather than moving pixels. On
* the machine it came out at 12.9 cycles a byte against 17.7, because
* writing on $E1 costs more than the instructions do.
*
* But a block move stays inside one bank, where a long pointer carries
* into the next by itself, and the Memory Manager puts the sixty-thousand
* byte room buffer wherever it likes: the last rows of a wide room fall
* on the other side. So the address is worked out in full every row, the
* bank goes into the instruction, and the one row that would run off the
* end is copied the old way.
MvnRiga          lda   MvnS
                 clc
                 adc   zpPix
                 sta   MvnX
                 lda   #0
                 adc   #0                   ; the carry into the bank
                 sta   MvnRip
                 lda   MvnX
                 clc
                 adc   MvnC
                 bcs   MvnPiedi             ; the row crosses a bank
                 sep   #$20
                 mx    %10
                 lda   zpPix+2
                 clc
                 adc   MvnRip
                 sta   MvnBanco
                 rep   #$30
                 mx    %00
                 ldx   MvnX
                 lda   MvnD
                 clc
                 adc   #$2000               ; the screen inside bank $E1
                 tay
                 lda   MvnC
                 jmp   MvnMove

MvnMove          mvn   $02,$E1              ; the source bank is written in
                 phk                        ; the move leaves its own bank
                 plb                        ; in the data bank register
                 rts
MvnBanco         =     MvnMove+2

MvnPiedi         ldy   MvnS
                 ldx   MvnD
                 lda   MvnC
                 inc   a
                 sta   MvnN
                 stz   MvnI
:pix             lda   [zpPix],y
                 stal  SHRBASE,x
                 iny
                 iny
                 inx
                 inx
                 inc   MvnI
                 inc   MvnI
                 lda   MvnI
                 cmp   MvnN
                 bcc   :pix
                 rts

*=======================================================================
* MvnZp - copy MvnC+1 bytes at offset MvnS from MvnPtrS/MvnSrcB
*         to MvnPtrD/MvnDstB. Carry set if the copy would wrap a bank.
*=======================================================================
MvnZp            lda   MvnS
                 clc
                 adc   MvnPtrS
                 tax
                 lda   #0
                 adc   #0
                 bne   :fail
                 txa
                 clc
                 adc   MvnC
                 bcs   :fail
                 lda   MvnS
                 clc
                 adc   MvnPtrD
                 tay
                 lda   #0
                 adc   #0
                 bne   :fail
                 tya
                 clc
                 adc   MvnC
                 bcs   :fail
                 lda   MvnS
                 clc
                 adc   MvnPtrS
                 tax
                 lda   MvnS
                 clc
                 adc   MvnPtrD
                 tay
                 sep   #$20
                 mx    %10
                 lda   MvnDstB
                 sta   MvnZpOp+1
                 lda   MvnSrcB
                 sta   MvnZpOp+2
                 rep   #$30
                 mx    %00
                 lda   MvnC
MvnZpOp          mvn   $00,$00
                 phk
                 plb
                 clc
                 rts
:fail            sec
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

FillArea         sta   FillCol
                 lda   FillEnd
                 sec
                 sbc   FillStart
                 cmp   #8
                 bcc   FillLento
                 ldx   FillStart
                 lda   FillCol
                 stal  SHRBASE,x
                 lda   FillStart
                 clc
                 adc   #$2000
                 tax
                 clc
                 adc   #2
                 tay
                 lda   FillEnd
                 sec
                 sbc   FillStart
                 sec
                 sbc   #3
                 bcc   FillLento
                 jmp   FillDoMvn
FillDoMvn        mvn   $E1,$E1
                 phk
                 plb
                 rts
FillLento        ldx   FillStart
                 lda   FillCol
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
                 bcc   :ce
                 brl   :fine
:ce              lda   DrawX                ; 255: leave it where it is
                 cmp   #255
                 beq   :stesso
* A new position. The picture is still at the old one: rub that
* out before the coordinates change, or the dream stamps a copy
* of the girl (and of Zak, and of the hat) at every step.
                 lda   DrawObj
                 sta   ObjNo
                 jsr   GetObjState
                 sta   TmpW
                 and   #8
                 beq   :solopos
                 lda   TmpW
                 and   #$0007               ; state, without "on screen"
                 jsr   PutObjState
                 jsr   AggiornaOggetto
:solopos         lda   DrawObj
                 sta   ObjFound
                 jsr   TrovaOggetto
                 bcs   :fine
                 lda   ObjCd
                 clc
                 adc   #7
                 tay
                 sep   #$20
                 mx    %10
                 lda   DrawX
                 sta   [zpRaw],y
                 iny
                 lda   [zpRaw],y            ; keep the parent-state bit
                 and   #$80
                 ora   DrawY
                 sta   [zpRaw],y
                 rep   #$20
                 mx    %00
:stesso          jsr   LeggiObj
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
* ObjectAt - the object under (FindX, FindY), or zero
*=======================================================================
* Every named room object whose rectangle contains the point is a
* candidate; the smallest area wins, so a cord or a remote beats the TV
* or the sofa they sit on. Parent is the same chain as drawing: that is
* how the cord and the remote stay hidden until the cushions are lifted,
* and how the food stays unclickable while the fridge door is shut.
* State bit 2 is V2 "untouchable"; owner 15 means it is still in the room.
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
                 beq   :vuoto
                 stz   ObjIdx
                 stz   ObjWant
                 lda   #$FFFF
                 sta   BestArea
:lp              lda   ObjIdx
                 jsr   ObjCdDaIdx
                 sta   ObjCd
                 beq   :salto
                 clc
                 adc   #4
                 tay
                 lda   [zpRaw],y
                 sta   ObjNo
                 beq   :salto
                 jsr   GetObjOwner
                 cmp   #15
                 bne   :salto
                 jsr   GetObjState
                 and   #2
                 bne   :salto
* Zak: skip nameless scenery so random hotspots do not steal clicks.
* The save screen's Save/Load/Cancel (703-705) and Game A-J builders
* are nameless on purpose - allow them while the disk UI is open.
                 lda   IsZak
                 beq   :mmok
                 lda   DiscoAperto
                 bne   :mmok
                 jsr   NomeC_e
                 bcs   :salto
:mmok            lda   ObjTabLen
                 sta   PadreLen
                 jsr   PadreOk
                 bcs   :salto
                 jsr   RettSotto
                 bcc   :cand
:salto           brl   :prossimo
:cand            jsr   AreaObj
                 cmp   BestArea
                 bcs   :prossimo
                 sta   BestArea
                 lda   ObjNo
                 sta   ObjWant
:prossimo        lda   ObjIdx
                 clc
                 adc   #2
                 sta   ObjIdx
                 cmp   ObjTabLen
                 bcs   :fine
                 brl   :lp
:fine            lda   ObjWant
                 rts

* NomeC_e - carry set if this object has no name to put on the sentence
NomeC_e          lda   ObjCd
                 clc
                 adc   #14
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 beq   :no
                 clc
                 adc   ObjCd
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 beq   :no
                 clc
                 rts
:no              sec
                 rts

* AreaObj - A = width * height of ObjCd
AreaObj          lda   ObjCd
                 clc
                 adc   #9
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 lda   ObjCd
                 clc
                 adc   #13
                 tay
                 lda   [zpRaw],y
                 and   #$00F8
                 sta   TmpW2
                 lda   #0
                 ldx   TmpW
                 beq   :zero
:mul             clc
                 adc   TmpW2
                 dex
                 bne   :mul
:zero            rts

* RettSotto - is (FindX,FindY) inside ObjCd's rectangle?
* Carry clear if it is. Same edges as ScummVM V2: left/top inclusive,
* right/bottom exclusive, height from the high bits of byte 13.
RettSotto        lda   ObjCd
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
                 cmp   TmpW
                 bcc   :no
                 lda   ObjCd
                 clc
                 adc   #9
                 tay
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   TmpW
                 cmp   FindX
                 beq   :no
                 bcc   :no
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
                 cmp   TmpW
                 bcc   :no
                 lda   ObjCd
                 clc
                 adc   #13
                 tay
                 lda   [zpRaw],y
                 and   #$00F8
                 clc
                 adc   TmpW
                 cmp   FindY
                 beq   :no
                 bcc   :no
                 clc
                 rts
:no              sec
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

* setActorElevation ($3D): how far above the floor the actor is drawn.
* Zak's dream parks the alien in the cloud with this, then drops him.
hSetElev         jsr   VOB1
                 sta   ActNo
                 jsr   VOB2
                 sta   ActArg
                 lda   ActNo
                 jsr   ActIndex
                 bcs   :fine
                 stx   ActIdx
                 lda   ActArg
                 sta   ActElev,x
                 jsr   SegnaAttore
:fine            stz   Esito
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
                 sta   TmpW
                 jsr   FetchB
                 sta   TmpW2
                 lda   BoxOff
                 beq   :fine
                 lda   TmpW
                 cmp   NumBox
                 bcs   :fine
                 asl   a
                 asl   a
                 asl   a
                 clc
                 adc   BoxOff
                 inc   a
                 clc
                 adc   #7
                 tay
                 sep   #$20
                 mx    %10
                 lda   TmpW2
                 sta   [zpRaw],y
                 rep   #$20
                 mx    %00
:fine            stz   Esito
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
                 bcc   :aok
                 brl   :lontano
:aok             lda   PosX
                 sta   DistX1
                 lda   PosY
                 sta   DistY1
                 lda   DistB
                 jsr   DovE
                 bcc   :bok
                 brl   :lontano
:bok             anop

* V2 getObjActToObjActDist: if the first is an actor and the second an
* object, snap the object's walk point into a box. walkActorToObject
* already walked to that same point; without the snap, getDist stays
* > 2 (the sign at y=52 vs the sidewalk at 57, the stairs at 20 vs
* box 0 at 36) and script 2 prints "I can't reach it" and RESETS to
* Walk to. Invisible boxes stay out (BoxLockOk=0).
*
* Zak walk (AvviaCamminoQui) keeps the official point when the snap
* moves less than 2: room-2 cushion #119 is at (33,52), snapped to
* (33,53). Using the snap here made getDist=1 while ego stood on the
* walk point, so verb 253 cleared state 8 and the remote stayed buried.
                 lda   DistA
                 jsr   ActIndex
                 bcs   :nosnap
                 lda   ActRoom,x
                 beq   :nosnap
                 lda   DistB
                 jsr   ActIndex
                 bcs   :snap
                 lda   ActRoom,x
                 bne   :nosnap
:snap            stz   BoxLockOk
                 lda   PosX
                 sta   BoxQx
                 sta   WalkAX               ; official walk point
                 lda   PosY
                 sta   BoxQy
                 sta   WalkAY
                 jsr   AvvicinaPunto
                 lda   BoxScelta
                 cmp   #$FFFF
                 beq   :nosnap
                 lda   IsZak
                 beq   :applica
                 lda   WalkAX
                 sec
                 sbc   BoxQx
                 bpl   :sdx
                 eor   #$FFFF
                 inc   a
:sdx             sta   WalkAX
                 lda   WalkAY
                 sec
                 sbc   BoxQy
                 bpl   :sdy
                 eor   #$FFFF
                 inc   a
:sdy             cmp   WalkAX
                 bcs   :smag
                 lda   WalkAX
:smag            cmp   #2
                 bcc   :nosnap              ; match walk: keep official
:applica         lda   BoxQx
                 sta   PosX
                 lda   BoxQy
                 sta   PosY
:nosnap          anop

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
                 bcs   :oggetto
* Slots 14..24 exist in the table but Zak's actors stop at 13.
* The same numbers are objects (kazoo, CashCard, power cord, remote).
* An unused slot has room 0: that number is the object, not a person.
                 lda   ActRoom,x
                 beq   :oggetto
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
                 stx   ActIdx
                 stz   ActMoving,x
                 jsr   FermaPose
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
                 jsr   NomeOffVerbo
                 sta   NameBase             ; slot * VERBNAME
:lp              jsr   FetchB
                 beq   :fine
                 cmp   #$00FE
                 bcc   :normale
                 jsr   FetchB
                 bra   :lp
:normale         cmp   #'@'
                 beq   :lp
                 ldx   NameLen
                 cpx   #VERBNAME-1
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
                 jsr   PatchCredVerb
                 rts

* Credits arrive as verb names (script 111), not as print(). Same two
* substitutions as RiscriviCred: IBM → IIGS port, Hayes → dots.
PatchCredVerb    lda   zpStr
                 pha
                 lda   zpStr+2
                 pha
                 lda   NameBase
                 tax
                 clc
                 adc   #VERBNAME
                 sta   TmpW2
:c1              cpx   TmpW2
                 bcs   :no
                 lda   VerbName,x
                 and   #$007F
                 cmp   #'I'
                 bne   :k
                 lda   VerbName+1,x
                 and   #$007F
                 cmp   #'B'
                 bne   :k
                 lda   VerbName+2,x
                 and   #$007F
                 cmp   #'M'
                 beq   :ibm
:k               lda   VerbName,x
                 and   #$007F
                 cmp   #'H'
                 bne   :av
                 lda   VerbName+1,x
                 and   #$007F
                 cmp   #'a'
                 bne   :av
                 lda   VerbName+2,x
                 and   #$007F
                 cmp   #'y'
                 beq   :nomi
:av              inx
                 bra   :c1
:no              bra   :esci
:ibm             lda   #MsgIIGS
                 bra   :copia
:nomi            lda   #MsgMusica
:copia           sta   zpStr
                 lda   #^MsgIIGS
                 sta   zpStr+2
                 lda   NameBase
                 tax
                 stz   NameLen
:lp              lda   [zpStr]
                 and   #$00FF
                 beq   :term
                 sep   #$20
                 mx    %10
                 sta   VerbName,x
                 rep   #$20
                 mx    %00
                 inc   zpStr
                 inx
                 inc   NameLen
                 lda   NameLen
                 cmp   #VERBNAME-1
                 bcc   :lp
:term            sep   #$20
                 mx    %10
                 lda   #0
                 sta   VerbName,x
                 rep   #$20
                 mx    %00
                 lda   NameBase             ; dots: centre on the 40-wide line
                 tax
                 lda   VerbName,x
                 and   #$007F
                 cmp   #'.'
                 bne   :esci
                 lda   #40
                 sec
                 sbc   NameLen
                 lsr   a
                 asl   a
                 asl   a
                 asl   a
                 ldx   VerbIdx
                 sta   VerbX,x
:esci            pla
                 sta   zpStr+2
                 pla
                 sta   zpStr
                 rts

*=======================================================================
* DrawVerbs - the verb panel where the game put it
*=======================================================================
DrawVerbs        lda   UserIface
                 and   #$0080
                 bne   :mostra
                 rts
:mostra          _HideCursor
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
:lp              jsr   DrawUnoVerbo
                 lda   VerbIdx
                 clc
                 adc   #2
                 sta   VerbIdx
                 cmp   #NVERBS*2
                 bcc   :lp
                 lda   #15
                 jsr   SetTextColor
                 rts

* Zak credits (script 111): cursorCommand($8400) sets UserIface=$80
* (verbs on, sentence off). Those lines stay up after loadRoom(51/55/49);
* room 58 is only the starfield before Var[60] unblocks them. SEC = do
* not light. Maniac never takes this path.
CredNoHover      lda   IsZak
                 beq   :no
                 lda   UserIface
                 and   #$00E0
                 cmp   #$0080
                 bne   :no
                 sec
                 rts
:no              clc
                 rts

*=======================================================================
* DrawUnoVerbo - one slot (VerbIdx): colour from on/off and VerbHover
*=======================================================================
DrawUnoVerbo     ldx   VerbIdx
                 lda   VerbId,x
                 beq   :fine
                 lda   VerbOn,x
                 beq   :fine
                 cmp   #1
                 beq   :vivo
                 lda   #COLVERBDIM
                 bra   :coloreok
:vivo            jsr   CredNoHover
                 bcs   :riposo
                 lda   VerbIdx
                 inc   a
                 cmp   VerbHover
                 beq   :acceso
:riposo          lda   #COLVERB
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
                 jsr   NomeOffVerbo
                 clc
                 adc   #VerbName
                 sta   zpStr
                 lda   #^VerbName
                 sta   zpStr+2
                 jsr   DrawStr
:fine            rts

* VerbIdx (slot times two) to the offset of that name in VerbName.
NomeOffVerbo     lsr   a                    ; slot
                 sta   TmpW
                 asl   a
                 asl   a
                 asl   a                    ; times eight
                 sta   NameBase
                 asl   a
                 asl   a                    ; times thirty-two
                 clc
                 adc   NameBase             ; times forty
                 rts

*=======================================================================
* DipingiCambioVerbo - un-light the previous verb, light the new one
*=======================================================================
* DrawChar writes the whole 8x8 cell (empty bits come out black), so the
* old colour is overwritten. No need to black the whole verb band.
DipingiCambioVerbo anop
                 lda   UserIface
                 and   #$0080
                 beq   :salva
                 _HideCursor
                 lda   VerbHoverLast
                 jsr   DisegnaVerboHover
                 lda   VerbHover
                 jsr   DisegnaVerboHover
                 _ShowCursor
:salva           lda   VerbHover
                 sta   VerbHoverLast
                 rts

* A = hover index plus one (zero: nothing). VerbHover is VerbIdx+1
* and VerbIdx is already the slot times two, so do not shift again.
DisegnaVerboHover anop
                 cmp   #0
                 beq   :fine
                 dec   a
                 cmp   #NVERBS*2
                 bcs   :fine
                 sta   VerbIdx
                 jsr   DrawUnoVerbo
:fine            rts

*=======================================================================
* DrawFrase - the line of the sentence being built
*=======================================================================
* Verb, first object, preposition, second object. In the DOS version it
* is purple (EGA's 13) and sits right above the verb panel.
DrawFrase        lda   UserIface
                 and   #$0020
                 bne   :mostra
                 rts
:mostra          _HideCursor
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
                 bne   :obj1
                 lda   Vars+VO_SENTPREP     ; still picking the first noun
                 bne   :fine
                 lda   HoverNow
                 beq   :fine
:obj1            jsr   Spazio
                 lda   Vars+VO_SENTOBJ1
                 bne   :n1
                 lda   HoverNow
:n1              jsr   ScriviNomeDi

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
                 bne   :obj2
                 lda   Vars+VO_SENTPREP
                 beq   :fine
                 lda   HoverNow
                 beq   :fine
:obj2            jsr   Spazio
                 lda   Vars+VO_SENTOBJ2
                 bne   :n2
                 lda   HoverNow
:n2              jsr   ScriviNomeDi
:fine            lda   #15
                 jmp   SetTextColor

Spazio           inc   TxtX
                 rts

*=======================================================================
* ScriviNomeVerbo - the name of the verb in slot X
*=======================================================================
ScriviNomeVerbo  txa
                 jsr   NomeOffVerbo
                 clc
                 adc   #VerbName
                 sta   zpStr
                 lda   #^VerbName
                 sta   zpStr+2
                 jmp   DrawStrFino

*=======================================================================
* ScriviNomeDi - A = object or actor number: writes its name
*=======================================================================
* Numbers below NACT are characters only if that slot is actually in a
* room. Zak's actors stop at 13; 14..24 are objects (kazoo, CashCard,
* power cord, remote). Treating them as people wrote a blank ActName
* on the sentence: "Use " with nothing after it, which is how the cord
* and the remote looked like they were not there.
ScriviNomeDi     sta   NomeChi
                 jsr   NomeSostituito       ; did the game rename it?
                 bcs   :normale
                 jmp   DrawStrFino
:normale         lda   NomeChi
                 cmp   #NACT
                 bcs   :oggetto
                 jsr   ActIndex
                 bcs   :oggetto
                 lda   ActRoom,x
                 beq   :oggetto
                 lda   NomeChi
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
DrawInv          lda   UserIface
                 and   #$0040
                 bne   :mostra
                 rts
:mostra          _HideCursor
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
                 stz   InvQuanti
                 stz   InvIdx
:lp              ldx   InvIdx
                 lda   InvObj,x
                 beq   :prossimo
                 jsr   MioOggetto           ; does the player really own it?
                 bcs   :prossimo
                 inc   InvQuanti            ; one more that he owns
                 lda   InvQuanti            ; still above the window?
                 cmp   InvOff
                 bcc   :prossimo
                 beq   :prossimo
                 lda   InvVisti
                 cmp   #4
                 bcs   :prossimo            ; the window is already full

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
:prossimo        lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcs   :finiti
                 brl   :lp
:finiti          anop

* the arrows, once it is known how many there really are
                 lda   InvOff
                 beq   :nosu
                 lda   #INVTOP
                 ldx   #0                   ; pointing up
                 jsr   DisegnaFreccia
:nosu            lda   InvOff
                 clc
                 adc   #4
                 cmp   InvQuanti
                 bcs   :nogiu
                 lda   #INVROW2
                 ldx   #1                   ; pointing down
                 jsr   DisegnaFreccia
:nogiu           lda   #15
                 jmp   SetTextColor

*=======================================================================
* DisegnaFreccia - A = the row it starts on, X = 0 up, 1 down
*=======================================================================
* Drawn here rather than written with the font. In the DOS version the
* two arrows are characters 1 to 4 of the game's own font, and this
* interpreter should not depend on what a particular font happens to
* have below the space. Sixteen pixels wide and seven tall, in the strip
* between the two columns of names, which is exactly where the original
* puts them.
FRECCIAX         =     152                  ; pixels from the left
FRECCIAW         =     8                    ; bytes: sixteen pixels

DisegnaFreccia   sta   FrecciaY
                 stx   FrecciaVerso
                 stz   FrecciaR
:riga            lda   FrecciaR             ; how wide this row is: the tip
                 cmp   #7                   ; is one pixel, the base sixteen
                 bcs   :fatta
                 lda   FrecciaVerso
                 beq   :versosu
                 lda   #6
                 sec
                 sbc   FrecciaR
                 bra   :largo
:versosu         lda   FrecciaR
:largo           asl   a                    ; two pixels wider each row
                 inc   a
                 sta   FrecciaN             ; pixels lit on this row
                 lda   #8
                 sec
                 sbc   FrecciaR
                 lda   FrecciaVerso
                 beq   :suok
                 lda   #6
                 sec
                 sbc   FrecciaR
                 bra   :meta
:suok            lda   FrecciaR
:meta            sta   FrecciaM             ; half the width, rounded down

                 lda   FrecciaY             ; where the row starts
                 clc
                 adc   FrecciaR
                 jsr   RigaSchermo
                 sta   FrecciaP
                 lda   #8                   ; the middle of the sixteen
                 sec
                 sbc   FrecciaM
                 clc
                 adc   #FRECCIAX
                 sta   FrecciaX0
                 stz   FrecciaI
:pix             lda   FrecciaI
                 cmp   FrecciaN
                 bcs   :finita
                 lda   FrecciaX0
                 clc
                 adc   FrecciaI
                 jsr   PuntoFreccia
                 inc   FrecciaI
                 bra   :pix
:finita          inc   FrecciaR
                 bra   :riga
:fatta           rts

* One pixel of the arrow: A = the column, FrecciaP = the row's first byte
PuntoFreccia     pha
                 lsr   a
                 clc
                 adc   FrecciaP
                 tax
                 pla
                 and   #1
                 bne   :bassa
                 sep   #$20
                 mx    %10
                 ldal  SHRBASE,x
                 and   #$0F
                 ora   #COLFRECCIA*16
                 bra   :metti
:bassa           sep   #$20
                 mx    %10
                 ldal  SHRBASE,x
                 and   #$F0
                 ora   #COLFRECCIA
:metti           stal  SHRBASE,x
                 rep   #$20
                 mx    %00
                 rts

* RigaSchermo - A = row, returns the offset of its first byte
RigaSchermo      asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   TmpW
                 asl   a
                 asl   a
                 clc
                 adc   TmpW
                 rts

*=======================================================================
* ScorriInv - a click on the arrows moves the window by two
*=======================================================================
* Two at a time, not four, so the pair that was at the bottom comes back
* at the top: that is how the original scrolls, and it keeps a long list
* readable.
ScorriInv        lda   MouseY
                 cmp   #INVROW2
                 bcs   :giu
                 lda   InvOff               ; up
                 beq   :fine
                 sec
                 sbc   #2
                 sta   InvOff
                 bra   :ridisegna
:giu             jsr   ContaInv
                 sta   InvTot
                 lda   InvOff
                 clc
                 adc   #4
                 cmp   InvTot
                 bcs   :fine                ; the last ones are already there
                 lda   InvOff
                 clc
                 adc   #2
                 sta   InvOff
:ridisegna       lda   #1
                 sta   InvDirty
:fine            rts

*=======================================================================
* ContaInv - how many objects the player is carrying
*=======================================================================
ContaInv         stz   InvTot
                 stz   InvIdx
:lp              ldx   InvIdx
                 lda   InvObj,x
                 beq   :prossimo
                 jsr   MioOggetto
                 bcs   :prossimo
                 inc   InvTot
:prossimo        lda   InvIdx
                 clc
                 adc   #2
                 sta   InvIdx
                 cmp   #INVSLOTS*2
                 bcc   :lp
                 lda   InvTot
                 rts

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
                 jsr   CredNoHover
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
* AggiornaMouseVirt - script 4's findObject reads these every click,
* and What Is polls them every frame. They have to follow the pointer,
* not the last mouse-down.
*=======================================================================
AggiornaMouseVirt lda  PtoX
                 clc
                 adc   ScrollX
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   Vars+VO_MOUSEX
                 lda   PtoY
                 sec
                 sbc   #ROOMTOP
                 bpl   :yok
                 lda   #0
:yok             lsr   a
                 sta   Vars+VO_MOUSEY
                 rts

*=======================================================================
* FraseSottoPuntatore - put the name of the thing under the pointer
* on the sentence line. Script 4 only runs on a click; without a hover
* "Walk to" and "Use" stay empty. SENTOBJ1 is NOT filled for Unlock /
* Give / Fix (and Use-with): those verbs set a preposition, and a
* pre-filled SENTOBJ1 makes Var[34]=1 so script 4 RESETS to Walk to
* instead of waiting for "with key".
*=======================================================================
FraseSottoPuntatore lda UserIface
                 and   #$0020
                 beq   :fine
                 lda   PtoY
                 cmp   #ROOMTOP
                 bcc   :fine
                 cmp   #PANTOP
                 bcs   :fine
                 lda   PtoX
                 cmp   #SCRPIX
                 bcs   :fine
                 clc
                 adc   ScrollX
                 sta   FindX
                 lda   PtoY
                 sec
                 sbc   #ROOMTOP
                 sta   FindY
                 jsr   ObjectAt
                 cmp   HoverNow
                 bne   :nuovo
                 rts
:nuovo           sta   HoverNow
                 lda   Vars+VO_SENTPREP
                 bne   :secondo
                 jsr   FraseNoObj1
                 bcs   :disegna
                 lda   HoverNow
                 cmp   Vars+VO_SENTOBJ1
                 beq   :fine
                 sta   Vars+VO_SENTOBJ1
                 jmp   DrawFrase
:secondo         lda   HoverNow
                 cmp   Vars+VO_SENTOBJ2
                 beq   :fine
                 sta   Vars+VO_SENTOBJ2
                 jmp   DrawFrase
:disegna         jmp   DrawFrase
:fine            rts

* Carry set: do not write SENTOBJ1 (two-object verbs / Use-with).
FraseNoObj1      lda   Vars+VO_SENTVERB
                 cmp   #3                   ; Give ... to
                 beq   :no
                 cmp   #6                   ; Fix ... with
                 beq   :no
                 cmp   #8                   ; Unlock ... with
                 beq   :no
                 cmp   #11                  ; Use: only if the object
                 bne   :si                  ; itself asks for a preposition
                 lda   HoverNow
                 beq   :si
                 sta   NomeChi
                 jsr   CercaObcd
                 bcs   :si
                 ldy   #12
                 lda   [zpNome],y
                 and   #$00FF
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 lsr   a
                 beq   :si
:no              sec
                 rts
:si              clc
                 rts

*=======================================================================
* SpegniScena - black out the play area
*=======================================================================
* Loading a room on the IIGS takes nearly a second. Without this the last
* frame of the previous one stays on screen the whole time, and it reads
* as a freeze. "Loading..." sits in the black playfield until DrawRoom
* puts the new picture on top of it.
SpegniScena      lda   CurRoom
                 beq   :room0               ; room 0 is a black gap, not a load
                 lda   IsZak
                 beq   :normale
                 lda   CurRoom
                 cmp   #46                  ; title: do not wipe, do not say
                 beq   :niente              ; "Loading..." over the logo
                 cmp   #51                  ; bed / title pan
                 beq   :niente
                 cmp   #55                  ; Lucasfilm copyright
                 beq   :niente
                 cmp   #49                  ; newspaper dream after it
                 beq   :niente
                 cmp   #58
                 beq   :niente
                 bra   :normale
:room0           bra   :nero                ; gap: black, not the last frame
:nero            jsr   MusDuck
                 _HideCursor
                 stz   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 _ShowCursor
                 jsr   DrawMsg
                 stz   InCarico
                 rts
:normale         lda   #1
                 sta   InCarico             ; no credit on the black "Loading..."
                 jsr   MusDuck              ; freeze DOC: loading must not loop the last notes
                 _HideCursor
                 stz   FillStart
                 lda   #PANOFF
                 sta   FillEnd
                 lda   #$0000
                 jsr   FillArea
                 jsr   MostraCarico
                 _ShowCursor
                 jsr   DrawMsg              ; and away with the old sentence,
                 rts                        ; at once: not when loading ends
:niente          jsr   MusDuck
                 stz   InCarico
                 rts

*=======================================================================
* MostraCarico - centred in the play area, on the black just laid down
*=======================================================================
MostraCarico     lda   #15
                 jsr   SetTextColor
                 lda   #ROOMTOP+60          ; middle of the 128-row room
                 sta   TxtY
                 lda   #MsgLoad
                 sta   zpStr
                 lda   #^MsgLoad
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 rts

* snd / sfx / te (LoadOneTool+StartUp) / se (SFXI) / n (plays)
MostraAudio      jsr   CompilaAudio
                 lda   TxtY
                 clc
                 adc   #10
                 sta   TxtY
                 lda   #15
                 jsr   SetTextColor
                 lda   #MsgAudio
                 sta   zpStr
                 lda   #^MsgAudio
                 sta   zpStr+2
                 jmp   DrawStrCenter

CompilaAudio     lda   SndOn
                 and   #$000F
                 ora   #'0'
                 sep   #$20
                 sta   MsgAudio+4
                 rep   #$20
                 lda   SfxOn
                 and   #$000F
                 ora   #'0'
                 sep   #$20
                 sta   MsgAudio+10
                 rep   #$20
                 lda   SndErr
                 and   #$000F
                 ora   #'0'
                 sep   #$20
                 sta   MsgAudio+15
                 rep   #$20
                 lda   SfxErr
                 and   #$000F
                 ora   #'0'
                 sep   #$20
                 sta   MsgAudio+20
                 rep   #$20
                 lda   SndPlays
                 jsr   DueCifre
                 sep   #$20
                 lda   TmpW
                 sta   MsgAudio+24
                 rep   #$20
                 txa
                 sep   #$20
                 sta   MsgAudio+25
                 rep   #$20
                 rts

DueCifre         ldx   #'0'
:lp              cmp   #10
                 bcc   :u
                 sec
                 sbc   #10
                 inx
                 bra   :lp
:u               ora   #'0'
                 stx   TmpW
                 tax
                 rts

*=======================================================================
* HoldSeLogo - keep Zak's title card (bed / Lucasfilm copyright)
*=======================================================================
* MACHINE_SPEED is 80 so the long dream runs, but that same flag skips
* the delay(180) before leaving room 55. The copyright has just been
* drawn; without a pause here SpegniScena paints "Loading..." over it.
HoldSeLogo       lda   IsZak
                 beq   :no
                 lda   CurRoom
                 cmp   #51                  ; pan onto the title
                 beq   :hold
                 cmp   #55                  ; copyright objects 756-760
                 bne   :no
:hold            PushLong #0
                 _GetTick
                 PullLong Tick
                 lda   Tick
                 sta   TmpW
:lp              PushLong #0
                 _GetTick
                 PullLong Tick
                 lda   Tick
                 sec
                 sbc   TmpW
                 cmp   #240                 ; four seconds
                 bcc   :lp
:no              rts

*=======================================================================
* ChangeRoom - A = room number
*=======================================================================
ChangeRoom       pha                        ; new room
                 lda   CurRoom
                 beq   :noex                ; first room: nothing to leave
                 cmp   1,s
                 beq   :noex
                 jsr   HoldSeLogo           ; keep the Lucas card a moment
                 jsr   EseguiUscita         ; EXCD while the old file is still here
                 lda   PlayingId            ; foyer clock must not follow you
                 cmp   #28
                 bne   :noex
                 jsr   StopSfx
:noex            pla
                 sta   CurRoom
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
                 bcc   :caricata
                 brl   :vuota
:caricata        anop

                 jsr   DecodeRoom
                 jsr   MusUnduck            ; Loading... over: bring the score back
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
                 stz   Vars+VO_LIGHTS       ; previous room's lights must not
                                            ; paint this one before ENCD

* and the room's entry script, if there is one. Nested, so lights()
* from startScript(50) has already run when the main loop composes:
* otherwise the library shows one lit frame, then goes dark.
                 ldy   #$1A
                 lda   [zpRaw],y
                 beq   :fine
                 sta   EnterOff
                 jsr   FreeSlot
                 bcs   :fine
                 sta   NestSlot
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
                 jsr   GiraSubito
:fine            stz   InCarico
                 rts
:vuota           jsr   MusUnduck
                 stz   RoomW
                 stz   RoomH
                 stz   DaComporre
                 lda   #1
                 sta   Redraw
                 stz   InCarico
                 rts

* V2 room header: EXCD at $18, ENCD at $1A. The exit must run now, nested,
* so stopScript(18) can kill the foyer clock before the kitchen is loaded.
EseguiUscita     ldy   #$18
                 lda   [zpRaw],y
                 beq   :no
                 sta   EnterOff
                 jsr   FreeSlot
                 bcs   :no
                 sta   NestSlot
                 asl   a
                 tax
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   #DA_STANZA
                 sta   SlotWhere,x
                 lda   #$7FFE
                 sta   SlotNum,x
                 lda   #0
                 sta   SlotBaseT,x
                 sta   SlotDelLo,x
                 sta   SlotDelHi,x
                 lda   EnterOff
                 sta   SlotPC,x
                 jsr   GiraSubito
:no              rts

*=======================================================================
* DecodeRoom - the background, the clean copy, and the lit objects on top
*=======================================================================
* Where this room's pictures stop and its descriptions begin depends on
* the room and on nothing else, so it is worked out here, once. It used
* to be worked out inside LeggiObj, which RidisegnaRett calls for every
* object in the room, and ConfineImmagini scans every object in turn:
* redrawing one rectangle was quadratic in the number of objects, and in
* the aliens' room that scan was most of the frame.
DecodeRoom       jsr   ConfineImmagini
                 ldy   #4
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
                 stz   SkipCloud8           ; cloud grey must be painted
                 jsr   DecodeRLE
                 lda   SrcIdx               ; the room's mask begins here,
                 sta   MaskSrc              ; right after its pixels
                 jsr   DecodeMaschera

* a copy of the background alone: it is what makes an object disappear
* without decompressing the whole room again
                 jsr   AltezzaByte
                 sta   CopyLen
                 jsr   CopiaPixBg

                 lda   #1                   ; what goes on top of it is put
                 sta   DaComporre           ; together separately
                 lda   #$FFFF
                 sta   BuioStato            ; and the lights are not known yet
                 rts

*=======================================================================
* RifaiMaschera - the room's own mask, as it came off disk
*=======================================================================
* The base every compose starts from: the objects that are lit then write
* theirs over it, so one that has gone out stops hiding anybody. Only the
* mask is read again, not the picture, so this costs a few hundred bytes
* of decoding and not a whole room.
RifaiMaschera    lda   RoomH
                 bne   :c_e
                 rts
* The plane only has to be decoded once per room: after that the clean
* copy in zpMask0 is the same bytes, and a block move is far cheaper than
* running the whole run-length stream again. In the alien room, where the
* screens animate every frame, that decode alone was a third of the time.
:c_e             lda   CurRoom
                 cmp   Masc0Room
                 bne   :decodi
                 jsr   CopiaMasc0
                 rts
:decodi          ldy   #$0A                 ; room picture, not the last object
                 lda   [zpRaw],y
                 clc
                 adc   zpRaw
                 sta   zpSrc
                 lda   zpRaw+2
                 adc   #0
                 sta   zpSrc+2
                 lda   MaskSrc
                 sta   SrcIdx
                 stz   DstX
                 stz   DstY
                 lda   RoomW
                 sta   BlkW
                 lda   RoomH
                 sta   BlkH
                 jsr   DecodeMaschera
                 jsr   SalvaMasc0
                 lda   CurRoom
                 sta   Masc0Room
                 rts

*=======================================================================
* BaseMascRett - the clean mask back inside AggX..AggR / AggY..AggB
*=======================================================================
* What an object state change really needs. The whole plane used to be
* decoded again (through DaComporre) only because one object's square
* had gone stale; this puts back that square from the clean copy, and
* RidisegnaRett then stamps the masks of the lit objects that touch it.
* Whole bytes: the two edges are rounded out to the eight-pixel column.
BaseMascRett     lda   RoomH
                 bne   :c_e
                 rts
:c_e             lda   AggX
                 lsr   a
                 lsr   a
                 lsr   a
                 sta   MascC1
                 lda   AggR
                 clc
                 adc   #7
                 lsr   a
                 lsr   a
                 lsr   a
                 cmp   MaskPitch
                 bcc   :c2ok
                 lda   MaskPitch
:c2ok            cmp   MascC1
                 beq   :vuoto
                 bcs   :largo
:vuoto           rts
:largo           sec
                 sbc   MascC1
                 sta   MascNb               ; bytes on each row
                 lda   AggY
                 sta   MascY
:riga            lda   MascY
                 cmp   AggB
                 bcc   :nonfinito
                 rts
:nonfinito       cmp   RoomH
                 bcc   :fai
                 rts
:fai             asl   a
                 tax
                 lda   MaskRow,x
                 clc
                 adc   MascC1
                 tay
                 ldx   MascNb
                 sep   #$20
                 mx    %10
:byte            lda   [zpMask0],y
                 sta   [zpMask],y
                 iny
                 dex
                 bne   :byte
                 rep   #$20
                 mx    %00
                 inc   MascY
                 bra   :riga

*=======================================================================
* SalvaMasc0 / CopiaMasc0 - the clean plane there and back
*=======================================================================
MascLunghezza    lda   RoomH                ; bytes in the whole plane, from
                 beq   :zero                ; the row table already built
                 dec   a
                 asl   a
                 tax
                 lda   MaskRow,x
                 clc
                 adc   MaskPitch
                 rts
:zero            lda   #0
                 rts

SalvaMasc0       jsr   MascLunghezza
                 beq   :fine
                 sta   MascLen
                 lda   zpMask
                 sta   MvnPtrS
                 lda   zpMask+2
                 sta   MvnSrcB
                 lda   zpMask0
                 sta   MvnPtrD
                 lda   zpMask0+2
                 sta   MvnDstB
                 bra   MascCopia
:fine            rts

CopiaMasc0       jsr   MascLunghezza
                 beq   :fine
                 sta   MascLen
                 lda   zpMask0
                 sta   MvnPtrS
                 lda   zpMask0+2
                 sta   MvnSrcB
                 lda   zpMask
                 sta   MvnPtrD
                 lda   zpMask+2
                 sta   MvnDstB
                 bra   MascCopia
:fine            rts

* MVN cannot cross a bank: when it would, fall back to the word loop.
MascCopia        lda   MascLen
                 dec   a
                 sta   MvnC
                 stz   MvnS
                 jsr   MvnZp
                 bcc   :fine
                 lda   MvnPtrS              ; MVN would cross a bank: go the
                 sta   zpSrc                ; slow way through long pointers
                 lda   MvnSrcB
                 sta   zpSrc+2
                 lda   MvnPtrD
                 sta   zpPix2
                 lda   MvnDstB
                 sta   zpPix2+2
                 ldy   #0
:lp              lda   [zpSrc],y
                 sta   [zpPix2],y
                 iny
                 iny
                 cpy   MascLen
                 bcc   :lp
:fine            rts

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
                 jsr   RifaiMaschera
                 lda   Vars+VO_LIGHTS
                 and   #6
                 sta   BuioStato
                 bne   :c_eluce
                 jsr   AltezzaByte
                 sta   CopyLen
                 jsr   ZeroRoomBuf
                 bra   :attori
* zpBg is the room with no objects and no characters. Painting the
* objects onto whatever is already in zpPix (the last composed frame)
* kept every costume stamp from the previous pass: setState08 of the
* bakery window rebuilt the masks that way and the street filled with
* leftover baker and Zak. Copy the clean room back first.
:c_eluce         lda   IsZak
                 beq   :ogg                 ; MM: objects onto the decoded room
                 jsr   AltezzaByte
                 sta   CopyLen
                 jsr   CopiaBgPix
:ogg             jsr   DrawObjects
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

* Repeat runs fill the rest of this strip in one go. MskData is loaded
* every store: adding MaskPitch is 16-bit and would otherwise leave A
* holding the offset, which is how the last burst painted noise.
:riga            lda   MskY
                 cmp   BlkH
                 bcc   :work
                 brl   :nexts
:work            lda   MskRun
                 bne   :have
                 jsr   MskApri
:have            lda   MskRep
                 beq   :uno
                 lda   BlkH
                 sec
                 sbc   MskY
                 bne   :c_burst
                 brl   :nexts
:c_burst         cmp   MskRun
                 bcc   :n
                 lda   MskRun
:n               sta   CelVis
                 tax
                 lda   MskRun
                 sec
                 sbc   CelVis
                 sta   MskRun
                 ldy   MskOff
:burst           sep   #$20
                 mx    %10
                 lda   MskData
                 sta   [zpMask],y
                 rep   #$20
                 mx    %00
                 tya
                 clc
                 adc   MaskPitch
                 tay
                 dex
                 bne   :burst
                 sty   MskOff
                 lda   MskY
                 clc
                 adc   CelVis
                 sta   MskY
                 brl   :riga

:uno             ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   MskData
                 dec   MskRun
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
                 brl   :riga

:nexts           inc   MskX
                 lda   MskX
                 cmp   MskEnd
                 bcs   :mskfine
                 brl   :striscia
:mskfine         rts

* Open the next mask run without storing. Repeat runs keep one data byte;
* literal runs read a fresh byte each time they are consumed.
MskApri          ldy   SrcIdx
                 lda   [zpSrc],y
                 and   #$00FF
                 inc   SrcIdx
                 sta   TmpW
                 and   #$0080
                 beq   :diversi
                 lda   TmpW
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
                 rts
:diversi         lda   TmpW
                 jsr   MskQuanti
                 sta   MskRun
                 stz   MskRep
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
                 beq   :zero
                 dec   a
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   Pitch
                 rts
:zero            lda   #0
                 rts

*=======================================================================
* ZeroRoomBuf - black zpPix only. zpBg keeps the decoded room so turning
* the light on can copy it back instead of decompressing again.
*=======================================================================
ZeroRoomBuf      lda   CopyLen
                 beq   :fine
                 cmp   #4
                 bcc   :lento
                 lda   zpPix
                 tax
                 clc
                 adc   CopyLen
                 bcs   :lento
                 ldy   #0
                 lda   #0
                 sta   [zpPix],y
                 lda   CopyLen
                 sec
                 sbc   #3
                 sta   MvnC
                 lda   zpPix
                 tax
                 clc
                 adc   #2
                 tay
                 sep   #$20
                 mx    %10
                 lda   zpPix+2
                 sta   :mv1+1
                 sta   :mv1+2
                 rep   #$30
                 mx    %00
                 lda   MvnC
:mv1             mvn   $00,$00
                 phk
                 plb
                 rts
:lento           ldy   #0
                 lda   #0
:lp              sta   [zpPix],y
                 iny
                 iny
                 cpy   CopyLen
                 bcc   :lp
:fine            rts

*=======================================================================
* CopiaPixBg - snapshot zpPix onto zpBg (MVN, word loop if it wraps)
*=======================================================================
CopiaPixBg       lda   CopyLen
                 beq   :fine
                 dec   a
                 sta   MvnC
                 stz   MvnS
                 lda   zpPix
                 sta   MvnPtrS
                 lda   zpBg
                 sta   MvnPtrD
                 lda   zpPix+2
                 sta   MvnSrcB
                 lda   zpBg+2
                 sta   MvnDstB
                 jsr   MvnZp
                 bcc   :fine
                 ldy   #0
:lp              lda   [zpPix],y
                 sta   [zpBg],y
                 iny
                 iny
                 cpy   CopyLen
                 bcc   :lp
:fine            rts

* CopiaBgPix - put the clean background back into zpPix (lights on)
CopiaBgPix       lda   CopyLen
                 beq   :fine
                 dec   a
                 sta   MvnC
                 stz   MvnS
                 lda   zpBg
                 sta   MvnPtrS
                 lda   zpPix
                 sta   MvnPtrD
                 lda   zpBg+2
                 sta   MvnSrcB
                 lda   zpPix+2
                 sta   MvnDstB
                 jsr   MvnZp
                 bcc   :fine
                 ldy   #0
:lp              lda   [zpBg],y
                 sta   [zpPix],y
                 iny
                 iny
                 cpy   CopyLen
                 bcc   :lp
:fine            rts

*=======================================================================
* ConfineImmagini - where a room's pictures stop and its descriptions
*                   begin: the lowest entry of the second table
*=======================================================================
ConfineImmagini  ldy   #20
                 lda   [zpRaw],y
                 and   #$00FF
                 asl   a
                 sta   ConfN
                 lda   #$FFFF
                 sta   ObjConfine
                 lda   ConfN
                 beq   :fine
                 stz   ConfI
:lp              lda   #28
                 clc
                 adc   ConfN
                 adc   ConfI
                 tay
                 lda   [zpRaw],y
                 beq   :prossimo
                 cmp   ObjConfine
                 bcs   :prossimo
                 sta   ObjConfine
:prossimo        lda   ConfI
                 clc
                 adc   #2
                 sta   ConfI
                 cmp   ConfN
                 bcc   :lp
:fine            rts

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
                 jsr   PrepSkipCloud8
                 jsr   DecodeRLE
                 stz   SkipCloud8
* An object carries a mask of its own, right after its picture, and it
* has to go into the plane over the room's. The bowl of wax fruit is
* where it showed: the bowl is painted into the room's background and is
* in the room's mask, so the table hides the character's legs and the
* bowl hides whatever is behind it. Picking it up lights the object,
* whose picture is that piece of table without the bowl - and whose mask
* is the table without the bowl too. Skipping it left the room's mask
* untouched, so an invisible bowl went on eating a piece of anyone who
* stood there, and coming back into the room did not help: the shape is
* in the room's own data.
                 jsr   DecodeMaschera

:prossimo        lda   ObjIdx
                 sec
                 sbc   #2
                 sta   ObjIdx
                 bmi   :fine
                 brl   :lp
:fine            rts

* PrepSkipCloud8 - Zak room 49 objects only: colour 8 = transparent.
* Room background decode must leave SkipCloud8 clear (the cloud IS 8).
PrepSkipCloud8   stz   SkipCloud8
                 lda   IsZak
                 beq   :no
                 lda   CurRoom
                 cmp   #49
                 bne   :no
                 lda   #1
                 sta   SkipCloud8
:no              rts

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
* SkipCloud8 (set by the object drawers, not here): Zak room 49 object
* colour 8 is cloud grey; writing it over object 700 erased the arm.
* Must NOT be set while decoding the room background itself.
DecodeRLE        lda   zpRaw
                 clc
                 adc   SrcOff
                 sta   zpSrc
                 lda   zpRaw+2
                 adc   #0
                 sta   zpSrc+2
                 lda   zpSrc
                 sta   SrcBase
                 stz   SrcIdx

                 stz   RunLen
                 stz   ColHi
                 stz   ColLo
                 stz   Dither
                 stz   ColX

                 lda   BlkH
                 beq   :colonna
                 asl   a                    ; the tables are a word apart,
                 sta   RigaXF               ; so one index serves for them
                 ldx   #0                   ; and for RowOff
                 sep   #$20
                 mx    %10
                 lda   #0
:pulisci         sta   DitLo,x
                 sta   DitHi,x
                 inx
                 cpx   RigaXF
                 bcc   :pulisci
                 rep   #$20
                 mx    %00

:colonna         lda   ColX
                 clc
                 adc   DstX
                 lsr   a                    ; two pixels per byte
                 sta   ColByte
                 lda   DstY
                 asl   a
                 tax
                 lda   RowOff,x
                 clc
                 adc   ColByte
                 sta   PixOff
                 stz   Riga

* The fast loops below take the row's offset straight out of RowOff,
* which counts from row zero, so the column's own first byte and the
* block's top row are folded into a pointer once, here.
                 lda   zpPix
                 clc
                 adc   PixOff
                 sta   zpPix2
                 lda   zpPix+2
                 adc   #0
                 sta   zpPix2+2
                 stz   RigaX

                 lda   ColX
                 and   #1
                 sta   Dispari

* Whether a column falls outside the piece being redone depends on the
* column, not on the pixel: decided here, once, instead of twice per
* pixel down the whole object. Redrawing the background under a walking
* character clips every object it touches, and most of their columns are
* outside - that test was the larger half of the decode.
                 stz   ColFuori
                 lda   ClipOn
                 beq   :dentrox
                 lda   ColX
                 clc
                 adc   DstX
                 cmp   ClipX1
                 bcc   :fuorix
                 cmp   ClipX2
                 bcc   :dentrox
:fuorix          lda   #1
                 sta   ColFuori
:dentrox         anop

* Clipping and the Zak cloud both need a decision per pixel, and both
* happen on small pieces: they go the slow way. Everything else - the
* rooms, the costumes, every object drawn whole - takes the loops below.
                 lda   ClipOn
                 ora   SkipCloud8
                 beq   :veloce
                 brl   :pixel

* One stretch at a time: as many rows as the run has left, or as many as
* the column has left. Whether the run carries its own colour and whether
* the column is an odd one do not change inside a stretch, so they are
* decided here instead of once per pixel. Inside a loop the accumulator
* stays eight bits, the row index serves for both the dithering tables
* and RowOff, and nothing is added or tested.
:veloce          lda   RigaX
                 cmp   RigaXF
                 bcc   :ancora
                 brl   :finecol
:ancora          lda   RunLen
                 bne   :quanto
                 jsr   NextRun
                 lda   RunLen
                 beq   :ancora              ; a length of zero: read again

:quanto          asl   a                    ; rows to words
                 clc
                 adc   RigaX
                 cmp   RigaXF
                 bcc   :limite
                 lda   RigaXF
:limite          sta   FineTratto
                 sec
                 sbc   RigaX
                 lsr   a
                 sta   FatteOra
                 lda   RunLen
                 sec
                 sbc   FatteOra
                 sta   RunLen

                 ldx   RigaX
                 lda   Dither
                 bne   :ricorda

* A run that carries its own colour: it goes into the two tables, for
* the dithered runs that come after it in this column, and on the
* picture.
                 sep   #$20
                 mx    %10
                 lda   Dispari
                 bne   :nuovadis
:nuovapar        lda   ColLo
                 sta   DitLo,x
                 lda   ColHi
                 sta   DitHi,x
                 ldy   RowOff,x
                 sta   [zpPix2],y           ; even column: the high nibble
                 inx
                 inx
                 cpx   FineTratto
                 bcc   :nuovapar
                 bra   :fattotratto

:nuovadis        lda   ColLo
                 sta   DitLo,x
                 lda   ColHi
                 sta   DitHi,x
                 ldy   RowOff,x
                 lda   ColLo                ; odd: the low nibble is added
                 ora   [zpPix2],y
                 sta   [zpPix2],y
                 inx
                 inx
                 cpx   FineTratto
                 bcc   :nuovadis
                 bra   :fattotratto

* A dithered run: every row keeps the colour it was left with.
:ricorda         sep   #$20
                 mx    %10
                 lda   Dispari
                 bne   :vecchiadis
:vecchiapar      ldy   RowOff,x
                 lda   DitHi,x
                 sta   [zpPix2],y
                 inx
                 inx
                 cpx   FineTratto
                 bcc   :vecchiapar
                 bra   :fattotratto

:vecchiadis      ldy   RowOff,x
                 lda   DitLo,x
                 ora   [zpPix2],y
                 sta   [zpPix2],y
                 inx
                 inx
                 cpx   FineTratto
                 bcc   :vecchiadis

:fattotratto     rep   #$30
                 mx    %00
                 lda   FineTratto
                 sta   RigaX
                 brl   :veloce


:pixel           lda   ColX
                 and   #1
                 sta   Dispari
:pixlp           lda   RunLen
                 bne   :dentro
                 jsr   NextRun
:dentro          lda   Dither
                 bne   :usatab

                 lda   Riga                 ; new colour: goes into the two
                 asl   a                    ; tables, for this row
                 tax
                 sep   #$20
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
                 lda   ColFuori
                 bne   :niente
                 lda   Riga
                 clc
                 adc   DstY
                 cmp   ClipY1
                 bcc   :niente
                 cmp   ClipY2
                 bcc   :scrivi
:niente          bra   :scritto2

:scrivi          lda   Riga
                 asl   a
                 tax
                 ldy   PixOff
                 sep   #$20
                 mx    %10
                 lda   SkipCloud8
                 beq   :scrok
                 lda   Dispari
                 bne   :scrlo
                 lda   DitHi,x
                 cmp   #$80
                 beq   :scritto
                 bra   :scrok
:scrlo           lda   DitLo,x
                 cmp   #8
                 beq   :scritto
:scrok           lda   Dispari
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
                 bcs   :finecol
                 brl   :pixlp

:finecol         inc   ColX
                 lda   ColX
                 cmp   BlkW
                 bcs   :fine
                 brl   :colonna
:fine            lda   zpSrc
                 sec
                 sbc   SrcBase
                 sta   SrcIdx
                 lda   SrcBase
                 sta   zpSrc
                 rts

*=======================================================================
* NextRun - the next group of identical pixels
*=======================================================================
* The pointer is walked rather than indexed, which is cheaper; but a
* room is forty thousand bytes and the Memory Manager puts it where it
* likes, so it can run off the end of a bank. The carry has to reach the
* bank byte.
NextRun          sep   #$20
                 mx    %10
                 lda   [zpSrc]
                 inc   zpSrc
                 bne   :oklo
                 inc   zpSrc+1
                 bne   :oklo
                 inc   zpSrc+2
:oklo            sta   RunByte
                 rep   #$20
                 mx    %00
                 lda   RunByte
                 and   #$00FF
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
                 sep   #$20
                 mx    %10
                 lda   [zpSrc]
                 inc   zpSrc
                 bne   :ok2
                 inc   zpSrc+1
                 bne   :ok2
                 inc   zpSrc+2
:ok2             sta   RunLen
                 stz   RunLen+1
                 rep   #$20
                 mx    %00
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
* SetTextColor - A = colour. Tables for all sixteen colours are built
* once; afterwards this is a 32-byte copy, or nothing if the colour
* did not change.
SetTextColor     and   #$000F
                 cmp   TxtCol
                 bne   :cambia
                 rts
:cambia          sta   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a                    ; *32
                 tax
                 ldy   #0
:cp              lda   EspPal,x
                 sta   EspTab,y
                 inx
                 inx
                 iny
                 iny
                 cpy   #32
                 bcc   :cp
                 rts

InitEspPal       stz   TxtCol
:col             jsr   BuildEsp
                 lda   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 tax
                 ldy   #0
:cp              lda   EspTab,y
                 sta   EspPal,x
                 inx
                 inx
                 iny
                 iny
                 cpy   #32
                 bcc   :cp
                 inc   TxtCol
                 lda   TxtCol
                 cmp   #16
                 bcc   :col
                 lda   #$FFFF
                 sta   TxtCol
                 rts

BuildEsp         lda   TxtCol
                 and   #$000F
                 sta   TxtCol
                 stz   NibIdx
                 ldx   #0
:nib             stz   Byte0
                 stz   Byte1
                 txa
                 and   #$0008
                 beq   :p1
                 lda   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   Byte0
:p1              txa
                 and   #$0004
                 beq   :p2
                 lda   Byte0
                 ora   TxtCol
                 sta   Byte0
:p2              txa
                 and   #$0002
                 beq   :p3
                 lda   TxtCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 sta   Byte1
:p3              txa
                 and   #$0001
                 beq   :salva
                 lda   Byte1
                 ora   TxtCol
                 sta   Byte1
:salva           lda   Byte1
                 xba
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
                 bcs   :incolonna
                 rts
* Never write past the last column. A glyph at column 40+ lands on the
* next scanline's SHR control bytes and paints red stripes across the
* panel, so clamp here rather than trusting every caller to count.
:incolonna       pha
                 lda   TxtX
                 cmp   #40
                 pla
                 bcc   :disegna
                 rts
:disegna         asl   a
                 asl   a
                 asl   a                    ; eight bytes per character
                 sta   FontIdx

                 lda   TxtY
                 cmp   TxtYCache
                 beq   :rowok
                 sta   TxtYCache
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
                 sta   TxtRowBase
:rowok           lda   TxtX
                 asl   a
                 asl   a
                 clc
                 adc   TxtRowBase
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

* Same as DrawChar, but only the ink bits: empty cells stay the paper
* colour. The game font writes a whole 8x8 stamp, which on a white
* dialog turns every letter into a black brick.
DrawCharInk      and   #$007F
                 cmp   #33
                 bcs   :incolonna
                 rts
:incolonna       pha                        ; same column clamp as DrawChar
                 lda   TxtX
                 cmp   #40
                 pla
                 bcc   :go
                 rts
:go              asl   a
                 asl   a
                 asl   a
                 sta   FontIdx
                 lda   TxtX
                 asl   a
                 asl   a
                 asl   a
                 sta   InkX0
                 lda   TxtY
                 sta   InkY
                 stz   Conta8
:riga            ldx   FontIdx
                 sep   #$20
                 mx    %10
                 lda   FontData,x
                 sta   Riga8
                 rep   #$20
                 mx    %00
                 inc   FontIdx
                 lda   InkX0
                 sta   InkX
                 lda   #8
                 sta   BitN
:bit             sep   #$20
                 mx    %10
                 asl   Riga8
                 rep   #$20
                 mx    %00
                 bcc   :skip
                 jsr   PlotInk
:skip            inc   InkX
                 dec   BitN
                 bne   :bit
                 inc   InkY
                 inc   Conta8
                 lda   Conta8
                 cmp   #8
                 bcc   :riga
                 rts

* Pixel (InkX,InkY) in TxtCol. Leaves the other nibble of the byte.
PlotInk          lda   InkY
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
                 sta   TmpW
                 lda   InkX
                 lsr   a
                 clc
                 adc   TmpW
                 tax
                 lda   TxtCol
                 and   #$000F
                 sta   InkCol
                 sep   #$20
                 mx    %10
                 ldal  SHRBASE,x
                 tay
                 lda   InkX
                 and   #1
                 bne   :odd
                 tya
                 and   #$0F
                 sta   TmpW
                 lda   InkCol
                 asl   a
                 asl   a
                 asl   a
                 asl   a
                 ora   TmpW
                 bra   :wr
:odd             tya
                 and   #$F0
                 ora   InkCol
:wr              stal  SHRBASE,x
                 rep   #$20
                 mx    %00
                 rts

DrawCStr         ldy   #0
:lp              sty   StrIdx
                 lda   [zpStr],y
                 and   #$00FF
                 beq   :fine
                 jsr   DrawCharInk
                 inc   TxtX
                 ldy   StrIdx
                 iny
                 bra   :lp
:fine            rts

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
DrawMsg          PushPtr PuntoMou
                 _GetMouse
                 lda   PuntoMou             ; Y first
                 cmp   #ROOMTOP+8
                 bcs   :libero              ; pointer is in the room
                 _HideCursor
                 jsr   DrawMsgReal
                 _ShowCursor
                 rts
:libero          jmp   DrawMsgReal

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
                 stz   CredVis
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
                 bne   :acceso
                 rts
:acceso          lda   IsZak                ; Maniac keeps the camera line;
                 beq   :stanza              ; Zak lists actors in the room
                 brl   DrawDbgZak
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

*=======================================================================
* DrawDbgZak - D key line for Zak only: room + actors in it
*   r<room> <id>:<cost>@<x>,<y>e<elev>f<face> ...
* Stops before column 35 so DrawStr never wraps off the bottom
* (wrapping corrupts the SHR scanline control bytes → red stripes).
*=======================================================================
DrawDbgZak       stz   TxtX
                 lda   #DBGTOP
                 sta   TxtY
                 lda   SempreCompone        ; F: whole room every frame
                 beq   :nofull
                 lda   #MsgFull
                 jsr   ScriviDbg
:nofull          lda   #MsgR
                 jsr   ScriviDbg
                 lda   CurRoom
                 jsr   DrawNum
* With F on, the line says what the two objects of the power-cord puzzle
* are doing instead of listing the characters: the whole byte of each,
* so both the state nibble and the flags are visible. If the numbers do
* not move when the cord is used on the outlet, the script never set
* them and nothing about drawing is to blame.
                 lda   SempreCompone
                 beq   :attori
                 lda   #MsgO1
                 jsr   ScriviDbg
                 lda   #20
                 jsr   DbgStatoObj
                 lda   #MsgO2
                 jsr   ScriviDbg
                 lda   #118
                 jsr   DbgStatoObj
                 lda   #MsgO3
                 jsr   ScriviDbg
                 lda   #131
                 jsr   DbgStatoObj
                 rts
:attori          stz   DbgIdx
:lp              lda   TxtX                 ; a whole actor record still fits
                 cmp   #20
                 bcc   :c_e
                 rts
:c_e             ldx   DbgIdx
                 lda   ActRoom,x
                 cmp   CurRoom
                 bne   :next
                 lda   ActCost,x
                 and   #$00FF
                 beq   :next
                 jsr   DbgZakUno
:next            lda   DbgIdx
                 clc
                 adc   #2
                 sta   DbgIdx
                 cmp   #NACT*2
                 bcc   :lp
                 rts

* A = object number: its whole flag byte onto the debug line.
DbgStatoObj      tax
                 sep   #$20
                 mx    %10
                 lda   ObjFlag,x
                 rep   #$20
                 mx    %00
                 and   #$00FF
                 jmp   DrawNum

* One actor from DbgIdx onto the debug line (Zak only).
DbgZakUno        lda   #MsgSpazio
                 jsr   ScriviDbg
                 lda   DbgIdx
                 lsr   a
                 jsr   DrawNum
                 lda   #MsgColon
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActCost,x
                 and   #$00FF
                 jsr   DrawNum
                 lda   #MsgAt
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActX,x
                 jsr   DrawNum
                 lda   #MsgComma
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActY,x
                 jsr   DrawNum
                 lda   #MsgZe
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActElev,x
                 jsr   DrawNum
                 lda   #MsgZf
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActFace,x
                 jsr   DrawNum
* b = the walk box he stands on, k = the mask that box asks for. Those
* two decide whether the costume is cut against the room's plane, which
* is what goes wrong on the stairs.
                 lda   #MsgZb
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActBox,x
                 jsr   DrawNum
                 lda   #MsgZk
                 jsr   ScriviDbg
                 ldx   DbgIdx
                 lda   ActBox,x
                 jsr   MascheraCasella
                 jmp   DrawNum

* The debug labels all live in the same bank: the low word is enough to
* pick one.
ScriviDbg        sta   zpStr
                 lda   TxtX                 ; stop at field boundaries, so a
                 cmp   #36                  ; long record ends on a whole field
                 bcs   :pieno                ; instead of a chopped number
                 lda   #^MsgR
                 sta   zpStr+2
                 jmp   DrawStr
:pieno           rts
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
* Zak: only under the Lucasfilm splash (room 46, camera on the left
* half). VAR_CAMERA_POS_X is in strips of eight, so 40 is the middle.
DrawCredit       lda   InCarico             ; not on the black "Loading..."
                 bne   :no
                 jsr   CredSi
                 bcs   :no
                 jsr   CredDisegna
                 lda   #1
                 sta   CredVis
:no              rts

* Called every frame: keep the splash credit painted (DrawRoom does not
* touch the panel, but a message or a load can rub it out), and rub it
* out as soon as the camera leaves the logo.
AggiornaCredit   lda   InCarico
                 bne   :off
                 jsr   CredSi
                 bcc   :on
:off             lda   CredVis
                 beq   :fine
                 jsr   CredPulisci
                 stz   CredVis
                 rts
:on              jsr   CredDisegna
                 lda   #1
                 sta   CredVis
:fine            rts

CredSi           lda   IsZak
                 beq   :mm
                 lda   CurRoom
                 cmp   #46
                 bne   :no
                 lda   Vars+VO_CAMPOS
                 cmp   #40
                 bcc   :si
:no              sec
                 rts
:si              clc
                 rts
:mm              lda   CurRoom
                 cmp   #45
                 bne   :no
                 jsr   CiSonoVerbi          ; title / kid select: no verbs yet
                 bcc   :no
                 clc
                 rts

CredDisegna      lda   #15
                 jsr   SetTextColor
                 lda   #CRED1TOP
                 sta   TxtY
                 lda   #MsgCred1
                 jsr   CredRiga
                 lda   #MsgCred2
                 jsr   CredRiga
                 lda   #15
                 jmp   SetTextColor

CredPulisci      lda   #CRED1TOP*SCRW
                 sta   FillStart
                 lda   #DBGTOP*SCRW
                 sta   FillEnd
                 lda   #$0000
                 jmp   FillArea

* Why the game did not start, when 00.LFL is not one we can play.
IdxMsg           lda   #15
                 jsr   SetTextColor
                 lda   #80
                 sta   TxtY
                 lda   IdxV1
                 beq   :altro
                 lda   #MsgIdxV1a
                 jsr   CredRiga
                 lda   #MsgIdxV1b
                 bra   :tasto
:altro           lda   #MsgIdxErr
:tasto           jsr   CredRiga
                 lda   TxtY
                 clc
                 adc   #8
                 sta   TxtY
                 lda   #MsgIdxTasto
                 jmp   CredRiga

* A = one credit line in this bank: centred at TxtY, then one row down.
CredRiga         sta   zpStr
                 lda   #^MsgCred1
                 sta   zpStr+2
                 jsr   DrawStrCenter
                 lda   TxtY
                 clc
                 adc   #8
                 sta   TxtY
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
                 lda   #INVTOP              ; no verbs: there is room
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
                 lda   TxtX                 ; a 40-char line has already
                 beq   :avanti              ; wrapped: do not skip a row
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
Shutdown         jsr   FermaSf
                 lda   SndOn
                 beq   :nosnd
                 PushWord #$FFFF
                 _FFStopSound
                 _SoundShutDown
:nosnd           _EMShutDown
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

* Costume 31 pointing cel +104 with a solid armpit (see PatchCost31Arm).
Cel31Arm         hex   1400160042001e00000000000a620a0961e2610909e3610909e3611108036611
                 hex   e26111080162e611e261110861e811e2611101130461e811e2611603e911e261
                 hex   1603ea11e161160361e911e161160361ea1161160301ea116116030261e26111
                 hex   e411611603036311e411611601120a11e1611441c1130a11e1011201c4120961
                 hex   e2011103c3120ae107c2020016

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

EofParm          dw    2
EofRef           dw    $0000
EofLen           ds    4

FFSynth          anop
FFWave           adrl  $00000000
FFPages          dw    $0000
FFFreq           dw    $0000
FFDoc            dw    $0000
FFBuf            dw    $0000                ; bytes, power of two (TN #37)
FFNext           adrl  $00000000
FFVol            dw    $0000                ; 0-255, after nextWave

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
* are called L00.LFL instead of 00.LFL. The folder is chosen at startup.
PathA            dw    0
                 ds    62
PathB            dw    0
                 ds    62
GamePre          dw    2
                 asc   'MM'
                 ds    14
PathTail         ds    16
SufSfxI          asc   'SFXI'
                 hex   00
SufSfx           asc   'SFX'
SufMus0          asc   'MUS0'
                 hex   00
SufMusQ          asc   'MUSQ'
                 hex   00
SufSave          asc   'SAVE'
SufL00           asc   'L00.LFL'
                 hex   00

SfPrompt         str   'Open the L00.LFL file for the game you want to run:'  ; Pascal string
SfReply          anop
SfGood           dw    0
SfType           dw    0
SfAux            ds    4
SfName           ds    16
MsgSfErr         asc   'Toolbox error $'
                 hex   00
MsgSfTasto       asc   'Opening MM - press a key'
                 hex   00

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
* Zak D-debug separators (same bank as MsgR for ScriviDbg)
MsgColon         asc   ':'
                 dfb   0
MsgAt            asc   '@'
                 dfb   0
MsgComma         asc   ','
                 dfb   0
MsgZe            asc   'e'
                 dfb   0
MsgFull          asc   'F '
                 dfb   0
MsgO1            asc   ' c20='
                 dfb   0
MsgO2            asc   ' p118='
                 dfb   0
MsgO3            asc   ' 131='
                 dfb   0
MsgZb            asc   ' b'
                 dfb   0
MsgZk            asc   ' k'
                 dfb   0
MsgZf            asc   'f'
                 dfb   0
MsgZo            asc   'o'
                 dfb   0
MsgRoom          asc   'room '
                 dfb   0
MsgBad           asc   'unknown opcode: '
                 dfb   0
MsgIIGS          asc   'IIGS porting by Michele Di Paola'
                 hex   00
MsgMusica        asc   '........................'
                 hex   00
MsgCred1         asc   'SCUMMv2 interpreter for Apple IIGS'
                 dfb   0
MsgCred2         asc   'by Michele Di Paola'
                 dfb   0
MsgIdxV1a        asc   'These are SCUMM V1 game files:'
                 dfb   0
MsgIdxV1b        asc   'only V2 is supported for now.'
                 dfb   0
MsgIdxErr        asc   'L00.LFL is not a SCUMM V2 index.'
                 dfb   0
MsgIdxTasto      asc   'Press a key to quit.'
                 dfb   0
MsgLoad          asc   'Loading...'
                 dfb   0
MsgAudio         asc   'snd:0 sfx:0 te:0 se:0 n:00'
                 dfb   0
MsgQuit1         asc   'Quit the game?'
                 dfb   0
MsgQuit2         asc   'Y = yes     N = no'
                 dfb   0
MsgPausa         asc   'Paused  -  SPACE to continue'
                 dfb   0
MsgRest1         asc   'Restart the game?'
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
* The script slots: seven tables of twelve words, one after the other in
* memory. Without them a saved game came back with nothing running - no
* timers, no background scripts - and Edna stood at her fridge for ever,
* because the door of the kitchen only sets her on you while script 152
* is still counting.
                 dw    SlotNum,168
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
                 jsr   MettiDaParte         ; the screen's own slot: the file
                 stz   DiscoIdx             ; is about to write over it
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
:finito                           jsr   ChiudiPos
                 jsr   RiattivaScript       ; and the scripts start again
                 lda   ScrVerbi             ; the verb panel the screen
                 jsr   StartScript          ; had wiped
                 clc
                 rts
:male            sec
                 rts

*=======================================================================
* MettiDaParte / RiattivaScript - the scripts across a load
*=======================================================================
* The slot tables are written straight from the file, and one of those
* slots is the disk screen itself, which still has to reach its
* endCutscene. So it is put aside first and given back its place
* afterwards, and whatever the saved game had in that slot is moved
* somewhere else.
*
* Only the code's whereabouts are on disk, never the code: every script
* that was running is read in again from the game's own files, into the
* piece of the store its slot owns. Scripts that lived inside a room are
* dropped - changing room throws those away in any case, and the room is
* about to be entered again from the top.
MettiDaParte     ldx   CurSlot
                 lda   SlotNum,x
                 sta   MioNum
                 lda   SlotWhere,x
                 sta   MioWhere
                 lda   SlotPC,x
                 sta   MioPC
                 lda   SlotBaseT,x
                 sta   MioBase
                 lda   SlotDelLo,x
                 sta   MioDelLo
                 lda   SlotDelHi,x
                 sta   MioDelHi
                 rts

RiattivaScript   ldx   CurSlot              ; what the file left in my slot
                 lda   SlotStat,x
                 sta   AltroStat
                 lda   SlotNum,x
                 sta   AltroNum
                 lda   SlotPC,x
                 sta   AltroPC
                 lda   SlotWhere,x
                 sta   AltroWhere
                 lda   SlotDelLo,x
                 sta   AltroDelLo
                 lda   SlotDelHi,x
                 sta   AltroDelHi

                 ldx   CurSlot              ; and my own place back
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   MioNum
                 sta   SlotNum,x
                 lda   MioWhere
                 sta   SlotWhere,x
                 lda   MioPC
                 sta   SlotPC,x
                 lda   MioBase
                 sta   SlotBaseT,x
                 lda   MioDelLo
                 sta   SlotDelLo,x
                 lda   MioDelHi
                 sta   SlotDelHi,x

* the one that was thrown out finds another slot, if it was a real one
                 lda   AltroStat
                 beq   :nessunaltro
                 lda   AltroWhere
                 bne   :nessunaltro         ; only the global ones come back
                 jsr   FreeSlot
                 bcs   :nessunaltro
                 asl   a
                 tax
                 lda   #VIVO
                 sta   SlotStat,x
                 lda   AltroNum
                 sta   SlotNum,x
                 stz   SlotWhere,x
                 lda   AltroPC
                 sta   SlotPC,x
                 lda   AltroDelLo
                 sta   SlotDelLo,x
                 lda   AltroDelHi
                 sta   SlotDelHi,x

:nessunaltro     stz   RiIdx                ; now read every code back in
:lp              ldx   RiIdx
                 cpx   CurSlot
                 beq   :prossimo
                 lda   SlotStat,x
                 beq   :prossimo
                 lda   SlotWhere,x
                 beq   :dalpool
                 lda   #MORTO               ; room and object scripts go
                 sta   SlotStat,x
                 bra   :prossimo

:dalpool         lda   SlotNum,x
                 sta   ScrNo
                 cmp   NumScr
                 bcs   :buttalo
                 asl   a
                 tax
                 lda   ScrOffs,x
                 sta   ScrOff
                 cmp   #$FFFF
                 beq   :buttalo
                 ora   #0
                 beq   :buttalo
                 ldx   ScrNo
                 sep   #$20
                 mx    %10
                 lda   ScrRoom,x
                 sta   ScrRm
                 rep   #$20
                 mx    %00
                 lda   ScrRm
                 and   #$00FF
                 sta   FileNo
                 lda   RiIdx
                 lsr   a
                 jsr   SlotBase
                 sta   PoolOff
                 jsr   LoadResource
                 bcs   :buttalo
                 ldx   RiIdx
                 lda   PoolOff
                 clc
                 adc   #4                   ; past the resource header
                 sta   SlotBaseT,x
                 bra   :prossimo

:buttalo         ldx   RiIdx
                 lda   #MORTO
                 sta   SlotStat,x
:prossimo        lda   RiIdx
                 clc
                 adc   #2
                 sta   RiIdx
                 cmp   #SLOTS*2
                 bcs   :basta
                 brl   :lp
:basta           rts

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
PosPath          ldx   #0
:c               lda   SufSave,x
                 and   #$00FF
                 sta   PathTail,x
                 inx
                 cpx   #4
                 bcc   :c
                 lda   PosI
                 clc
                 adc   #'0'
                 sep   #$20
                 mx    %10
                 sta   PathTail+4
                 stz   PathTail+5
                 rep   #$20
                 mx    %00
                 jsr   MkPaths
                 lda   PathUsata
                 bne   :seconda
                 lda   #PathA
                 sta   PathPos
                 lda   #^PathA
                 sta   PathPos+2
                 rts
:seconda         lda   #PathB
                 sta   PathPos
                 lda   #^PathB
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

Firma            asc   'SCUMMGS2'

OpTab            anop
                 dw    hStop,hPutActor,hStartMusic,hActorRoom   ; $00
                 dw    hUnless,hDrawObject,hResB,hSetState   ; $04
                 dw    hUnless,hFaceActor,hMoveInd,hObjPrep   ; $08
                 dw    hRes,hWalkActor,hPutAtObj,hUnlessState   ; $0C
                 dw    hGetOwner,hAnimate,hPanCamera,hActorOps   ; $10
                 dw    hPrint,hActorFromPos,hRandom,hClearState   ; $14
                 dw    hGoto,hSentence,hMove,hSetBit   ; $18
                 dw    hStartSound,hClassOf,hWalkTo,hUnlessState   ; $1C
                 dw    hStopMusic,hPutActor,hSaveLoad,hGetActY   ; $20
                 dw    hRoomEgo,hDrawObject,hVarRange,hSetState   ; $24
                 dw    hUnless,hSetOwner,hAddInd,hUnoB   ; $28
                 dw    hAssignB,hPutInRoom,hDelay,hUnlessState   ; $2C
                 dw    hBoxFlags,hGetBit,hSetCamera,hRoomOps   ; $30
                 dw    hGetDist,hFindObject,hWalkToObj,hSetState   ; $34
                 dw    hUnless,hSentence,hSub,hWaitActor   ; $38
                 dw    hStopSound,hSetElev,hWalkTo,hUnlessState   ; $3C
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
                 dw    hIsSound,hDueB,hWalkTo,hUnlessState   ; $7C
                 dw    hBreak,hPutActor,hStartMusic,hActorRoom   ; $80
                 dw    hUnless,hDrawObject,hResB,hSetState   ; $84
                 dw    hUnless,hFaceActor,hMoveInd,hObjPrep   ; $88
                 dw    hRes,hWalkActor,hPutAtObj,hUnlessState   ; $8C
                 dw    hGetOwner,hAnimate,hPanCamera,hActorOps   ; $90
                 dw    hPrint,hActorFromPos,hRandom,hClearState   ; $94
                 dw    hRestart,hSentence,hMove,hSetBit   ; $98
                 dw    hStartSound,hClassOf,hWalkTo,hUnlessState   ; $9C
                 dw    hStop,hPutActor,hSaveLoad,hGetActY   ; $A0
                 dw    hRoomEgo,hDrawObject,hVarRange,hSetState   ; $A4
                 dw    hUnless,hSetOwner,hAddInd,hUnoB   ; $A8
                 dw    hNop,hPutInRoom,hWaitMsg,hUnlessState   ; $AC
                 dw    hBoxFlags,hGetBit,hSetCamera,hRoomOps   ; $B0
                 dw    hGetDist,hFindObject,hWalkToObj,hSetState   ; $B4
                 dw    hUnless,hSentence,hSub,hWaitActor   ; $B8
                 dw    hStopSound,hSetElev,hWalkTo,hUnlessState   ; $BC
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
                 dw    hIsSound,hDueB,hWalkTo,hUnlessState   ; $FC

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
IdxV1            ds    2      ; 00.LFL is a SCUMM V1 index
InCarico         ds    2      ; 1 while the black "Loading..." is up
IsZak            ds    2      ; the game is Zak McKracken
ScrVerbi         ds    2      ; script that rebuilds verbs after save screen
CredVis          ds    2      ; the splash credit is on the panel
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
SfOn             ds    2
SfDPHandle       ds    4
SfDPAddr         ds    2
SfErr            ds    2
HexVal           ds    2
InkX             ds    2
InkY             ds    2
InkX0            ds    2
InkCol           ds    2
BitN             ds    2
Capo             ds    CAPOLEN
CutRoom          ds    2      ; the room before a cutscene
CutCam           ds    2
CutLiv           ds    2      ; nested cutscene() count; ESC must not quit
PadreCd          ds    2      ; walking an object's parent chain
PadreNo          ds    2
PadreMask        ds    2
PadreLen         ds    2
ClipOn           ds    2      ; draw only inside the rectangle
ColFuori         ds    2      ; this column is outside it altogether
ClipX1           ds    2
ClipX2           ds    2
ClipY1           ds    2
ClipY2           ds    2
RunNow           ds    2      ; pixels left in a fast RLE/cel run
CelLit           ds    2      ; bit 3 of lights: 0 = grey costumes
SlamDP           ds    2
SlamStack        ds    2
SlamPage         ds    2
SpecialeOra      ds    2      ; a special doSentence verb
NestSlot         ds    2      ; the slot to run here and now
NestLiv          ds    2      ; how deep the nesting has gone
NestNum          ds    2      ; which script the caller was
NestWhere        ds    2      ; and where his code lived
MioNum           ds    2      ; the disk screen's own slot,
MioWhere         ds    2      ; put aside while the file is read
MioPC            ds    2
MioBase          ds    2
MioDelLo         ds    2
MioDelHi         ds    2
AltroNum         ds    2      ; and what the file had in it
AltroStat        ds    2
AltroWhere       ds    2
AltroPC          ds    2
AltroDelLo       ds    2
AltroDelHi       ds    2
RiIdx            ds    2      ; the slot being read back in
UserSt           ds    2      ; the high half of cursorCommand
UserIface        ds    2      ; sentence, inventory, verbs
InvOff           ds    2      ; the first object shown
InvQuanti        ds    2      ; how many were counted drawing
InvTot           ds    2
FrecciaY         ds    2
FrecciaVerso     ds    2
FrecciaR         ds    2
FrecciaN         ds    2
FrecciaM         ds    2
FrecciaP         ds    2
FrecciaX0        ds    2
FrecciaI         ds    2
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
DbgObjN          ds    2      ; room object count while listing lit ones
MaskSrc          ds    2      ; where the room's own mask begins
MascLen          ds    2      ; bytes in one mask plane for this room
Masc0Room        ds    2      ; the room whose clean mask zpMask0 holds
MascC1           ds    2      ; first and last byte column of the piece
MascNb           ds    2
MascY            ds    2
MascRett         ds    2      ; RidisegnaRett also stamps object masks
Alive            ds    2
Tick             ds    4
LastTick         ds    2
Elapsed          ds    2
EnterOff         ds    2
DirtyX           ds    2
DirtyY           ds    2
DirtyR           ds    2                    ; right edge
DirtyB           ds    2                    ; bottom edge
DirtyN           ds    2                    ; how many dirty rectangles
DirtyI           ds    2
DirtyXs          ds    8
DirtyYs          ds    8
DirtyRs          ds    8
DirtyBs          ds    8

ObjConfine       ds    2                    ; the pictures end here
CalcA            ds    2
CalcB            ds    2
ConfN            ds    2
ConfI            ds    2

MvnS             ds    2                    ; the block move's row
MvnD             ds    2
MvnC             ds    2
MvnX             ds    2
MvnRip           ds    2
MvnSrcB          ds    2
MvnDstB          ds    2
MvnPtrS          ds    2
MvnPtrD          ds    2
SrcBase          ds    2
AnimSeen         ds    64
MvnN             ds    2
MvnI             ds    2

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
CutIface         ds    2      ; panel bits saved across a cutscene
DbgOn            ds    2
SempreCompone    ds    2      ; F key: compose the whole room every frame
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
BoxLockOk        ds    2                    ; 1: locked+walk, 2: locked only
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
ActTutti         ds    2
ActSporco        ds    {25}*2
ActOrd           ds    {25}*2
ActNOrd          ds    2
DrawSoloSporco   ds    2
OrdI             ds    2
OrdJ             ds    2
OrdAct           ds    2
OrdY             ds    2
OrdTmp           ds    2
ActScan          ds    2
TmpAct           ds    2
EspandiN         ds    2
FillCol          ds    2
CelMbit          ds    2
CelMcol          ds    2
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
MsgKeep          ds    2      ; the last print ended with code 2
MsgDa            ds    2      ; where this print's own letters begin
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
EspPal           ds    16*32

VerbId           ds    {16}*2
VerbX            ds    {16}*2
VerbY            ds    {16}*2
VerbW            ds    {16}*2
VerbOn           ds    {16}*2
VerbName         ds    {16}*VERBNAME
VerbsDirty       ds    2
VerbIdx          ds    2
VerbXT           ds    2
VerbYT           ds    2
VerbCmd          ds    2
VerbHover        ds    2                    ; the verb under the pointer, plus one
VerbHoverLast    ds    2
SentHotLast      ds    2
InvHotLast       ds    2
HoverNow         ds    2
BestArea         ds    2
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
HitId            ds    2
HitW             ds    2
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
CelSkip          ds    2      ; 1 = this run is the file's colour 0
CelBuf           ds    128    ; one column of that cel, file colours
HatClip          ds    2      ; Zak costume 31: 18x22 flying hat (HatRowSkip)
HatPal6          ds    2      ; saved DrawPal[6] while painting the hat
TvSoftMask       ds    2      ; Zak room 2 TV: punch mask in glass only
TvColOk          ds    2      ; this column is inside the glass
TvSoftX1         ds    2
TvSoftX2         ds    2
TvSoftY1         ds    2
TvSoftY2         ds    2
SoftY            ds    2      ; scanline while punching TV mask
SkipCloud8       ds    2      ; Zak room 49: object colour 8 = transparent
RigaX            ds    2      ; the row inside the block, counted in words
RigaXF           ds    2
FineTratto       ds    2
FatteOra         ds    2
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
ActElev          ds    {25}*2
ActCost          ds    {25}*2
ActFace          ds    {25}*2
ActFrame         ds    {25}*2
ActVis           ds    {25}*2
ActTalk          ds    {25}*2
ActPal           ds    {25}*16            ; actorOps Color remap
DrawPal          ds    16                 ; that table, ready to draw with
ActDstX          ds    {25}*2
ActDstY          ds    {25}*2
ActMoving        ds    {25}*2
ActErr           ds    {25}*2
ActOldX          ds    {25}*2
ActOldY          ds    {25}*2
ActStuck         ds    {25}*2     ; frames spent walking without moving
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

DitLo            ds    {128}*2             ; a word apart, so the row index
DitHi            ds    {128}*2             ; serves for RowOff as well
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
ActMasc          ds    {NACT}*2             ; the last mask each one really had
CelRy            ds    2                    ; the pixel's row inside the room
CelVis           ds    2
TxtYCache        ds    2
TxtRowBase       ds    2
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
ObjInit          ds    {800}
ScrRoom          ds    {256}
ScrOffs          ds    {256}*2
CosRoom          ds    {64}
CosOffs          ds    {64}*2
SndRoom          ds    {128}
SndOffs          ds    {128}*2
SndOn            ds    2
SfxOn            ds    2
SndErr           ds    2
SfxErr           ds    2
SndTried         ds    2
SndPlays         ds    2
SndDP            ds    2
PlayingId        ds    2
SndWant          ds    2
SndWaitT         ds    2
MusFinta         ds    2      ; no score playing: the timer counts seconds
MusFintaT        ds    2      ; ticks towards the next second
SndWaitId        ds    2
SndLen           ds    2
SndLoop          ds    2
SfxPlayLo        ds    2
SfxPlayHi        ds    2
SfxHave          ds    2
SndBank          ds    2
SndPage          ds    2
SndVol           ds    2
SfxLvl           ds    2
GameDP           ds    2
MusReady         ds    2
MusOn            ds    2
MusId            ds    2
MusWant          ds    2
MusClock         ds    2
MusLoop          ds    2
MusTLen          ds    2
MusTmp           ds    2
MusPage          ds    2
MusPlayLo        ds    2
MusPlayHi        ds    2
MusEgoLast       ds    2
MusPend          ds    2
MusBurst         ds    2
MusFreq          ds    2
MusWSize         ds    2
MusOsc           ds    2
MusCh            ds    2
MusMute          ds    2
MusLvl           ds    2
MusEvTick        ds    2
VolTmp           ds    2
CometHold        ds    2
MusOneShot       ds    2
MusSlot          ds    2
MusLoadDuck      ds    2
MusCatch         ds    2
MusN             ds    8
MusPtr           ds    8
MusEnd           ds    8
MusLastPg        ds    8

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

