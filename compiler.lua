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

local cpu = require(script.Parent.cpu)

local instTable={
	["MOV"] = "00",
	["MOVR"] = "10",
	["MOVM"] = "20",
	["STR"] = "30",
	["STRR"] = "40",
	["PUSH"] = "5000",
	["PUSHR"] = "500100",
	["POP"] = "60",
	["JMP"] = "7000",
	["JMPR"] = "700100",
	["JZ"] = "7100",
	["JZR"] = "710100",
	["JE"] = "7200",
	["JER"] = "720100",
	["RET"] = "80",
	["PRNT"] = "9000",
	["PRNTR"] = "900100",
	-- ["CMP"] = "a0", -- Currently working on an implementation
	["BREAK"] = "cccccccc",
	["NOP"] = "fefefefe",
	["HALT"] = "ffffffff",
}

local regTable={
	["sp"] = "01",
	["bp"] = "02",
	["ip"] = "03",
	["ax"] = "04",
	["bx"] = "05",
	["cx"] = "06",
	["dx"] = "07",
	["r8"] = "08",
	["r9"] = "09",
	["r10"] = "0a",
	["r11"] = "0b",
	["r12"] = "0c",
	["r13"] = "0d",
	["r14"] = "0e",
	["r15"] = "0f",
}

local delim = "|"

local compiler = {}

function compiler.compile(code)
	local temp = string.split(code, delim)
	local out = ""
	for i = 1, #temp do
		local t = temp[i]
		-- retrive the specifics
		local instruction = string.split(t, " ")
		local tout = instTable[instruction[1]]
		for j = 2, #instruction do
			if string.sub(instruction[j], 1, 1) == "$" then
				if j == #instruction and j == 3 then
					tout = tout .. "00"
				end
				tout = tout .. regTable[string.sub(instruction[j], 2, -1)]
			else
				--print(tout, instruction[j])
				tout = tout .. instruction[j]
			end
		end
		if string.len(tout) % 8 ~= 0 then
			repeat
				tout = tout .. "0"
			until string.len(tout) % 8 == 0
		end
		
		out = out .. tout
	end
	print(out)
	cpu.load(out)
end

return compiler
