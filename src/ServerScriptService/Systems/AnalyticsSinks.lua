--!strict
-- Sinks d'AnalyticsService (T9) : seul endroit qui appelle l'API Roblox.
--   * roblox : AnalyticsService:Log*Event (API en vigueur au 2026-11-16 ;
--     les méthodes Fire* dépréciées ne sont pas utilisées) ;
--   * log    : écrit chaque événement dans l'Output (Studio, où Roblox
--     n'envoie rien) ;
--   * off    : n'envoie rien.
-- Les erreurs remontent à AnalyticsService, qui les isole.

local AnalyticsService = require(script.Parent.Parent.Services.AnalyticsService)

local AnalyticsSinks = {}

local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

local function toCustomFields(fields: AnalyticsService.Fields?): { [string]: string }?
	if fields == nil or #fields == 0 then
		return nil
	end
	local result = {}
	for index, value in ipairs(fields) do
		result[FIELD_KEYS[index]] = value
	end
	return result
end

local function describeFields(fields: AnalyticsService.Fields?): string
	if fields == nil or #fields == 0 then
		return "-"
	end
	return table.concat(fields, ",")
end

function AnalyticsSinks.roblox(): AnalyticsService.Sink
	local Analytics = game:GetService("AnalyticsService")
	return {
		custom = function(player, eventName, value, fields)
			Analytics:LogCustomEvent(player, eventName, value, toCustomFields(fields))
		end,
		economy = function(player, flowType, currency, amount, endingBalance, transactionType, itemSku, fields)
			local flow = if flowType == "Source"
				then Enum.AnalyticsEconomyFlowType.Source
				else Enum.AnalyticsEconomyFlowType.Sink
			Analytics:LogEconomyEvent(
				player,
				flow,
				currency,
				amount,
				endingBalance,
				transactionType,
				itemSku,
				toCustomFields(fields)
			)
		end,
		onboarding = function(player, step, stepName, fields)
			Analytics:LogOnboardingFunnelStepEvent(player, step, stepName, toCustomFields(fields))
		end,
		progressionComplete = function(player, pathName, level, levelName, fields)
			Analytics:LogProgressionCompleteEvent(player, pathName, level, levelName, toCustomFields(fields))
		end,
	}
end

function AnalyticsSinks.log(): AnalyticsService.Sink
	return {
		custom = function(_player, eventName, value, fields)
			print(`[Analytics] custom {eventName} = {value} [{describeFields(fields)}]`)
		end,
		economy = function(_player, flowType, currency, amount, endingBalance, transactionType, itemSku, fields)
			print(
				`[Analytics] economy {flowType} {amount} {currency} -> {endingBalance} ({transactionType}, {itemSku}) [{describeFields(fields)}]`
			)
		end,
		onboarding = function(_player, step, stepName, _fields)
			print(`[Analytics] onboarding {step} {stepName}`)
		end,
		progressionComplete = function(_player, pathName, level, levelName, _fields)
			print(`[Analytics] progression {pathName} {level} {levelName} complete`)
		end,
	}
end

function AnalyticsSinks.off(): AnalyticsService.Sink
	local function noop() end
	return {
		custom = noop :: any,
		economy = noop :: any,
		onboarding = noop :: any,
		progressionComplete = noop :: any,
	}
end

return AnalyticsSinks
