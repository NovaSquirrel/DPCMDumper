--[[
 DPCM sample dumping script for FCEUX
 Original version by NovaSquirrel
 Enhancements by JustBurn.
--]]

-- Options
DumpMode=true     -- Enable/Disable dumping
Verbose=false     -- 1 = Output when the DPCM play, 0 = Only output when sound is ripped
OutputDir="C:\\DPCM\\"

DPCMAddr=0        -- \ 
DPCMLen=0         --  Currently playing DPCM sample
DPCMFreq=0        -- /
LastAddr=0        -- Last DPCM sample played
DPCM_Writes=0     -- Counter for DPCM writes
Direct_Writes=0   -- Counter for $4011 writes
CurOpcode=0xEA    -- Variables

function DPCM_Write(Addr)
--[[ For some reason, FCEUX's Lua interface doesn't actually provide the value
    that was written to the address you're watching, so I need to look at
    the opcode. This doesn't cover every possible case, but it should
    cover what games actually use. --]]

  RegisterUsed="a"
  CurOpcode=memory.readbyteunsigned(memory.getregister("pc")-3)
  if(CurOpcode == 0x8E) then RegisterUsed="x" end  --STX absolute
  if(CurOpcode == 0x8C) then RegisterUsed="y" end  --STY absolute
  Value= memory.getregister(RegisterUsed)

  if(Addr == 0x4012) then  --$4012  Sample address  %11AAAAAA.AA000000
    LastAddr=DPCMAddr      --Store the last address so we have something to compare to
    Value=Value * 64
    Value=Value + 0xC000
    DPCMAddr=Value
    DPCM_Writes=AND(DPCM_Writes,0xffff) +1
  end
  if(Addr == 0x4013) then  --$4013  Sample length  %0000LLLL.LLLL0001
    Value=Value * 16       -- Shift left four times
    Value=Value + 1        -- set the LSB to 1
    DPCMLen=Value
    DPCM_Writes=AND(DPCM_Writes,0xffff) +1
  end
  if(Addr == 0x4011) then
    Direct_Writes=AND(Direct_Writes,0xfff) +1
  end
  if(Addr == 0x4010) then
    DPCMFreq=Value
    DPCM_Writes=AND(DPCM_Writes,0xffff) +1
  end
end

memory.registerwrite(0x4010, 4, DPCM_Write)  -- Watch for writes on $4010 to $4013

-- Generate a filename for the ripped file
function Filename(checksum)
  return(string.format("%srip_%.4x(%.4x)-%i.dmc", OutputDir, DPCMAddr, checksum, DPCMLen))
end

while true do
  gui.text(10, 200, string.format("Addr:%.4x Freq:%x Op:%.2x Len:%i", DPCMAddr, DPCMFreq, CurOpcode, DPCMLen))
  gui.text(10, 210, string.format("Times:%i, Direct:%i", DPCM_Writes, Direct_Writes))

  FCEU.frameadvance()
  if(DumpMode) then
    if(LastAddr ~= DPCMAddr) then  -- Is this a new sample?
      if(DPCMLen ~= 1) then        -- Don't bother to write one byte samples

        -- Checksum due to lack of bank interface
        checksum=0
        for i=DPCMAddr,DPCMAddr+DPCMLen-1 do
          checksum = checksum + memory.readbyteunsigned(i)
        end

        if (Verbose) then
          print(string.format("Playing $%.4X with a length of %i (Checksum $%.4x)", DPCMAddr, DPCMLen, checksum))
        end

        -- Write if file doesn't exist
        F=io.open(Filename(checksum),"rb")
        if (F == nil) then
          F=io.open(Filename(checksum),"wb")
          if (F ~= nil) then
            print(string.format("Writing $%.4X with a length of %i (Checksum $%.4x)", DPCMAddr, DPCMLen, checksum))
            for i=DPCMAddr,DPCMAddr+DPCMLen-1 do
              F:write(string.char(memory.readbyteunsigned(i)))
            end
          end
        end
        F:close()
      end
    end
  end
end
