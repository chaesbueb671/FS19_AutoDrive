function ADTableLength(T)
	if T == nil then
		return 0
	end
	local count = 0
	for _ in pairs(T) do
		count = count + 1
	end
	return count
end

function AutoDrive:BoxesIntersect(a, b)
	local polygons = {a, b}
	local minA, maxA, minB, maxB

	for i, polygon in pairs(polygons) do
		-- for each polygon, look at each edge of the polygon, and determine if it separates
		-- the two shapes

		for i1, corners in pairs(polygon) do
			--grab 2 vertices to create an edge
			local i2 = (i1 % 4 + 1)
			local p1 = polygon[i1]
			local p2 = polygon[i2]

			-- find the line perpendicular to this edge
			local normal = {x = p2.z - p1.z, z = p1.x - p2.x}

			minA = nil
			maxA = nil
			-- for each vertex in the first shape, project it onto the line perpendicular to the edge
			-- and keep track of the min and max of these values

			for j, corner in pairs(polygons[1]) do
				local projected = normal.x * corner.x + normal.z * corner.z
				if minA == nil or projected < minA then
					minA = projected
				end
				if maxA == nil or projected > maxA then
					maxA = projected
				end
			end

			--for each vertex in the second shape, project it onto the line perpendicular to the edge
			--and keep track of the min and max of these values
			minB = nil
			maxB = nil
			for j, corner in pairs(polygons[2]) do
				projected = normal.x * corner.x + normal.z * corner.z
				if minB == nil or projected < minB then
					minB = projected
				end
				if maxB == nil or projected > maxB then
					maxB = projected
				end
			end
			-- if there is no overlap between the projects, the edge we are looking at separates the two
			-- polygons, and we know there is no overlap
			if maxA < minB or maxB < minA then
				--print("polygons don't intersect!");
				return false
			end
		end
	end

	--print("polygons intersect!");
	return true
end

function string:split(sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(
		pattern,
		function(c)
			fields[#fields + 1] = c
		end
	)
	return fields
end

function AutoDrive:printMessage(vehicle, newMessage)
	AutoDrive.print.nextMessage = newMessage
	AutoDrive.print.nextReferencedVehicle = vehicle
end

function ADBoolToString(value)
	if value == true then
		return "true"
	end
	return "false"
end

function AutoDrive:angleBetween(vec1, vec2)
	--local scalarproduct_top = vec1.x * vec2.x + vec1.z * vec2.z;
	--local scalarproduct_down = math.sqrt(vec1.x * vec1.x + vec1.z*vec1.z) * math.sqrt(vec2.x * vec2.x + vec2.z*vec2.z)
	--local scalarproduct = scalarproduct_top / scalarproduct_down;
	local angle = math.atan2(vec2.z, vec2.x) - math.atan2(vec1.z, vec1.x)
	angle = normalizeAngleToPlusMinusPI(angle)
	return math.deg(angle) --math.acos(angle)
end

function normalizeAngle(inputAngle)
	if inputAngle > (2 * math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < -(2 * math.pi) then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function normalizeAngle2(inputAngle)
	if inputAngle > (2 * math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < 0 then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function normalizeAngleToPlusMinusPI(inputAngle)
	if inputAngle > (math.pi) then
		inputAngle = inputAngle - (2 * math.pi)
	else
		if inputAngle < -(math.pi) then
			inputAngle = inputAngle + (2 * math.pi)
		end
	end

	return inputAngle
end

function AutoDrive:createVector(x, y, z)
	local t = {x = x, y = y, z = z}
	return t
end

function AutoDrive:round(num)
	under = math.floor(num)
	upper = math.floor(num) + 1
	underV = -(under - num)
	upperV = upper - num
	if (upperV > underV) then
		return under
	else
		return upper
	end
end

function AutoDrive:getWorldDirection(fromX, fromY, fromZ, toX, toY, toZ)
	-- NOTE: if only 2D is needed, pass fromY and toY as 0
	local wdx, wdy, wdz = toX - fromX, toY - fromY, toZ - fromZ
	local dist = MathUtil.vector3Length(wdx, wdy, wdz) -- length of vector
	if dist and dist > 0.01 then
		wdx, wdy, wdz = wdx / dist, wdy / dist, wdz / dist -- if not too short: normalize
		return wdx, wdy, wdz, dist
	end
	return 0, 0, 0, 0
end

AIVehicleUtil.driveInDirection = function(self, dt, steeringAngleLimit, acceleration, slowAcceleration, slowAngleLimit, allowedToDrive, moveForwards, lx, lz, maxSpeed, slowDownFactor)
	local angle = 0
	if lx ~= nil and lz ~= nil then
		local dot = lz
		angle = math.deg(math.acos(dot))
		if angle < 0 then
			angle = angle + 180
		end
		local turnLeft = lx > 0.00001
		if not moveForwards then
			turnLeft = not turnLeft
		end
		local targetRotTime = 0
		if turnLeft then
			--rotate to the left
			targetRotTime = self.maxRotTime * math.min(angle / steeringAngleLimit, 1)
		else
			--rotate to the right
			targetRotTime = self.minRotTime * math.min(angle / steeringAngleLimit, 1)
		end
		if targetRotTime > self.rotatedTime then
			self.rotatedTime = math.min(self.rotatedTime + dt * self:getAISteeringSpeed(), targetRotTime)
		else
			self.rotatedTime = math.max(self.rotatedTime - dt * self:getAISteeringSpeed(), targetRotTime)
		end
	end
	if self.firstTimeRun then
		local acc = acceleration
		if maxSpeed ~= nil and maxSpeed ~= 0 then
			if math.abs(angle) >= slowAngleLimit then
				maxSpeed = maxSpeed * slowDownFactor
			end
			self.spec_motorized.motor:setSpeedLimit(maxSpeed)
			if self.spec_drivable.cruiseControl.state ~= Drivable.CRUISECONTROL_STATE_ACTIVE then
				self:setCruiseControlState(Drivable.CRUISECONTROL_STATE_ACTIVE)
			end
		else
			if math.abs(angle) >= slowAngleLimit then
				acc = slowAcceleration
			end
		end
		if not allowedToDrive then
			acc = 0
		end
		if not moveForwards then
			acc = -acc
		end
		--FS 17 Version WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal, acc, not allowedToDrive, self.requiredDriveMode);
		WheelsUtil.updateWheelsPhysics(self, dt, self.lastSpeedReal * self.movingDirection, acc, not allowedToDrive, true)
	end
end

function AutoDrive:onActivateObject(superFunc, vehicle)
	if vehicle ~= nil then
		--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
		if g_currentMission.controlledVehicle ~= vehicle or g_currentMission.controlledVehicles[vehicle] == nil then
			local oldControlledVehicle = nil
			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
				vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle
			else
				oldControlledVehicle = g_currentMission.controlledVehicle
			end
			g_currentMission.controlledVehicle = vehicle

			superFunc(self, vehicle)

			if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
				g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle
				vehicle.ad.oldControlledVehicle = nil
			else
				if oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = oldControlledVehicle
				end
			end
			return
		end
	end

	superFunc(self, vehicle)
end

function AutoDrive:onFillTypeSelection(superFunc, fillType)
	if fillType ~= nil and fillType ~= FillType.UNKNOWN then
		local validFillableObject = self.validFillableObject
		if validFillableObject ~= nil then --and validFillableObject:getRootVehicle() == g_currentMission.controlledVehicle
			local fillUnitIndex = self.validFillableFillUnitIndex
			self:setIsLoading(true, validFillableObject, fillUnitIndex, fillType)
		end
	end
end

-- LoadTrigger doesn't allow filling non controlled tools
function AutoDrive:getIsActivatable(superFunc, objectToFill)
	--when the trigger is filling, it uses this function without objectToFill
	if objectToFill ~= nil then
		local vehicle = objectToFill:getRootVehicle()
		if vehicle ~= nil and vehicle.ad ~= nil and vehicle.ad.isActive then
			--if i'm in the vehicle, all is good and I can use the normal function, if not, i have to cheat:
			if g_currentMission.controlledVehicle ~= vehicle then
				local oldControlledVehicle = nil
				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle == nil then
					vehicle.ad.oldControlledVehicle = g_currentMission.controlledVehicle
				else
					oldControlledVehicle = g_currentMission.controlledVehicle
				end
				g_currentMission.controlledVehicle = vehicle or objectToFill

				local result = superFunc(self, objectToFill)

				if vehicle.ad ~= nil and vehicle.ad.oldControlledVehicle ~= nil then
					g_currentMission.controlledVehicle = vehicle.ad.oldControlledVehicle
					vehicle.ad.oldControlledVehicle = nil
				else
					if oldControlledVehicle ~= nil then
						g_currentMission.controlledVehicle = oldControlledVehicle
					end
				end
				return result
			end
		end
	end
	return superFunc(self, objectToFill)
end

function AutoDrive.renderTable(posX, posY, textSize, inputTable, maxDepth)
	maxDepth = maxDepth or 2
	local function renderTableRecursively(posX, posY, textSize, inputTable, depth, maxDepth, i)
		if depth >= maxDepth then
			return i
		end
		for k, v in pairs(inputTable) do
			local offset = i * textSize * 1.05
			setTextAlignment(RenderText.ALIGN_RIGHT)
			renderText(posX, posY - offset, textSize, tostring(k) .. " :")
			setTextAlignment(RenderText.ALIGN_LEFT)
			renderText(posX, posY - offset, textSize, " " .. tostring(v))
			i = i + 1
			if type(v) == "table" then
				i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, depth + 1, maxDepth, i)
			end
		end
		return i
	end
	local i = 0
	setTextColor(1, 1, 1, 1)
	setTextBold(false)
	textSize = getCorrectTextSize(textSize)
	for k, v in pairs(inputTable) do
		local offset = i * textSize * 1.05
		setTextAlignment(RenderText.ALIGN_RIGHT)
		renderText(posX, posY - offset, textSize, tostring(k) .. " :")
		setTextAlignment(RenderText.ALIGN_LEFT)
		renderText(posX, posY - offset, textSize, " " .. tostring(v))
		i = i + 1
		if type(v) == "table" then
			i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, 1, maxDepth, i)
		end
	end
end

function AutoDrive:loadTriggerLoad(superFunc, rootNode, xmlFile, xmlNode)
	local result = superFunc(self, rootNode, xmlFile, xmlNode)

	if result and AutoDrive.Triggers ~= nil then
		AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1
		AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = self
	end

	return result
end

function AutoDrive:loadTriggerDelete(superFunc)
	if AutoDrive.Triggers ~= nil then
		for i, trigger in pairs(AutoDrive.Triggers.siloTriggers) do
			if trigger == self then
				AutoDrive.Triggers.siloTriggers[i] = nil
			end
		end
	end
	superFunc(self)
end

addConsoleCommand("ADsetDebugLevel", "Set new debug level", "setDebugLevel", AutoDrive)

function AutoDrive:setDebugLevel(newDebugLevel)
	if newDebugLevel ~= nil then
		AutoDrive.currentDebugLevel = newDebugLevel
	else
		AutoDrive.currentDebugLevel = ADDEBUGLEVEL_ALL
	end
end

function AutoDrive:debugPrint(vehicle, debugLevel, debugText)
	if AutoDrive.currentDebugLevel >= debugLevel then
		local printText = ""
		if (vehicle ~= nil and vehicle.ad.name ~= nil) then
			printText = vehicle.ad.name .. ": "
		end

		printText = printText .. debugText

		print(printText)
	end
end

addConsoleCommand("ADshowNetworkEvents", "Debug network traffic", "showNetworkEvents", AutoDrive)

AutoDrive.debug = {}
AutoDrive.debug.connectionSendEventBackup = nil
AutoDrive.debug.serverBroadcastEventBackup = nil
AutoDrive.debug.lastSentEvent = nil
AutoDrive.debug.lastSentEventSize = 0
AutoDrive.debug.showNetworkEventsPrint = false

function AutoDrive:showNetworkEvents(print)
	AutoDrive.debug.showNetworkEventsPrint = print
	if g_server ~= nil then
		if AutoDrive.debug.serverBroadcastEventBackup == nil then
			AutoDrive.debug.serverBroadcastEventBackup = g_server.broadcastEvent
			g_server.broadcastEvent = Utils.overwrittenFunction(g_server.broadcastEvent, AutoDrive.ServerBroadcastEvent)
		else
			g_server.broadcastEvent = AutoDrive.debug.serverBroadcastEventBackup
			AutoDrive.debug.serverBroadcastEventBackup = nil
		end
	else
		local connection = g_client:getServerConnection()
		if AutoDrive.debug.connectionSendEventBackup == nil then
			AutoDrive.debug.connectionSendEventBackup = connection.sendEvent
			connection.sendEvent = Utils.overwrittenFunction(connection.sendEvent, AutoDrive.ConnectionSendEvent)
		else
			connection.sendEvent = AutoDrive.debug.connectionSendEventBackup
			AutoDrive.debug.connectionSendEventBackup = nil
		end
	end
	AutoDrive.debug.lastSentEvent = nil
end

function AutoDrive:ServerBroadcastEvent(superFunc, event, sendLocal, ignoreConnection, ghostObject, force)
	local eCopy = {}
	eCopy.event = tableClone(event)
	eCopy.eventName = eCopy.event.className or EventIds.eventIdToName[event.eventId]
	eCopy.sendLocal = sendLocal or false
	eCopy.ignoreConnection = ignoreConnection or "nil"
	eCopy.force = force or false
	eCopy.clients = table.getn(self.clientConnections)
	superFunc(self, event, sendLocal, ignoreConnection, ghostObject, force)
	eCopy.size = AutoDrive.debug.lastSentEventSize
	if AutoDrive.debug.showNetworkEventsPrint then
		g_logManager:info(string.format("Event %s size %s (x%s = %s) Bytes", eCopy.eventName, eCopy.size / (eCopy.clients), eCopy.clients, eCopy.size))
	end
	AutoDrive.debug.lastSentEvent = eCopy
end

function AutoDrive:ConnectionSendEvent(superFunc, event, deleteEvent, force)
	local eCopy = {}
	eCopy.event = tableClone(event)
	eCopy.eventName = eCopy.event.className or EventIds.eventIdToName[event.eventId]
	eCopy.deleteEvent = deleteEvent or true
	eCopy.force = force or false
	superFunc(self, event, deleteEvent, force)
	eCopy.size = AutoDrive.debug.lastSentEventSize
	if AutoDrive.debug.showNetworkEventsPrint then
		g_logManager:info(string.format("Event %s size %s Bytes", eCopy.eventName, eCopy.size))
	end
	AutoDrive.debug.lastSentEvent = eCopy
end

function NetworkNode:addPacketSize(packetType, packetSizeInBytes)
	if AutoDrive.debug.connectionSendEventBackup ~= nil and packetType == NetworkNode.PACKET_EVENT then
		AutoDrive.debug.lastSentEventSize = packetSizeInBytes
	end
	if self.showNetworkTraffic then
		self.packetBytes[packetType] = self.packetBytes[packetType] + packetSizeInBytes
	end
end

function tableClone(org)
	local otype = type(org)
	local copy
	if otype == "table" then
		copy = {}
		for org_key, org_value in pairs(org) do
			copy[org_key] = org_value
		end
	else -- number, string, boolean, etc
		copy = org
	end
	return copy
end

-- TODO: Maybe we should add a console command that allows to run console commands to server
