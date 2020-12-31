-- dmesg: very basic --

while true do
  local sig = table.pack(coroutine.yield())
  if sig.n > 0 then
    print(table.unpack(sig))
    if sig[1] == "key_down" and string.char(sig[3]) == "q" then
      os.exit(0)
    end
  end
end

os.exit(0)
