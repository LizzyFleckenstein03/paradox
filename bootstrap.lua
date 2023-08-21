#!/usr/bin/env lua

local macros = {
	["$"] = [[
mov rax, [r12]
sub r12, 8
mov [r12], rax
]],
	["%"] = [[
add r12, 8
]],
	["\\"] = [[
mov rax, [r12]
mov rbx, [r12+8]
mov [r12], rbx
mov [r12+8], rax
]],
	["@"] = [[
mov rax, [r12]
mov rbx, [r12+8]
mov rcx, [r12+16]
mov [r12], rcx
mov [r12+8], rax
mov [r12+16], rbx
]],
	["O"] = [[
mov rax, [r12]
lea rax, [r12+8*rax]
mov rax, [rax+8]
mov [r12], rax
]],
	["+"] = [[
mov eax, [r12]
add r12, 8
add [r12], eax
]],
	["-"] = [[
mov eax, [r12]
add r12, 8
sub [r12], eax
]],
	["*"] = [[
mov eax, [r12+8]
imul dword[r12]
add r12, 8
mov [r12], eax
]],
	["/"] = [[
xor edx, edx
mov eax, [r12+8]
idiv dword[r12]
add r12, 8
mov [r12], eax
]],
	["_"] = [[
neg dword[r12]
]],
	["&"] = [[
mov eax, [r12]
and eax, [r12+8]
add r12, 8
mov [r12], eax
]],
	["|"] = [[
mov eax, [r12]
or eax, [r12+8]
add r12, 8
mov [r12], eax
]],
	["~"] = [[
not dword[r12]
]],
	[">"] = [[
mov ebx, 0
mov ecx, -1
add r12, 8
mov eax, [r12]
cmp eax, [r12-8]
cmovg ebx, ecx
mov [r12], ebx
]],
	["="] = [[
mov ebx, 0
mov ecx, -1
add r12, 8
mov eax, [r12]
cmp eax, [r12-8]
cmove ebx, ecx
mov [r12], ebx
]],
	["!"] = [[
add r12, 8
call [r12-8]
]],
	["?"] = [[
call conditional
]],
	["#"] = [[
call loop
]],
	[":"] = [[
add r12, 16
mov rax, [r12-16]
mov rbx, [r12-8]
mov [rax], rbx
]],
	[";"] = [[
mov rax, [r12]
mov rax, [rax]
mov [r12], rax
]],
	[","] = [[
mov rsi, r12
mov rcx, 1
call write
add r12, 8
]],
	["^"] = [[
call read
sub r12, 8
mov [r12], eax
]],
	["."] = [[
call print_num
]],
	["B"] = [[
call flush
]],
}

local fn_counter = 0
local str_counter = 0
local current_int

local line_number = 1
local line_position = 0

local stack_size = 8388608
local buffer_size = 8192

local c

local function read_char()
	local char = io.read(1)

	if char == "\n" then
		line_number = line_number + 1
		line_position = 0
	else
		line_position = line_position + 1
	end

	return char
end

local function syntax_error(msg)
	error("FALSE syntax error at "..line_number..":"..line_position..": " .. msg)
end

local function compile_fn()
	local fn_id = fn_counter
	fn_counter = fn_counter + 1

	print("fun_" .. fn_id .. ":")

	local strings = ""

	c = nil

	while true do
		if not c then
			c = read_char()
		end

		if c and c:match("%d") then
			current_int = current_int or 0
			current_int = current_int * 10 + tonumber(c)
			c = nil
		elseif current_int then
			if c == "S" then
				stack_size = current_int
				c = nil
			elseif c == "U" then
				buffer_size = current_int
				c = nil
			else
				print("sub r12, 8")
				print("mov qword[r12], " .. current_int)
			end
			current_int = nil
		elseif c and c:match("[a-z]") then
			print("sub r12, 8")
			print("mov qword[r12], var_" .. c)
			c = nil
		elseif c == "'" then
			local x = read_char()
			if not x then
				syntax_error("unterminated char literal")
			end
			print("sub r12, 8")
			print("mov qword[r12], " .. x:byte(1))
			c = nil
		elseif c == "\"" then
			local str = {}
			while true do
				local x = read_char()
				if not x then
					syntax_error("unterminated string literal")
				end
				if x == "\"" then
					break
				end
				table.insert(str, x:byte(1))
			end
			print("mov rsi, str_" .. str_counter)
			print("mov rcx, " .. #str)
			print("call write")
			strings = "str_" .. str_counter .. ": db " .. table.concat(str, ",") .. "\n" .. strings
			str_counter = str_counter + 1
			c = nil
		elseif c == "`" then
			while true do
				local x = read_char()
				if not x then
					syntax_error("unterminated inline assembly")
				end
				if x == "`" then
					break
				end
				io.write(x)
			end
			c = nil
		elseif c == "[" then
			local lambda = fn_counter
			print("jmp end_" .. lambda)
			compile_fn()
			if c ~= "]" then
				syntax_error("unterminated lambda")
			end
			print("sub r12, 8")
			print("mov qword[r12], fun_" .. lambda)
			c = nil
		elseif c and c:match("%s") then
			c = nil
		elseif not c or c == "]" then
			break
		elseif c and c:byte(1) == 195 then
			c = read_char()

			if c and c:byte(1) == 184 then
				c = "O"
			elseif c and c:byte(1) == 159 then
				c = "B"
			else
				syntax_error("unknown UTF-8 character")
			end
		elseif c and c:byte(1) == 248 then
			c = "O"
		elseif c and c:byte(1) == 223 then
			c = "B"
		elseif c == "{" then
			while read_char() ~= "}" do end
			c = nil
		elseif c and macros[c] then
			io.write(macros[c])
			c = nil
		else
			syntax_error("unknown character: " .. c)
		end
	end

	print("ret")

	print("section .data")
	io.write(strings)
	print("section .text")

	print("end_" .. fn_id .. ":")
end

print("section .text")

compile_fn()

print("%define STKSIZ " .. stack_size)
print("%define BUFSIZ " .. buffer_size)

io.write([[
section .data
readbuf_len: dq 0
readbuf_cursor: dq 0
writebuf_len: dq 0
section .bss
readbuf: resb BUFSIZ
writebuf: resb BUFSIZ
section .text
read:
mov rax, [readbuf_cursor]
cmp rax, [readbuf_len]
jb .has
mov rax, 0
mov rdi, 0
mov rsi, readbuf
mov rdx, BUFSIZ
syscall
mov [readbuf_len], rax
mov qword[readbuf_cursor], 0
cmp rax, 0
jne .has
mov eax, -1
ret
.has:
mov rax, [readbuf_cursor]
movzx eax, byte[readbuf+rax]
inc qword[readbuf_cursor]
ret
write:
mov rdi, [writebuf_len]
mov rax, BUFSIZ
sub rax, rdi
add rdi, writebuf
mov rdx, rcx
sub rdx, rax
jna .simple
mov rcx, rax
rep movsb
push rsi
push rdx
mov qword[writebuf_len], BUFSIZ
call flush
pop rdx
pop rsi
cmp rdx, BUFSIZ
ja .direct
mov rcx, rdx
mov rdi, writebuf
.simple:
add [writebuf_len], rcx
rep movsb
ret
.direct:
mov rax, 1
mov rdi, 1
syscall
ret
flush:
mov rdx, [writebuf_len]
cmp rdx, 0
je .return
mov rax, 1
mov rdi, 1
mov rsi, writebuf
syscall
mov qword[writebuf_len], 0
.return:
ret
conditional:
add r12, 16
mov eax, [r12-8]
cmp eax, 0
je .return
call [r12-16]
.return:
ret
loop:
add r12, 16
sub rsp, 16
mov rax, [r12-8]
mov [rsp], rax
mov rax, [r12-16]
mov [rsp+8], rax
.loop:
call [rsp]
add r12, 8
mov eax, [r12-8]
cmp eax, 0
je .return
call [rsp+8]
jmp .loop
.return:
add rsp, 16
ret
print_num:
mov rcx, rsp
sub rsp, 16
mov eax, dword[r12]
add r12, 8
mov ebx, eax
neg ebx
cmp eax, 0
cmovl eax, ebx
mov edi, 10
.loop:
dec rcx
xor edx, edx
idiv edi
add dl, '0'
mov byte[rcx], dl
cmp eax, 0
jne .loop
cmp ebx, 0
jle .print
dec rcx
mov byte[rcx], '-'
.print:
mov rsi, rcx
lea rcx, [rsp+16]
sub rcx, rsi
call write
add rsp, 16
ret
global _start
_start:
lea r12, [data_stack+STKSIZ]
lea rsp, [call_stack+STKSIZ]
call fun_0
call flush
mov rax, 60
mov rdi, 0
syscall
section .bss
data_stack: resq STKSIZ
call_stack: resq STKSIZ
]])

print("section .data")
for x = ("a"):byte(1), ("z"):byte(1) do
	print("var_" .. string.char(x) .. ": dq 0")
end
