-- Copyright 2022 SmartThings & jido1517
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
local zigbee_constants = require "st.zigbee.constants"
local clusters = require "st.zigbee.zcl.clusters"
local ElectricalMeasurement = clusters.ElectricalMeasurement
local SimpleMetering = clusters.SimpleMetering

local POWER_UNIT_WATT = "W"
local ENERGY_UNIT_KWH = "kWh"

local do_configure = function(self, device)
  device:refresh()
  device:configure()
  -- Additional one time configuration
  if device:supports_capability(capabilities.energyMeter) or device:supports_capability(capabilities.powerMeter) then
    -- Divisor and multipler for EnergyMeter
    device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
    device:send(ElectricalMeasurement.attributes.ACPowerMultiplier:read(device))
    -- Divisor and multipler for PowerMeter
    device:send(SimpleMetering.attributes.Divisor:read(device))
    device:send(SimpleMetering.attributes.Multiplier:read(device))
  end
end

local device_init = function(self, device)
  device:set_field(zigbee_constants.SIMPLE_METERING_DIVISOR_KEY, 100, {persist = true})
  device:set_field(zigbee_constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 1000, {persist = true})
end

local function power_meter_handler(driver, device, value, zb_rx)
  local raw_power = value.value
  local powerdivisor = 1
  local raw_power_watts = raw_power / powerdivisor
  local raw_rssi = zb_rx.rssi.value
  local raw_lqi = zb_rx.lqi.value
  device:emit_event(capabilities.signalStrength.lqi(raw_lqi))
  device:emit_event(capabilities.signalStrength.rssi(raw_rssi))
  print("raw: "..raw_power.."  powerdivisor: "..powerdivisor.."  watts: "..raw_power_watts)
  device:emit_event(capabilities.powerMeter.power({value = raw_power_watts, unit = POWER_UNIT_WATT}))
end

local function energy_meter_handler(driver, device, value, zb_rx)
  local raw_value = value.value
  local multiplier = 1
  local divisor = 100
  raw_value = raw_value * multiplier/divisor
  local raw_watt = raw_value * 1000
  local delta = 0.0
  local current_power_consumption = device:get_latest_state("main", capabilities.powerConsumptionReport.ID, capabilities.powerConsumptionReport.powerConsumption.NAME)
  if current_power_consumption ~= nil then
    delta = math.max(raw_watt - current_power_consumption.energy, 0.0)
  end
  local delta_arguments = {deltaEnergy = delta, energy = raw_watt}
  device:emit_event(capabilities.powerConsumptionReport.powerConsumption(delta_arguments))
  device:emit_event(capabilities.energyMeter.energy({value = raw_value, unit = "kWh"}))
end

local function momentary_handler(driver, device, command)
  device:refresh()
end

local zigbee_power_meter_driver_template = {
  supported_capabilities = {
    capabilities.switch,
    capabilities.refresh,
    capabilities.powerMeter,
    capabilities.energyMeter,
    capabilities.momentary,
    capabilities.powerConsumptionReport,
    capabilities.signalStrength
  },
  zigbee_handlers = {
    attr = {
      [ElectricalMeasurement.ID] = {
        [ElectricalMeasurement.attributes.ActivePower.ID] = power_meter_handler
      },
      [SimpleMetering.ID] = {
        [SimpleMetering.attributes.CurrentSummationDelivered.ID] = energy_meter_handler,
      }
    }
  },
  capability_handlers = {
    [capabilities.momentary.ID] = {
      [capabilities.momentary.commands.push.NAME] = momentary_handler
    }
  },
  sub_drivers = {},
  lifecycle_handlers = {
    init = device_init,
    doConfigure = do_configure,
  }
}

defaults.register_for_default_handlers(zigbee_power_meter_driver_template, zigbee_power_meter_driver_template.supported_capabilities)
local zigbee_power_meter = ZigbeeDriver("zigbee_power_meter", zigbee_power_meter_driver_template)
zigbee_power_meter:run()
