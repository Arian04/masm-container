.386
.model flat,stdcall
.stack 4096
ExitProcess proto, dwExitCode:dword

.code
main proc
	; mov eax, 1
	; xor ebx,ebx
	; int 80h
	INVOKE ExitProcess,1
main endp

END main
