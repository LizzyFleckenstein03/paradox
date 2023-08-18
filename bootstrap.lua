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
mov rax, 1
mov rdi, 1
mov rsi, r12
mov rdx, 1
syscall
add r12, 8
]],
	["^"] = [[
sub r12, 8
mov qword[r12], 0
mov rax, 0
mov rdi, 0
mov rsi, r12
mov rdx, 1
syscall
mov ebx, [r12]
mov ecx, -1
cmp rax, 0
cmove ebx, ecx
mov [r12], ebx
]],
	["."] = [[
call print_num
]],
	["B"] = "",
}

local fn_counter = 0
local str_counter = 0
local current_int

local line_number = 1
local line_position = 0

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
			print("sub r12, 8")
			print("mov qword[r12], " .. current_int)
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
			print("mov rax, 1")
			print("mov rdi, 1")
			print("mov rsi, str_" .. str_counter)
			print("mov rdx, " .. #str)
			print("syscall")
			strings = "str_" .. str_counter .. ": db " .. table.concat(str, ",") .. "\n" .. strings
			str_counter = str_counter + 1
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

	io.write(strings)
	print("end_" .. fn_id .. ":")
end

print("section .text")

compile_fn()

io.write([[
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
mov rax, 1
mov rdi, 1
mov rsi, rcx
lea rdx, [rsp+16]
sub rdx, rcx
syscall
add rsp, 16
ret
]])

io.write([[
global _start
_start:
lea r12, [1000000+8*"$."]
call fun_0
mov rax, 60
mov rdi, 0
syscall
section .bss
stack: resq 1000000
]])

print("section .data")
for x = ("a"):byte(1), ("z"):byte(1) do
	print("var_" .. string.char(x) .. ": dq 0")
end
