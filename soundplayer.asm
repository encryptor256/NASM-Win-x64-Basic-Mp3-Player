%ifndef soundplayer_asm
%define soundplayer_asm
; ------------------------------------- ----------------------- ;
; Tell compiler to generate 64 bit code                         ;
; ------------------------------------- ----------------------- ;
bits 64
;###################################### ;
;# Data segment                            ;
;###################################### ;
segment .data use64


      align 16
      txt_code_start: db 10,"~[Program: start]",0

      align 16
      txt_code_error: db 10,"~ !!! [Program: error] !!!",0

      align 16
      txt_code_end: db 10,"~[Program: end]",0


      align 16
      txt_code_req: db 10,"~[Program requires sound file argument: 'program.exe file.mp3']",0

      align 16
      txt_musicplay:db "->",0
;###################################### ;
;# Code segment                         ;
;###################################### ;
segment .text use64
; ------------------------------------- ;
; externs, globals, constants           ;
; ------------------------------------- ;
      ;                               ;
      ; general                       ;
      ;                               ;
      ; ----------------------------- ;
      global main
      extern printf, malloc, memset, free
      extern ExitProcess, HeapAlloc
      ; ----------------------------- ;
      ;                               ;
      ; mpg123                        ;
      ;                               ;
      ; ----------------------------- ;
      MPG123_ENC_SIGNED_16 equ 208
      extern mpg123_init,       mpg123_exit, \
            mpg123_new,       mpg123_delete, \
            mpg123_open,       mpg123_getformat, \
            mpg123_format,       mpg123_format_none, \
            mpg123_close,      mpg123_read, \
            mpg123_scan
      ; ----------------------------- ;
      ;                               ;
      ; sdl 2                         ;
      ;                               ;
      ; ----------------------------- ;
      SDL_INIT_AUDIO      equ 0x00000010
      AUDIO_S16         equ 0x8010
      extern SDL_Init, SDL_Quit, \
            SDL_OpenAudio, SDL_PauseAudio, \
            SDL_Delay, SDL_CloseAudio
      ;
      ; Structure: SDL_AudioSpec
      ;
      SDL_AudioSpec.freq      equ (0)  ; 4x bytes, int;
      SDL_AudioSpec.format    equ (4)  ; 2x bytes, SDL_AudioFormat;
      SDL_AudioSpec.channels  equ (6)  ; 1x bytes, Uint8;
      SDL_AudioSpec.silence   equ (7)  ; 1x bytes, Uint8;
      SDL_AudioSpec.samples   equ (8)  ; 2x bytes, Uint16;
      SDL_AudioSpec.padding   equ (10) ; 2x bytes, Uint16;
      SDL_AudioSpec.size      equ (12) ; 4x bytes, Uint32;
      SDL_AudioSpec.callback  equ (16) ; 8x bytes, SDL_AudioCallback;
      SDL_AudioSpec.userdata  equ (24) ; 8x bytes, void*;
      SDL_AudioSpec_size      equ (32) ; ?x bytes
      ;
      ; Structure: SDLMPG123
      ; This structure is used to pass data
      ; to SDL_AudioSpec.callback procedure
      ;
      SDLMPG123.mpg123handle  equ (0)
      SDLMPG123.isplaying     equ (8)
      SDLMPG123.stopplaying   equ (16)
      SDLMPG123_size          equ (24)


; ------------------------------------- ;
; Procedure: main                       ;
; ------------------------------------- ;
align 16
main:
      %define argc            rbp + 8 * 2
      %define argv            rbp + 8 * 3
      %define mpg123handle    rbp - 8 * 9
      %define frequenc        rbp - 8 * 10
      %define channels        rbp - 8 * 11
      %define encoding        rbp - 8 * 12
      %define audiospecwant   rbp - 8 * 13
      %define audiospechave   rbp - 8 * 14
      %define sdlmpg123       rbp - 8 * 15
      ; ----------------------------- ;
      ;
      ; I: tasks are seperated by ';' and starts after task list
      ; Task list:
      ; // 0. Save arguments and create stack
      ; // 1. Print info: txt_code_start
      ; // 2. Check if supplied music file argument and test for error
      ; // 3. Init local some of variables
      ; // 4. Init mpg123 library and check for error
      ; // 5. Init sdl2 library and check for error
      ;
      mov [rsp+8*1],rcx
      mov [rsp+8*2],rdx
      push rbp
      mov rbp,rsp
      lea rsp,[rsp-8*20]
      ;
      mov rcx,txt_code_start
      call printf
      ;
      mov rdx,2
      mov rax,[argc]
      cmp rdx,rax
      jne .quiterrorreq
      ;
      xor rax,rax
      mov [frequenc],rax
      mov [channels],rax
      mov [encoding],rax
      ;
      call mpg123_init
      test rax,rax
      jnz .quiterror
      ;
      mov rcx,SDL_INIT_AUDIO
      call SDL_Init
      test rax,rax
      jnz .quiterror
      ; ----------------------------- ;
      ;
      ; MPG123
      ; // Create new mpg123 handle and test for error, and save handle
      ; // RDX: Get music file argument
      ; // Open and prepare to decode the specified file by filesystem path
      ; // Get music file format and test for error
      ; // Check format error
      ; // Set new format
      ; // Scan file - mpg123 dll file displays some error if happens,
      ;      in case shitty mp3 was provided.
      ;
      xor rcx,rcx
      xor rdx,rdx
      call mpg123_new
      test rax,rax
      jz .quiterror
      mov [mpg123handle],rax
      ;
      mov rdx,[argv]
      mov rdx,[rdx+8]
      ;
      mov rcx,rax
      call mpg123_open
      test rax,rax
      jnz .quiterror
      ;
      lea r9,[encoding]
      lea r8,[channels]
      lea rdx,[frequenc]
      mov rcx,[mpg123handle]
      call mpg123_getformat
      test rax,rax
      jnz .quiterror
      ;
      mov rax,MPG123_ENC_SIGNED_16
      mov rdx,[encoding]
      cmp rax,rdx
      jne .quiterror
      ;
      mov rcx,[mpg123handle]
      call mpg123_format_none
      mov r9,[encoding]
      mov r8,[channels]
      mov rdx,[frequenc]
      mov rcx,[mpg123handle]
      call mpg123_format
      ;
      mov rcx,[mpg123handle]
      call mpg123_scan
      ; ----------------------------- ;
      ;
      ; SDL2
      ; // Allocate sdlmpg123 structure, test for error and save handle
      ; // Fill sdlmpg123 structure
      ; // Allocate audiospecwant structure, test for error and save handle
      ; // Init audiospecwant structure
      ; // Fill audiospecwant structure
      ; // Allocate audiospechave structure, test for error and save handle
      ;
      mov rcx,SDLMPG123_size
      call malloc
      test rax,rax
      jz .quiterror
      mov [sdlmpg123],rax
      ;
      mov rdx,[mpg123handle]
      mov [rax+SDLMPG123.mpg123handle],rdx
      mov rdx,1
      mov [rax+SDLMPG123.isplaying],rdx
      xor rdx,rdx
      mov [rax+SDLMPG123.stopplaying],rdx
      ;
      mov rcx,SDL_AudioSpec_size
      call malloc
      test rax,rax
      jz .quiterror
      mov [audiospecwant],rax
      ;
      mov r8,SDL_AudioSpec_size
      xor rdx,rdx
      mov rcx,[audiospecwant]
      call memset
      ;
      mov rdx,[audiospecwant]
      mov eax,[frequenc]
      mov [rdx+SDL_AudioSpec.freq],eax
      mov ax,AUDIO_S16
      mov [rdx+SDL_AudioSpec.format],ax
      mov al,[channels]
      mov [rdx+SDL_AudioSpec.channels],al
      mov ax,4096
      mov [rdx+SDL_AudioSpec.samples],ax
      mov rax,sdl_audiobackstabprocedure
      mov [rdx+SDL_AudioSpec.callback],rax
      mov rax,[sdlmpg123]
      mov [rdx+SDL_AudioSpec.userdata],rax
      ;
      mov rcx,SDL_AudioSpec_size
      call malloc
      test rax,rax
      jz .quiterror
      mov [audiospechave],rax
      ; ----------------------------- ;
      ;
      ; SDL2 - audio
      ; // Open audio device and test for error
      ; // Check if specified format remains the same
      ; // Start audio play
      ; // Enter audio loop "audioloop"
      ; // Close audio
      ;
      mov rdx,[audiospechave]
      mov rcx,[audiospecwant]
      call SDL_OpenAudio
      test rax,rax
      jnz .quiterror
      ;
      mov rdx,[audiospecwant]
      mov rcx,[audiospechave]
      mov dx,[rdx+SDL_AudioSpec.format]
      mov cx,[rcx+SDL_AudioSpec.format]
      cmp cx,dx
      jne .quiterror
      ;
      xor rcx,rcx
      call SDL_PauseAudio
      ;
.audioloop:
      mov rcx,250
      call SDL_Delay
      mov rax,[sdlmpg123]
      mov al,[rax+SDLMPG123.isplaying]
      test al,al
      jnz .audioloop
      ;
      call SDL_CloseAudio
      ; ----------------------------- ;
      ;
      ; // Close and delete mp123 handle
      ; // Print info: txt_code_end
      ;
      mov rcx,[mpg123handle]
      call mpg123_close
      mov rcx,[mpg123handle]
      call mpg123_delete
      ;
      mov rcx,txt_code_end
      call printf


      jmp .quit

.quiterrorreq:

      ;
      ; // Print info: txt_code_req
      ;
      mov rcx,txt_code_req
      call printf

.quiterror:
      ;
      ; // Print info: txt_code_error
      ;
      mov rcx,txt_code_error
      call printf


.quit:
      ;
      ; // Release mpg123 library
      ; // Release sdl2 library
      ; // Exit process
      ; // Clear stack n quit
      ;
      call mpg123_exit
      ;
      call SDL_Quit
      ;
      xor rcx,rcx
      call ExitProcess
      ;
      lea rsp,[rsp+8*20]
      pop rbp
      ret
; ------------------------------------- ;
; Procedure: sdl_audiobackstabprocedure ;
; ------------------------------------- ;
align 16
sdl_audiobackstabprocedure:
      %define userdata        rbp + 8 * 2
      %define stream          rbp + 8 * 3
      %define len             rbp + 8 * 4
      %define bytesread       rbp - 8 * 6
      ; ----------------------------- ;
      ;
      ; // Save arguments and create stack
      ; // Init stream
      ; // Check if still playing
      ; // Check if last read was the last one
      ; // Print info message txt_musicplay
      ; // Read and decode audio data
      ; // Check if read is last one and update SDLMPG123.stopplaying
      ; // Check if bytes were read and if needed update SDLMPG123.isplaying
      ;
      mov [rsp+8*1],rcx
      mov [rsp+8*2],rdx
      mov [rsp+8*3],r8
      mov [rsp+8*4],r9
      push rbp
      mov rbp,rsp
      lea rsp,[rsp-8*6]
      ;
      mov rcx,[stream]
      xor rdx,rdx
      mov r8,[len]
      call memset
      ;
      mov rcx,[userdata]
      mov al,[rcx+SDLMPG123.isplaying]
      test al,al
      jz .quit
      ;
      mov al,[rcx+SDLMPG123.stopplaying]
      test al,al
      jnz .stopplay
      ;
      mov rcx,txt_musicplay
      call printf
      ;
      mov rcx,[userdata]
      mov rcx,[rcx+SDLMPG123.mpg123handle]
      mov rdx,[stream]
      mov r8,[len]
      lea r9,[bytesread]
      call mpg123_read
      ;
      test rax,rax
      mov rcx,[userdata]
      setnz byte [rcx+SDLMPG123.stopplaying]
      ;
      mov eax,[bytesread]
      test eax,eax
      jnz .quit
      ;
.stopplay:
      mov rcx,[userdata]
      mov al,0
      mov [rcx+SDLMPG123.isplaying],al
.quit:
      ; ----------------------------- ;
      ;
      ; // Clear stack n quit
      ;
      lea rsp,[rsp+8*6]
      pop rbp
      ret
%endif



