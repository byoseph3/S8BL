-- 8 bit machine

-- IMPORTANT, DO NOT MIX CASES. ONLY USE LOWER CASE LETTERS

local function dec(hex)
	return tonumber(hex, 16)
end

local function hex(dec)
	return string.format("%.2x", dec)
end

local cpu = {}

local memory = ""
local allocate = 1024
local INTERVAL = 0.01
local heartbeat = {}

-- Memory
--[[

	Program is allocated at the top of the stack.
	Old programs are overwritten.
	IP points to the start of the program.

]]

-- Registers
--[[

	sp   0x01
	bp   0x02
	ip   0x03
	ax   0x04
	bx   0x05
	cx   0x06
	dx   0x07
	
	-- true registers start here
	r8   0x08
	r9   0x09
	r10  0x0a
	r11  0x0b
	r12  0x0c
	r13  0x0d
	r14  0x0e
	r15  0x0f
	
	-- flags
	jflag 0x11
	eflag 0x12
	zflag 0x13
	hflag 0x14

]]

-- Operations

--[[

	-- MOV 0x00    -- Load to a register
	-- MOVR 0x10   -- Load from a register
	-- MOVM 0x20   -- Load from memory
	-- STR 0x30    -- Store to memory at a specific location
	-- STRR 0x40   -- Store from register at a specific locationx
	-- PUSH 0x50   -- Store at the bottom of the stack (set 2nd byte to 01 for registers)
	-- POP 0x60    -- Take from the top of the stack
	-- JMP 0x70    -- Move the IP and set the jflag (set 2nd byte to 01 for registers)
	-- JNZ 0x71    -- Jump if zflag ~= 01
	-- JE 0x72     -- Jump if zflag == 0
	-- RET 0x80    -- Return the IP to the return address
	-- PRNT 0x90   -- Print the value (set 2nd byte to 01 for registers)
	-- CMP 0xa0    -- Compare two values (only byte values, or registers) 00 = 2 byte values; 01 = byte, reg; 10 = reg, byte; 11 = reg, reg
	
	-- BREAK 0xcc  -- Breakpoint, pause executions
	
	-- NOP 0xfe    -- No Operation, skip
	-- HALT 0xff   -- Stop execution

]]

local function setup()
	-- 1 MB of RAM
	for i = 1, allocate do
		memory = memory.."00"
	end
	
	-- clear registers
	for i = 2, 15 do
		cpu["0x"..hex(i)] = "00"
	end
	
	-- set sp to 1
	cpu["0x01"] = "01"
	
end

local function subPadRegisters()
	for i = 1, 15 do
		local temp = cpu["0x"..hex(i)]
		if string.len(temp) > 4 then
			temp = string.sub(temp, 1, 4)
		elseif string.len(temp) < 4 then
			repeat 
				temp = "0"..temp
			until string.len(temp) == 4
		end
	end
end
table.insert(heartbeat, subPadRegisters)

local function subClock()
	while wait(INTERVAL) do
		for i = 1, #heartbeat do
			spawn(heartbeat[i])
		end
	end
end

local function mov(reg, d1, d2)
	cpu["0x"..reg] = d1..d2
end
cpu["0x00"] = mov

local function movr(reg, _, reg1)
	if (dec("0x"..reg) > 15 or reg == "0x00") or (dec("0x"..reg1) > 15 or reg1 == "0x00") then
		error("Illegal Instruction!")
	end
	cpu["0x"..reg] = cpu["0x"..reg1]
end
cpu["0x10"] = movr

local function movm(reg, addr1, addr2)
	-- Get the address
	local t = dec("0x"..addr1..addr2)
	
	-- read from the address
	cpu["0x"..reg] = string.sub(memory, t, t+3)
	
	--cpu["0x"..reg] = string.sub(memory, dec("0x"..addr1..addr2)*4, (dec("0x"..addr1..addr2)*4)+4)
end
cpu["0x20"] = movm

local function str(addr, d1, d2)
	-- store d at addr
	
	-- get addr
	local t = dec("0x"..addr)
	
	-- fix anyone trying to index 0
	if t == 0 then t = 1 end
	
	-- get before t
	local s = string.sub(memory, 1, t-1)
	
	-- get after t+4
	local e = string.sub(memory, t+4)
	
	-- set memory
	memory = s..d1..d2..e
end
cpu["0x30"] = str

local function strr(addr, _, reg)
	-- store the register value at addr
	
	-- get addr
	local t = dec("0x"..addr)

	-- fix anyone trying to index 0
	if t == 0 then t = 1 end

	-- get before t
	local s = string.sub(memory, 1, t-1)

	-- get after t+4
	local e = string.sub(memory, t+4)
	
	-- set memory
	memory = s..cpu["0x"..reg]..e
end
cpu["0x40"] = strr

local function push(rflag, d1, d2)
	-- Get the avalible position of sp.
	local t = dec("0x"..cpu["0x01"])
	
	-- get everything before this position in memory
	local s = string.sub(memory, 1, t-1)
	
	-- get everything after this position in memory
	local e = string.sub(memory, t + 4)
	
	-- data
	local g = ""
	
	-- check rflag
	if rflag == "01" then
		-- register
		g = cpu["0x"..d2]
	else
		-- value
		g = d1 .. d2
	end
	
	-- store
	memory = s .. g .. e
	
	-- set sp to next free space
	cpu["0x01"] = hex(t + 4)
end
cpu["0x50"] = push

local function pop(reg, _, _)
	-- set sp back to the previous space
	local t = dec("0x"..cpu["0x01"])
	
	t = t - 4
	
	-- set sp to the new free space
	cpu["0x01"] = hex("0x"..t)
	
	-- set register to that part in memory
	cpu["0x"..reg] = string.sub(memory, t, t+3)
end
cpu["0x60"] = pop

local function breakp(_, _, _)
	cpu["0x12"] = "cc"
end
cpu["0xcc"] = breakp

local function jmp(rflag, d1, d2)
	cpu["0x11"] = "01" -- jflag
	if rflag == "01" then
		mov("03", cpu["0x"..d2])
	else
		mov("03", d1, d2)
	end
end
cpu["0x70"] = jmp

local function ret()
	cpu["0x11"] = "01" -- jflag
	-- return address is right behind the basepointer
	local retaddr = string.sub(memory, ((dec("0x"..cpu["0x02"])-1)*4)+1, ((dec("0x"..cpu["0x02"])-1)*4)+4)
	mov("03", string.sub(retaddr, 1, 2), string.sub(retaddr, 3, 4))
end
cpu["0x80"] = ret

local function prnt(rflag, d1, d2)
	if rflag == "01" then
		print("0x"..d2..": "..cpu["0x"..d2])
	else
		print(d1..d2)
	end
end
cpu["0x90"] = prnt

local function nop()
	-- NOP
end
cpu["0xfe"] = nop

local function cmp(flag, d1, d2)	
	if flag == "00" then
		-- val, val
		cpu["0x13"] = (dec(d1) - dec(d2)) == 0 and "01" or "00"
	elseif flag == "01" then
		-- val, reg
		cpu["0x13"] = (dec(d1) - dec(cpu["0x"..d2])) == 0 and "01" or "00"
	elseif flag == "10" then
		-- reg, val
		cpu["0x13"] = (dec(cpu["0x"..d1]) - dec(d2)) == 0 and "01" or "00"
	elseif flag == "11" then
		-- reg, reg
		cpu["0x13"] = (dec(cpu["0x"..d1]) - dec(cpu["0x"..d2])) == 0 and "01" or "00"
	end
	
end
cpu["0xa0"] = cmp

local function jnz(...)
	if cpu["0x13"] == "00" then
		jmp(...)
	end
end
cpu["0x71"] = jnz

local function je(...)
	if cpu["0x13"] == "01" then
		jmp(...)
	end
end
cpu["0x72"] = je

local function halt(...)
	cpu["0x14"] = "01"
end
cpu["0xff"] = halt

local function run()
	while (dec(cpu["0x03"])+7 < string.len(memory)+1) and cpu["0x14"] ~= "01" do
		local instruction = string.sub(memory, dec(cpu["0x03"]), dec(cpu["0x03"])+7)
		--print(dec(cpu["0x03"]))
		-- parse the code
		local opcode = string.sub(instruction, 1, 2)
		local reg = string.sub(instruction, 3, 4)
		local data1 = string.sub(instruction, 5, 6)
		local data2 = string.sub(instruction, 7, 8)

		local succ, err = pcall(function()
			return cpu["0x"..opcode](reg, data1, data2)
		end)
		if not succ then
			local ip = cpu["0x03"]
			if string.len(ip) % 2 == 1 then
				ip = "0"..ip
			end
			error(string.format("Segfault!\nip: 0x"..ip.."\ninstruction: "..instruction))
		end

		-- Custom error
		if cpu["0x12"] ~= "00" then
			if cpu["0x12"] == "cc" then
				error("Trace breakpoint.")
			end
		end

		if cpu["0x11"] == "00" then
			-- Increment
			cpu["0x03"] = hex(dec("0x"..cpu["0x03"]) + 8)
		else
			-- Reset jump flag after jump instruction
			cpu["0x11"] = "00"
		end
	end
	--print(dec(cpu["0x03"]))
end

function cpu.load(code)
	-- pad the code
	if string.len(code) % 8 ~= 0 then
		repeat
			code = code .. "0"
		until string.len(code) % 8 == 0
	end
	-- store it in memory
	local t = string.len(memory) - string.len(code)
	
	memory = string.sub(memory, 1, t-1) .. code
	
	-- set ip to the start
	cpu["0x03"] = hex(t)
	
	-- clear registers
	for i = 8, 15 do
		cpu["0x"..hex(i)] = "0000"
	end

	-- clear flags
	for i = 17,20 do
		cpu["0x"..hex(i)] = "00"
	end
	
	run()
end

setup()
spawn(subClock)
return cpu
