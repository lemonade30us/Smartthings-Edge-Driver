-- Zwave Metering Plug ver 1.1
-- Copyright 2021 jido1517
--F
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy ofF the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.CommandClass.Meter
local Meter = (require "st.zwave.CommandClass.Meter")({ version=3 })
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
local POWER_UNIT_WATT = "W"
local ENERGY_UNIT_KWH = "kWh"
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
--------------------------------------------------------------------------------------------
-- Register message handlers and run driver
--------------------------------------------------------------------------------------------
local function meter_report_handler(self, device, cmd)
  local event_arguments = nil

  if cmd.args.scale == Meter.scale.electric_meter.KILOWATT_HOURS then
    event_arguments = {
      value = cmd.args.meter_value,
      unit = ENERGY_UNIT_KWH
    }
    device:emit_event(capabilities.energyMeter.energy(event_arguments))

    local cEnergy = cmd.args.meter_value * 1000
    local pEnergy = cmd.args.previous_meter_value * 1000
    local delta = cEnergy - pEnergy
    local delta_arguments = {deltaEnergy = delta, energy = cEnergy}
    device:emit_event(capabilities.powerConsumptionReport.powerConsumption(delta_arguments))

  elseif cmd.args.scale == Meter.scale.electric_meter.WATTS then
    local event_arguments = {
      value = cmd.args.meter_value,
      unit = POWER_UNIT_WATT
    }
    device:emit_event(capabilities.powerMeter.power(event_arguments))
  end
end

local function notification_report_handler(self, device, cmd)
  if cmd.args.notification_type == Notification.notification_type.POWER_MANAGEMENT then
    if cmd.args.event == Notification.event.power_management.AC_MAINS_DISCONNECTED then
      device:emit_event(capabilities.switch.switch.off())
    elseif cmd.args.event == Notification.event.power_management.AC_MAINS_RE_CONNECTED then
      device:emit_event(capabilities.switch.switch.on())
    end
  end
end

local function momentary_reset_handler(driver, device, command)
  device:send(Meter:Reset({}))
  device:refresh()
end

local device_added = function (self, device)
  device:refresh()
end

local driver_template = {
  zwave_handlers = {
    [cc.METER] = {
      [Meter.REPORT] = meter_report_handler
    },
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_report_handler
    }
  },
  supported_capabilities = {
    capabilities.switch,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.refresh,
    capabilities.momentary,
    capabilities.powerConsumptionReport
  },
  lifecycle_handlers = {
    added = device_added
  },
  capability_handlers = {
    [capabilities.momentary.ID] = {
      [capabilities.momentary.commands.push.NAME] = momentary_reset_handler
    }
  },
  sub_drivers = {
    require("dawon-plug")
  }
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local zwavedevice = ZwaveDriver("zwave_metering_plug_report", driver_template)
zwavedevice:run()
