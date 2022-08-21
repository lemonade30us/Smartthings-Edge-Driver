  
-- Zigbee Multi Switch ver 0.1.2
-- Copyright 2021 jido1517
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local clusters = require "st.zigbee.zcl.clusters"
local log = require "log"
local util = require "st.utils"

local startEnable
local startDuration
local endEnable
local endDuration
-- Custom capabilities
local textCapa = capabilities["trustsmile56703.text"]

local function text_set_handler(driver, device, command)
  device:emit_event(textCapa.text(command.args.value))
end

local function component_to_endpoint(device, component_id)
  if component_id == "main" then
    return device.fingerprinted_endpoint_id
  else
    local ep_num = component_id:match("switch(%d)")
    return ep_num and tonumber(ep_num) or device.fingerprinted_endpoint_id
  end
end

local function endpoint_to_component(device, ep)
  if ep == device.fingerprinted_endpoint_id then
    return "main"
  else
    return string.format("switch%d", ep)
  end
end

local function info_changed(driver, device, event, args)
  local get1 = device:get_endpoint(6)
  print(get1)
  if device.preferences.numberOfComponents ~= args.old_st_store.preferences.numberOfComponents then
    device:try_update_metadata({profile = string.format("zigbee-multichannel-%d",tonumber(device.preferences.numberOfComponents))})
    local readAttr = function()
      for _, component in pairs(device.st_store.profile.components) do
        device:send_to_component(component.id, clusters.OnOff.attributes.OnOff:read(device))
      end
    end
    device.thread:call_with_delay(2, readAttr)
  end
end

local do_configure = function(self, device)
	device:configure()
  for _, component in pairs(device.st_store.profile.components) do
    device:send_to_component(component.id, clusters.OnOff.attributes.OnOff:read(device))
  end
  device:emit_event(textCapa.text("Custom Text"))
end

local device_init = function(self, device)
  device:set_component_to_endpoint_fn(component_to_endpoint)
  device:set_endpoint_to_component_fn(endpoint_to_component)
end

local zigbee_multi_switch_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    textCapa,
  },
---[[
  capability_handlers = {
    [textCapa.ID] = {
      [textCapa.commands.setText.NAME] = text_set_handler,
    },
  },
--]]
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
    infoChanged = info_changed,
  },
}

defaults.register_for_default_handlers(zigbee_multi_switch_driver_template, zigbee_multi_switch_driver_template.supported_capabilities)
local zigbee_multi_switch = ZigbeeDriver("zigbee_multi_switch", zigbee_multi_switch_driver_template)
zigbee_multi_switch:run()