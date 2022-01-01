-- QUICKAPP TOON WATER

-- This Quickapp retrieves water consumption from the Toon Watermeter
-- The main devices containes the Water Flow (liters/minute)
-- This QuickApp has Child Device for Water Total (m³)

-- See http://www.toonwater.nl for the device and more info


-- Version 0.1 (1st January 2022)
-- Initial version


-- Variables (mandatory): 
-- IPaddress = IP address of your Toonwater meter
-- Interval = Number in seconds 
-- debugLevel = Number (1=some, 2=few, 3=all, 4=simulation mode) (default = 1)
  
  
-- No editing of this code is needed 


class 'waterquantity'(QuickAppChild)
function waterquantity:__init(dev)
  QuickAppChild.__init(self,dev)
end
function waterquantity:updateValue(data) 
  self:updateProperty("value", tonumber(data.waterquantity))
  self:updateProperty("unit", "m³")
  self:updateProperty("log", " ")
end


local function getChildVariable(child,varName)
  for _,v in ipairs(child.properties.quickAppVariables or {}) do
    if v.name==varName then return v.value end
  end
  return ""
end


-- QuickApp Functions


function QuickApp:updateChildDevices() -- Update Child Devices
  for id,child in pairs(self.childDevices) do 
    child:updateValue(data) 
  end
end


function QuickApp:logging(level,text) -- Logging function for debug messages
  if tonumber(debugLevel) >= tonumber(level) then 
    self:debug(text)
  end
end


function QuickApp:updateProperties() -- Update the properties
  self:logging(3,"QuickApp:updateProperties")
  self:updateProperty("value", tonumber(data.waterflow))
  self:updateProperty("unit", "l/m")
  self:updateProperty("log", os.date("%d-%m-%Y %T"))
end


function QuickApp:updateLabels() -- Update the labels
  self:logging(3,"QuickApp:updateLabels")

  local labelText = ""
  if debugLevel == 4 then
    labelText = labelText .."SIMULATION MODE" .."\n\n"
  end
  
  labelText = labelText .."Water Flow: " ..data.waterflow .." liters/minute" .."\n"
  labelText = labelText .."Total Water: " ..data.waterquantity .." m³" .."\n\n"
  labelText = labelText ..os.date("%d-%m-%Y %T")


  self:updateView("label1", "text", labelText)
  self:logging(2,labelText)
end


function QuickApp:valuesToon() -- Get the values from json file
  self:logging(3,"QuickApp:valuesToon")
  data.waterflow = jsonTable.waterflow
  data.waterquantity = tonumber(jsonTable.waterquantity)/1000
end


function QuickApp:simData() -- Simulate Toon Water
  self:logging(3,"simData")
  apiResult = '{"waterflow":"4","waterquantity":"635281"}'
  jsonTable = json.decode(apiResult) -- Decode the json string from api to lua-table 

  self:valuesToon() -- Get the values for Toon Water
  self:updateLabels() -- Update the labels
  self:updateProperties() -- Update the properties
  self:updateChildDevices() -- Update the Child Devices
  
  self:logging(3,"SetTimeout " ..Interval .." seconds")
  fibaro.setTimeout(Interval*1000, function() 
     self:simData()
  end)
end


function QuickApp:getData() -- Get data from Toon Water
  self:logging(3,"getData")
  local url = "http://" ..IPaddress .."/json.html"
  self:logging(3,"url: " ..url)
  self.http:request(url, {
  options = {
    headers = {Accept = "application/json"}, method = 'GET'},
    success = function(response)
      self:logging(3,"Response status: " ..response.status)
      self:logging(3,"Response data: " ..response.data)

      jsonTable = json.decode(response.data) -- Decode the json string from api to lua-table

      self:valuesToon() -- Get the values for Toon Water
      self:updateLabels() -- Update the labels
      self:updateProperties() -- Update the properties
      self:updateChildDevices() -- Update the Child Devices

    end,
    error = function(error)
      self:error("error: " ..json.encode(error))
      self:updateProperty("log", "error: " ..json.encode(error))
    end
  }) 
  fibaro.setTimeout(Interval*1000, function() -- Checks every [Interval] seconds for new data
    self:getData()
  end)
end 


function QuickApp:createVariables() -- Create all Variables
  self:logging(3,"Start createVariables")
  data = {}
  data.waterflow = ""
  data.waterquantity = ""
end


function QuickApp:getQuickappVariables() -- Get all Quickapp Variables or create them
  IPaddress = self:getVariable("IPaddress")
  Interval = tonumber(self:getVariable("Interval")) 
  debugLevel = tonumber(self:getVariable("debugLevel"))

  -- Check existence of the mandatory variables, if not, create them with default values 
  if IPaddress == "" or IPaddress == nil then 
    IPaddress = "192.168.1.112" -- Default IPaddress 
    self:setVariable("IPaddress", IPaddress)
    self:trace("Added QuickApp variable IPaddress")
  end
  if Interval == "" or Interval == nil then
    Interval = "10" -- Default interval in seconds
    self:setVariable("Interval", Interval)
    self:trace("Added QuickApp variable Interval")
    Interval = tonumber(Interval)
  end
  if debugLevel == "" or debugLevel == nil then
    debugLevel = "1" -- Default value for debugLevel
    self:setVariable("debugLevel",debugLevel)
    self:trace("Added QuickApp variable debugLevel")
    debugLevel = tonumber(debugLevel)
  end
  self:logging(3,"Interval: " ..Interval)
end


function QuickApp:setupChildDevices() -- Setup Child Devices
  local cdevs = api.get("/devices?parentId="..self.id) or {} -- Pick up all Child Devices
  function self:initChildDevices() end -- Null function, else Fibaro calls it after onInit()...

  if #cdevs == 0 then -- If no Child Devices, create them
    local initChildData = { 
      {className="waterquantity", name="Water Total", type="com.fibaro.multilevelSensor", value=0}, 
    }
    for _,c in ipairs(initChildData) do
      local child = self:createChildDevice(
        {name = c.name,
          type=c.type,
          value=c.value,
          unit=c.unit,
          initialInterfaces = {},
        },
        _G[c.className] -- Fetch class constructor from class name
      )
      child:setVariable("className",c.className)  -- Save class name so we know when we load it next time
    end   
  else 
    for _,child in ipairs(cdevs) do
      local className = getChildVariable(child,"className") -- Fetch child class name
      local childObject = _G[className](child) -- Create child object from the constructor name
      self.childDevices[child.id]=childObject
      childObject.parent = self -- Setup parent link to device controller 
    end
  end
end


function QuickApp:onInit()
  __TAG = fibaro.getName(plugin.mainDeviceId) .." ID:" ..plugin.mainDeviceId
  self.http = net.HTTPClient({timeout=3000})
  self:debug("onInit")
  self:setupChildDevices() -- Setup the Child Devices 
  
  if not api.get("/devices/"..self.id).enabled then
    self:warning("Device", fibaro.getName(plugin.mainDeviceId), "is disabled")
    return
  end
  
  self:getQuickappVariables() -- Get Quickapp Variables or create them
  self:createVariables() -- Create Variables
    
  if tonumber(debugLevel) >= 4 then 
    self:simData() -- Go in simulation
  else
    self:getData() -- Get data
  end
    
end

-- EOF
