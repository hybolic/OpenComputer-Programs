--varibles
local drone = component.proxy(component.list("drone")())
local modem = component.proxy(component.list("modem")())
local nav   = component.proxy(component.list("navigation")())
local geo   = component.proxy(component.list("geolyzer")())

local PORT = 3576
local MAX_DIST = 16

local hasConnection
local DOCK
local cx, cy, cz

--functions
local function move(tx,ty,tz)
  local dx = tx - cx
  local dy = ty - cy
  local dz = tz - cz
  drone.move(dx,dy,dz)
  while drone.getOffset() > 0.7 or drone.getVelocity() > 0.7 do end
  cx,cy,cz = tx,ty,tz
end

local function goDock()
  move(DOCK.x, DOCK.y, DOCK.z)
  while computer.energy() / computer.maxEnergy() < 0.99 do end 
  drone.setLightColor(0x00ff00)
  computer.beep(783.99,.25)
  computer.beep(783.99,.25)
  computer.beep(783.99)
  computer.beep(659.25)
  computer.beep(1046.5)
end

local function getWaypoints()
  DOCK = {}
  cx, cy, cz = 0, 0, 0
  local way = nav.findWaypoints(256)
  for i=1, way.n do
    if way[i].label == "DOCK" then
      DOCK.x = way[i].position[1]
      DOCK.y = way[i].position[2] + 2
      DOCK.z = way[i].position[3] - 1
    end
  end
end

local function split(str,sep)
  local array = {}
  local reg = string.format("([^%s]+)",sep)
  for mem in string.gmatch(str,reg) do
    table.insert(array,mem)
  end
  return array
end

--init
drone.setLightColor(0xffff00)
drone.setStatusText("Booting Penny OS..")

drone.setStatusText("PENNY: Opening Port..")
modem.open(PORT)
hasConnection = false

drone.setStatusText("PENNY: Movement Test..")
getWaypoints()
move(0,.5,0)

drone.setStatusText("PENNY")
drone.setLightColor(0x00ff00)

local client

--running loop
while true do
  getWaypoints()
  local evt,_,sender,port,dist,msg = computer.pullSignal(.25)
  if hasConnection then
    if evt ~= nil then
      if evt == "modem_message" then
        if sender == client and port == PORT then
          if string.match(msg, "MOVE") then
            local var = split(string.gsub(msg, "MOVE", ""),";")
            if #var >= 3 then
              move(tonumber(var[1]),tonumber(var[2]),tonumber(var[3]))
            end
          elseif string.match(msg, "DOCK") then
            goDock()
          elseif string.match(msg, "GET_CHARGE") then
            modem.send(client, PORT +1, "" .. getCharge())
          elseif string.match(msg, "DISCONNECT") then
            hasConnection = false
          elseif string.match(msg, "MAP") then
            local var = split(string.gsub(msg, "MAP", ""),";")
            if #var >= 2 then
              -- map col and send to server
              local sd = geo.scan(tonumber(var[1]), tonumber(var[2]))
              local list = "COL" .. tonumber(var[1]) .. ";" .. tonumber(var[2]) .. ";" .. #sd
              for k, d in pairs(sd) do
                list = list .. ";" .. d
              end
              modem.broadcast(PORT,list)
            end
          end
        end
      end
    end
  else
    if evt ~= nill then
      if evt == "modem_message" and port == PORT and msg == "CONNECTION_REQUEST" then
          client = sender
          hasConnection = true
          --tell host that they have full control
          modem.send(client,PORT+1,"CONFIRMED")
		  drone.setLightColor(0x00f0ff)
          drone.setLightColor(0x00ff00)
        end
      end
  end

  if getCharge() < 0.5 and getCharge() > 0.1 then
    drone.setLightColor(0xff7f00)
  elseif getCharge() < 0.1 then
    drone.setLightColor(0xff0000)
    goDock()
  end
end